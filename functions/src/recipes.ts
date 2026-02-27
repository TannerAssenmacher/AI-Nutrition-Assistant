import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  MAX_EXCLUDE_IDS,
  MAX_FILTER_ITEMS,
  MAX_FILTER_TEXT_CHARS,
  MAX_SEARCH_LIMIT,
  MAX_SEARCH_QUERY_CHARS,
  RATE_LIMITS,
  RECIPE_DOC_CACHE_TTL_MS,
  geminiApiKey,
  pgPassword,
} from "./config";
import {
  db,
  enforceAppCheckIfRequired,
  enforcePerUserRateLimit,
  getPool,
} from "./infra";
import {
  clampNumber,
  sanitizeStringArray,
  sanitizeTextInput,
  toNullableNumber,
  toRequestData,
} from "./utils";

type CachedRecipeDoc = {
  data: FirebaseFirestore.DocumentData | null;
  expiresAtMs: number;
};

const recipeDocCache = new Map<string, CachedRecipeDoc>();

function getCachedRecipeDoc(
  recipeId: string
): FirebaseFirestore.DocumentData | null | undefined {
  const entry = recipeDocCache.get(recipeId);
  if (!entry) {
    return undefined;
  }
  if (Date.now() >= entry.expiresAtMs) {
    recipeDocCache.delete(recipeId);
    return undefined;
  }
  return entry.data;
}

function setCachedRecipeDoc(
  recipeId: string,
  data: FirebaseFirestore.DocumentData | null
): void {
  recipeDocCache.set(recipeId, {
    data,
    expiresAtMs: Date.now() + RECIPE_DOC_CACHE_TTL_MS,
  });
}

async function loadRecipesById(
  recipeIds: string[]
): Promise<Map<string, FirebaseFirestore.DocumentData | null>> {
  const resolvedDocs = new Map<string, FirebaseFirestore.DocumentData | null>();
  const uncachedIds: string[] = [];

  for (const recipeId of recipeIds) {
    const cached = getCachedRecipeDoc(recipeId);
    if (cached !== undefined) {
      resolvedDocs.set(recipeId, cached);
      continue;
    }
    uncachedIds.push(recipeId);
  }

  if (uncachedIds.length > 0) {
    const refs = uncachedIds.map((recipeId) => db.collection("recipes").doc(recipeId));
    const snapshots = await db.getAll(...refs);
    for (const snapshot of snapshots) {
      const recipeData = snapshot.exists ? snapshot.data() ?? null : null;
      setCachedRecipeDoc(snapshot.id, recipeData);
      resolvedDocs.set(snapshot.id, recipeData);
    }
  }

  for (const recipeId of recipeIds) {
    if (!resolvedDocs.has(recipeId)) {
      resolvedDocs.set(recipeId, null);
      setCachedRecipeDoc(recipeId, null);
    }
  }

  return resolvedDocs;
}

/**
 * Generate embedding for a recipe using Gemini REST API
 */
async function generateEmbedding(text: string): Promise<number[]> {
  const apiKey = geminiApiKey.value();
  // Use v1beta API with gemini-embedding-001
  // Note: text-embedding-004 was shut down on January 14, 2026
  // Using outputDimensionality=768 for compatibility with existing embeddings
  const url =
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent";
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify({
      model: "models/gemini-embedding-001",
      content: { parts: [{ text }] },
      outputDimensionality: 768,
    }),
  });

  if (!response.ok) {
    console.error(`Embedding API failed with status ${response.status}`);
    throw new Error(`Embedding API error: ${response.status}`);
  }

  const data = (await response.json()) as any;
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
    ...(recipe.ingredients || []).slice(0, 10),
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

  return { calories: 400, protein: 20, carbs: 40, fat: 15 };
}

/**
 * Firestore Trigger: Generate embedding when a recipe is created
 */
