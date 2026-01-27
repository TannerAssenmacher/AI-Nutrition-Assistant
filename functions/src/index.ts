/**
 * Genkit Cloud Functions for AI Nutrition Assistant
 * 
 * Exports:
 * - onRecipeCreated: Firestore trigger to generate embeddings
 * - searchRecipes: Callable function for RAG recipe search
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import { genkit } from "genkit";
import { googleAI, textEmbedding004 } from "@genkit-ai/googleai";

import { Pool } from "pg";

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();

// Define secrets
const pgPassword = defineSecret("pg-password");
const geminiApiKey = defineSecret("gemini-api-key");

// Initialize Genkit with Google AI (will use GOOGLE_API_KEY env var)
const ai = genkit({
  plugins: [googleAI()],
});

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
 * Generate embedding for a recipe using Gemini
 */
async function generateEmbedding(text: string): Promise<number[]> {
  const response = await ai.embed({
    embedder: textEmbedding004,
    content: text,
  });
  // Genkit returns array of embeddings, we need the first one
  return response[0].embedding;
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
          calories, protein, carbs, fat, fiber, sugar, sodium
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
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
          sodium = EXCLUDED.sodium
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
  dietaryGoal?: string;  // "Lose Weight", "Maintain Weight", "Gain Weight"
  dailyCalorieGoal?: number;
  macroGoals?: { protein: number; carbs: number; fat: number };  // percentages
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
      dietaryGoal,
      dailyCalorieGoal,
      macroGoals,
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
        if (cuisineType && cuisineType.toLowerCase() !== 'none') queryParts.push(cuisineType);
        
        // User food preferences
        if (likes.length > 0) queryParts.push(...likes);
        
        // Dietary habits enhance semantic matching
        if (dietaryHabits.length > 0) queryParts.push(...dietaryHabits);
        
        // Dietary goal context for semantic relevance
        if (dietaryGoal) {
          if (dietaryGoal.toLowerCase().includes('lose')) {
            queryParts.push('low calorie', 'light', 'healthy');
          } else if (dietaryGoal.toLowerCase().includes('gain')) {
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
        
        queryText = queryParts.filter(Boolean).join(' ');
      }
      
      if (!queryText) {
        queryText = 'delicious healthy meal';  // Fallback
      }

      console.log('Searching with query:', queryText);
      console.log('User profile - Goal:', dietaryGoal, 'Calories:', dailyCalorieGoal, 'Macros:', macroGoals);
      
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
      if (cuisineType && cuisineType.toLowerCase() !== "none") {
        sql += ` AND cuisine = $${paramIndex}`;
        params.push(cuisineType.toLowerCase());
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

      // Filter by calorie range based on user's daily goal and meal type
      if (dailyCalorieGoal && dailyCalorieGoal > 0) {
        // Calculate per-meal calorie target based on meal type
        // Breakfast: ~25%, Lunch: ~30%, Dinner: ~35%, Snack: ~10%
        let mealCaloriePercent = 0.30;  // default
        const mealLower = mealType?.toLowerCase() || '';
        if (mealLower === 'breakfast') mealCaloriePercent = 0.25;
        else if (mealLower === 'lunch') mealCaloriePercent = 0.30;
        else if (mealLower === 'dinner') mealCaloriePercent = 0.35;
        else if (mealLower === 'snack') mealCaloriePercent = 0.10;
        
        const targetCalories = Math.round(dailyCalorieGoal * mealCaloriePercent);
        const minCalories = Math.round(targetCalories * 0.5);  // Allow 50% below target
        const maxCalories = Math.round(targetCalories * 1.3);  // Allow 30% above target
        
        sql += ` AND calories >= $${paramIndex} AND calories <= $${paramIndex + 1}`;
        params.push(minCalories, maxCalories);
        paramIndex += 2;
        
        console.log(`Calorie filter: ${minCalories}-${maxCalories} (target: ${targetCalories} for ${mealType})`);
      }

      // Filter by macro distribution if goals are set (prioritize protein for high-protein diets)
      if (macroGoals && macroGoals.protein >= 30) {
        // For high-protein diets, prefer recipes where protein provides significant calories
        // protein * 4 cal/g should be at least 25% of recipe calories
        sql += ` AND (protein * 4.0 / NULLIF(calories, 0)) >= 0.20`;
        console.log('Applying high-protein filter');
      }

      // Exclude already shown recipes
      if (excludeIds.length > 0) {
        sql += ` AND id != ALL($${paramIndex}::text[])`;
        params.push(excludeIds);
        paramIndex++;
      }

      // Order by similarity and limit
      sql += ` ORDER BY similarity DESC LIMIT $${paramIndex}`;
      params.push(limit);

      console.log("Executing search query:", sql);
      console.log("Params:", params.slice(1)); // Skip embedding for logging

      let result = await getPool().query(sql, params);
      let isExactMatch = true;

      // If no results with strict filters, try relaxed search (just vector similarity + dislikes + excludeIds)
      if (result.rows.length === 0) {
        console.log("No exact matches found, trying relaxed search...");
        isExactMatch = false;
        
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
            1 - (embedding <=> $1::vector) as similarity
          FROM recipe_embeddings
          WHERE 1=1
        `;
        
        const relaxedParams: any[] = [`[${queryEmbedding.join(",")}]`];
        let relaxedParamIndex = 2;
        
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
        
        relaxedSql += ` ORDER BY similarity DESC LIMIT $${relaxedParamIndex}`;
        relaxedParams.push(limit);
        
        console.log("Executing relaxed search query:", relaxedSql);
        result = await getPool().query(relaxedSql, relaxedParams);
      }

      // Fetch full recipe data from Firestore and estimate nutrition if missing
      const recipes = await Promise.all(
        result.rows.map(async (row) => {
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
