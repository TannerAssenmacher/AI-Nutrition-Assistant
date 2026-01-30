/**
 * Embedding Regeneration Script (Resumable, Quota-Aware)
 *
 * 1. Removes orphaned embeddings (PostgreSQL rows with no matching Firestore recipe)
 * 2. Re-embeds recipes using gemini-embedding-001 model with the latest schema
 * 3. Respects the free-tier daily quota (1,000 requests/day) and stops gracefully
 * 4. Resumable: re-run the next day to continue where it left off
 *
 * The script identifies recipes needing re-embedding by checking for rows where
 * servings IS NULL (old schema) or rows that don't exist yet in PostgreSQL.
 *
 * Prerequisites:
 *   1. Cloud SQL Proxy running on localhost:5433
 *   2. Run migrate_postgres.sql first to add any new columns
 *   3. Set environment variables:
 *      export PG_PASSWORD="your-postgres-password"
 *      export GEMINI_API_KEY="your-gemini-api-key"
 *
 * Usage:
 *   node regenerate_embeddings.js
 *
 * Options:
 *   --dry-run        Show what would be done without making changes
 *   --batch=N        Firestore fetch batch size (default: 50)
 *   --quota=N        Max embedding API calls this run (default: 950)
 *   --skip-cleanup   Skip the orphan cleanup step
 *   --force          Re-embed ALL recipes, even ones already updated
 */

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import pg from 'pg';
import fetch from 'node-fetch';

const { Pool } = pg;

// Configuration
const BATCH_SIZE = parseInt(process.argv.find(a => a.startsWith('--batch='))?.split('=')[1] || '50');
const DRY_RUN = process.argv.includes('--dry-run');
const SKIP_CLEANUP = process.argv.includes('--skip-cleanup');
const FORCE = process.argv.includes('--force');
const DAILY_QUOTA = parseInt(process.argv.find(a => a.startsWith('--quota='))?.split('=')[1] || '950');
const RATE_LIMIT_DELAY_MS = 500; // 500ms between API calls to stay well under per-minute limits

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
      outputDimensionality: 768,
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

/**
 * Step 1: Remove orphaned embeddings from PostgreSQL
 * (rows whose IDs don't exist in Firestore)
 */
async function cleanupOrphans() {
  console.log('\nStep 1: Cleaning up orphaned embeddings...');

  // Get all IDs from PostgreSQL
  const pgResult = await pool.query('SELECT id FROM recipe_embeddings');
  const pgIds = new Set(pgResult.rows.map(r => r.id));
  console.log(`  PostgreSQL has ${pgIds.size} embeddings`);

  if (pgIds.size === 0) {
    console.log('  No embeddings to clean up');
    return 0;
  }

  // Get all recipe IDs from Firestore
  console.log('  Fetching all Firestore recipe IDs...');
  const firestoreIds = new Set();
  let lastDoc = null;

  while (true) {
    let query = db.collection('recipes')
      .where('source', '==', 'spoonacular')
      .orderBy('__name__')
      .select() // Only fetch document references, not data
      .limit(500);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    for (const doc of snapshot.docs) {
      firestoreIds.add(doc.id);
    }
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
  }

  console.log(`  Firestore has ${firestoreIds.size} recipes`);

  // Find orphans (in PostgreSQL but not in Firestore)
  const orphanIds = [];
  for (const pgId of pgIds) {
    if (!firestoreIds.has(pgId)) {
      orphanIds.push(pgId);
    }
  }

  console.log(`  Found ${orphanIds.length} orphaned embeddings to remove`);

  if (orphanIds.length === 0) {
    return 0;
  }

  if (DRY_RUN) {
    console.log('  [DRY RUN] Would delete:');
    for (const id of orphanIds.slice(0, 20)) {
      console.log(`    - ${id}`);
    }
    if (orphanIds.length > 20) {
      console.log(`    ... and ${orphanIds.length - 20} more`);
    }
    return orphanIds.length;
  }

  // Delete orphans in batches of 100
  let deleted = 0;
  for (let i = 0; i < orphanIds.length; i += 100) {
    const batch = orphanIds.slice(i, i + 100);
    const placeholders = batch.map((_, idx) => `$${idx + 1}`).join(', ');
    await pool.query(`DELETE FROM recipe_embeddings WHERE id IN (${placeholders})`, batch);
    deleted += batch.length;
    console.log(`  Deleted ${deleted}/${orphanIds.length} orphans`);
  }

  return deleted;
}

