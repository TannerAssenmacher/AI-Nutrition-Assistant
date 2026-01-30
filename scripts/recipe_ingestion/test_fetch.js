/**
 * Test Script - Small Batch Fetch
 * 
 * Tests the Spoonacular integration with a small batch of recipes.
 * Use this to verify the pipeline works before running the full daily fetch.
 * 
 * Usage:
 *   export SPOONACULAR_API_KEY="your-key"
 *   node test_fetch.js
 */

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const API_KEYS = [
  '5c03d61e35e6423f9d85cba97abe9c9b',
  'f7733922048f4b439533101785244150',
  '3ff3175c82d1435a941219ed38c55473',
  'be1b00e1fd0646e1ad12e48aad78d1b8',
  'b7402fac116342be927d7a98cf2a5c3d',
  '15b4096cb5c24b41aed6c1b2683444b0',
  'a80b53549c1a443787491aaa8ea68e8f',
];
const BASE_URL = 'https://api.spoonacular.com';

// Initialize Firebase
initializeApp({
  projectId: 'ai-nutrition-assistant-e2346',
});
const db = getFirestore();

// Same transformation functions as daily_fetch.js
const cuisineMap = {
  'african': 'african', 'american': 'american', 'british': 'british',
  'cajun': 'american', 'caribbean': 'caribbean', 'chinese': 'chinese',
  'italian': 'italian', 'japanese': 'japanese', 'mexican': 'mexican',
  'mediterranean': 'mediterranean', 'indian': 'indian',
  'thai': 'south east asian', 'vietnamese': 'south east asian',
};

const dishTypeMap = {
  'breakfast': ['breakfast'], 'lunch': ['lunch'],
  'main course': ['lunch', 'dinner'], 'dinner': ['dinner'],
  'snack': ['snack'], 'dessert': ['snack'], 'appetizer': ['snack'],
};

function extractHealthLabels(recipe) {
  const labels = [];
  if (recipe.vegetarian) labels.push('vegetarian');
  if (recipe.vegan) labels.push('vegan');
  if (recipe.glutenFree) labels.push('gluten-free');
  if (recipe.dairyFree) labels.push('dairy-free');
  if (recipe.veryHealthy) labels.push('very-healthy');
  if (recipe.cheap) labels.push('cheap');
  if (recipe.veryPopular) labels.push('very-popular');
  if (recipe.sustainable) labels.push('sustainable');
  if (recipe.lowFodmap) labels.push('low-fodmap');
  if (recipe.ketogenic) labels.push('ketogenic');
  if (recipe.whole30) labels.push('whole30');

  (recipe.diets || []).forEach(diet => {
    const normalized = diet.toLowerCase().replace(/\s+/g, '-');
    if (!labels.includes(normalized)) labels.push(normalized);
  });

  return labels;
}

function transformRecipe(recipe) {
  const extendedIngredients = recipe.extendedIngredients || [];
  const ingredients = extendedIngredients
    .map(ing => ing.name?.toLowerCase() || ing.originalName?.toLowerCase())
    .filter(Boolean);
  const ingredientLines = extendedIngredients
    .map(ing => ing.original || `${ing.amount || ''} ${ing.unit || ''} ${ing.name || ''}`.trim())
    .filter(Boolean);
  
  const cuisines = recipe.cuisines || [];
  let cuisine = 'world';
  for (const c of cuisines) {
    const mapped = cuisineMap[c.toLowerCase()];
    if (mapped) { cuisine = mapped; break; }
  }
  
  const dishTypes = recipe.dishTypes || [];
  let mealTypes = ['lunch', 'dinner'];
  for (const dt of dishTypes) {
    const mapped = dishTypeMap[dt.toLowerCase()];
    if (mapped) { mealTypes = mapped; break; }
  }
  
  let calories = null, protein = null, carbs = null, fat = null;
  let fiber = null, sugar = null, sodium = null;
  
  if (recipe.nutrition?.nutrients) {
    const nutrients = recipe.nutrition.nutrients;
    const findNutrient = (name) => {
      const n = nutrients.find(n => n.name?.toLowerCase() === name.toLowerCase());
      return n ? Math.round(n.amount) : null;
    };
    calories = findNutrient('Calories');
    protein = findNutrient('Protein');
    carbs = findNutrient('Carbohydrates');
    fat = findNutrient('Fat');
    fiber = findNutrient('Fiber');
    sugar = findNutrient('Sugar');
    sodium = findNutrient('Sodium');
  }
  
  const category = dishTypes[0]?.toLowerCase().replace(/\s+/g, '-') || 'main-dish';
  
  let instructions = '';
  if (recipe.analyzedInstructions?.length > 0) {
    const steps = recipe.analyzedInstructions[0].steps || [];
    instructions = steps.map(s => `Step ${s.number}: ${s.step}`).join('\n\n');
  }
  
  const summary = recipe.summary?.replace(/<[^>]*>/g, '').substring(0, 500) || null;
  
  return {
    id: `spoonacular_${recipe.id}`,
    label: recipe.title,
    cuisine, mealTypes, category,
    ingredients, ingredientLines, instructions,
    calories, protein, carbs, fat, fiber, sugar, sodium,
    imageUrl: recipe.image || null,
    sourceUrl: recipe.sourceUrl || null,
    readyInMinutes: recipe.readyInMinutes || null,
    servings: recipe.servings || null,
    summary,
    healthLabels: extractHealthLabels(recipe),
    source: 'spoonacular',
  };
}

