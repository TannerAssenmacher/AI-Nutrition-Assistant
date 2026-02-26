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
const fatSecretClientId = defineSecret("FATSECRET_CLIENT_ID");
const fatSecretClientSecret = defineSecret("FATSECRET_CLIENT_SECRET");
const openAiApiKey = defineSecret("OPENAI_API_KEY");

const FATSECRET_VPC_CONNECTOR =
  "projects/ai-nutrition-assistant-e2346/locations/us-central1/connectors/fatsecret-egress-conn";
const FATSECRET_OAUTH_URL = "https://oauth.fatsecret.com/connect/token";
const FATSECRET_API_BASE_URL = "https://platform.fatsecret.com/rest";
const FATSECRET_SEARCH_OAUTH_SCOPE = "premier";
const FATSECRET_BARCODE_OAUTH_SCOPE = "barcode";
const FATSECRET_TOKEN_REFRESH_BUFFER_MS = 60_000;
const MAX_IMAGE_PAYLOAD_BYTES = 5 * 1024 * 1024;
const MAX_IMAGE_BASE64_CHARS = Math.ceil((MAX_IMAGE_PAYLOAD_BYTES * 4) / 3) + 4;
const MAX_GEMINI_PROMPT_CHARS = 4_000;
const MAX_GEMINI_SYSTEM_INSTRUCTION_CHARS = 4_000;
const MAX_HISTORY_ITEMS = 20;
const MAX_HISTORY_TEXT_CHARS = 1_000;
const MAX_SEARCH_QUERY_CHARS = 500;
const MAX_FILTER_ITEMS = 40;
const MAX_FILTER_TEXT_CHARS = 80;
const MAX_EXCLUDE_IDS = 200;
const MAX_SEARCH_LIMIT = 20;
const MAX_ANALYZED_FOOD_ITEMS = 25;
const PROXY_IMAGE_TIMEOUT_MS = 8_000;
const PROXY_IMAGE_MAX_BYTES = 5 * 1024 * 1024;
const PROXY_IMAGE_HOST = "img.spoonacular.com";
const OPENAI_TIMEOUT_MS = 30_000;
const MAX_GEMINI_MESSAGES_PER_DAY = 5;
const ALLOWED_IMAGE_MIME_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/heic",
  "image/heif",
]);
const ALLOWED_GEMINI_MODELS = new Set([
  "gemini-2.5-flash",
  "gemini-2.5-pro",
  "gemini-1.5-flash",
  "gemini-1.5-pro",
  "gemini-3.0-flash-preview",
]);
const ALLOWED_PROXY_ORIGINS = [
  /^https:\/\/ai-nutrition-assistant-e2346\.web\.app$/,
  /^https:\/\/ai-nutrition-assistant-e2346\.firebaseapp\.com$/,
  /^http:\/\/localhost(?::\d+)?$/,
];

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
 * Check and track daily Gemini chat message usage for rate limiting.
 * Throws HttpsError if user has exceeded daily limit.
 */
async function checkAndTrackGeminiUsage(userId: string): Promise<void> {
  const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
  const usageRef = db.collection('users').doc(userId).collection('chatUsage').doc(today);
  
  try {
    await db.runTransaction(async (transaction) => {
      const usageDoc = await transaction.get(usageRef);
      const currentCount = usageDoc.exists ? (usageDoc.data()?.count || 0) : 0;
      
      if (currentCount >= MAX_GEMINI_MESSAGES_PER_DAY) {
        throw new HttpsError(
          'resource-exhausted',
          `Daily chat limit reached. You can send up to ${MAX_GEMINI_MESSAGES_PER_DAY} messages per day. Please try again tomorrow.`
        );
      }
      
      transaction.set(usageRef, {
        count: currentCount + 1,
        lastUpdated: new Date(),
      }, { merge: true });
    });
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    console.error('Error tracking Gemini usage:', error);
    // Don't block the request if tracking fails
  }
}

/**
 * Generate embedding for a recipe using Gemini REST API
 */
