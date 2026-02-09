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
const usdaApiKey = defineSecret("USDA_API_KEY");
const openAiApiKey = defineSecret("OPENAI_API_KEY");
const spoonacularApiKey = defineSecret("SPOONACULAR_API_KEY");

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

/**
 * Secure Gemini proxy callable.
 * Keeps Gemini API key in Cloud Functions secrets instead of client.
 */
export const callGemini = onCall(
  {
    cors: true,
    invoker: 'public',
    secrets: [geminiApiKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'User must be authenticated to call Gemini'
      );
    }

    const prompt = (request.data?.prompt || '').toString();
    const systemInstruction = (request.data?.systemInstruction || '').toString();
    const modelName =
      (request.data?.model || 'gemini-2.5-flash').toString().trim() ||
      'gemini-2.5-flash';
    const imageBase64 = normalizeBase64Payload(
      (request.data?.imageBase64 || '').toString()
    );
    const mimeType = (request.data?.mimeType || 'image/jpeg').toString();

    if (!prompt.trim() && !imageBase64) {
      throw new HttpsError(
        'invalid-argument',
        'Prompt or imageBase64 is required'
      );
    }

    const rawHistory = Array.isArray(request.data?.history)
      ? request.data.history
      : [];
    const history = rawHistory
      .map((entry: any) => {
        const text = (entry?.text || '').toString().trim();
        if (!text) {
          return null;
        }
        const roleRaw = (entry?.role || '').toString().toLowerCase();
        const role = roleRaw === 'model' ? 'model' : 'user';
        return {
          role,
          parts: [{ text }],
        };
      })
      .filter((entry: any) => entry !== null)
      .slice(-20);

    try {
      const { GoogleGenerativeAI } = await import('@google/generative-ai');
      const genAI = new GoogleGenerativeAI(geminiApiKey.value());
      const model = genAI.getGenerativeModel({
        model: modelName,
        ...(systemInstruction ? { systemInstruction } : {}),
      });

      let text = '';
      if (imageBase64) {
        const parts: any[] = [];
        if (prompt.trim()) {
          parts.push({ text: prompt.trim() });
        }
        parts.push({
          inlineData: {
            mimeType,
            data: imageBase64,
          },
        });

        const response = await model.generateContent({
          contents: [{ role: 'user', parts }],
        });
        text = response.response.text();
      } else if (history.length > 0) {
        const chat = model.startChat({ history });
        const response = await chat.sendMessage(prompt);
        text = response.response.text();
      } else {
        const response = await model.generateContent(prompt);
        text = response.response.text();
      }

      if (!text || !text.trim()) {
        throw new HttpsError('internal', 'Gemini returned an empty response');
      }

      return { text };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error('Gemini callable failed:', error);
      throw new HttpsError('internal', 'Gemini request failed');
    }
  }
);

/**
 * Analyze meal image via OpenAI Responses API.
 * Keeps OpenAI API key in Cloud Functions secrets instead of client.
 */
