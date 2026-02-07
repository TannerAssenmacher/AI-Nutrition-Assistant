/**
 * Daily Recipe Fetch Script
 * 
 * Fetches new recipes from Spoonacular daily and uploads to Firestore.
 * Designed to run as a cron job or scheduled task.
 * 
 * Features:
 * - Respects free tier limits (150 points/day per key)
 * - Skips duplicates automatically
 * - Persists pagination progress across days (only API quotas reset daily)
 * - Tracks exhausted cuisine+mealType combinations to skip on future runs
 * - Logs all operations
 * 
 * Usage:
 *   export SPOONACULAR_API_KEY="your-key"
 *   node daily_fetch.js
 * 
 * Or with npm:
 *   npm run daily
 * 
 * Cron example (run at 2 AM daily):
 *   0 2 * * * cd /path/to/recipe_ingestion && npm run daily >> daily.log 2>&1
 */

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configuration
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
const TARGET_COLLECTION = 'recipes';

// Free tier: 150 points/day per key
// complexSearch with nutrition = ~1.1 points per call (1 + 0.01*100 + 0.025*100*3)
// Conservative: 100 recipes per call = ~4.6 points
// With 7 API keys: ~6 requests per key per day = ~42 successful requests expected
// Script will automatically stop when ALL keys hit their quota limit
const RECIPES_PER_REQUEST = 100;
const EXPECTED_REQUESTS_PER_KEY = 6; // Expected successful requests per key

// Cuisines to cycle through (Spoonacular API values)
// These match the app's cuisine picker exactly (lowercased)
// null = no cuisine filter, fetches recipes regardless of cuisine tag
const CUISINES_TO_FETCH = [
  null,
  'african', 'american', 'british', 'cajun', 'caribbean', 'chinese',
  'eastern european', 'european', 'french', 'german', 'greek', 'indian',
  'irish', 'italian', 'japanese', 'jewish', 'korean', 'latin american',
  'mediterranean', 'mexican', 'middle eastern', 'nordic', 'southern',
  'spanish', 'thai', 'vietnamese',
];

// Spoonacular meal types to cycle through for each cuisine
// null = no type filter (gets mostly main courses = lunch/dinner)
// Additional types fetch recipes that may not appear in the default results
const MEAL_TYPES_TO_FETCH = [
  null, 'breakfast', 'snack', 'dessert', 'appetizer',
  'salad', 'soup', 'side dish', 'beverage', 'fingerfood', 'bread',
];

// Sort orders to cycle through — different sorts surface different recipes
// Each cuisine+mealType combo is tried with each sort before being marked exhausted
const SORT_ORDERS = ['popularity', 'healthiness', 'time', 'random'];

// Initialize Firebase
initializeApp({
  projectId: 'ai-nutrition-assistant-e2346',
});
const db = getFirestore();