async function generateEmbedding(text: string): Promise<number[]> {
  const apiKey = geminiApiKey.value();
  // Use v1beta API with gemini-embedding-001
  // Note: text-embedding-004 was shut down on January 14, 2026
  // Using outputDimensionality=768 for compatibility with existing embeddings
  const url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent";
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify({
      model: "models/gemini-embedding-001",
      content: { parts: [{ text }] },
      outputDimensionality: 768,  // Match existing text-embedding-004 dimensions
    }),
  });

  if (!response.ok) {
    console.error(`Embedding API failed with status ${response.status}`);
    throw new Error(`Embedding API error: ${response.status}`);
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
  { cors: ALLOWED_PROXY_ORIGINS },
  async (request, response) => {
    const imageUrlRaw = (request.query.url || "").toString().trim();

    if (!imageUrlRaw) {
      response.status(400).send("Missing image URL");
      return;
    }

    let imageUrl: URL;
    try {
      imageUrl = new URL(imageUrlRaw);
    } catch (_) {
      response.status(400).send("Invalid image URL");
      return;
    }

    if (
      imageUrl.protocol !== "https:" ||
      imageUrl.hostname.toLowerCase() !== PROXY_IMAGE_HOST
    ) {
      response.status(400).send("Invalid image URL");
      return;
    }

    try {
      const abortController = new AbortController();
      const timeoutHandle = setTimeout(
        () => abortController.abort(),
        PROXY_IMAGE_TIMEOUT_MS
      );
      let imageResponse: Response;
      try {
        imageResponse = await fetch(imageUrl.toString(), {
          signal: abortController.signal,
        });
      } finally {
        clearTimeout(timeoutHandle);
      }

      if (!imageResponse.ok) {
        response.status(404).send("Image not found");
        return;
      }

      const contentTypeRaw = (imageResponse.headers.get("content-type") || "")
        .split(";")[0]
        .trim()
        .toLowerCase();
      if (!ALLOWED_IMAGE_MIME_TYPES.has(contentTypeRaw)) {
        response.status(415).send("Unsupported image format");
        return;
      }

      const contentLengthHeader = imageResponse.headers.get("content-length");
      const contentLength =
        contentLengthHeader === null ? null : Number(contentLengthHeader);
      if (
        contentLength !== null &&
        Number.isFinite(contentLength) &&
        contentLength > PROXY_IMAGE_MAX_BYTES
      ) {
        response.status(413).send("Image too large");
        return;
      }

      const arrayBuffer = await imageResponse.arrayBuffer();
      if (arrayBuffer.byteLength > PROXY_IMAGE_MAX_BYTES) {
        response.status(413).send("Image too large");
        return;
      }

      response.set("Cache-Control", "public, max-age=86400");
      response.set("Content-Type", contentTypeRaw || "image/jpeg");
      response.send(Buffer.from(arrayBuffer));
    } catch (error) {
      if (error instanceof Error && error.name === "AbortError") {
        response.status(504).send("Image fetch timed out");
        return;
      }
      console.error("Error proxying image:", error);
      response.status(502).send("Error loading image");
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
    timeoutSeconds: 120,
    memory: '512MiB',
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'User must be authenticated to call Gemini'
      );
    }

    // Check and track daily usage limit
    await checkAndTrackGeminiUsage(request.auth.uid);

    const data = toRequestData(request.data);
    const prompt = sanitizeTextInput(data.prompt, MAX_GEMINI_PROMPT_CHARS);
    const systemInstruction = sanitizeTextInput(
      data.systemInstruction,
      MAX_GEMINI_SYSTEM_INSTRUCTION_CHARS
    );
    const requestedModel = sanitizeTextInput(
      data.model || 'gemini-2.5-flash',
      64
    ).toLowerCase();
    const modelName = ALLOWED_GEMINI_MODELS.has(requestedModel)
      ? requestedModel
      : 'gemini-2.5-flash';
    const imageBase64 = normalizeBase64Payload((data.imageBase64 || '').toString());
    const mimeType = sanitizeTextInput(data.mimeType || 'image/jpeg', 64).toLowerCase();

    if (!prompt.trim() && !imageBase64) {
      throw new HttpsError(
        'invalid-argument',
        'Prompt or imageBase64 is required'
      );
    }

    if (imageBase64.length > MAX_IMAGE_BASE64_CHARS) {
      throw new HttpsError('invalid-argument', 'imageBase64 exceeds size limits');
    }

    if (imageBase64) {
      validateImagePayload(imageBase64, mimeType);
    }

    const rawHistory = Array.isArray(data.history)
      ? data.history.slice(-MAX_HISTORY_ITEMS)
      : [];
    const history = rawHistory
      .map((entry: any) => {
        const text = sanitizeTextInput(entry?.text, MAX_HISTORY_TEXT_CHARS);
        if (!text) {
          return null;
        }
        const roleRaw = (entry?.role || '').toString().toLowerCase();
        const role: 'model' | 'user' = roleRaw === 'model' ? 'model' : 'user';
        return {
          role,
          parts: [{ text }],
        };
      })
      .filter(
        (
          entry
        ): entry is { role: 'model' | 'user'; parts: Array<{ text: string }> } =>
          entry !== null
      )
      .slice(-MAX_HISTORY_ITEMS);

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
    timeoutSeconds: 120,
    memory: '512MiB',
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'User must be authenticated to analyze meal images'
      );
    }

    const data = toRequestData(request.data);
    const imageBase64Raw = (data.imageBase64 || '').toString();
    const imageBase64 = normalizeBase64Payload(imageBase64Raw);
    const mimeType = sanitizeTextInput(data.mimeType || 'image/jpeg', 64).toLowerCase();
    const userContext = sanitizeTextInput(data.userContext, 500);

    if (!imageBase64) {
      throw new HttpsError('invalid-argument', 'imageBase64 is required');
    }
    if (imageBase64.length > MAX_IMAGE_BASE64_CHARS) {
      throw new HttpsError('invalid-argument', 'imageBase64 exceeds size limits');
    }
    validateImagePayload(imageBase64, mimeType);

    const imageUrl = `data:${mimeType};base64,${imageBase64}`;

    try {
      const abortController = new AbortController();
      const timeoutHandle = setTimeout(
        () => abortController.abort(),
        OPENAI_TIMEOUT_MS
      );
      let response: Response;
      try {
        response = await fetch('https://api.openai.com/v1/responses', {
          method: 'POST',
          signal: abortController.signal,
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
      } finally {
        clearTimeout(timeoutHandle);
      }

      if (!response.ok) {
        console.error(`OpenAI image analysis failed with status ${response.status}`);
        throw new HttpsError(
          'unavailable',
          'Meal analysis provider request failed'
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
      if (error instanceof Error && error.name === 'AbortError') {
        throw new HttpsError('deadline-exceeded', 'Meal analysis request timed out');
      }
      console.error('analyzeMealImage failed:', error);
      throw new HttpsError('internal', 'Meal analysis failed');
    }
  }
);

interface FoodServingOptionPayload {
  id: string;
  description: string;
  grams: number;
  caloriesPerGram: number;
  proteinPerGram: number;
  carbsPerGram: number;
  fatPerGram: number;
  isDefault: boolean;
}

interface FatSecretFoodResultPayload {
  id: string;
  name: string;
  caloriesPerGram: number;
  proteinPerGram: number;
  carbsPerGram: number;
  fatPerGram: number;
  servingGrams: number;
  source: "fatsecret";
  servingOptions: FoodServingOptionPayload[];
  barcode?: string;
  brand?: string;
  imageUrl?: string;
}

let fatSecretTokenCache: Record<
  string,
  { token: string; expiresAtMs: number }
> = {};

function ensureArray<T>(value: T | T[] | null | undefined): T[] {
  if (Array.isArray(value)) {
    return value;
  }
  if (value === null || value === undefined) {
    return [];
  }
  return [value];
}

function normalizeBarcode(value: string): string {
  return value.replace(/\D/g, "");
}

function canonicalBarcode(value: string): string {
  const normalized = normalizeBarcode(value);
  if (normalized.length === 13 && normalized.startsWith("0")) {
    return normalized.substring(1);
  }
  return normalized;
}

function toGtin13Barcode(value: string): string | null {
  const normalized = normalizeBarcode(value);
  if (normalized.length < 8 || normalized.length > 13) {
    return null;
  }
  return normalized.padStart(13, "0");
}

function buildBarcodeCandidates(value: string): string[] {
  const normalized = normalizeBarcode(value);
  if (normalized.length < 8 || normalized.length > 13) {
    return [];
  }

  const candidates: string[] = [];
  const seen = new Set<string>();
  const add = (candidate: string) => {
    const trimmed = candidate.trim();
    if (!trimmed || seen.has(trimmed)) {
      return;
    }
    seen.add(trimmed);
    candidates.push(trimmed);
  };

  // Try exact scanned digits first.
  add(normalized);
  // Then GTIN-13 padded form for UPC/EAN compatibility.
  const gtin13 = toGtin13Barcode(normalized);
  if (gtin13) {
    add(gtin13);
  }
  // If scanner produced a leading-zero EAN-13, also try UPC-A form.
  if (normalized.length === 13 && normalized.startsWith("0")) {
    add(normalized.substring(1));
  }

  return candidates;
}

function toHttpUrl(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }

  if (trimmed.startsWith("//")) {
    return `https:${trimmed}`;
  }

  try {
    const parsed = new URL(trimmed);
    if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
      return null;
    }
    if (parsed.protocol === "http:") {
      parsed.protocol = "https:";
      return parsed.toString();
    }
    return parsed.toString();
  } catch (_) {
    return null;
  }
}