export const analyzeMealImage = onCall(
  {
    cors: true,
    invoker: 'public',
    secrets: [openAiApiKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'User must be authenticated to analyze meal images'
      );
    }

    const imageBase64Raw = (request.data?.imageBase64 || '').toString();
    const imageBase64 = normalizeBase64Payload(imageBase64Raw);
    const mimeType = (request.data?.mimeType || 'image/jpeg').toString();
    const userContextRaw = (request.data?.userContext || '').toString().trim();
    const userContext = userContextRaw.length > 500
      ? userContextRaw.substring(0, 500)
      : userContextRaw;

    if (!imageBase64) {
      throw new HttpsError('invalid-argument', 'imageBase64 is required');
    }

    const imageUrl = `data:${mimeType};base64,${imageBase64}`;

    try {
      const response = await fetch('https://api.openai.com/v1/responses', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${openAiApiKey.value()}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'gpt-5.2',
          reasoning: { effort: 'low' },
          max_output_tokens: 3000,
          input: [
            {
              role: 'system',
              content: [
                {
                  type: 'input_text',
                  text: 'You are a nutrition expert. Analyze meal images and return ONLY valid JSON. '
                    + 'THINK STEP-BY-STEP (internally) BEFORE ANSWERING: identify foods → determine mass → derive per-gram macros → scale to mass → compute calories with 4/4/9 → sanity-check totals. '
                    + 'DO NOT return your reasoning, only the final JSON. '
                    + 'OUTPUT FORMAT: {"f":[{"n":"food name","m":grams,"k":calories,"p":protein_g,"c":carbs_g,"a":fat_g}]} '
                    + 'RULES: '
                    + '- All numeric values must be numbers, not strings. '
                    + '- Use at least 1 decimal place for grams/calories when appropriate. '
                    + '- k MUST equal (p×4)+(c×4)+(a×9) exactly. '
                    + '- If a scale shows weight, that is the authoritative mass; for multiple items on one scale, estimate proportional weight per item. '
                    + '- Prefer slightly conservative estimates over overestimates when uncertain. '
                    + 'Example: 150g chicken breast → ~46.5g protein, ~0g carbs, ~4.5g fat → (46.5×4)+(0×4)+(4.5×9) = 226.5 calories',
                },
              ],
            },
            {
              role: 'user',
              content: [
                {
                  type: 'input_text',
                  text: 'Analyze this meal and break down each food item.',
                },
                ...(userContext
                  ? [{
                    type: 'input_text',
                    text: `User context (optional): ${userContext}`,
                  }]
                  : []),
                {
                  type: 'input_image',
                  image_url: imageUrl,
                },
              ],
            },
          ],
        }),
      });

      if (!response.ok) {
        const body = await response.text();
        throw new HttpsError(
          'unavailable',
          `OpenAI API error: ${response.status} ${response.statusText} - ${body}`
        );
      }

      const data = await response.json() as any;
      const rawText = extractOpenAiTextResponse(data);
      const parsed = JSON.parse(extractFirstJsonObject(rawText)) as any;
      const analysis = normalizeMealAnalysisPayload(parsed);

      return { analysis };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error('analyzeMealImage failed:', error);
      throw new HttpsError('internal', 'Meal analysis failed');
    }
  }
);

/**
 * Lookup a packaged food by UPC/GTIN barcode via USDA FoodData Central.
 * Requires authentication (including anonymous auth)
 */
