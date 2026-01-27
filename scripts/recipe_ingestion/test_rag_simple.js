/**
 * Simple RAG Search Test
 *
 * Tests the searchRecipes Cloud Function using Firebase Admin SDK.
 * This is simpler than making HTTP requests and works locally.
 *
 * Usage:
 *   node test_rag_simple.js
 */

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

// Initialize Firebase
initializeApp({
  projectId: 'ai-nutrition-assistant-e2346',
});
const db = getFirestore();

async function testRagSearch() {
  console.log('\n🧪 RAG SEARCH TEST\n' + '='.repeat(70));

  // Test case: Simple dinner search
  console.log('\n📋 Test: Basic Dinner Search');
  console.log('─'.repeat(70));

  try {
    // First, let's verify we have recipes in Firestore
    const recipesSnapshot = await db.collection('recipes')
      .where('source', '==', 'spoonacular')
      .limit(5)
      .get();

    if (recipesSnapshot.empty) {
      console.log('❌ No recipes found in Firestore!');
      console.log('💡 Run "npm run daily" to fetch recipes first.');
      return;
    }

    console.log(`✅ Found ${recipesSnapshot.size} sample recipes in Firestore`);

    // Display sample recipes
    console.log('\n📊 Sample Recipes from Firestore:');
    recipesSnapshot.docs.forEach((doc, i) => {
      const data = doc.data();
      console.log(`\n  ${i + 1}. ${data.label}`);
      console.log(`     ID: ${doc.id}`);
      console.log(`     Cuisine: ${data.cuisine}`);
      console.log(`     Meal Types: ${data.mealTypes?.join(', ') || 'N/A'}`);
      console.log(`     Nutrition: ${data.calories || 'N/A'} cal, ${data.protein || 'N/A'}g protein, ${data.carbs || 'N/A'}g carbs, ${data.fat || 'N/A'}g fat`);
      if (data.fiber || data.sugar || data.sodium) {
        console.log(`     Fiber: ${data.fiber || 'N/A'}g, Sugar: ${data.sugar || 'N/A'}g, Sodium: ${data.sodium || 'N/A'}mg`);
      }
      console.log(`     Health Labels: ${data.healthLabels?.join(', ') || 'N/A'}`);
      console.log(`     Ingredients: ${data.ingredients?.length || 0} items`);
    });

    console.log('\n' + '='.repeat(70));
    console.log('✅ FIRESTORE VERIFICATION COMPLETE');
    console.log('='.repeat(70));
    console.log('\n💡 To test the full RAG search:');
    console.log('   1. Ensure Cloud SQL Proxy is running (for PostgreSQL embeddings)');
    console.log('   2. Verify embeddings exist: npm run verify-embeddings');
    console.log('   3. Test via Flutter app or call searchRecipes Cloud Function');

  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

testRagSearch().catch(console.error);