async function test() {
  // Allow cuisine to be passed as command line argument
  const testCuisine = process.argv[2] || null;

  if (testCuisine) {
    console.log(`\n🧪 TEST: Fetching 5 ${testCuisine} recipes from Spoonacular...\n`);
  } else {
    console.log('\n🧪 TEST: Fetching 5 random recipes from Spoonacular...\n');
    console.log('💡 Tip: Pass cuisine as argument (e.g., node test_fetch.js italian)\n');
  }

  // Step 1: Fetch from API - try each key until one works
  let data = null;
  let lastError = null;

  for (let i = 0; i < API_KEYS.length; i++) {
    const apiKey = API_KEYS[i];
    console.log(`🔑 Trying API key #${i + 1}...`);

    const params = new URLSearchParams({
      apiKey: apiKey,
      number: '5',
      addRecipeInformation: 'true',
      addRecipeNutrition: 'true',
      fillIngredients: 'true',
      instructionsRequired: 'true',
    });

    // Add cuisine filter if specified
    if (testCuisine) {
      params.set('cuisine', testCuisine);
    }

    const response = await fetch(`${BASE_URL}/recipes/complexSearch?${params}`);

    if (response.ok) {
      data = await response.json();
      console.log(`✅ API key #${i + 1} works!\n`);
      break;
    } else if (response.status === 401 || response.status === 402) {
      console.log(`❌ API key #${i + 1} quota exceeded or unauthorized`);
      lastError = `${response.status} ${response.statusText}`;
      continue;
    } else {
      console.error(`❌ API Error: ${response.status} ${response.statusText}`);
      const text = await response.text();
      console.error(text);
      process.exit(1);
    }
  }

  if (!data) {
    console.error(`\n❌ All API keys failed. Last error: ${lastError}`);
    process.exit(1);
  }
  console.log(`✅ API returned ${data.results?.length || 0} recipes\n`);
  
  if (!data.results?.length) {
    console.error('❌ No results returned');
    process.exit(1);
  }
  
  // Step 2: Transform recipes
  const transformed = data.results.map(transformRecipe);

  console.log('📋 Cuisine distribution:');
  const cuisineCounts = {};
  transformed.forEach(r => {
    cuisineCounts[r.cuisine] = (cuisineCounts[r.cuisine] || 0) + 1;
  });
  Object.entries(cuisineCounts).forEach(([cuisine, count]) => {
    console.log(`   ${cuisine}: ${count} recipe(s)`);
  });

  console.log('\n📋 Sample transformed recipe:');
  console.log(JSON.stringify(transformed[0], null, 2));
  
  // Step 3: Validate schema
  console.log('\n🔍 Validating schema...');
  const requiredFields = ['id', 'label', 'cuisine', 'mealTypes', 'ingredients', 'source'];
  let valid = true;
  
  for (const recipe of transformed) {
    for (const field of requiredFields) {
      if (recipe[field] === undefined) {
        console.error(`❌ Missing field: ${field}`);
        valid = false;
      }
    }
  }
  
  if (valid) {
    console.log('✅ All required fields present');
  }
  
  // Step 4: Upload to Firestore (with test_ prefix to avoid pollution)
  console.log('\n📤 Uploading to Firestore (test collection)...');
  
  const batch = db.batch();
  for (const recipe of transformed) {
    const testId = `test_${recipe.id}`;
    const docRef = db.collection('recipes').doc(testId);
    batch.set(docRef, { ...recipe, id: testId, createdAt: new Date() });
  }
  
  await batch.commit();
  console.log(`✅ Uploaded ${transformed.length} test recipes`);
  
  // Step 5: Verify upload
  console.log('\n🔎 Verifying upload...');
  const testDoc = await db.collection('recipes').doc(`test_${transformed[0].id}`).get();
  
  if (testDoc.exists) {
    console.log('✅ Recipe verified in Firestore');
    console.log(`   ID: ${testDoc.id}`);
    console.log(`   Label: ${testDoc.data().label}`);
    console.log(`   Calories: ${testDoc.data().calories}`);
    console.log(`   Fiber: ${testDoc.data().fiber}`);
    console.log(`   Sugar: ${testDoc.data().sugar}`);
    console.log(`   Sodium: ${testDoc.data().sodium}`);
  } else {
    console.error('❌ Recipe not found in Firestore!');
  }
  
  // Step 6: Cleanup
  console.log('\n🧹 Cleaning up test recipes...');
  const cleanupBatch = db.batch();
  for (const recipe of transformed) {
    const testId = `test_${recipe.id}`;
    cleanupBatch.delete(db.collection('recipes').doc(testId));
  }
  await cleanupBatch.commit();
  console.log('✅ Test recipes deleted');
  
  console.log('\n' + '='.repeat(50));
  console.log('🎉 ALL TESTS PASSED!');
  console.log('='.repeat(50));
  console.log('\nYou can now run: npm run daily');
}

test().catch(console.error);