export const lookupFoodByBarcode = onCall(
  {
    cors: true,
    invoker: 'public',
    secrets: [usdaApiKey],
  },
  async (request) => {
    // Verify user is authenticated (including anonymous users)
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'User must be authenticated to look up barcodes'
      );
    }

    const rawBarcode = (request.data?.barcode || '').toString().trim();
    const barcode = normalizeBarcode(rawBarcode);
    if (!barcode || barcode.length < 8) {
      throw new HttpsError('invalid-argument', 'A valid barcode is required');
    }

    try {
      const apiKey = usdaApiKey.value();
      const candidates = barcodeCandidates(barcode);
      const canonicalCode = canonicalBarcode(barcode);
      console.log('lookupFoodByBarcode request', {
        rawBarcode,
        normalized: barcode,
        canonical: canonicalCode,
        candidates,
      });
      const foods: any[] = [];
      for (const candidate of candidates) {
        const usdaUrl = new URL('https://api.nal.usda.gov/fdc/v1/foods/search');
        usdaUrl.searchParams.set('api_key', apiKey);
        usdaUrl.searchParams.set('query', candidate);
        usdaUrl.searchParams.set('pageSize', '20');
        usdaUrl.searchParams.set('dataType', 'Branded');

        const response = await fetch(usdaUrl.toString());
        if (!response.ok) {
          throw new HttpsError(
            'unavailable',
            `USDA API error: ${response.status} ${response.statusText}`
          );
        }

        const data = (await response.json()) as any;
        const batch = Array.isArray(data?.foods) ? data.foods : [];
        console.log('USDA barcode search', {
          candidate,
          results: batch.length,
        });
        foods.push(...batch);
        if (foods.length > 0) {
          break;
        }
      }

      if (foods.length === 0) {
        console.log('USDA barcode search returned 0 results', { candidates });
        const openFoodFactsFallback = await lookupOpenFoodFactsByBarcode(
          candidates,
          canonicalCode
        );
        if (openFoodFactsFallback) {
          console.log('Open Food Facts fallback hit', {
            barcode: openFoodFactsFallback.barcode,
          });
          return { result: openFoodFactsFallback };
        }
        throw new HttpsError(
          'not-found',
          `No food found for barcode ${barcode}`
        );
      }

      const exactMatch = foods.find((food: any) => {
        const gtin = canonicalBarcode((food?.gtinUpc || '').toString());
        return gtin === canonicalCode;
      });
      const selected = exactMatch ?? foods[0];
      console.log('USDA barcode selection', {
        exactMatch: Boolean(exactMatch),
        selectedFdcId: selected?.fdcId,
        selectedGtin: selected?.gtinUpc || null,
      });

      const name = (selected?.description || '').toString().trim();
      if (!name) {
        throw new HttpsError(
          'not-found',
          `Food result for barcode ${barcode} has no description`
        );
      }

      const servingGrams = resolveServingGrams(selected);
      const nutrients = Array.isArray(selected?.foodNutrients)
        ? selected.foodNutrients
        : [];
      const labelNutrients = selected?.labelNutrients || {};

      const calories =
        findNutrient(nutrients, [1008], ['Energy']) ??
        toNullableNumber(labelNutrients?.calories?.value) ??
        toNullableNumber(labelNutrients?.calories);
      const protein =
        findNutrient(nutrients, [1003], ['Protein']) ??
        toNullableNumber(labelNutrients?.protein?.value) ??
        toNullableNumber(labelNutrients?.protein) ??
        0;
      const carbs =
        findNutrient(nutrients, [1005], ['Carbohydrate']) ??
        toNullableNumber(labelNutrients?.carbohydrates?.value) ??
        toNullableNumber(labelNutrients?.carbohydrates) ??
        0;
      const fat =
        findNutrient(nutrients, [1004], ['Total lipid (fat)']) ??
        toNullableNumber(labelNutrients?.fat?.value) ??
        toNullableNumber(labelNutrients?.fat) ??
        0;

      if (calories === null) {
        const openFoodFactsFallback = await lookupOpenFoodFactsByBarcode(
          [
            normalizeBarcode((selected?.gtinUpc || '').toString()),
            ...candidates,
          ],
          canonicalCode
        );
        if (openFoodFactsFallback) {
          return { result: openFoodFactsFallback };
        }
        throw new HttpsError(
          'not-found',
          `No nutrition facts found for barcode ${barcode}`
        );
      }

      const resolvedBarcodeRaw =
        normalizeBarcode((selected?.gtinUpc || '').toString()) || barcode;
      const displayBarcode =
        canonicalBarcode(resolvedBarcodeRaw) || canonicalCode || barcode;
      return {
        result: {
          id: `usda_barcode_${selected?.fdcId || barcode}`,
          barcode: displayBarcode,
          name,
          caloriesPerGram: calories / servingGrams,
          proteinPerGram: protein / servingGrams,
          carbsPerGram: carbs / servingGrams,
          fatPerGram: fat / servingGrams,
          servingGrams,
          source: 'usda',
          brand: (selected?.brandOwner || '').toString().trim(),
        },
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error('USDA barcode lookup failed:', error);
      throw new HttpsError('internal', 'Barcode lookup failed');
    }
  }
);

/**
 * Search foods via USDA FoodData Central, with Spoonacular fallback
 * Requires authentication (including anonymous auth)
 */
