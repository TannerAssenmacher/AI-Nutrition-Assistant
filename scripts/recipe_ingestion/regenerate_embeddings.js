/**
 * Embedding Regeneration Script
 *
 * Regenerates all embeddings in PostgreSQL using gemini-embedding-001 model.
 * Run this after updating the Cloud Function to use the new model.
 *
 * Prerequisites:
 *   1. Cloud SQL Proxy running: gcloud sql connect recipe-vectors --user=postgres -p 5433
 *   2. Set environment variables:
 *      export PG_PASSWORD="your-postgres-password"
 *      export GEMINI_API_KEY="your-gemini-api-key"
 *
 * Usage:
 *   node regenerate_embeddings.js
 *
 * Options:
 *   --dry-run    Show what would be done without making changes
 *   --batch=N    Process N recipes at a time (default: 10)
 */

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import pg from 'pg';
import fetch from 'node-fetch';

const { Pool } = pg;

// Configuration
const BATCH_SIZE = parseInt(process.argv.find(a => a.startsWith('--batch='))?.split('=')[1] || '10');
const DRY_RUN = process.argv.includes('--dry-run');
const RATE_LIMIT_DELAY_MS = 200; // Delay between API calls to avoid rate limiting

// Initialize Firebase
initializeApp({
  projectId: 'ai-nutrition-assistant-e2346',
});
const db = getFirestore();

// PostgreSQL connection
const pool = new Pool({
  host: process.env.PG_HOST || '127.0.0.1',
  port: parseInt(process.env.PG_PORT || '5433'),
  user: process.env.PG_USER || 'postgres',
  password: process.env.PG_PASSWORD,
  database: process.env.PG_DATABASE || 'recipes_db',
});

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

/**
 * Generate embedding using gemini-embedding-001
 */
async function generateEmbedding(text) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${GEMINI_API_KEY}`;

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: 'models/gemini-embedding-001',
      content: { parts: [{ text }] },
      outputDimensionality: 768,  // Match existing vector dimensions in PostgreSQL
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Embedding API error: ${response.status} - ${error}`);
  }

  const data = await response.json();
  return data.embedding.values;
}

/**
 * Create searchable text from recipe
 */
function createRecipeText(recipe) {
  const parts = [
    recipe.label,
    recipe.cuisine,
    ...(recipe.mealTypes || []),
    ...(recipe.healthLabels || []),
    ...(recipe.ingredients || recipe.ingredientLines || []).slice(0, 10),
  ];
  return parts.filter(Boolean).join(' ');
}

/**
 * Sleep helper for rate limiting
 */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function regenerateEmbeddings() {
  console.log('\n' + '='.repeat(60));
  console.log('EMBEDDING REGENERATION SCRIPT');
  console.log('='.repeat(60));

  if (!GEMINI_API_KEY) {
    console.error('\n[ERROR] GEMINI_API_KEY environment variable not set');
    console.log('Usage: export GEMINI_API_KEY="your-api-key"');
    process.exit(1);
  }

  if (DRY_RUN) {
    console.log('\n[DRY RUN MODE] No changes will be made\n');
  }

  try {
    // Step 1: Count existing recipes
    console.log('\nStep 1: Counting recipes in Firestore...');
    const countSnapshot = await db.collection('recipes')
      .where('source', '==', 'spoonacular')
      .count()
      .get();
    const totalRecipes = countSnapshot.data().count;
    console.log(`  Found ${totalRecipes} recipes to process`);

    if (totalRecipes === 0) {
      console.log('\n[WARNING] No recipes found in Firestore');
      return;
    }

    // Step 2: Clear existing embeddings (unless dry run)
    if (!DRY_RUN) {
      console.log('\nStep 2: Clearing existing embeddings from PostgreSQL...');
      const deleteResult = await pool.query('DELETE FROM recipe_embeddings');
      console.log(`  Deleted ${deleteResult.rowCount} old embeddings`);
    } else {
      console.log('\nStep 2: [DRY RUN] Would clear existing embeddings');
    }

    // Step 3: Process recipes in batches
    console.log(`\nStep 3: Regenerating embeddings (batch size: ${BATCH_SIZE})...\n`);

    let processed = 0;
    let errors = 0;
    let lastDoc = null;

    while (processed < totalRecipes) {
      // Fetch next batch from Firestore
      let query = db.collection('recipes')
        .where('source', '==', 'spoonacular')
        .orderBy('__name__')
        .limit(BATCH_SIZE);

      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const snapshot = await query.get();
      if (snapshot.empty) break;

      lastDoc = snapshot.docs[snapshot.docs.length - 1];

      // Process each recipe in the batch
      for (const doc of snapshot.docs) {
        const recipe = doc.data();
        const recipeId = doc.id;

        try {
          // Generate embedding
          const recipeText = createRecipeText(recipe);

          if (DRY_RUN) {
            console.log(`  [DRY RUN] Would process: ${recipe.label || recipeId}`);
            processed++;
            continue;
          }

          const embedding = await generateEmbedding(recipeText);

          // Insert into PostgreSQL
          const insertQuery = `
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

          await pool.query(insertQuery, [
            recipeId,
            `[${embedding.join(',')}]`,
            recipe.label,
            recipe.cuisine,
            recipe.mealTypes || [],
            recipe.healthLabels || [],
            recipe.ingredients || recipe.ingredientLines || [],
            recipe.calories || null,
            recipe.protein || null,
            recipe.carbs || null,
            recipe.fat || null,
            recipe.fiber || null,
            recipe.sugar || null,
            recipe.sodium || null,
          ]);

          processed++;
          console.log(`  [${processed}/${totalRecipes}] ${recipe.label || recipeId}`);

          // Rate limiting
          await sleep(RATE_LIMIT_DELAY_MS);

        } catch (error) {
          errors++;
          console.error(`  [ERROR] ${recipeId}: ${error.message}`);

          // If rate limited, wait longer
          if (error.message.includes('429')) {
            console.log('  Rate limited - waiting 60 seconds...');
            await sleep(60000);
          }
        }
      }

      // Progress update
      const percent = Math.round((processed / totalRecipes) * 100);
      console.log(`\n  Progress: ${percent}% (${processed}/${totalRecipes})\n`);
    }

    // Final summary
    console.log('\n' + '='.repeat(60));
    console.log('REGENERATION COMPLETE');
    console.log('='.repeat(60));
    console.log(`  Total recipes: ${totalRecipes}`);
    console.log(`  Processed: ${processed}`);
    console.log(`  Errors: ${errors}`);
    console.log('='.repeat(60) + '\n');

    // Verify final count
    if (!DRY_RUN) {
      const finalCount = await pool.query('SELECT COUNT(*) FROM recipe_embeddings');
      console.log(`PostgreSQL now has ${finalCount.rows[0].count} embeddings\n`);
    }

  } catch (error) {
    console.error('\n[FATAL ERROR]', error.message);
    if (error.message.includes('ECONNREFUSED')) {
      console.log('\nMake sure Cloud SQL Proxy is running:');
      console.log('  gcloud sql connect recipe-vectors --user=postgres -p 5433');
    }
    process.exit(1);
  } finally {
    await pool.end();
  }
}

regenerateEmbeddings().catch(console.error);