function resolveFatSecretImageUrl(food: any): string | null {
  const imageRoots = [
    food?.food_images?.food_image,
    food?.food_images,
    food?.food_image,
    food?.images?.image,
    food?.images,
  ];

  for (const root of imageRoots) {
    const imageNodes = ensureArray<any>(root);
    for (const node of imageNodes) {
      const candidateValues = [
        node?.image_url,
        node?.url,
        node?.image_url_large,
        node?.image_url_medium,
        node?.image_url_small,
        node,
      ];
      for (const candidate of candidateValues) {
        const resolved = toHttpUrl(candidate);
        if (resolved) {
          return resolved;
        }
      }
    }
  }

  const directCandidates = [
    food?.food_image_url,
    food?.food_image_thumbnail,
    food?.food_image,
    food?.image_url,
    food?.photo_url,
  ];
  for (const candidate of directCandidates) {
    const resolved = toHttpUrl(candidate);
    if (resolved) {
      return resolved;
    }
  }

  return null;
}

function convertServingAmountToGrams(amount: number, unitRaw: string): number | null {
  if (!Number.isFinite(amount) || amount <= 0) {
    return null;
  }

  const unit = unitRaw.trim().toLowerCase();
  if (!unit || unit === "g" || unit === "gram" || unit === "grams") {
    return amount;
  }
  if (unit === "ml" || unit === "milliliter" || unit === "milliliters") {
    // Approximation: 1ml ~= 1g for common liquids.
    return amount;
  }
  if (unit === "oz" || unit === "ounce" || unit === "ounces") {
    return amount * 28.3495;
  }
  return null;
}

function resolveFatSecretServingGrams(serving: any): number | null {
  const metricAmount = toNullableNumber(serving?.metric_serving_amount);
  const metricUnit = (serving?.metric_serving_unit || "").toString();
  if (metricAmount !== null) {
    const metricGrams = convertServingAmountToGrams(metricAmount, metricUnit);
    if (metricGrams !== null) {
      return metricGrams;
    }
  }

  const numberOfUnits = toNullableNumber(serving?.number_of_units);
  const measurementDescription = (serving?.measurement_description || "").toString();
  if (numberOfUnits !== null) {
    const measuredGrams = convertServingAmountToGrams(
      numberOfUnits,
      measurementDescription
    );
    if (measuredGrams !== null) {
      return measuredGrams;
    }
  }

  const servingDescription = (serving?.serving_description || "")
    .toString()
    .toLowerCase();
  const regexMatch = servingDescription.match(
    /([\d.]+)\s*(g|gram|grams|ml|milliliter|milliliters|oz|ounce|ounces)\b/
  );
  if (!regexMatch) {
    return null;
  }

  const parsedAmount = Number(regexMatch[1]);
  return convertServingAmountToGrams(parsedAmount, regexMatch[2]);
}