export const searchFoods = onCall(
  {
    cors: true,
    invoker: 'public',
    secrets: [usdaApiKey, spoonacularApiKey],
  },
  async (request) => {
    // Verify user is authenticated (including anonymous users)
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'User must be authenticated to search foods'
      );
    }

    const query = (request.data?.query || '').toString().trim();
    if (!query) {
      throw new HttpsError('invalid-argument', 'Query is required');
    }

    const results: any[] = [];

    // USDA FoodData Central API
    try {
      const apiKey = usdaApiKey.value();
      const usdaUrl = new URL('https://api.nal.usda.gov/fdc/v1/foods/search');
      usdaUrl.searchParams.set('api_key', apiKey);
      usdaUrl.searchParams.set('query', query);
      usdaUrl.searchParams.set('pageSize', '10');
      usdaUrl.searchParams.set('dataType', 'Foundation,SR Legacy');

      const response = await fetch(usdaUrl.toString());

      if (response.ok) {
        const data = (await response.json()) as any;
        const foods = Array.isArray(data?.foods) ? data.foods : [];

        for (const food of foods) {
          const name = (food?.description || '').toString().trim();
          if (!name) continue;

          const nutrients = Array.isArray(food?.foodNutrients)
            ? food.foodNutrients
            : [];

          // USDA nutrient IDs: 1008=Energy, 1003=Protein, 1005=Carbs, 1004=Fat
          const calories = findNutrient(nutrients, [1008], ['Energy']);
          const protein = findNutrient(nutrients, [1003], ['Protein']);
          const carbs = findNutrient(nutrients, [1005], ['Carbohydrate']);
          const fat = findNutrient(nutrients, [1004], ['Total lipid (fat)']);

          if (calories === null) continue;

          // USDA nutrients are per 100g
          const servingGrams = 100;

          results.push({
            id: `usda_${food?.fdcId || name}`,
            name,
            caloriesPerGram: calories / servingGrams,
            proteinPerGram: (protein || 0) / servingGrams,
            carbsPerGram: (carbs || 0) / servingGrams,
            fatPerGram: (fat || 0) / servingGrams,
            servingGrams,
            source: 'usda',
          });
        }

        console.log(`USDA returned ${results.length} results`);
      } else {
        console.warn(`USDA API error: ${response.status} ${response.statusText}`);
      }
    } catch (error) {
      console.warn('USDA search failed:', error);
    }

    // Spoonacular fallback keys from Secret Manager (comma/newline separated or JSON array).
    const keysToTry = parseApiKeysSecret(spoonacularApiKey.value());
    if (keysToTry.length === 0) {
      console.warn('SPOONACULAR_API_KEY secret is empty. Skipping Spoonacular fallback.');
      return { results };
    }

    for (const apiKey of keysToTry) {
      try {
        const spoonUrl = new URL('https://api.spoonacular.com/recipes/complexSearch');
        spoonUrl.searchParams.set('apiKey', apiKey);
        spoonUrl.searchParams.set('query', query);
        spoonUrl.searchParams.set('number', '10');
        spoonUrl.searchParams.set('addRecipeNutrition', 'true');

        const response = await fetch(spoonUrl.toString());

        // Quota exceeded - try next key
        if (response.status === 402 || response.status === 401) {
          console.warn(
            `Spoonacular API key quota exceeded (${response.status}), trying next key...`
          );
          continue;
        }

        if (!response.ok) {
          console.warn(
            `Spoonacular error: ${response.status} ${response.statusText}`
          );
          continue;
        }

        const data = (await response.json()) as any;
        const items = Array.isArray(data?.results) ? data.results : [];

        for (const item of items) {
          const name = (item?.title || '').toString().trim();
          if (!name) continue;

          const nutrition = item?.nutrition || null;
          if (!nutrition) continue;

          const weight = nutrition?.weightPerServing || null;
          const servingGrams =
            weight?.unit === 'g' ? Number(weight?.amount) : null;
          if (!servingGrams || servingGrams <= 0) continue;

          const nutrients = Array.isArray(nutrition?.nutrients)
            ? nutrition.nutrients
            : [];

          const calories = findNutrient(nutrients, [], ['Calories']);
          const protein = findNutrient(nutrients, [], ['Protein']);
          const carbs = findNutrient(nutrients, [], ['Carbohydrates']);
          const fat = findNutrient(nutrients, [], ['Fat']);

          if (calories === null) continue;

          results.push({
            id: `spoon_${item?.id || name}`,
            name,
            caloriesPerGram: calories / servingGrams,
            proteinPerGram: (protein || 0) / servingGrams,
            carbsPerGram: (carbs || 0) / servingGrams,
            fatPerGram: (fat || 0) / servingGrams,
            servingGrams,
            source: 'spoonacular',
          });
        }

        // Success - return results from this key
        return { results };
      } catch (error) {
        console.warn(`Spoonacular search with key failed: ${error}, trying next key...`);
      }
    }

    console.warn('All Spoonacular API keys exhausted or failed');
    return { results };
  }
);

function findNutrient(
  nutrients: any[],
  ids: number[],
  names: string[],
): number | null {
  for (const nutrient of nutrients) {
    const id = nutrient?.nutrientId;
    if (typeof id === 'number' && ids.includes(id)) {
      const value = nutrient?.value ?? nutrient?.amount;
      if (typeof value === 'number') return value;
    }

    const name = (nutrient?.nutrientName ?? nutrient?.name ?? '').toString();
    if (
      name &&
      names.some((n) => n.toLowerCase() === name.toLowerCase())
    ) {
      const value = nutrient?.value ?? nutrient?.amount;
      if (typeof value === 'number') return value;
    }
  }

  return null;
}

function normalizeBarcode(value: string): string {
  return value.replace(/\D/g, '');
}

function canonicalBarcode(value: string): string {
  const normalized = normalizeBarcode(value);
  if (normalized.length === 13 && normalized.startsWith('0')) {
    return normalized.substring(1);
  }
  return normalized;
}