/**
 * Step 2: Identify recipes that need (re-)embedding
 * - Recipes in Firestore but not in PostgreSQL (missing)
 * - Recipes in PostgreSQL with old schema (servings IS NULL) unless --force skips this check
 */
async function findRecipesNeedingEmbedding() {
  console.log('\nStep 2: Identifying recipes needing embedding...');

  // Get PostgreSQL state
  let pgState;
  if (FORCE) {
    // When forcing, treat all as needing re-embedding
    pgState = { upToDate: new Set(), needsUpdate: new Set() };
    console.log('  --force flag: will re-embed ALL recipes');
  } else {
    // Check which recipes already have the new schema (servings column populated)
    const upToDateResult = await pool.query(
      'SELECT id FROM recipe_embeddings WHERE servings IS NOT NULL'
    );
    const needsUpdateResult = await pool.query(
      'SELECT id FROM recipe_embeddings WHERE servings IS NULL'
    );
    pgState = {
      upToDate: new Set(upToDateResult.rows.map(r => r.id)),
      needsUpdate: new Set(needsUpdateResult.rows.map(r => r.id)),
    };
    console.log(`  Already up-to-date: ${pgState.upToDate.size}`);
    console.log(`  Needs schema update: ${pgState.needsUpdate.size}`);
  }

  // Get all Firestore recipe IDs
  console.log('  Fetching Firestore recipe IDs...');
  const recipesToProcess = [];
  let lastDoc = null;

  while (true) {
    let query = db.collection('recipes')
      .where('source', '==', 'spoonacular')
      .orderBy('__name__')
      .select()
      .limit(500);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    for (const doc of snapshot.docs) {
      if (FORCE || !pgState.upToDate.has(doc.id)) {
        recipesToProcess.push(doc.id);
      }
    }
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
  }

  console.log(`  Total recipes needing embedding: ${recipesToProcess.length}`);
  return recipesToProcess;
}

/**
 * Step 3: Re-embed recipes with quota awareness
 */