function parseFatSecretServingOptions(servingsRoot: any): FoodServingOptionPayload[] {
  const servings = ensureArray<any>(servingsRoot?.serving).filter(
    (serving) => serving && typeof serving === "object"
  );

  const options = servings
    .map((serving, index) => {
      const servingId = (serving?.serving_id ?? `${index}`)
        .toString()
        .trim() || `${index}`;
      const grams = resolveFatSecretServingGrams(serving);
      if (grams === null || grams <= 0) {
        return null;
      }

      const calories = toNullableNumber(serving?.calories);
      if (calories === null || calories < 0) {
        return null;
      }

      const carbs = toNullableNumber(serving?.carbohydrate) ?? 0;
      const protein = toNullableNumber(serving?.protein) ?? 0;
      const fat = toNullableNumber(serving?.fat) ?? 0;
      const servingDescription = (serving?.serving_description || "").toString().trim();
      const measurementDescription = (serving?.measurement_description || "")
        .toString()
        .trim();
      const description =
        servingDescription ||
        measurementDescription ||
        `Serving ${index + 1}`;
      const isDefault =
        servingId === "0" ||
        (serving?.is_default || "").toString().trim() === "1";

      return {
        id: servingId,
        description,
        grams,
        caloriesPerGram: Math.max(0, calories / grams),
        proteinPerGram: Math.max(0, protein / grams),
        carbsPerGram: Math.max(0, carbs / grams),
        fatPerGram: Math.max(0, fat / grams),
        isDefault,
      };
    })
    .filter((option): option is FoodServingOptionPayload => option !== null);

  if (options.length === 0) {
    return [];
  }

  if (!options.some((option) => option.isDefault)) {
    options[0] = { ...options[0], isDefault: true };
  }
  return options;
}

function parseFatSecretFoodResult(
  food: any,
  options?: { idPrefix?: string; barcode?: string }
): FatSecretFoodResultPayload | null {
  const name = (food?.food_name || "").toString().trim();
  if (!name) {
    return null;
  }

  const servingOptions = parseFatSecretServingOptions(food?.servings);
  if (servingOptions.length === 0) {
    return null;
  }
  const defaultServing =
    servingOptions.find((option) => option.isDefault) ?? servingOptions[0];

  const imageUrl = resolveFatSecretImageUrl(food);
  const foodId = (food?.food_id || "").toString().trim();
  const idPrefix = options?.idPrefix || "fatsecret_";
  const barcode = canonicalBarcode(options?.barcode || "");

  return {
    id: `${idPrefix}${foodId || name.toLowerCase().replace(/\s+/g, "_")}`,
    barcode: barcode || undefined,
    name,
    caloriesPerGram: defaultServing.caloriesPerGram,
    proteinPerGram: defaultServing.proteinPerGram,
    carbsPerGram: defaultServing.carbsPerGram,
    fatPerGram: defaultServing.fatPerGram,
    servingGrams: defaultServing.grams,
    source: "fatsecret",
    servingOptions,
    brand: (food?.brand_name || "").toString().trim() || undefined,
    imageUrl: imageUrl || undefined,
  };
}

async function fetchFatSecretFoodImageById(
  foodIdRaw: string,
  options?: {
    oauthScope?: string;
    fallbackScope?: string;
    allowScopeFallback?: boolean;
  }
): Promise<string | null> {
  const foodId = foodIdRaw.trim();
  if (!foodId) {
    return null;
  }

  try {
    const payload = await callFatSecretJson(
      "/food/v5",
      {
        food_id: foodId,
        format: "json",
        flag_default_serving: "true",
        include_food_images: "true",
      },
      {
        oauthScope: options?.oauthScope,
        fallbackScope: options?.fallbackScope,
        allowScopeFallback: options?.allowScopeFallback,
      }
    );

    return resolveFatSecretImageUrl(payload?.food);
  } catch (error) {
    console.warn(
      `FatSecret image fallback lookup failed for food_id=${foodId}:`,
      error
    );
    return null;
  }
}

function parseFatSecretSuggestions(payload: any): string[] {
  const rawSuggestions = payload?.suggestions?.suggestion;
  return ensureArray(rawSuggestions)
    .map((value) => value.toString().trim())
    .filter((value) => value.length > 0);
}

function parseFatSecretSearchSuggestions(payload: any, maxResults: number): string[] {
  const foods = ensureArray<any>(payload?.foods_search?.results?.food);
  const seen = new Set<string>();
  const suggestions: string[] = [];

  for (const food of foods) {
    const foodName = (food?.food_name || "").toString().trim();
    if (!foodName) {
      continue;
    }
    const key = foodName.toLowerCase();
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    suggestions.push(foodName);
    if (suggestions.length >= maxResults) {
      break;
    }
  }

  return suggestions;
}

function extractFatSecretErrorCode(payload: any): number | null {
  if (!payload || !payload.error) {
    return null;
  }
  if (typeof payload.error === "number") {
    return payload.error;
  }
  return toNullableNumber(payload.error.code);
}

function extractFatSecretErrorMessage(payload: any): string {
  if (!payload || !payload.error) {
    return "";
  }
  if (typeof payload.error === "string") {
    return payload.error.trim();
  }
  if (typeof payload.error.message === "string") {
    return payload.error.message.trim();
  }
  return "";
}

