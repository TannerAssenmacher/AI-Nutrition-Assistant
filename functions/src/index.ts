/**
 * Genkit Cloud Functions for AI Nutrition Assistant
 *
 * Exports:
 * - onRecipeCreated: Firestore trigger to generate embeddings
 * - searchRecipes: Callable function for RAG recipe search
 *
 * Version: 1.0.3 - Migrated to gemini-embedding-001 (text-embedding-004 shut down Jan 14, 2026)
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import { Pool } from "pg";

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();

// Define secrets
const pgPassword = defineSecret("pg-password");
const geminiApiKey = defineSecret("gemini-api-key");

// PostgreSQL connection pool (lazy initialization)
let pool: Pool | null = null;

const INSTANCE_CONNECTION_NAME = "ai-nutrition-assistant-e2346:us-central1:recipe-vectors";

function getPool(): Pool {
  if (!pool) {
    const isProduction = process.env.K_SERVICE !== undefined;
    
    if (isProduction) {
      // In Cloud Functions, use the Cloud SQL Unix socket path
      // Cloud Run/Cloud Functions automatically mount Cloud SQL sockets
      pool = new Pool({
        host: `/cloudsql/${INSTANCE_CONNECTION_NAME}`,
        user: "postgres",
        password: pgPassword.value(),
        database: "recipes_db",
      });
    } else {
      // Local development - use Cloud SQL Proxy
      pool = new Pool({
        host: process.env.PG_HOST || "127.0.0.1",
        port: parseInt(process.env.PG_PORT || "5433"),
        user: process.env.PG_USER || "postgres",
        password: process.env.PG_PASSWORD,
        database: process.env.PG_DATABASE || "recipes_db",
      });
    }
  }
  return pool;
}

/**
 * Generate embedding for a recipe using Gemini REST API
 */