async function embedRecipes(recipeIds) {
  const total = recipeIds.length;

  if (total === 0) {
    console.log('\nStep 3: All recipes are already up-to-date!');
    return { processed: 0, errors: 0, quotaReached: false };
  }

  const willProcess = Math.min(total, DAILY_QUOTA);
  console.log(`\nStep 3: Embedding recipes (${willProcess} of ${total}, quota: ${DAILY_QUOTA})...\n`);

  let processed = 0;
  let errors = 0;
  let apiCalls = 0;
  let consecutiveRateLimits = 0;

  // Process in Firestore batches
  for (let batchStart = 0; batchStart < recipeIds.length; batchStart += BATCH_SIZE) {
    // Check quota
    if (apiCalls >= DAILY_QUOTA) {
      console.log(`\n  [QUOTA] Reached daily limit of ${DAILY_QUOTA} API calls.`);
      console.log(`  Re-run this script tomorrow to continue.`);
      return { processed, errors, quotaReached: true, remaining: total - processed };
    }

    const batchIds = recipeIds.slice(batchStart, batchStart + BATCH_SIZE);

    // Fetch full recipe data from Firestore for this batch
    const docs = await Promise.all(
      batchIds.map(id => db.collection('recipes').doc(id).get())
    );

    for (const doc of docs) {
      // Check quota before each API call
      if (apiCalls >= DAILY_QUOTA) {
        console.log(`\n  [QUOTA] Reached daily limit of ${DAILY_QUOTA} API calls.`);
        console.log(`  Re-run this script tomorrow to continue.`);
        return { processed, errors, quotaReached: true, remaining: total - processed };
      }

      if (!doc.exists) {
        console.log(`  [SKIP] ${doc.id} - not found in Firestore`);
        continue;
      }

      const recipe = doc.data();
      const recipeId = doc.id;

      try {
        const recipeText = createRecipeText(recipe);

        if (DRY_RUN) {
          console.log(`  [DRY RUN] Would embed: ${recipe.label || recipeId}`);
          processed++;
          continue;
        }

        const embedding = await generateEmbedding(recipeText);
        apiCalls++;
        consecutiveRateLimits = 0; // Reset on success

        // Upsert into PostgreSQL with full schema
        const insertQuery = `
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
          recipe.servings || null,
          recipe.readyInMinutes || null,
        ]);

        processed++;
        console.log(`  [${processed}/${total}] (API: ${apiCalls}/${DAILY_QUOTA}) ${recipe.label || recipeId}`);

        // Rate limiting
        await sleep(RATE_LIMIT_DELAY_MS);

      } catch (error) {
        if (error.message.includes('429')) {
          consecutiveRateLimits++;
          if (consecutiveRateLimits >= 3) {
            // Hit the daily quota wall
            console.log(`\n  [QUOTA] Hit rate limit 3 times consecutively.`);
            console.log(`  Likely reached daily quota. Stopping.`);
            console.log(`  Re-run this script tomorrow to continue.`);
            return { processed, errors, quotaReached: true, remaining: total - processed };
          }
          console.log(`  [RATE LIMIT] ${recipeId} - waiting 60s (attempt ${consecutiveRateLimits}/3)...`);
          await sleep(60000);
          // Push this ID back to retry
          recipeIds.splice(batchStart + docs.indexOf(doc), 0, recipeId);
        } else {
          errors++;
          console.error(`  [ERROR] ${recipeId}: ${error.message}`);
        }
      }
    }

    // Progress update every batch
    const percent = Math.round((processed / total) * 100);
    console.log(`  --- Progress: ${percent}% (${processed}/${total}) | API calls: ${apiCalls}/${DAILY_QUOTA} ---`);
  }

  return { processed, errors, quotaReached: false };
}

async function main() {
  console.log('\n' + '='.repeat(60));
  console.log('EMBEDDING REGENERATION SCRIPT (Resumable)');
  console.log('='.repeat(60));

  if (!GEMINI_API_KEY) {
    console.error('\n[ERROR] GEMINI_API_KEY environment variable not set');
    console.log('Usage: export GEMINI_API_KEY="your-api-key"');
    process.exit(1);
  }

  console.log(`  Mode: ${DRY_RUN ? 'DRY RUN' : 'LIVE'}`);
  console.log(`  Daily quota: ${DAILY_QUOTA}`);
  console.log(`  Batch size: ${BATCH_SIZE}`);
  console.log(`  Force re-embed all: ${FORCE}`);
  console.log(`  Skip cleanup: ${SKIP_CLEANUP}`);

  try {
    // Step 1: Orphan cleanup
    let orphansRemoved = 0;
    if (!SKIP_CLEANUP) {
      orphansRemoved = await cleanupOrphans();
    } else {
      console.log('\nStep 1: Skipped (--skip-cleanup)');
    }

    // Step 2: Find what needs embedding
    const recipeIds = await findRecipesNeedingEmbedding();

    // Step 3: Embed with quota awareness
    const result = await embedRecipes(recipeIds);

    // Summary
    console.log('\n' + '='.repeat(60));
    console.log(result.quotaReached ? 'PAUSED (QUOTA REACHED)' : 'COMPLETE');
    console.log('='.repeat(60));
    console.log(`  Orphans removed: ${orphansRemoved}`);
    console.log(`  Recipes embedded this run: ${result.processed}`);
    console.log(`  Errors: ${result.errors}`);
    if (result.quotaReached) {
      console.log(`  Remaining (re-run tomorrow): ${result.remaining}`);
    }
    console.log('='.repeat(60));

    // Verify final counts
    if (!DRY_RUN) {
      const pgCount = await pool.query('SELECT COUNT(*) FROM recipe_embeddings');
      const upToDate = await pool.query('SELECT COUNT(*) FROM recipe_embeddings WHERE servings IS NOT NULL');
      const outdated = await pool.query('SELECT COUNT(*) FROM recipe_embeddings WHERE servings IS NULL');
      console.log(`\n  PostgreSQL total embeddings: ${pgCount.rows[0].count}`);
      console.log(`  Up-to-date (new schema): ${upToDate.rows[0].count}`);
      console.log(`  Still needs update: ${outdated.rows[0].count}`);
    }

    console.log('');

  } catch (error) {
    console.error('\n[FATAL ERROR]', error.message);
    if (error.message.includes('ECONNREFUSED')) {
      console.log('\nMake sure Cloud SQL Proxy is running on localhost:5433');
    }
    process.exit(1);
  } finally {
    await pool.end();
  }
}

main().catch(console.error);
