/**
 * RAG Search Test Script
 *
 * Tests the searchRecipes Cloud Function with various queries.
 * Verifies that the RAG system returns results that match the schema.
 *
 * Usage:
 *   node test_rag_search.js
 *
 * Prerequisites:
 * - Firebase CLI logged in
 * - Cloud Functions deployed
 * - Recipes with embeddings in PostgreSQL
 */

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFunctions } from 'firebase-admin/functions';

// Initialize Firebase Admin with application default credentials
initializeApp({
  projectId: 'ai-nutrition-assistant-e2346',
  credential: applicationDefault(),
});

// Test scenarios
const testCases = [
  {
    name: 'Basic meal search',
    params: {
      mealType: 'dinner',
      cuisineType: 'italian',
      limit: 5,
    },
  },
  {
    name: 'Search with health restrictions',
    params: {
      mealType: 'lunch',
      cuisineType: 'mexican',
      healthRestrictions: ['vegetarian', 'gluten-free'],
      limit: 5,
    },
  },
  {
    name: 'Search with dietary goal (weight loss)',
    params: {
      mealType: 'breakfast',
      cuisineType: 'american',
      dietaryGoal: 'Lose Weight',
      dailyCalorieGoal: 2000,
      macroGoals: {
        protein: 30,
        carbs: 40,
        fat: 30,
      },
      limit: 5,
    },
  },
  {
    name: 'Search with dislikes',
    params: {
      mealType: 'dinner',
      cuisineType: 'none',
      dislikes: ['mushrooms', 'olives'],
      limit: 5,
    },
  },
  {
    name: 'High protein search',
    params: {
      mealType: 'lunch',
      cuisineType: 'none',
      dietaryGoal: 'Gain Weight',
      macroGoals: {
        protein: 35,
        carbs: 40,
        fat: 25,
      },
      limit: 5,
    },
  },
];

async function testRagSearch() {
  console.log('\n🧪 RAG SEARCH TEST\n' + '='.repeat(70));

  for (const testCase of testCases) {
    console.log(`\n📋 Test: ${testCase.name}`);
    console.log('─'.repeat(70));
    console.log('Parameters:', JSON.stringify(testCase.params, null, 2));

    try {
      // Call the Cloud Function
      // Note: This requires the Firebase Admin SDK with proper authentication
      const response = await fetch(
        `https://searchrecipes-j2yf6n33uq-uc.a.run.app`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ data: testCase.params }),
        }
      );

      if (!response.ok) {
        console.error(`❌ HTTP Error: ${response.status} ${response.statusText}`);
        continue;
      }

      const result = await response.json();

      // Validate response
      if (!result.result) {
        console.error('❌ Invalid response format');
        continue;
      }

      const { recipes, isExactMatch } = result.result;

      console.log(`\n✅ Found ${recipes.length} recipes (${isExactMatch ? 'Exact' : 'Relaxed'} match)`);

      // Validate schema for each recipe
      const requiredFields = [
        'id', 'label', 'cuisine', 'ingredients', 'instructions',
        'calories', 'protein', 'carbs', 'fat', 'similarity'
      ];

      let schemaValid = true;
      for (const recipe of recipes) {
        for (const field of requiredFields) {
          if (recipe[field] === undefined && field !== 'instructions') {
            console.error(`❌ Missing field: ${field} in recipe ${recipe.id}`);
            schemaValid = false;
          }
        }

        // Validate nutrition fields are numbers
        if (typeof recipe.calories !== 'number' || recipe.calories <= 0) {
          console.error(`❌ Invalid calories: ${recipe.calories}`);
          schemaValid = false;
        }
      }

      if (schemaValid) {
        console.log('✅ Schema validation passed');
      }

      // Display top 3 results
      console.log('\n📊 Top Results:');
      recipes.slice(0, 3).forEach((recipe, i) => {
        console.log(`\n  ${i + 1}. ${recipe.label}`);
        console.log(`     Cuisine: ${recipe.cuisine}`);
        console.log(`     Nutrition: ${recipe.calories} cal, ${recipe.protein}g protein, ${recipe.carbs}g carbs, ${recipe.fat}g fat`);
        if (recipe.fiber) console.log(`     Fiber: ${recipe.fiber}g, Sugar: ${recipe.sugar}g, Sodium: ${recipe.sodium}mg`);
        console.log(`     Similarity: ${(recipe.similarity * 100).toFixed(1)}%`);
      });

    } catch (error) {
      console.error(`❌ Error: ${error.message}`);
    }
  }

  console.log('\n' + '='.repeat(70));
  console.log('✅ RAG SEARCH TEST COMPLETE');
  console.log('='.repeat(70));
}

testRagSearch().catch(console.error);
