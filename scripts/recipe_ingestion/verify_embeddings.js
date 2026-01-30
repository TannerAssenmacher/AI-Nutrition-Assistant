/**
 * Embedding Verification Script
 *
 * Verifies that:
 * 1. Recipes in Firestore have corresponding embeddings in PostgreSQL
 * 2. The embedding generation trigger is working
 * 3. Schema consistency between Firestore and PostgreSQL
 *
 * Usage:
 *   export PG_PASSWORD="your-postgres-password"
 *   node verify_embeddings.js
 */

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import pg from 'pg';

const { Pool } = pg;

// Initialize Firebase
initializeApp({
  projectId: 'ai-nutrition-assistant-e2346',
});
const db = getFirestore();

// PostgreSQL connection (for local testing via Cloud SQL Proxy)
const pool = new Pool({
  host: process.env.PG_HOST || '127.0.0.1',
  port: parseInt(process.env.PG_PORT || '5433'),
  user: process.env.PG_USER || 'postgres',
  password: process.env.PG_PASSWORD,
  database: process.env.PG_DATABASE || 'recipes_db',
});

async function verifyEmbeddings() {
  console.log('\n🔍 EMBEDDING VERIFICATION\n' + '='.repeat(50));

  try {
    // Step 1: Get sample recipes from Firestore
    console.log('\n📥 Fetching recipes from Firestore...');
    const firestoreSnapshot = await db.collection('recipes')
      .where('source', '==', 'spoonacular')
      .limit(10)
      .get();

    if (firestoreSnapshot.empty) {
      console.log('❌ No recipes found in Firestore');
      return;
    }

    const firestoreRecipes = firestoreSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    console.log(`✅ Found ${firestoreRecipes.length} recipes in Firestore`);

    // Step 2: Check if embeddings exist in PostgreSQL
    console.log('\n🔎 Checking PostgreSQL embeddings...');
    const recipeIds = firestoreRecipes.map(r => r.id);

    const pgResult = await pool.query(
      'SELECT id, label, cuisine, calories, protein, carbs, fat, fiber, sugar, sodium FROM recipe_embeddings WHERE id = ANY($1::text[])',
      [recipeIds]
    );

    console.log(`✅ Found ${pgResult.rows.length}/${firestoreRecipes.length} embeddings in PostgreSQL`);

    // Step 3: Compare schemas
    console.log('\n📊 Schema Comparison:');
    console.log('─'.repeat(50));

    const missing = [];
    const schemaMatches = [];
    const schemaMismatches = [];

    for (const fsRecipe of firestoreRecipes) {
      const pgRecipe = pgResult.rows.find(r => r.id === fsRecipe.id);

      if (!pgRecipe) {
        missing.push(fsRecipe.id);
        continue;
      }

      // Compare nutrition fields
      const fields = ['calories', 'protein', 'carbs', 'fat', 'fiber', 'sugar', 'sodium'];
      let hasMatches = true;
      const mismatches = [];

      for (const field of fields) {
        const fsValue = fsRecipe[field];
        const pgValue = pgRecipe[field];

        if (fsValue !== pgValue) {
          hasMatches = false;
          mismatches.push(`${field}: Firestore=${fsValue}, PostgreSQL=${pgValue}`);
        }
      }

      if (hasMatches) {
        schemaMatches.push(fsRecipe.id);
      } else {
        schemaMismatches.push({ id: fsRecipe.id, mismatches });
      }
    }

    // Step 4: Report results
    console.log(`\n✅ Schema Matches: ${schemaMatches.length}`);
    console.log(`⚠️  Schema Mismatches: ${schemaMismatches.length}`);
    console.log(`❌ Missing Embeddings: ${missing.length}`);

    if (schemaMismatches.length > 0) {
      console.log('\n⚠️  SCHEMA MISMATCHES:');
      schemaMismatches.slice(0, 3).forEach(m => {
        console.log(`  ${m.id}:`);
        m.mismatches.forEach(mm => console.log(`    - ${mm}`));
      });
    }

    if (missing.length > 0) {
      console.log('\n❌ MISSING EMBEDDINGS:');
      missing.slice(0, 5).forEach(id => console.log(`  - ${id}`));
      console.log('\n💡 These recipes may be recent. The onRecipeCreated trigger should generate embeddings within 1-2 minutes.');
    }

    // Step 5: Sample recipe details
    if (pgResult.rows.length > 0) {
      console.log('\n📋 Sample Recipe from PostgreSQL:');
      const sample = pgResult.rows[0];
      console.log(JSON.stringify({
        id: sample.id,
        label: sample.label,
        cuisine: sample.cuisine,
        nutrition: {
          calories: sample.calories,
          protein: sample.protein,
          carbs: sample.carbs,
          fat: sample.fat,
          fiber: sample.fiber,
          sugar: sample.sugar,
          sodium: sample.sodium,
        }
      }, null, 2));
    }

    console.log('\n' + '='.repeat(50));
    console.log('✅ VERIFICATION COMPLETE');
    console.log('='.repeat(50));

  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.message.includes('ECONNREFUSED')) {
      console.log('\n💡 Make sure Cloud SQL Proxy is running:');
      console.log('   gcloud sql connect recipe-vectors --user=postgres -p 5433');
    }
  } finally {
    await pool.end();
  }
}

verifyEmbeddings().catch(console.error);