function barcodeCandidates(value: string): string[] {
  const normalized = normalizeBarcode(value);
  if (!normalized) {
    return [];
  }

  const candidates = new Set<string>();
  candidates.add(normalized);

  // EAN-13 and UPC-A often represent the same code with/without a leading 0.
  if (normalized.length === 12) {
    candidates.add(`0${normalized}`);
  } else if (normalized.length === 13 && normalized.startsWith('0')) {
    candidates.add(normalized.substring(1));
  }

  return Array.from(candidates);
}

function parseApiKeysSecret(rawValue: string): string[] {
  const trimmed = rawValue.trim();
  if (!trimmed) {
    return [];
  }

  try {
    const parsed = JSON.parse(trimmed);
    if (Array.isArray(parsed)) {
      return parsed
        .map((value) => value.toString().trim())
        .filter((value) => value.length > 0);
    }
  } catch (_) {
    // Fall back to delimiter-based parsing below.
  }

  return trimmed
    .split(/[\n,\s]+/)
    .map((value) => value.trim())
    .filter((value) => value.length > 0);
}

function normalizedOpenFoodFactsCandidates(candidates: string[]): string[] {
  return Array.from(
    new Set(
      candidates
        .map((candidate) => normalizeBarcode(candidate))
        .filter((candidate) => candidate.length >= 8)
    )
  );
}

async function fetchOpenFoodFactsProduct(
  candidates: string[]
): Promise<{ barcode: string; product: any } | null> {
  const uniqueCodes = normalizedOpenFoodFactsCandidates(candidates);

  for (const code of uniqueCodes) {
    try {
      const response = await fetch(
        `https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(code)}.json`
      );

      if (!response.ok) {
        continue;
      }

      const data = (await response.json()) as any;
      if (data?.status !== 1 || !data?.product) {
        continue;
      }

      return {
        barcode: code,
        product: data.product,
      };
    } catch (error) {
      console.warn(`Open Food Facts lookup failed for barcode ${code}:`, error);
    }
  }

  return null;
}

function parseOpenFoodFactsLookupResult(
  product: any,
  fallbackBarcode: string
): {
  id: string;
  barcode: string;
  name: string;
  caloriesPerGram: number;
  proteinPerGram: number;
  carbsPerGram: number;
  fatPerGram: number;
  servingGrams: number;
  source: string;
  brand: string;
} | null {
  const name = (
    product?.product_name ||
    product?.product_name_en ||
    product?.generic_name ||
    ''
  )
    .toString()
    .trim();
  if (!name) {
    return null;
  }

  const nutriments = product?.nutriments || {};
  const energyKj100g =
    toNullableNumber(nutriments?.['energy_100g']) ??
    toNullableNumber(nutriments?.energy);
  const calories100g =
    toNullableNumber(nutriments?.['energy-kcal_100g']) ??
    toNullableNumber(nutriments?.['energy-kcal']) ??
    (energyKj100g !== null ? energyKj100g / 4.184 : null);

  if (calories100g === null || calories100g <= 0) {
    return null;
  }

  const protein100g =
    toNullableNumber(nutriments?.['proteins_100g']) ??
    toNullableNumber(nutriments?.proteins) ??
    0;
  const carbs100g =
    toNullableNumber(nutriments?.['carbohydrates_100g']) ??
    toNullableNumber(nutriments?.carbohydrates) ??
    0;
  const fat100g =
    toNullableNumber(nutriments?.['fat_100g']) ??
    toNullableNumber(nutriments?.fat) ??
    0;

  const servingQuantity = toNullableNumber(product?.serving_quantity);
  const servingGrams =
    servingQuantity !== null && servingQuantity > 0 ? servingQuantity : 100;
  const resolvedBarcode =
    canonicalBarcode((product?.code || '').toString()) ||
    canonicalBarcode(fallbackBarcode) ||
    fallbackBarcode;
  return {
    id: `open_food_facts_${resolvedBarcode}`,
    barcode: resolvedBarcode,
    name,
    caloriesPerGram: Math.max(0, calories100g / 100),
    proteinPerGram: Math.max(0, protein100g / 100),
    carbsPerGram: Math.max(0, carbs100g / 100),
    fatPerGram: Math.max(0, fat100g / 100),
    servingGrams,
    source: 'open_food_facts',
    brand: (product?.brands || '').toString().trim(),
  };
}