async function generateEmbedding(text: string): Promise<number[]> {
  const apiKey = geminiApiKey.value();
  // Use v1beta API with gemini-embedding-001
  // Note: text-embedding-004 was shut down on January 14, 2026
  // Using outputDimensionality=768 for compatibility with existing embeddings
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${apiKey}`;

  const fetch = (await import("node-fetch")).default;
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "models/gemini-embedding-001",
      content: { parts: [{ text }] },
      outputDimensionality: 768,  // Match existing text-embedding-004 dimensions
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    console.error(`Embedding API error: ${response.status}`);
    console.error(`Full error response: ${error}`);
    console.error(`Request URL: ${url}`);
    throw new Error(`Embedding API error: ${response.status} - ${error}`);
  }

  const data = await response.json() as any;
  return data.embedding.values;
}

/**
 * Create searchable text from recipe for embedding
 */
function createRecipeText(recipe: FirebaseFirestore.DocumentData): string {
  const parts = [
    recipe.label,
    recipe.cuisine,
    ...(recipe.mealTypes || []),
    ...(recipe.healthLabels || []),
    ...(recipe.ingredients || []).slice(0, 10), // First 10 ingredients
  ];
  return parts.filter(Boolean).join(" ");
}

/**
 * Estimate calories from recipe using Gemini
 */
async function estimateCalories(
  label: string,
  ingredients: string[]
): Promise<{ calories: number; protein: number; carbs: number; fat: number }> {
  try {
    const { GoogleGenerativeAI } = await import("@google/generative-ai");
    const genAI = new GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
    
    const prompt = `Estimate the nutritional values for one serving of this recipe.
Recipe: ${label}
Ingredients: ${ingredients.slice(0, 15).join(", ")}

Return ONLY a JSON object with these integer values (no text, no explanation):
{"calories": <number>, "protein": <number in grams>, "carbs": <number in grams>, "fat": <number in grams>}`;

    const result = await model.generateContent(prompt);
    const text = result.response.text().trim();
    
    // Extract JSON from response
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      const nutrition = JSON.parse(jsonMatch[0]);
      return {
        calories: Math.round(nutrition.calories) || 400,
        protein: Math.round(nutrition.protein) || 20,
        carbs: Math.round(nutrition.carbs) || 40,
        fat: Math.round(nutrition.fat) || 15,
      };
    }
  } catch (error) {
    console.error("Error estimating calories:", error);
  }
  // Default fallback
  return { calories: 400, protein: 20, carbs: 40, fat: 15 };
}

/**
 * Firestore Trigger: Generate embedding when a recipe is created
 */
export const onRecipeCreated = onDocumentCreated(
  {
    document: "recipes/{recipeId}",
    secrets: [pgPassword, geminiApiKey],
    // Memory and timeout for embedding generation
    memory: "512MiB",
    timeoutSeconds: 120,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data in snapshot");
      return;
    }

    const recipe = snapshot.data();
    const recipeId = event.params.recipeId;

    console.log(`Generating embedding for recipe: ${recipeId}`);

    try {
      // Generate embedding from recipe text
      const recipeText = createRecipeText(recipe);
      const embedding = await generateEmbedding(recipeText);

      // Insert into PostgreSQL
      const query = `
        INSERT INTO recipe_embeddings (
          id, embedding, label, cuisine, meal_types,
          health_labels, ingredients,
          calories, protein, carbs, fat, fiber, sugar, sodium,
          servings, ready_in_minutes
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
        ON CONFLICT (id) DO UPDATE SET
          embedding = EXCLUDED.embedding,
          label = EXCLUDED.label,
          cuisine = EXCLUDED.cuisine,
          meal_types = EXCLUDED.meal_types,
          health_labels = EXCLUDED.health_labels,
          ingredients = EXCLUDED.ingredients,
          calories = EXCLUDED.calories,
          protein = EXCLUDED.protein,
          carbs = EXCLUDED.carbs,
          fat = EXCLUDED.fat,
          fiber = EXCLUDED.fiber,
          sugar = EXCLUDED.sugar,
          sodium = EXCLUDED.sodium,
          servings = EXCLUDED.servings,
          ready_in_minutes = EXCLUDED.ready_in_minutes
      `;

      await getPool().query(query, [
        recipeId,
        `[${embedding.join(",")}]`,
        recipe.label,
        recipe.cuisine,
        recipe.mealTypes || [],
        recipe.healthLabels || [],
        recipe.ingredients || [],
        recipe.calories || null,
        recipe.protein || null,
        recipe.carbs || null,
        recipe.fat || null,
        recipe.fiber || null,
        recipe.sugar || null,
        recipe.sodium || null,
        recipe.servings || null,
        recipe.readyInMinutes || null,
      ]);

      console.log(`Embedding stored for recipe: ${recipeId}`);
    } catch (error) {
      console.error(`Error generating embedding for ${recipeId}:`, error);
      throw error;
    }
  }
);

/**
 * Search recipes using RAG
 */
interface SearchParams {
  query?: string;  // Free-form query text
  mealType?: string;
  cuisineType?: string;
  healthRestrictions?: string[];
  dietaryHabits?: string[];
  dislikes?: string[];
  likes?: string[];
  excludeIds?: string[];  // Recipe IDs to exclude (already shown)
  limit?: number;
  // User profile data for personalized filtering
  sex?: string;
  activityLevel?: string;
  dietaryGoal?: string;  // "Lose Weight", "Maintain Weight", "Gain Muscle"
  dailyCalorieGoal?: number;
  macroGoals?: { protein: number; carbs: number; fat: number };  // percentages of daily calories
  // Today's consumption data for smart calorie targeting
  consumedCalories?: number;        // Total calories consumed today so far
  consumedMealTypes?: string[];     // e.g. ["breakfast"] if breakfast already logged
  consumedMacros?: { protein: number; carbs: number; fat: number };  // grams consumed today
  // Physical profile for context
  dob?: string;                     // ISO date string for age calculation
  height?: number;                  // inches
  weight?: number;                  // pounds
}

/**
 * Standard meal calorie allocations (% of daily goal)
 */
const MEAL_CALORIE_PERCENTAGES: Record<string, number> = {
  breakfast: 0.25,
  lunch: 0.30,
  dinner: 0.35,
  snack: 0.10,
};

const ALL_MEAL_TYPES = ['breakfast', 'lunch', 'dinner', 'snack'];

interface CalorieTarget {
  targetCalories: number;
  minCalories: number;
  maxCalories: number;
}

/**
 * Calculate smart per-meal calorie target based on daily goal,
 * already consumed calories, and remaining meals.
 * Falls back to fixed percentages when no consumption data is available.
 */
function calculateSmartCalorieTarget(
  dailyCalorieGoal: number,
  mealType: string | undefined,
  consumedCalories?: number,
  consumedMealTypes?: string[],
): CalorieTarget {
  const mealLower = (mealType || '').toLowerCase();
  const mealPercent = MEAL_CALORIE_PERCENTAGES[mealLower] ?? 0.30;

  // If no consumption data, use fixed percentages (backward compatible)
  if (consumedCalories === undefined || consumedCalories === null || !consumedMealTypes) {
    const target = Math.round(dailyCalorieGoal * mealPercent);
    return {
      targetCalories: target,
      minCalories: Math.round(target * 0.50),
      maxCalories: Math.round(target * 1.30),
    };
  }

  // Smart calculation: distribute remaining calories proportionally
  const remainingCalories = Math.max(0, dailyCalorieGoal - consumedCalories);

  // Determine remaining meals (not yet consumed)
  const consumed = new Set(consumedMealTypes.map(m => m.toLowerCase()));
  const remainingMeals = ALL_MEAL_TYPES.filter(m => !consumed.has(m));

  // If the current meal type was already consumed (re-eating same type),
  // include it in remaining for proportional calculation
  if (!remainingMeals.includes(mealLower) && mealLower) {
    remainingMeals.push(mealLower);
  }

  // Sum up percentages of remaining meals
  const remainingPercentTotal = remainingMeals.reduce(
    (sum, m) => sum + (MEAL_CALORIE_PERCENTAGES[m] ?? 0), 0
  );

  // Avoid division by zero — fall back to fixed percentages
  if (remainingPercentTotal <= 0) {
    const target = Math.round(dailyCalorieGoal * mealPercent);
    return {
      targetCalories: target,
      minCalories: Math.round(target * 0.50),
      maxCalories: Math.round(target * 1.30),
    };
  }

  // This meal's share of remaining calories
  const targetCalories = Math.round(
    remainingCalories * (mealPercent / remainingPercentTotal)
  );

  return {
    targetCalories,
    minCalories: Math.round(targetCalories * 0.50),
    maxCalories: Math.round(targetCalories * 1.30),
  };
}

/**
 * Scored recipe result from the ranking pipeline
 */
interface ScoredRecipe {
  row: any;
  totalScore: number;
  breakdown: {
    dietaryGoalAlignment: number;
    calorieProximity: number;
    proteinProximity: number;
    carbsProximity: number;
    fatProximity: number;
    semanticSimilarity: number;
    likesBoost: number;
    servingsScore: number;
    prepTimeScore: number;
  };
}

/**
 * Calculate dietary goal alignment sub-score (0.0 to 1.0).
 * Tailored to the user's chosen goal direction.
 */
function calculateDietaryGoalScore(
  row: any,
  dietaryGoal: string | undefined,
  calorieTarget: CalorieTarget,
  macroGoals: { protein: number; carbs: number; fat: number } | undefined,
): number {
  if (!dietaryGoal || !row.calories || row.calories === 0) return 0.5; // neutral

  const goalLower = dietaryGoal.toLowerCase();
  const recipeProteinPct = (row.protein || 0) * 4 / row.calories * 100;
  const recipeFatPct = (row.fat || 0) * 9 / row.calories * 100;
  const recipeCarbsPct = (row.carbs || 0) * 4 / row.calories * 100;
  const userProteinPct = macroGoals?.protein ?? 20;
  const userFatPct = macroGoals?.fat ?? 30;
  const userCarbsPct = macroGoals?.carbs ?? 50;

  if (goalLower.includes('lose')) {
    // "Lose Weight" — prioritizes deficit and satiety
    let score = 0;
    // Calories at or below target: +0.35
    if (calorieTarget.targetCalories > 0) {
      score += (row.calories <= calorieTarget.targetCalories) ? 0.35 : 0.10;
    }
    // Higher fiber (>=5g): +0.15
    score += ((row.fiber || 0) >= 5) ? 0.15 : 0.05;
    // Protein% meets or exceeds goal: +0.25
    score += (recipeProteinPct >= userProteinPct) ? 0.25 : 0.08;
    // Fat% at or below goal: +0.15
    score += (recipeFatPct <= userFatPct + 5) ? 0.15 : 0.05;
    // Low sugar (<=10g): +0.10
    score += ((row.sugar || 0) <= 10) ? 0.10 : 0.03;
    return score;

  } else if (goalLower.includes('gain') || goalLower.includes('muscle')) {
    // "Gain Muscle" — prioritizes surplus and protein
    let score = 0;
    // Protein% meets or exceeds goal: +0.35
    score += (recipeProteinPct >= userProteinPct) ? 0.35 : 0.10;
    // Calories at or above target: +0.30
    if (calorieTarget.targetCalories > 0) {
      score += (row.calories >= calorieTarget.targetCalories * 0.9) ? 0.30 : 0.10;
    }
    // Absolute protein >= 25g per serving: +0.20
    score += ((row.protein || 0) >= 25) ? 0.20 : 0.05;
    // Carbs% meets goal (fuel for training): +0.15
    score += (Math.abs(recipeCarbsPct - userCarbsPct) <= 10) ? 0.15 : 0.05;
    return score;

  } else {
    // "Maintain Weight" — prioritizes balance and precision
    let score = 0;
    // Calories within 10% of target: +0.40
    if (calorieTarget.targetCalories > 0) {
      const calDiff = Math.abs(row.calories - calorieTarget.targetCalories) / calorieTarget.targetCalories;
      score += (calDiff <= 0.10) ? 0.40 : (calDiff <= 0.20) ? 0.25 : 0.10;
    }
    // All three macros within 5 percentage points of goals: +0.30
    const proteinClose = Math.abs(recipeProteinPct - userProteinPct) <= 5;
    const carbsClose = Math.abs(recipeCarbsPct - userCarbsPct) <= 5;
    const fatClose = Math.abs(recipeFatPct - userFatPct) <= 5;
    const macrosClose = [proteinClose, carbsClose, fatClose].filter(Boolean).length;
    score += macrosClose * 0.10; // 0.10 per close macro, max 0.30
    // Fiber >= 3g: +0.15
    score += ((row.fiber || 0) >= 3) ? 0.15 : 0.05;
    // Reasonable sodium (<800mg): +0.15
    score += ((row.sodium || 0) < 800) ? 0.15 : 0.05;
    return score;
  }
}

/**
 * Score a recipe candidate using all available criteria.
 * Returns a total score (0.0 to 1.0) with breakdown.
 *
 * Weight distribution:
 *   Goal-related (70%): dietary goal 0.25, calorie 0.25, protein 0.08, carbs 0.06, fat 0.06
 *   Preference (30%): similarity 0.10, likes 0.10, servings 0.05, prepTime 0.05
 */
function scoreRecipe(
  row: any,
  calorieTarget: CalorieTarget,
  macroGoals: { protein: number; carbs: number; fat: number } | undefined,
  dailyCalorieGoal: number | undefined,
  likes: string[],
  dietaryGoal: string | undefined,
): ScoredRecipe {
  const breakdown = {
    dietaryGoalAlignment: 0,
    calorieProximity: 0,
    proteinProximity: 0,
    carbsProximity: 0,
    fatProximity: 0,
    semanticSimilarity: 0,
    likesBoost: 0,
    servingsScore: 0,
    prepTimeScore: 0,
  };

  // 1. Dietary goal alignment — weight: 0.25
  const goalScore = calculateDietaryGoalScore(row, dietaryGoal, calorieTarget, macroGoals);
  breakdown.dietaryGoalAlignment = goalScore * 0.25;

  // 2. Calorie proximity — weight: 0.25
  if (calorieTarget.targetCalories > 0 && row.calories) {
    const calDiff = Math.abs(row.calories - calorieTarget.targetCalories);
    const calRange = calorieTarget.maxCalories - calorieTarget.minCalories;
    const calScore = Math.max(0, 1 - calDiff / Math.max(calRange, 1));
    breakdown.calorieProximity = calScore * 0.25;
  } else {
    breakdown.calorieProximity = 0.125; // neutral if no target
  }

  // 3-5. Macro proximity scores — protein 0.08, carbs 0.06, fat 0.06
  if (macroGoals && row.calories && row.calories > 0) {
    const recipeProteinPct = (row.protein || 0) * 4 / row.calories * 100;
    const recipeCarbsPct = (row.carbs || 0) * 4 / row.calories * 100;
    const recipeFatPct = (row.fat || 0) * 9 / row.calories * 100;
    const maxDiff = 30; // percentage points

    const proteinDiff = Math.abs(recipeProteinPct - macroGoals.protein);
    const carbsDiff = Math.abs(recipeCarbsPct - macroGoals.carbs);
    const fatDiff = Math.abs(recipeFatPct - macroGoals.fat);

    breakdown.proteinProximity = Math.max(0, 1 - proteinDiff / maxDiff) * 0.08;
    breakdown.carbsProximity = Math.max(0, 1 - carbsDiff / maxDiff) * 0.06;
    breakdown.fatProximity = Math.max(0, 1 - fatDiff / maxDiff) * 0.06;
  } else {
    breakdown.proteinProximity = 0.04;
    breakdown.carbsProximity = 0.03;
    breakdown.fatProximity = 0.03;
  }

  // 6. Semantic similarity — weight: 0.10
  breakdown.semanticSimilarity = (row.similarity || 0) * 0.10;

  // 7. Likes match (ingredients + label) — weight: 0.10
  if (likes.length > 0) {
    const likesLower = likes.map(l => l.toLowerCase());
    const labelLower = (row.label || '').toLowerCase();
    const ingredientsLower: string[] = (row.ingredients || []).map((i: string) => i.toLowerCase());

    let matchCount = 0;
    for (const like of likesLower) {
      // Check label first
      if (labelLower.includes(like)) {
        matchCount++;
        continue;
      }
      // Check ingredients
      if (ingredientsLower.some((ing: string) => ing.includes(like))) {
        matchCount++;
      }
    }

    const likesScore = Math.min(1, matchCount / Math.max(likes.length, 1));
    breakdown.likesBoost = likesScore * 0.10;
  } else {
    breakdown.likesBoost = 0.05; // neutral if no likes
  }

  // 8. Servings appropriateness — weight: 0.05
  const servings = row.servings || 4;
  if (servings >= 1 && servings <= 4) {
    breakdown.servingsScore = 1.0 * 0.05;
  } else if (servings <= 6) {
    breakdown.servingsScore = 0.7 * 0.05;
  } else {
    breakdown.servingsScore = 0.4 * 0.05;
  }

  // 9. Prep time — weight: 0.05
  const readyInMinutes = row.ready_in_minutes || row.readyInMinutes || 30;
  if (readyInMinutes <= 30) {
    breakdown.prepTimeScore = 1.0 * 0.05;
  } else if (readyInMinutes <= 60) {
    breakdown.prepTimeScore = 0.7 * 0.05;
  } else {
    breakdown.prepTimeScore = 0.4 * 0.05;
  }

  const totalScore =
    breakdown.dietaryGoalAlignment +
    breakdown.calorieProximity +
    breakdown.proteinProximity +
    breakdown.carbsProximity +
    breakdown.fatProximity +
    breakdown.semanticSimilarity +
    breakdown.likesBoost +
    breakdown.servingsScore +
    breakdown.prepTimeScore;

  return { row, totalScore, breakdown };
}

/**
 * Image Proxy for CORS workaround
 * Proxies Spoonacular images so they can be loaded on Flutter Web
 */
export const proxyImage = onRequest(
  { cors: true },
  async (request, response) => {
    const imageUrl = request.query.url as string;

    if (!imageUrl || !imageUrl.startsWith('https://img.spoonacular.com/')) {
      response.status(400).send('Invalid image URL');
      return;
    }

    try {
      const fetch = (await import('node-fetch')).default;
      const imageResponse = await fetch(imageUrl);

      if (!imageResponse.ok) {
        response.status(404).send('Image not found');
        return;
      }

      // Set CORS headers
      response.set('Access-Control-Allow-Origin', '*');
      response.set('Cache-Control', 'public, max-age=86400'); // Cache for 1 day
      response.set('Content-Type', imageResponse.headers.get('content-type') || 'image/jpeg');

      const arrayBuffer = await imageResponse.arrayBuffer();
      response.send(Buffer.from(arrayBuffer));
    } catch (error) {
      console.error('Error proxying image:', error);
      response.status(500).send('Error loading image');
    }
  }
);

export const searchRecipes = onCall<SearchParams>(
  {
    cors: true,
    secrets: [pgPassword, geminiApiKey],
  },
  async (request) => {
    const {
      query,
      mealType,
      cuisineType,
      healthRestrictions = [],
      dietaryHabits = [],
      dislikes = [],
      likes = [],
      excludeIds = [],
      limit = 10,
      // User profile data
      sex,
      activityLevel,
      dietaryGoal,
      dailyCalorieGoal,
      macroGoals,
      // Today's consumption data
      consumedCalories,
      consumedMealTypes = [],
      // consumedMacros is sent by client but not yet used in scoring
      // (macro matching uses percentage goals, not remaining grams)
      // Physical profile
      dob,
      height,
      weight,
    } = request.data;

    try {
      // Build rich query text for semantic search incorporating user goals
      let queryText: string;
      if (query) {
        queryText = query;
      } else {
        const queryParts: string[] = [];
        
        // Meal context
        if (mealType) queryParts.push(mealType);
        if (cuisineType && cuisineType.toLowerCase() !== 'none' && cuisineType.toLowerCase() !== 'no preference') queryParts.push(cuisineType);
        
        // User food preferences
        if (likes.length > 0) queryParts.push(...likes);
        
        // Dietary habits enhance semantic matching
        if (dietaryHabits.length > 0) queryParts.push(...dietaryHabits);
        
        // Dietary goal context for semantic relevance
        if (dietaryGoal) {
          if (dietaryGoal.toLowerCase().includes('lose')) {
            queryParts.push('low calorie', 'light', 'healthy');
          } else if (dietaryGoal.toLowerCase().includes('gain') || dietaryGoal.toLowerCase().includes('muscle')) {
            queryParts.push('high protein', 'calorie dense', 'nutritious');
          } else {
            queryParts.push('balanced', 'nutritious');
          }
        }

        // Macro focus for semantic matching
        if (macroGoals) {
          if (macroGoals.protein >= 30) queryParts.push('high protein');
          if (macroGoals.fat <= 25) queryParts.push('low fat');
          if (macroGoals.carbs <= 30) queryParts.push('low carb');
        }

        // Activity level context
        if (activityLevel) {
          const actLower = activityLevel.toLowerCase();
          if (actLower.includes('very') || actLower.includes('extra')) {
            queryParts.push('high energy', 'protein rich');
          } else if (actLower.includes('sedentary') || actLower.includes('low')) {
            queryParts.push('light portions');
          }
        }

        // BMI-based context from height & weight
        if (height && weight && height > 0) {
          const bmi = (weight / (height * height)) * 703; // imperial BMI
          if (bmi < 18.5) {
            queryParts.push('calorie dense', 'energy rich');
          } else if (bmi > 30) {
            queryParts.push('light', 'low calorie');
          }
        }

        // Age-based context from dob
        if (dob) {
          const age = Math.floor(
            (Date.now() - new Date(dob).getTime()) / (365.25 * 24 * 60 * 60 * 1000)
          );
          if (age >= 60) queryParts.push('easy to prepare');
          if (age >= 13 && age <= 19) queryParts.push('growth supporting');
        }

        queryText = queryParts.filter(Boolean).join(' ');
      }
      
      if (!queryText) {
        queryText = 'delicious healthy meal';  // Fallback
      }

      console.log('Searching with query:', queryText);
      console.log('User profile - Goal:', dietaryGoal, 'Calories:', dailyCalorieGoal, 'Macros:', macroGoals,
        'Activity:', activityLevel, 'Sex:', sex);

      // Generate query embedding
      console.log('Generating embedding for query...');
      const queryEmbedding = await generateEmbedding(queryText);
      console.log('Embedding generated successfully. Length:', queryEmbedding.length);

      // Build SQL query with filters and vector similarity
      let sql = `
        SELECT
          id,
          label,
          cuisine,
          meal_types,
          health_labels,
          ingredients,
          calories,
          protein,
          carbs,
          fat,
          fiber,
          sugar,
          sodium,
          servings,
          ready_in_minutes,
          1 - (embedding <=> $1::vector) as similarity
        FROM recipe_embeddings
        WHERE 1=1
      `;
      
      const params: any[] = [`[${queryEmbedding.join(",")}]`];
      let paramIndex = 2;

      // Filter by meal type
      if (mealType) {
        sql += ` AND $${paramIndex} = ANY(meal_types)`;
        params.push(mealType.toLowerCase());
        paramIndex++;
      }

      // Filter by cuisine
      // "Asian" is a meta-cuisine in the app that maps to multiple DB cuisines
      const ASIAN_CUISINES = ['chinese', 'japanese', 'korean', 'thai', 'vietnamese'];
      if (cuisineType && cuisineType.toLowerCase() !== "none" && cuisineType.toLowerCase() !== "no preference") {
        if (cuisineType.toLowerCase() === "asian") {
          sql += ` AND cuisine = ANY($${paramIndex}::text[])`;
          params.push(ASIAN_CUISINES);
        } else {
          sql += ` AND cuisine = $${paramIndex}`;
          params.push(cuisineType.toLowerCase());
        }
        paramIndex++;
      }

      // Filter by health restrictions (recipe must have ALL user's restrictions)
      if (healthRestrictions.length > 0) {
        sql += ` AND health_labels @> $${paramIndex}::text[]`;
        params.push(healthRestrictions.map(h => h.toLowerCase()));
        paramIndex++;
      }

      // Exclude recipes containing disliked ingredients
      if (dislikes.length > 0) {
        sql += ` AND NOT (ingredients && $${paramIndex}::text[])`;
        params.push(dislikes.map(d => d.toLowerCase()));
        paramIndex++;
      }

      // NOTE: Calorie range and macro hard filters have been removed.
      // These are now handled by the post-fetch scoring function which
      // provides weighted ranking instead of binary exclusion.

      // Exclude already shown recipes
      if (excludeIds.length > 0) {
        sql += ` AND id != ALL($${paramIndex}::text[])`;
        params.push(excludeIds);
        paramIndex++;
      }

      // Fetch extra candidates for scoring (score before Firestore reads)
      const fetchLimit = limit * 3;
      sql += ` ORDER BY similarity DESC LIMIT $${paramIndex}`;
      params.push(fetchLimit);

      console.log("Executing search query:", sql);
      console.log("Params:", params.slice(1)); // Skip embedding for logging

      console.log('Querying PostgreSQL...');
      let result = await getPool().query(sql, params);
      console.log(`PostgreSQL returned ${result.rows.length} results`);
      let isExactMatch = true;

      // If no results with strict filters, try graduated relaxation.
      // Priority: ALWAYS keep mealType and cuisine (user explicitly selected these).
      // Fallback 1: Drop only healthRestrictions
      // Fallback 2: Drop healthRestrictions + cuisine (keep mealType)
      if (result.rows.length === 0) {
        console.log("No exact matches found, trying relaxed search (drop health restrictions only)...");
        // isExactMatch stays true here because cuisine + mealType are still kept

        let relaxedSql = `
          SELECT
            id,
            label,
            cuisine,
            meal_types,
            health_labels,
            ingredients,
            calories,
            protein,
            carbs,
            fat,
            fiber,
            sugar,
            sodium,
            servings,
            ready_in_minutes,
            1 - (embedding <=> $1::vector) as similarity
          FROM recipe_embeddings
          WHERE 1=1
        `;

        const relaxedParams: any[] = [`[${queryEmbedding.join(",")}]`];
        let relaxedParamIndex = 2;

        // ALWAYS keep mealType filter (user's explicit selection)
        if (mealType) {
          relaxedSql += ` AND $${relaxedParamIndex} = ANY(meal_types)`;
          relaxedParams.push(mealType.toLowerCase());
          relaxedParamIndex++;
        }

        // Keep cuisine filter in first relaxation attempt
        if (cuisineType && cuisineType.toLowerCase() !== "none" && cuisineType.toLowerCase() !== "no preference") {
          if (cuisineType.toLowerCase() === "asian") {
            relaxedSql += ` AND cuisine = ANY($${relaxedParamIndex}::text[])`;
            relaxedParams.push(ASIAN_CUISINES);
          } else {
            relaxedSql += ` AND cuisine = $${relaxedParamIndex}`;
            relaxedParams.push(cuisineType.toLowerCase());
          }
          relaxedParamIndex++;
        }

        // Still exclude disliked ingredients (important for allergies/preferences)
        if (dislikes.length > 0) {
          relaxedSql += ` AND NOT (ingredients && $${relaxedParamIndex}::text[])`;
          relaxedParams.push(dislikes.map(d => d.toLowerCase()));
          relaxedParamIndex++;
        }

        // Still exclude already shown recipes
        if (excludeIds.length > 0) {
          relaxedSql += ` AND id != ALL($${relaxedParamIndex}::text[])`;
          relaxedParams.push(excludeIds);
          relaxedParamIndex++;
        }

        const relaxedFetchLimit = limit * 3;
        relaxedSql += ` ORDER BY similarity DESC LIMIT $${relaxedParamIndex}`;
        relaxedParams.push(relaxedFetchLimit);

        console.log("Executing relaxed search (no health restrictions):", relaxedSql);
        result = await getPool().query(relaxedSql, relaxedParams);

        // Fallback 2: If still no results, drop cuisine but keep mealType
        if (result.rows.length === 0 && cuisineType && cuisineType.toLowerCase() !== "none" && cuisineType.toLowerCase() !== "no preference") {
          console.log("Still no results, trying without cuisine filter (keeping mealType)...");
          isExactMatch = false; // Only mark as non-exact when cuisine is dropped

          let fallback2Sql = `
            SELECT
              id, label, cuisine, meal_types, health_labels, ingredients,
              calories, protein, carbs, fat, fiber, sugar, sodium,
              servings, ready_in_minutes,
              1 - (embedding <=> $1::vector) as similarity
            FROM recipe_embeddings
            WHERE 1=1
          `;

          const fb2Params: any[] = [`[${queryEmbedding.join(",")}]`];
          let fb2Index = 2;

          // Keep mealType — never drop this
          if (mealType) {
            fallback2Sql += ` AND $${fb2Index} = ANY(meal_types)`;
            fb2Params.push(mealType.toLowerCase());
            fb2Index++;
          }

          if (dislikes.length > 0) {
            fallback2Sql += ` AND NOT (ingredients && $${fb2Index}::text[])`;
            fb2Params.push(dislikes.map(d => d.toLowerCase()));
            fb2Index++;
          }

          if (excludeIds.length > 0) {
            fallback2Sql += ` AND id != ALL($${fb2Index}::text[])`;
            fb2Params.push(excludeIds);
            fb2Index++;
          }

          fallback2Sql += ` ORDER BY similarity DESC LIMIT $${fb2Index}`;
          fb2Params.push(relaxedFetchLimit);

          console.log("Executing fallback 2 (mealType only):", fallback2Sql);
          result = await getPool().query(fallback2Sql, fb2Params);
        }
      }

      // --- SCORING PIPELINE ---
      // Step 1: Calculate smart calorie target
      const calorieTarget = (dailyCalorieGoal && dailyCalorieGoal > 0)
        ? calculateSmartCalorieTarget(dailyCalorieGoal, mealType, consumedCalories, consumedMealTypes)
        : { targetCalories: 0, minCalories: 0, maxCalories: 0 };

      console.log('Smart calorie target:', calorieTarget);
      if (consumedCalories !== undefined) {
        console.log(`Consumed today: ${consumedCalories} cal, meals: [${consumedMealTypes.join(', ')}]`);
      }

      // Step 2: Filter out label-matched dislikes (hard filter in TypeScript)
      let candidates = result.rows;
      if (dislikes.length > 0) {
        const dislikesLower = dislikes.map(d => d.toLowerCase());
        candidates = candidates.filter(row => {
          const labelLower = (row.label || '').toLowerCase();
          return !dislikesLower.some(d => labelLower.includes(d));
        });
        console.log(`After label dislikes filter: ${candidates.length} candidates`);
      }

      // Step 3: Score all candidates
      const scored = candidates.map(row =>
        scoreRecipe(row, calorieTarget, macroGoals, dailyCalorieGoal, likes, dietaryGoal)
      );

      // Step 4: Sort by score descending, take top `limit`
      scored.sort((a, b) => b.totalScore - a.totalScore);
      const topResults = scored.slice(0, limit);

      console.log('Top scored results:', topResults.map(s => ({
        label: s.row.label,
        score: s.totalScore.toFixed(3),
        breakdown: Object.fromEntries(
          Object.entries(s.breakdown).map(([k, v]) => [k, (v as number).toFixed(3)])
        ),
      })));

      // Step 5: Firestore enrichment (only for top results — same cost as before)
      const recipes = await Promise.all(
        topResults.map(async ({ row, totalScore }) => {
          const recipeDoc = await db.collection("recipes").doc(row.id).get();
          const recipeData = recipeDoc.data();
          const ingredients = recipeData?.ingredientLines || row.ingredients || [];

          // Estimate nutrition if calories are null/0
          let calories = row.calories;
          let protein = row.protein;
          let carbs = row.carbs;
          let fat = row.fat;

          if (!calories || calories === 0) {
            console.log(`Estimating nutrition for: ${row.label}`);
            const estimated = await estimateCalories(row.label, ingredients);
            calories = estimated.calories;
            protein = estimated.protein;
            carbs = estimated.carbs;
            fat = estimated.fat;
          }

          return {
            id: row.id,
            label: row.label,
            cuisine: row.cuisine,
            ingredients: ingredients,
            instructions: recipeData?.instructions || "",
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: row.fiber,
            sugar: row.sugar,
            sodium: row.sodium,
            imageUrl: recipeData?.imageUrl,
            readyInMinutes: recipeData?.readyInMinutes,
            servings: recipeData?.servings,
            similarity: row.similarity,
            matchScore: totalScore,
          };
        })
      );

      return { recipes, isExactMatch };
    } catch (error) {
      console.error("Error searching recipes:", error);
      throw new HttpsError("internal", "Failed to search recipes");
    }
  }
);