function throwFatSecretApiError(
  responseStatus: number,
  payload: any,
  context: string
): never {
  const fatSecretCode = extractFatSecretErrorCode(payload);
  const fatSecretMessage = extractFatSecretErrorMessage(payload);
  const lowerMessage = fatSecretMessage.toLowerCase();

  if (fatSecretCode === 211) {
    throw new HttpsError(
      "not-found",
      fatSecretMessage || "No matching food found"
    );
  }

  if (fatSecretCode === 101 || fatSecretCode === 107) {
    throw new HttpsError(
      "invalid-argument",
      fatSecretMessage || `Invalid FatSecret request for ${context}`
    );
  }

  if (lowerMessage.includes("scope")) {
    throw new HttpsError(
      "permission-denied",
      fatSecretMessage ||
        `FatSecret scope is missing for ${context}. Upgrade API scope or use fallback.`
    );
  }

  if (
    fatSecretCode === 13 ||
    fatSecretCode === 14 ||
    fatSecretCode === 21 ||
    responseStatus === 401 ||
    responseStatus === 403
  ) {
    throw new HttpsError(
      "permission-denied",
      fatSecretMessage ||
        `FatSecret authentication or allowlist failed for ${context}`
    );
  }

  const detailSuffix = fatSecretMessage ? `: ${fatSecretMessage}` : "";
  throw new HttpsError(
    "unavailable",
    `FatSecret API error during ${context} (HTTP ${responseStatus})${detailSuffix}`
  );
}

function isFatSecretScopeError(error: unknown): boolean {
  if (!(error instanceof HttpsError)) {
    return false;
  }
  const message = (error.message || "").toLowerCase();
  return message.includes("scope");
}