export const onRecipeCreated = onDocumentCreated(
  {
    document: "recipes/{recipeId}",
    secrets: [pgPassword, geminiApiKey],
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
      const recipeText = createRecipeText(recipe);
      const embedding = await generateEmbedding(recipeText);

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

interface SearchParams {
  query?: string;
  mealType?: string;
  cuisineType?: string;
  healthRestrictions?: string[];
  dietaryHabits?: string[];
  dislikes?: string[];
  likes?: string[];
  excludeIds?: string[];
  limit?: number;
  sex?: string;
  activityLevel?: string;
  dietaryGoal?: string;
  dailyCalorieGoal?: number;
  macroGoals?: { protein: number; carbs: number; fat: number };
  consumedCalories?: number;
  consumedMealTypes?: string[];
  consumedMacros?: { protein: number; carbs: number; fat: number };
  dob?: string;
  height?: number;
  weight?: number;
}

const MEAL_CALORIE_PERCENTAGES: Record<string, number> = {
  breakfast: 0.25,
  lunch: 0.30,
  dinner: 0.35,
  snack: 0.10,
};

const ALL_MEAL_TYPES = ["breakfast", "lunch", "dinner", "snack"];

interface CalorieTarget {
  targetCalories: number;
  minCalories: number;
  maxCalories: number;
}

function calculateSmartCalorieTarget(
  dailyCalorieGoal: number,
  mealType: string | undefined,
  consumedCalories?: number,
  consumedMealTypes?: string[]
): CalorieTarget {
  const mealLower = (mealType || "").toLowerCase();
  const mealPercent = MEAL_CALORIE_PERCENTAGES[mealLower] ?? 0.30;

  if (consumedCalories === undefined || consumedCalories === null || !consumedMealTypes) {
    const target = Math.round(dailyCalorieGoal * mealPercent);
    return {
      targetCalories: target,
      minCalories: Math.round(target * 0.50),
      maxCalories: Math.round(target * 1.30),
    };
  }

  const remainingCalories = Math.max(0, dailyCalorieGoal - consumedCalories);

  const consumed = new Set(consumedMealTypes.map((m) => m.toLowerCase()));
  const remainingMeals = ALL_MEAL_TYPES.filter((m) => !consumed.has(m));

  if (!remainingMeals.includes(mealLower) && mealLower) {
    remainingMeals.push(mealLower);
  }

  const remainingPercentTotal = remainingMeals.reduce(
    (sum, m) => sum + (MEAL_CALORIE_PERCENTAGES[m] ?? 0),
    0
  );

  if (remainingPercentTotal <= 0) {
    const target = Math.round(dailyCalorieGoal * mealPercent);
    return {
      targetCalories: target,
      minCalories: Math.round(target * 0.50),
      maxCalories: Math.round(target * 1.30),
    };
  }

  const targetCalories = Math.round(
    remainingCalories * (mealPercent / remainingPercentTotal)
  );

  return {
    targetCalories,
    minCalories: Math.round(targetCalories * 0.50),
    maxCalories: Math.round(targetCalories * 1.30),
  };
}

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

function calculateDietaryGoalScore(
  row: any,
  dietaryGoal: string | undefined,
  calorieTarget: CalorieTarget,
  macroGoals: { protein: number; carbs: number; fat: number } | undefined
): number {
  if (!dietaryGoal || !row.calories || row.calories === 0) return 0.5;

  const goalLower = dietaryGoal.toLowerCase();
  const recipeProteinPct = ((row.protein || 0) * 4 / row.calories) * 100;
  const recipeFatPct = ((row.fat || 0) * 9 / row.calories) * 100;
  const recipeCarbsPct = ((row.carbs || 0) * 4 / row.calories) * 100;
  const userProteinPct = macroGoals?.protein ?? 20;
  const userFatPct = macroGoals?.fat ?? 30;
  const userCarbsPct = macroGoals?.carbs ?? 50;

  if (goalLower.includes("lose")) {
    let score = 0;
    if (calorieTarget.targetCalories > 0) {
      score += row.calories <= calorieTarget.targetCalories ? 0.35 : 0.10;
    }
    score += (row.fiber || 0) >= 5 ? 0.15 : 0.05;
    score += recipeProteinPct >= userProteinPct ? 0.25 : 0.08;
    score += recipeFatPct <= userFatPct + 5 ? 0.15 : 0.05;
    score += (row.sugar || 0) <= 10 ? 0.10 : 0.03;
    return score;
  }

  if (goalLower.includes("gain") || goalLower.includes("muscle")) {
    let score = 0;
    score += recipeProteinPct >= userProteinPct ? 0.35 : 0.10;
    if (calorieTarget.targetCalories > 0) {
      score += row.calories >= calorieTarget.targetCalories * 0.9 ? 0.30 : 0.10;
    }
    score += (row.protein || 0) >= 25 ? 0.20 : 0.05;
    score += Math.abs(recipeCarbsPct - userCarbsPct) <= 10 ? 0.15 : 0.05;
    return score;
  }

  let score = 0;
  if (calorieTarget.targetCalories > 0) {
    const calDiff = Math.abs(row.calories - calorieTarget.targetCalories) /
      calorieTarget.targetCalories;
    score += calDiff <= 0.10 ? 0.40 : calDiff <= 0.20 ? 0.25 : 0.10;
  }
  const proteinClose = Math.abs(recipeProteinPct - userProteinPct) <= 5;
  const carbsClose = Math.abs(recipeCarbsPct - userCarbsPct) <= 5;
  const fatClose = Math.abs(recipeFatPct - userFatPct) <= 5;
  const macrosClose = [proteinClose, carbsClose, fatClose].filter(Boolean).length;
  score += macrosClose * 0.10;
  score += (row.fiber || 0) >= 3 ? 0.15 : 0.05;
  score += (row.sodium || 0) < 800 ? 0.15 : 0.05;
  return score;
}

function scoreRecipe(
  row: any,
  calorieTarget: CalorieTarget,
  macroGoals: { protein: number; carbs: number; fat: number } | undefined,
  dailyCalorieGoal: number | undefined,
  likes: string[],
  dietaryGoal: string | undefined
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

  const goalScore = calculateDietaryGoalScore(
    row,
    dietaryGoal,
    calorieTarget,
    macroGoals
  );
  breakdown.dietaryGoalAlignment = goalScore * 0.25;

  if (calorieTarget.targetCalories > 0 && row.calories) {
    const calDiff = Math.abs(row.calories - calorieTarget.targetCalories);
    const calRange = calorieTarget.maxCalories - calorieTarget.minCalories;
    const calScore = Math.max(0, 1 - calDiff / Math.max(calRange, 1));
    breakdown.calorieProximity = calScore * 0.25;
  } else {
    breakdown.calorieProximity = 0.125;
  }

  if (macroGoals && row.calories && row.calories > 0) {
    const recipeProteinPct = ((row.protein || 0) * 4 / row.calories) * 100;
    const recipeCarbsPct = ((row.carbs || 0) * 4 / row.calories) * 100;
    const recipeFatPct = ((row.fat || 0) * 9 / row.calories) * 100;
    const maxDiff = 30;

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

  breakdown.semanticSimilarity = (row.similarity || 0) * 0.10;

  if (likes.length > 0) {
    const likesLower = likes.map((l) => l.toLowerCase());
    const labelLower = (row.label || "").toLowerCase();
    const ingredientsLower: string[] = (row.ingredients || []).map((i: string) =>
      i.toLowerCase()
    );

    let matchCount = 0;
    for (const like of likesLower) {
      if (labelLower.includes(like)) {
        matchCount++;
        continue;
      }
      if (ingredientsLower.some((ing: string) => ing.includes(like))) {
        matchCount++;
      }
    }

    const likesScore = Math.min(1, matchCount / Math.max(likes.length, 1));
    breakdown.likesBoost = likesScore * 0.10;
  } else {
    breakdown.likesBoost = 0.05;
  }

  const servings = row.servings || 4;
  if (servings >= 1 && servings <= 4) {
    breakdown.servingsScore = 1.0 * 0.05;
  } else if (servings <= 6) {
    breakdown.servingsScore = 0.7 * 0.05;
  } else {
    breakdown.servingsScore = 0.4 * 0.05;
  }

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

    enforceAppCheckIfRequired(request, "searchRecipes");
    await enforcePerUserRateLimit({
      uid: request.auth.uid,
      endpointName: "searchRecipes",
      maxRequests: RATE_LIMITS.searchRecipes.maxRequests,
      windowMs: RATE_LIMITS.searchRecipes.windowMs,
    });

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
          protein: clampNumber(toNullableNumber(macroGoalInput.protein) ?? 20, 5, 70),
          carbs: clampNumber(toNullableNumber(macroGoalInput.carbs) ?? 50, 5, 80),
          fat: clampNumber(toNullableNumber(macroGoalInput.fat) ?? 30, 5, 60),
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
      let queryText: string;
      if (query) {
        queryText = query;
      } else {
        const queryParts: string[] = [];

        if (mealType) queryParts.push(mealType);
        if (
          cuisineType &&
          cuisineType.toLowerCase() !== "none" &&
          cuisineType.toLowerCase() !== "no preference"
        ) {
          queryParts.push(cuisineType);
        }

        if (likes.length > 0) queryParts.push(...likes);
        if (dietaryHabits.length > 0) queryParts.push(...dietaryHabits);

        if (dietaryGoal) {
          if (dietaryGoal.toLowerCase().includes("lose")) {
            queryParts.push("low calorie", "light", "healthy");
          } else if (
            dietaryGoal.toLowerCase().includes("gain") ||
            dietaryGoal.toLowerCase().includes("muscle")
          ) {
            queryParts.push("high protein", "calorie dense", "nutritious");
          } else {
            queryParts.push("balanced", "nutritious");
          }
        }

        if (macroGoals) {
          if (macroGoals.protein >= 30) queryParts.push("high protein");
          if (macroGoals.fat <= 25) queryParts.push("low fat");
          if (macroGoals.carbs <= 30) queryParts.push("low carb");
        }

        if (activityLevel) {
          const actLower = activityLevel.toLowerCase();
          if (actLower.includes("very") || actLower.includes("extra")) {
            queryParts.push("high energy", "protein rich");
          } else if (actLower.includes("sedentary") || actLower.includes("low")) {
            queryParts.push("light portions");
          }
        }

        if (height && weight && height > 0) {
          const bmi = (weight / (height * height)) * 703;
          if (bmi < 18.5) {
            queryParts.push("calorie dense", "energy rich");
          } else if (bmi > 30) {
            queryParts.push("light", "low calorie");
          }
        }

        if (dob) {
          const age = Math.floor(
            (Date.now() - new Date(dob).getTime()) /
              (365.25 * 24 * 60 * 60 * 1000)
          );
          if (age >= 60) queryParts.push("easy to prepare");
          if (age >= 13 && age <= 19) queryParts.push("growth supporting");
        }

        queryText = queryParts
          .filter(Boolean)
          .join(" ")
          .substring(0, MAX_SEARCH_QUERY_CHARS);
      }

      if (!queryText) {
        queryText = "delicious healthy meal";
      }

      const queryEmbedding = await generateEmbedding(queryText);

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

      if (mealType) {
        sql += ` AND $${paramIndex} = ANY(meal_types)`;
        params.push(mealType.toLowerCase());
        paramIndex++;
      }

      const ASIAN_CUISINES = ["chinese", "japanese", "korean", "thai", "vietnamese"];
      if (
        cuisineType &&
        cuisineType.toLowerCase() !== "none" &&
        cuisineType.toLowerCase() !== "no preference"
      ) {
        if (cuisineType.toLowerCase() === "asian") {
          sql += ` AND cuisine = ANY($${paramIndex}::text[])`;
          params.push(ASIAN_CUISINES);
        } else {
          sql += ` AND cuisine = $${paramIndex}`;
          params.push(cuisineType.toLowerCase());
        }
        paramIndex++;
      }

      if (healthRestrictions.length > 0) {
        sql += ` AND health_labels @> $${paramIndex}::text[]`;
        params.push(healthRestrictions.map((h) => h.toLowerCase()));
        paramIndex++;
      }

      if (dislikes.length > 0) {
        sql += ` AND NOT (ingredients && $${paramIndex}::text[])`;
        params.push(dislikes.map((d) => d.toLowerCase()));
        paramIndex++;
      }

      if (excludeIds.length > 0) {
        sql += ` AND id != ALL($${paramIndex}::text[])`;
        params.push(excludeIds);
        paramIndex++;
      }

      const fetchLimit = limit * 3;
      sql += ` ORDER BY similarity DESC LIMIT $${paramIndex}`;
      params.push(fetchLimit);

      let result = await getPool().query(sql, params);
      console.log(`Recipe search returned ${result.rows.length} initial candidates`);
      let isExactMatch = true;

      if (result.rows.length === 0) {
        console.log(
          "No exact matches found, trying relaxed search (drop health restrictions only)..."
        );

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

        if (mealType) {
          relaxedSql += ` AND $${relaxedParamIndex} = ANY(meal_types)`;
          relaxedParams.push(mealType.toLowerCase());
          relaxedParamIndex++;
        }

        if (
          cuisineType &&
          cuisineType.toLowerCase() !== "none" &&
          cuisineType.toLowerCase() !== "no preference"
        ) {
          if (cuisineType.toLowerCase() === "asian") {
            relaxedSql += ` AND cuisine = ANY($${relaxedParamIndex}::text[])`;
            relaxedParams.push(ASIAN_CUISINES);
          } else {
            relaxedSql += ` AND cuisine = $${relaxedParamIndex}`;
            relaxedParams.push(cuisineType.toLowerCase());
          }
          relaxedParamIndex++;
        }

        if (dislikes.length > 0) {
          relaxedSql += ` AND NOT (ingredients && $${relaxedParamIndex}::text[])`;
          relaxedParams.push(dislikes.map((d) => d.toLowerCase()));
          relaxedParamIndex++;
        }

        if (excludeIds.length > 0) {
          relaxedSql += ` AND id != ALL($${relaxedParamIndex}::text[])`;
          relaxedParams.push(excludeIds);
          relaxedParamIndex++;
        }

        const relaxedFetchLimit = limit * 3;
        relaxedSql += ` ORDER BY similarity DESC LIMIT $${relaxedParamIndex}`;
        relaxedParams.push(relaxedFetchLimit);

        result = await getPool().query(relaxedSql, relaxedParams);

        if (
          result.rows.length === 0 &&
          cuisineType &&
          cuisineType.toLowerCase() !== "none" &&
          cuisineType.toLowerCase() !== "no preference"
        ) {
          console.log("Still no results, trying without cuisine filter (keeping mealType)...");
          isExactMatch = false;

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

          if (mealType) {
            fallback2Sql += ` AND $${fb2Index} = ANY(meal_types)`;
            fb2Params.push(mealType.toLowerCase());
            fb2Index++;
          }

          if (dislikes.length > 0) {
            fallback2Sql += ` AND NOT (ingredients && $${fb2Index}::text[])`;
            fb2Params.push(dislikes.map((d) => d.toLowerCase()));
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

      const calorieTarget =
        dailyCalorieGoal && dailyCalorieGoal > 0
          ? calculateSmartCalorieTarget(
              dailyCalorieGoal,
              mealType,
              consumedCalories,
              consumedMealTypes
            )
          : { targetCalories: 0, minCalories: 0, maxCalories: 0 };

      let candidates = result.rows;
      if (dislikes.length > 0) {
        const dislikesLower = dislikes.map((d) => d.toLowerCase());
        candidates = candidates.filter((row) => {
          const labelLower = (row.label || "").toLowerCase();
          return !dislikesLower.some((d) => labelLower.includes(d));
        });
      }

      const scored = candidates.map((row) =>
        scoreRecipe(row, calorieTarget, macroGoals, dailyCalorieGoal, likes, dietaryGoal)
      );

      scored.sort((a, b) => b.totalScore - a.totalScore);
      const topResults = scored.slice(0, limit);

      const recipeDocsById = await loadRecipesById(topResults.map(({ row }) => row.id));

      const recipes = await Promise.all(
        topResults.map(async ({ row, totalScore }) => {
          const recipeData = recipeDocsById.get(row.id) ?? null;
          const ingredients = recipeData?.ingredientLines || row.ingredients || [];

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
            ingredients,
            instructions: recipeData?.instructions || "",
            calories,
            protein,
            carbs,
            fat,
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