async function lookupOpenFoodFactsByBarcode(
  candidates: string[],
  fallbackBarcode: string
): Promise<{
  id: string;
  barcode: string;
  name: string;
  caloriesPerGram: number;
  proteinPerGram: number;
  carbsPerGram: number;
  fatPerGram: number;
  servingGrams: number;
  source: string;
  brand: string;
} | null> {
  const found = await fetchOpenFoodFactsProduct(candidates);
  if (!found) {
    return null;
  }
  return parseOpenFoodFactsLookupResult(found.product, found.barcode || fallbackBarcode);
}

function toNullableNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function resolveServingGrams(food: any): number {
  const servingSize = toNullableNumber(food?.servingSize);
  const servingUnit = (food?.servingSizeUnit || '').toString().toLowerCase();

  if (servingSize !== null && servingSize > 0) {
    if (
      servingUnit === '' ||
      servingUnit === 'g' ||
      servingUnit === 'gram' ||
      servingUnit === 'grams'
    ) {
      return servingSize;
    }

    if (servingUnit === 'ml') {
      // Approximation: 1 ml ~= 1 g for most liquid foods.
      return servingSize;
    }

    if (
      servingUnit === 'oz' ||
      servingUnit === 'ounce' ||
      servingUnit === 'ounces'
    ) {
      return servingSize * 28.3495;
    }
  }

  return 100;
}

function normalizeBase64Payload(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) {
    return '';
  }

  const commaIndex = trimmed.indexOf(',');
  if (trimmed.startsWith('data:') && commaIndex > 0) {
    return trimmed.substring(commaIndex + 1);
  }

  return trimmed;
}

function extractTextFromResponseNode(node: any): string | null {
  if (node === null || node === undefined) {
    return null;
  }

  if (typeof node === 'string' && node.trim().length > 0) {
    return node;
  }

  if (Array.isArray(node)) {
    for (const item of node.slice().reverse()) {
      const found = extractTextFromResponseNode(item);
      if (found) {
        return found;
      }
    }
    return null;
  }

  if (typeof node === 'object') {
    const text = typeof node.text === 'string' ? node.text : null;
    if (text && text.trim().length > 0) {
      return text;
    }

    const outputText = typeof node.output_text === 'string' ? node.output_text : null;
    if (outputText && outputText.trim().length > 0) {
      return outputText;
    }

    const foundInContent = extractTextFromResponseNode(node.content);
    if (foundInContent) {
      return foundInContent;
    }
  }

  return null;
}

function extractOpenAiTextResponse(responseData: any): string {
  const directOutputText =
    typeof responseData?.output_text === 'string'
      ? responseData.output_text
      : '';
  if (directOutputText.trim().length > 0) {
    return directOutputText;
  }

  const output = responseData?.output;
  const fromOutput = extractTextFromResponseNode(output);
  if (fromOutput) {
    return fromOutput;
  }

  const choices = responseData?.choices;
  const fromChoices = extractTextFromResponseNode(choices);
  if (fromChoices) {
    return fromChoices;
  }

  throw new Error('OpenAI response missing text output');
}

function extractFirstJsonObject(text: string): string {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) {
    throw new Error('No JSON object found in model response');
  }
  return text.substring(start, end + 1);
}

function toNonNegativeNumber(value: unknown): number {
  const parsed = toNullableNumber(value) ?? 0;
  if (!Number.isFinite(parsed)) {
    return 0;
  }
  return parsed < 0 ? 0 : parsed;
}

function roundTo(value: number, decimals: number): number {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}

function normalizeMealAnalysisPayload(payload: any): { f: Array<{ n: string; m: number; k: number; p: number; c: number; a: number }> } {
  const foodsRaw = Array.isArray(payload?.f)
    ? payload.f
    : Array.isArray(payload?.foods)
      ? payload.foods
      : [];

  const foods = foodsRaw.map((item: any, index: number) => {
    const nameRaw =
      (item?.n ?? item?.name ?? `Food ${index + 1}`).toString().trim();
    const name = nameRaw.length > 0 ? nameRaw : `Food ${index + 1}`;

    const mass = roundTo(toNonNegativeNumber(item?.m ?? item?.mass), 1);
    const protein = roundTo(toNonNegativeNumber(item?.p ?? item?.protein), 1);
    const carbs = roundTo(toNonNegativeNumber(item?.c ?? item?.carbs), 1);
    const fat = roundTo(toNonNegativeNumber(item?.a ?? item?.fat), 1);
    const calories = roundTo((protein * 4) + (carbs * 4) + (fat * 9), 1);

    return {
      n: name,
      m: mass,
      k: calories,
      p: protein,
      c: carbs,
      a: fat,
    };
  });

  return { f: foods };
}

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