const dishTypeMap = {
  'breakfast': ['breakfast'], 'brunch': ['breakfast'], 'morning meal': ['breakfast'],
  'lunch': ['lunch'], 'main course': ['lunch', 'dinner'], 'main dish': ['lunch', 'dinner'],
  'dinner': ['dinner'], 'appetizer': ['snack'], 'starter': ['snack'], 'snack': ['snack'],
  'side dish': ['lunch', 'dinner'], 'salad': ['lunch', 'dinner'], 'soup': ['lunch', 'dinner'],
  'dessert': ['snack'], 'beverage': ['snack'], 'drink': ['snack'],
  'sauce': ['lunch', 'dinner'], 'marinade': ['lunch', 'dinner'],
  'fingerfood': ['snack'], 'bread': ['breakfast', 'snack'],
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

function transformRecipe(recipe, fetchedCuisine = null) {
  const extendedIngredients = recipe.extendedIngredients || [];
  const ingredients = extendedIngredients
    .map(ing => ing.name?.toLowerCase() || ing.originalName?.toLowerCase())
    .filter(Boolean);
  const ingredientLines = extendedIngredients
    .map(ing => ing.original || `${ing.amount || ''} ${ing.unit || ''} ${ing.name || ''}`.trim())
    .filter(Boolean);

  // Use the cuisine we fetched with (matches app's cuisine picker values exactly).
  // Fall back to the recipe's own cuisines array, then 'world'.
  let cuisine = fetchedCuisine || 'world';
  if (cuisine === 'world') {
    const cuisines = recipe.cuisines || [];
    if (cuisines.length > 0) {
      cuisine = cuisines[0].toLowerCase();
    }
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
  } else if (recipe.instructions) {
    instructions = recipe.instructions.replace(/<[^>]*>/g, '').trim();
  }
  
  const summary = recipe.summary?.replace(/<[^>]*>/g, '').substring(0, 500) || null;
  
  return {
    id: `spoonacular_${recipe.id}`,
    label: recipe.title,
    cuisine, mealTypes, category,
    ingredients, ingredientLines, instructions,
    calories, protein, carbs, fat, fiber, sugar, sodium,
    imageUrl: recipe.image || null,
    sourceUrl: recipe.sourceUrl || recipe.spoonacularSourceUrl || null,
    readyInMinutes: recipe.readyInMinutes || null,
    servings: recipe.servings || null,
    summary,
    healthLabels: extractHealthLabels(recipe),
    source: 'spoonacular',
  };
}

async function fetchRecipeBatch(offset, cuisine = null, mealType = null, apiKey, sort = 'popularity') {
  const params = new URLSearchParams({
    apiKey: apiKey,
    offset: offset.toString(),
    number: RECIPES_PER_REQUEST.toString(),
    addRecipeInformation: 'true',
    addRecipeNutrition: 'true',
    fillIngredients: 'true',
    instructionsRequired: 'true',
    sort: sort,
  });

  // Add cuisine filter if specified
  if (cuisine) {
    params.set('cuisine', cuisine);
  }

  // Add meal type filter if specified (e.g., 'breakfast', 'snack')
  if (mealType) {
    params.set('type', mealType);
  }

  const url = `${BASE_URL}/recipes/complexSearch?${params}`;

  try {
    const response = await fetch(url);

    if (response.status === 402 || response.status === 401) {
      console.error(`❌ API key quota exceeded (${response.status})!`);
      return { results: [], quotaExceeded: true };
    }

    if (!response.ok) {
      console.error(`API Error: ${response.status}`);
      return { results: [] };
    }

    return await response.json();
  } catch (error) {
    console.error('Fetch error:', error.message);
    return { results: [] };
  }
}

function loadState() {
  const statePath = path.join(__dirname, 'daily_state.json');
  const today = new Date().toISOString().split('T')[0];

  let state = {
    date: today,
    offset: 0,
    requestsMade: 0,
    recipesAdded: 0,
    cuisineIndex: 0,
    apiKeyIndex: 0,
    exhaustedCombos: [], // Track cuisine+mealType combos that have no more results
  };

  if (fs.existsSync(statePath)) {
    try {
      const saved = JSON.parse(fs.readFileSync(statePath, 'utf-8'));

      // Always persist pagination progress across days
      state.cuisineIndex = saved.cuisineIndex || 0;
      state.offset = saved.offset || 0;
      state.exhaustedCombos = saved.exhaustedCombos || [];

      if (saved.date === today) {
        // Same day: also restore daily quota tracking
        state.apiKeyIndex = saved.apiKeyIndex || 0;
        state.requestsMade = saved.requestsMade || 0;
        state.recipesAdded = saved.recipesAdded || 0;
      }
      // Different day: apiKeyIndex/requestsMade/recipesAdded stay at 0 (quotas reset)
    } catch (e) {}
  }

  state.date = today;
  return state;
}

function saveState(state) {
  const statePath = path.join(__dirname, 'daily_state.json');
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
}

async function main() {
  const startTime = new Date();
  console.log(`\n${'='.repeat(50)}`);
  console.log(`🍳 Daily Recipe Fetch - ${startTime.toISOString()}`);
  console.log('='.repeat(50));
  
  // Load today's state
  let state = loadState();
  console.log(`📊 Today's progress: ${state.requestsMade} requests, ${state.recipesAdded} recipes added`);
  console.log(`🔑 Starting with API key #${state.apiKeyIndex + 1} of ${API_KEYS.length}`);

  if (state.apiKeyIndex >= API_KEYS.length) {
    console.log('✅ All API keys exhausted for today. Run again tomorrow.');
    return;
  }

  // Get existing recipe IDs from Firestore to skip duplicates
  console.log('\n🔍 Checking existing recipes...');
  const existingSnapshot = await db.collection(TARGET_COLLECTION).select().get();
  const existingIds = new Set(existingSnapshot.docs.map(doc => doc.id));
  console.log(`   Found ${existingIds.size} existing recipes`);

  let newRecipes = [];
  let requestsThisRun = 0;
  let noResultsCount = 0;

  // Total combinations = cuisines * meal types * sort orders
  const totalCombinations = CUISINES_TO_FETCH.length * MEAL_TYPES_TO_FETCH.length * SORT_ORDERS.length;
  const exhaustedSet = new Set(state.exhaustedCombos || []);

  // Helper to get combo key for exhaustion tracking
  function comboKey(cuisineIdx, mealTypeIdx, sortIdx) {
    return `${CUISINES_TO_FETCH[cuisineIdx] || 'world'}|${MEAL_TYPES_TO_FETCH[mealTypeIdx] || 'all'}|${SORT_ORDERS[sortIdx]}`;
  }

  // Fetch until all API keys are exhausted
  while (true) {
    // Check if we've exhausted all API keys
    if (state.apiKeyIndex >= API_KEYS.length) {
      console.log('⚠️ All API keys exhausted for today');
      break;
    }

    // Check if all combinations are exhausted
    if (exhaustedSet.size >= totalCombinations) {
      console.log('🎉 All cuisine+mealType combinations have been fully fetched!');
      break;
    }

    // Get current API key, cuisine, and meal type
    const currentApiKey = API_KEYS[state.apiKeyIndex];
    const comboIndex = state.cuisineIndex % totalCombinations;
    const sortIdx = comboIndex % SORT_ORDERS.length;
    const mealTypeIdx = Math.floor(comboIndex / SORT_ORDERS.length) % MEAL_TYPES_TO_FETCH.length;
    const cuisineIdx = Math.floor(comboIndex / (SORT_ORDERS.length * MEAL_TYPES_TO_FETCH.length));
    const currentCuisine = CUISINES_TO_FETCH[cuisineIdx];
    const currentMealType = MEAL_TYPES_TO_FETCH[mealTypeIdx];
    const currentSort = SORT_ORDERS[sortIdx];
    const cuisineLabel = currentCuisine || 'world';
    const mealTypeLabel = currentMealType || 'all types';
    const currentComboKey = comboKey(cuisineIdx, mealTypeIdx, sortIdx);

    // Skip exhausted combinations
    if (exhaustedSet.has(currentComboKey)) {
      state.cuisineIndex++;
      state.offset = 0;
      continue;
    }

    console.log(`\n📥 Fetching ${cuisineLabel} (${mealTypeLabel}, sort: ${currentSort}) recipes at offset ${state.offset}... [combo ${comboIndex + 1}/${totalCombinations}, ${exhaustedSet.size} exhausted]`);

    const result = await fetchRecipeBatch(state.offset, currentCuisine, currentMealType, currentApiKey, currentSort);

    if (result.quotaExceeded) {
      console.log(`⚠️ API key #${state.apiKeyIndex + 1} quota exceeded`);

      // Try next API key (don't count failed request)
      state.apiKeyIndex++;

      if (state.apiKeyIndex < API_KEYS.length) {
        console.log(`🔄 Switching to API key #${state.apiKeyIndex + 1}`);
        continue;
      } else {
        console.log('⚠️ All API keys exhausted for today');
        break;
      }
    }

    // Only count successful requests
    requestsThisRun++;

    if (!result.results || result.results.length === 0) {
      noResultsCount++;
      console.log(`⚠️ No results for ${cuisineLabel} (${mealTypeLabel}) at offset ${state.offset}`);

      // Mark this combination as exhausted — no more recipes available
      if (noResultsCount >= 2 || state.offset > 0) {
        console.log(`   ✗ Marking ${cuisineLabel} (${mealTypeLabel}) as exhausted`);
        exhaustedSet.add(currentComboKey);
        state.exhaustedCombos = Array.from(exhaustedSet);
        state.cuisineIndex++;
        state.offset = 0;
        noResultsCount = 0;
      } else {
        state.offset += RECIPES_PER_REQUEST;
      }
      // Save state after marking exhausted
      saveState(state);
      continue;
    }

    // Reset no-results counter on success
    noResultsCount = 0;

    // Transform and filter duplicates
    let addedThisBatch = 0;
    for (const recipe of result.results) {
      const transformed = transformRecipe(recipe, currentCuisine);

      if (!existingIds.has(transformed.id)) {
        existingIds.add(transformed.id);
        newRecipes.push(transformed);
        addedThisBatch++;
      }
    }

    const totalResults = result.totalResults || 0;
    console.log(`   ✅ ${addedThisBatch} new recipes (${result.results.length - addedThisBatch} duplicates skipped) [${totalResults} total available]`);

    state.offset += RECIPES_PER_REQUEST;

    // Check if we've reached the end of available results for this combination
    // Spoonacular max offset is 900, and totalResults tells us the actual count
    if (state.offset >= 900 || (totalResults > 0 && state.offset >= totalResults)) {
      console.log(`   ✗ Reached end of ${cuisineLabel} (${mealTypeLabel}) — marking exhausted`);
      exhaustedSet.add(currentComboKey);
      state.exhaustedCombos = Array.from(exhaustedSet);
      state.cuisineIndex++;
      state.offset = 0;
    }

    // Save state after every successful request for resumability
    saveState(state);

    // Upload in batches of 500
    if (newRecipes.length >= 500) {
      await uploadBatch(newRecipes.splice(0, 500));
      state.recipesAdded += 500;
      saveState(state);
    }

    // Rate limiting
    await new Promise(r => setTimeout(r, 1000));
  }
  
  // Upload remaining recipes
  if (newRecipes.length > 0) {
    await uploadBatch(newRecipes);
    state.recipesAdded += newRecipes.length;
  }
  
  // Save state
  state.requestsMade += requestsThisRun;
  saveState(state);
  
  const endTime = new Date();
  const duration = Math.round((endTime - startTime) / 1000);
  
  console.log(`\n${'='.repeat(50)}`);
  console.log('✅ DAILY FETCH COMPLETE');
  console.log('='.repeat(50));
  console.log(`📊 Successful requests made: ${state.requestsMade}`);
  console.log(`📦 Recipes added today: ${state.recipesAdded}`);
  console.log(`⏱️ Duration: ${duration}s`);
  console.log(`🔑 API keys used: ${Math.min(state.apiKeyIndex + 1, API_KEYS.length)}/${API_KEYS.length}`);
  console.log(`📋 Exhausted combos: ${exhaustedSet.size}/${totalCombinations}`);
  if (exhaustedSet.size < totalCombinations) {
    const comboIdx = state.cuisineIndex % totalCombinations;
    const sIdx = comboIdx % SORT_ORDERS.length;
    const mtIdx = Math.floor(comboIdx / SORT_ORDERS.length) % MEAL_TYPES_TO_FETCH.length;
    const cIdx = Math.floor(comboIdx / (SORT_ORDERS.length * MEAL_TYPES_TO_FETCH.length));
    console.log(`🍽️ Next combo: ${CUISINES_TO_FETCH[cIdx] || 'world'} (${MEAL_TYPES_TO_FETCH[mtIdx] || 'all types'}, sort: ${SORT_ORDERS[sIdx]}) at offset ${state.offset}`);
  }
  console.log(`📅 Next run will resume from where this run left off`);
}

async function uploadBatch(recipes) {
  console.log(`\n📤 Uploading ${recipes.length} recipes to Firestore...`);
  
  const BATCH_SIZE = 500;
  for (let i = 0; i < recipes.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = recipes.slice(i, i + BATCH_SIZE);
    
    for (const recipe of chunk) {
      const docRef = db.collection(TARGET_COLLECTION).doc(recipe.id);
      batch.set(docRef, { ...recipe, createdAt: new Date() });
    }
    
    await batch.commit();
    console.log(`   ✅ Uploaded ${Math.min(i + BATCH_SIZE, recipes.length)}/${recipes.length}`);
  }
}

main().catch(console.error);