async function requestFatSecretToken(
  scope?: string
): Promise<{ status: number; payload: any }> {
  const clientId = fatSecretClientId.value().trim();
  const clientSecret = fatSecretClientSecret.value().trim();
  if (!clientId || !clientSecret) {
    throw new HttpsError(
      "failed-precondition",
      "FatSecret OAuth secrets are missing"
    );
  }

  const tokenBody = new URLSearchParams();
  tokenBody.set("grant_type", "client_credentials");
  if (scope && scope.trim().length > 0) {
    tokenBody.set("scope", scope.trim());
  }

  const basicAuth = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
  const tokenResponse = await fetch(FATSECRET_OAUTH_URL, {
    method: "POST",
    headers: {
      Authorization: `Basic ${basicAuth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: tokenBody.toString(),
  });
  const rawTokenResponse = await tokenResponse.text();
  let tokenPayload: any = null;
  if (rawTokenResponse) {
    try {
      tokenPayload = JSON.parse(rawTokenResponse);
    } catch (_) {
      tokenPayload = null;
    }
  }

  return {
    status: tokenResponse.status,
    payload: tokenPayload,
  };
}

function fatSecretTokenCacheKey(scope?: string): string {
  const normalized = (scope || "").toString().trim().toLowerCase();
  return normalized || "__default__";
}

async function getFatSecretAccessToken(options?: {
  scope?: string;
  fallbackScope?: string;
  allowScopeFallback?: boolean;
}): Promise<string> {
  const requestedScope = (options?.scope || "").toString().trim() || undefined;
  const fallbackScope = (options?.fallbackScope || "")
    .toString()
    .trim() || undefined;
  const allowScopeFallback = options?.allowScopeFallback !== false;
  const now = Date.now();
  const requestedScopeKey = fatSecretTokenCacheKey(requestedScope);
  const cachedToken = fatSecretTokenCache[requestedScopeKey];
  if (
    cachedToken &&
    now < cachedToken.expiresAtMs - FATSECRET_TOKEN_REFRESH_BUFFER_MS
  ) {
    return cachedToken.token;
  }

  let attemptedScope = requestedScope;
  let cacheScopeKey = requestedScopeKey;
  let tokenAttempt = await requestFatSecretToken(requestedScope);
  const tokenAttemptError = extractFatSecretErrorMessage(
    tokenAttempt.payload
  ).toLowerCase();
  const invalidScope =
    tokenAttemptError === "invalid_scope" ||
    tokenAttempt.payload?.error === "invalid_scope";
  if (tokenAttempt.status >= 400 && requestedScope && invalidScope && allowScopeFallback) {
    const fallbackTarget = fallbackScope || undefined;
    if (fallbackTarget && fallbackTarget !== requestedScope) {
      console.warn(
        `FatSecret OAuth scope "${requestedScope}" was rejected. Retrying token request with fallback scope "${fallbackTarget}".`
      );
      attemptedScope = fallbackTarget;
      cacheScopeKey = fatSecretTokenCacheKey(fallbackTarget);
      tokenAttempt = await requestFatSecretToken(fallbackTarget);
    } else {
      console.warn(
        `FatSecret OAuth scope "${requestedScope}" was rejected. Retrying token request without explicit scope.`
      );
      attemptedScope = undefined;
      cacheScopeKey = fatSecretTokenCacheKey(undefined);
      tokenAttempt = await requestFatSecretToken(undefined);
    }
  } else if (tokenAttempt.status >= 400 && requestedScope && invalidScope && !allowScopeFallback) {
    console.warn(
      `FatSecret OAuth scope "${requestedScope}" was rejected and fallback is disabled.`
    );
  }

  if (tokenAttempt.status >= 400) {
    throwFatSecretApiError(
      tokenAttempt.status,
      tokenAttempt.payload,
      attemptedScope
        ? `oauth token request (${attemptedScope})`
        : "oauth token request"
    );
  }

  const accessToken = (tokenAttempt.payload?.access_token || "")
    .toString()
    .trim();
  const expiresInSeconds =
    toNullableNumber(tokenAttempt.payload?.expires_in) ?? 3600;
  if (!accessToken) {
    throw new HttpsError(
      "internal",
      "FatSecret OAuth token response did not include an access token"
    );
  }

  fatSecretTokenCache[cacheScopeKey] = {
    token: accessToken,
    expiresAtMs: now + Math.max(60, Math.floor(expiresInSeconds)) * 1000,
  };
  return accessToken;
}

async function callFatSecretJson(
  endpointPath: string,
  params: Record<string, string | number | boolean | null | undefined>,
  options?: {
    oauthScope?: string;
    fallbackScope?: string;
    allowScopeFallback?: boolean;
  }
): Promise<any> {
  const token = await getFatSecretAccessToken({
    scope: options?.oauthScope,
    fallbackScope: options?.fallbackScope,
    allowScopeFallback: options?.allowScopeFallback,
  });
  const url = new URL(`${FATSECRET_API_BASE_URL}${endpointPath}`);
  for (const [key, value] of Object.entries(params)) {
    if (value === null || value === undefined) {
      continue;
    }
    const normalized = value.toString().trim();
    if (!normalized) {
      continue;
    }
    url.searchParams.set(key, normalized);
  }
  if (!url.searchParams.has("format")) {
    url.searchParams.set("format", "json");
  }

  const response = await fetch(url.toString(), {
    method: "GET",
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
    },
  });
  const rawBody = await response.text();
  let payload: any = null;
  if (rawBody) {
    try {
      payload = JSON.parse(rawBody);
    } catch (_) {
      payload = null;
    }
  }

  if (!response.ok || payload?.error) {
    throwFatSecretApiError(response.status, payload, endpointPath);
  }
  return payload;
}

/**
 * Lookup a packaged food by barcode via FatSecret.
 * Requires authentication (including anonymous auth)
 */
export const lookupFoodByBarcode = onCall(
  {
    cors: true,
    invoker: "public",
    secrets: [fatSecretClientId, fatSecretClientSecret],
    vpcConnector: FATSECRET_VPC_CONNECTOR,
    vpcConnectorEgressSettings: "ALL_TRAFFIC",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to look up barcodes"
      );
    }

    const rawBarcode = (request.data?.barcode || "").toString().trim();
    const normalizedBarcode = normalizeBarcode(rawBarcode);
    const barcodeCandidates = buildBarcodeCandidates(normalizedBarcode);
    if (barcodeCandidates.length === 0) {
      throw new HttpsError("invalid-argument", "A valid barcode is required");
    }

    try {
      let resolvedResult: FatSecretFoodResultPayload | null = null;

      for (const candidate of barcodeCandidates) {
        try {
          const payload = await callFatSecretJson(
            "/food/barcode/find-by-id/v2",
            {
              barcode: candidate,
              format: "json",
              flag_default_serving: "true",
              include_food_images: "true",
            },
            {
              oauthScope: FATSECRET_BARCODE_OAUTH_SCOPE,
              fallbackScope: FATSECRET_SEARCH_OAUTH_SCOPE,
              allowScopeFallback: true,
            }
          );

          const food = payload?.food;
          if (!food || typeof food !== "object") {
            continue;
          }

          resolvedResult = parseFatSecretFoodResult(food, {
            idPrefix: "fatsecret_barcode_",
            barcode: normalizedBarcode,
          });
          if (resolvedResult && !resolvedResult.imageUrl) {
            const fallbackImageUrl = await fetchFatSecretFoodImageById(
              (food?.food_id || "").toString(),
              {
                oauthScope: FATSECRET_BARCODE_OAUTH_SCOPE,
                fallbackScope: FATSECRET_SEARCH_OAUTH_SCOPE,
                allowScopeFallback: true,
              }
            );
            if (fallbackImageUrl) {
              resolvedResult = {
                ...resolvedResult,
                imageUrl: fallbackImageUrl,
              };
            }
          }
          if (resolvedResult) {
            break;
          }
        } catch (candidateError) {
          if (candidateError instanceof HttpsError) {
            if (
              candidateError.code === "not-found" ||
              candidateError.code === "invalid-argument"
            ) {
              continue;
            }
            throw candidateError;
          }
          throw candidateError;
        }
      }

      if (!resolvedResult) {
        throw new HttpsError(
          "not-found",
          `No nutrition facts found for barcode ${normalizedBarcode}`
        );
      }

      console.log(
        `FatSecret barcode lookup resolved result with image=${Boolean(
          (resolvedResult.imageUrl || "").trim()
        )}`
      );

      return { result: resolvedResult };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error("FatSecret barcode lookup failed:", error);
      throw new HttpsError("internal", "Barcode lookup failed");
    }
  }
);

/**
 * Search foods via FatSecret only.
 * Requires authentication (including anonymous auth)
 */
export const searchFoods = onCall(
  {
    cors: true,
    invoker: "public",
    secrets: [fatSecretClientId, fatSecretClientSecret],
    vpcConnector: FATSECRET_VPC_CONNECTOR,
    vpcConnectorEgressSettings: "ALL_TRAFFIC",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to search foods"
      );
    }

    const query = sanitizeTextInput(request.data?.query, 120);
    if (!query) {
      throw new HttpsError("invalid-argument", "Query is required");
    }

    const maxResultsInput = toNullableNumber(request.data?.maxResults);
    const maxResults = Math.max(1, Math.min(50, Math.floor(maxResultsInput ?? 10)));

    try {
      const payload = await callFatSecretJson("/foods/search/v4", {
        search_expression: query,
        page_number: 0,
        max_results: maxResults,
        format: "json",
        flag_default_serving: "true",
        include_food_images: "true",
      }, {
        oauthScope: FATSECRET_SEARCH_OAUTH_SCOPE,
        allowScopeFallback: true,
      });
      const foods = ensureArray<any>(payload?.foods_search?.results?.food);
      const fallbackImageLookupByFoodId = new Map<string, Promise<string | null>>();
      const results = (
        await Promise.all(
          foods.map(async (food) => {
            const parsed = parseFatSecretFoodResult(food);
            if (!parsed) {
              return null;
            }
            if ((parsed.imageUrl || "").trim()) {
              return parsed;
            }

            const foodId = (food?.food_id || "").toString().trim();
            if (!foodId) {
              return parsed;
            }

            let lookupPromise = fallbackImageLookupByFoodId.get(foodId);
            if (!lookupPromise) {
              lookupPromise = fetchFatSecretFoodImageById(foodId, {
                oauthScope: FATSECRET_SEARCH_OAUTH_SCOPE,
                allowScopeFallback: true,
              });
              fallbackImageLookupByFoodId.set(foodId, lookupPromise);
            }

            const fallbackImageUrl = await lookupPromise;
            if (!fallbackImageUrl) {
              return parsed;
            }

            return {
              ...parsed,
              imageUrl: fallbackImageUrl,
            };
          })
        )
      ).filter((item): item is FatSecretFoodResultPayload => item !== null);

      const imageCount = results.filter((item) =>
        Boolean((item.imageUrl || "").trim())
      ).length;
      console.log(
        `FatSecret returned ${results.length} search results (${imageCount} with images)`
      );
      return { results };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("FatSecret search failed:", error);
      throw new HttpsError("internal", "Food search failed");
    }
  }
);

/**
 * Autocomplete food terms via FatSecret foods.autocomplete.v2.
 * Requires authentication (including anonymous auth)
 */
export const autocompleteFoods = onCall(
  {
    cors: true,
    invoker: "public",
    secrets: [fatSecretClientId, fatSecretClientSecret],
    vpcConnector: FATSECRET_VPC_CONNECTOR,
    vpcConnectorEgressSettings: "ALL_TRAFFIC",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to use autocomplete"
      );
    }

    const expression = sanitizeTextInput(request.data?.expression, 120);
    if (expression.length < 2) {
      return { suggestions: [] as string[] };
    }

    const maxResultsInput = toNullableNumber(request.data?.maxResults);
    const maxResults = Math.max(1, Math.min(10, Math.floor(maxResultsInput ?? 6)));

    try {
      const payload = await callFatSecretJson("/food/autocomplete/v2", {
        expression,
        max_results: maxResults,
        format: "json",
      }, {
        oauthScope: FATSECRET_SEARCH_OAUTH_SCOPE,
        allowScopeFallback: true,
      });
      const suggestions = parseFatSecretSuggestions(payload).slice(0, maxResults);
      return { suggestions };
    } catch (error) {
      if (isFatSecretScopeError(error)) {
        try {
          const fallbackPayload = await callFatSecretJson("/foods/search/v4", {
            search_expression: expression,
            page_number: 0,
            max_results: maxResults,
            format: "json",
            flag_default_serving: "false",
          }, {
            oauthScope: FATSECRET_SEARCH_OAUTH_SCOPE,
            allowScopeFallback: true,
          });
          const suggestions = parseFatSecretSearchSuggestions(
            fallbackPayload,
            maxResults
          );
          return { suggestions };
        } catch (fallbackError) {
          if (fallbackError instanceof HttpsError) {
            throw fallbackError;
          }
          console.error("FatSecret autocomplete fallback failed:", fallbackError);
          throw new HttpsError("internal", "Autocomplete fallback failed");
        }
      }

      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("FatSecret autocomplete failed:", error);
      throw new HttpsError("internal", "Autocomplete failed");
    }
  }
);

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

function clampNumber(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) {
    return min;
  }
  return Math.min(max, Math.max(min, value));
}

function toRequestData(value: unknown): Record<string, any> {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, any>;
  }
  return {};
}

function sanitizeTextInput(value: unknown, maxLength: number): string {
  const normalized = (value ?? "").toString().trim();
  if (!normalized) {
    return "";
  }
  return normalized.substring(0, maxLength);
}

function sanitizeStringArray(
  value: unknown,
  maxItems: number,
  maxItemLength: number
): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  const sanitized: string[] = [];
  const seen = new Set<string>();
  for (const entry of value) {
    const item = sanitizeTextInput(entry, maxItemLength);
    if (!item) {
      continue;
    }
    const key = item.toLowerCase();
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    sanitized.push(item);
    if (sanitized.length >= maxItems) {
      break;
    }
  }

  return sanitized;
}

function estimateBase64DecodedBytes(base64: string): number {
  const normalized = base64.replace(/\s+/g, "");
  if (!normalized) {
    return 0;
  }

  let padding = 0;
  if (normalized.endsWith("==")) {
    padding = 2;
  } else if (normalized.endsWith("=")) {
    padding = 1;
  }

  return Math.max(0, Math.floor((normalized.length * 3) / 4) - padding);
}

function validateImagePayload(base64: string, mimeType: string): void {
  if (!ALLOWED_IMAGE_MIME_TYPES.has(mimeType)) {
    throw new HttpsError("invalid-argument", "Unsupported image mimeType");
  }

  const decodedSize = estimateBase64DecodedBytes(base64);
  if (decodedSize <= 0 || decodedSize > MAX_IMAGE_PAYLOAD_BYTES) {
    throw new HttpsError(
      "invalid-argument",
      "Image payload exceeds the maximum allowed size"
    );
  }
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
  const foodsRaw = (
    Array.isArray(payload?.f)
      ? payload.f
      : Array.isArray(payload?.foods)
        ? payload.foods
        : []
  ).slice(0, MAX_ANALYZED_FOOD_ITEMS);

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
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to search recipes"
      );
    }

    const data = toRequestData(request.data);
    const query = sanitizeTextInput(data.query, MAX_SEARCH_QUERY_CHARS);
    const mealType = sanitizeTextInput(data.mealType, 24).toLowerCase();
    const cuisineType = sanitizeTextInput(data.cuisineType, 40);
    const healthRestrictions = sanitizeStringArray(
      data.healthRestrictions,
      MAX_FILTER_ITEMS,
      MAX_FILTER_TEXT_CHARS
    );
    const dietaryHabits = sanitizeStringArray(
      data.dietaryHabits,
      MAX_FILTER_ITEMS,
      MAX_FILTER_TEXT_CHARS
    );
    const dislikes = sanitizeStringArray(
      data.dislikes,
      MAX_FILTER_ITEMS,
      MAX_FILTER_TEXT_CHARS
    );
    const likes = sanitizeStringArray(
      data.likes,
      MAX_FILTER_ITEMS,
      MAX_FILTER_TEXT_CHARS
    );
    const excludeIds = sanitizeStringArray(data.excludeIds, MAX_EXCLUDE_IDS, 128);
    const limitInput = toNullableNumber(data.limit) ?? 10;
    const limit = Math.floor(clampNumber(limitInput, 1, MAX_SEARCH_LIMIT));
    const activityLevel = sanitizeTextInput(data.activityLevel, 40);
    const dietaryGoal = sanitizeTextInput(data.dietaryGoal, 48);
    const dailyCalorieGoalInput = toNullableNumber(data.dailyCalorieGoal);
    const dailyCalorieGoal =
      dailyCalorieGoalInput !== null && dailyCalorieGoalInput > 0
        ? Math.floor(clampNumber(dailyCalorieGoalInput, 500, 10_000))
        : undefined;
    const macroGoalInput =
      data.macroGoals && typeof data.macroGoals === "object"
        ? (data.macroGoals as Record<string, unknown>)
        : null;
    const macroGoals = macroGoalInput
      ? {
          protein: clampNumber(
            toNullableNumber(macroGoalInput.protein) ?? 20,
            5,
            70
          ),
          carbs: clampNumber(
            toNullableNumber(macroGoalInput.carbs) ?? 50,
            5,
            80
          ),
          fat: clampNumber(
            toNullableNumber(macroGoalInput.fat) ?? 30,
            5,
            60
          ),
        }
      : undefined;
    const consumedCaloriesInput = toNullableNumber(data.consumedCalories);
    const consumedCalories =
      consumedCaloriesInput === null
        ? undefined
        : clampNumber(consumedCaloriesInput, 0, 15_000);
    const consumedMealTypes = sanitizeStringArray(
      data.consumedMealTypes,
      ALL_MEAL_TYPES.length,
      24
    )
      .map((meal) => meal.toLowerCase())
      .filter(
        (meal, index, values) =>
          ALL_MEAL_TYPES.includes(meal) && values.indexOf(meal) === index
      );
    const dob = sanitizeTextInput(data.dob, 40);
    const height = clampNumber(toNullableNumber(data.height) ?? 0, 0, 120);
    const weight = clampNumber(toNullableNumber(data.weight) ?? 0, 0, 1_400);

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

        queryText = queryParts
          .filter(Boolean)
          .join(' ')
          .substring(0, MAX_SEARCH_QUERY_CHARS);
      }
      
      if (!queryText) {
        queryText = 'delicious healthy meal';  // Fallback
      }

      // Generate query embedding
      const queryEmbedding = await generateEmbedding(queryText);

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

      let result = await getPool().query(sql, params);
      console.log(`Recipe search returned ${result.rows.length} initial candidates`);
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

          result = await getPool().query(fallback2Sql, fb2Params);
        }
      }

      // --- SCORING PIPELINE ---
      // Step 1: Calculate smart calorie target
      const calorieTarget = (dailyCalorieGoal && dailyCalorieGoal > 0)
        ? calculateSmartCalorieTarget(dailyCalorieGoal, mealType, consumedCalories, consumedMealTypes)
        : { targetCalories: 0, minCalories: 0, maxCalories: 0 };

      // Step 2: Filter out label-matched dislikes (hard filter in TypeScript)
      let candidates = result.rows;
      if (dislikes.length > 0) {
        const dislikesLower = dislikes.map(d => d.toLowerCase());
        candidates = candidates.filter(row => {
          const labelLower = (row.label || '').toLowerCase();
          return !dislikesLower.some(d => labelLower.includes(d));
        });
      }

      // Step 3: Score all candidates
      const scored = candidates.map(row =>
        scoreRecipe(row, calorieTarget, macroGoals, dailyCalorieGoal, likes, dietaryGoal)
      );

      // Step 4: Sort by score descending, take top `limit`
      scored.sort((a, b) => b.totalScore - a.totalScore);
      const topResults = scored.slice(0, limit);

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
