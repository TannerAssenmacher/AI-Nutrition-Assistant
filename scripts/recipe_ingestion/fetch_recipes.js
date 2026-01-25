/**
 * Fetch all recipes from TheMealDB API and save to JSON
 * TheMealDB is free and provides ~300 curated recipes with instructions
 * 
 * Run: npm run fetch
 * Output: ./recipes_for_firestore.json
 */

// Map TheMealDB area to cuisine types (matching your app's cuisine picker)
const areaToCuisine = {
  'American': 'american',
  'British': 'british',
  'Canadian': 'american',
  'Chinese': 'chinese',
  'Croatian': 'eastern european',
  'Dutch': 'central europe',
  'Egyptian': 'middle eastern',
  'Filipino': 'south east asian',
  'French': 'french',
  'Greek': 'mediterranean',
  'Indian': 'indian',
  'Irish': 'british',
  'Italian': 'italian',
  'Jamaican': 'caribbean',
  'Japanese': 'japanese',
  'Kenyan': 'african',
  'Malaysian': 'south east asian',
  'Mexican': 'mexican',
  'Moroccan': 'middle eastern',
  'Polish': 'eastern european',
  'Portuguese': 'mediterranean',
  'Russian': 'eastern european',
  'Spanish': 'mediterranean',
  'Thai': 'south east asian',
  'Tunisian': 'middle eastern',
  'Turkish': 'middle eastern',
  'Ukrainian': 'eastern european',
  'Vietnamese': 'south east asian',
};

// Map TheMealDB category to meal types
const categoryToMealTypes = {
  'Breakfast': ['breakfast'],
  'Starter': ['lunch', 'dinner'],
  'Side': ['lunch', 'dinner'],
  'Dessert': ['snack'],
  'Beef': ['lunch', 'dinner'],
  'Chicken': ['lunch', 'dinner'],
  'Goat': ['lunch', 'dinner'],
  'Lamb': ['lunch', 'dinner'],
  'Miscellaneous': ['lunch', 'dinner'],
  'Pasta': ['lunch', 'dinner'],
  'Pork': ['lunch', 'dinner'],
  'Seafood': ['lunch', 'dinner'],
  'Vegan': ['lunch', 'dinner'],
  'Vegetarian': ['lunch', 'dinner'],
};

/**
 * Extract ingredients from TheMealDB recipe format
 * TheMealDB uses strIngredient1-20 and strMeasure1-20
 */
function extractIngredients(meal) {
  const ingredients = [];
  const ingredientLines = [];

  for (let i = 1; i <= 20; i++) {
    const ingredient = meal[`strIngredient${i}`];
    const measure = meal[`strMeasure${i}`];

    if (ingredient && ingredient.trim()) {
      ingredients.push(ingredient.trim().toLowerCase());
      const line = measure?.trim() 
        ? `${measure.trim()} ${ingredient.trim()}`
        : ingredient.trim();
      ingredientLines.push(line);
    }
  }

  return { ingredients, ingredientLines };
}

/**
 * Detect health labels using EXACT Edamam API format
 * These match the _healthOptions in profile_screen.dart
 */
function detectHealthLabels(ingredients, category) {
  const labels = [];
  const ingredientStr = ingredients.join(' ').toLowerCase();

  // Meat/protein detection
  const meatKeywords = ['beef', 'chicken', 'pork', 'lamb', 'bacon', 'ham', 'turkey', 'duck', 'goat', 'veal', 'sausage', 'mince', 'steak', 'meat'];
  const porkKeywords = ['pork', 'bacon', 'ham', 'pancetta', 'prosciutto', 'chorizo'];
  const redMeatKeywords = ['beef', 'lamb', 'goat', 'veal', 'steak', 'mince'];
  const fishKeywords = ['fish', 'salmon', 'tuna', 'cod', 'tilapia', 'mackerel', 'trout', 'halibut', 'anchov', 'sardine'];
  const shellfishKeywords = ['shrimp', 'prawn', 'crab', 'lobster', 'clam', 'mussel', 'oyster', 'scallop'];
  const molluskKeywords = ['mussel', 'oyster', 'clam', 'scallop', 'octopus', 'squid', 'snail'];
  const crustaceanKeywords = ['shrimp', 'prawn', 'crab', 'lobster', 'crawfish', 'crayfish'];

  // Allergen detection
  const dairyKeywords = ['milk', 'cheese', 'cream', 'butter', 'yogurt', 'yoghurt', 'parmesan', 'mozzarella', 'cheddar', 'ricotta', 'mascarpone', 'brie', 'feta', 'ghee'];
  const glutenKeywords = ['flour', 'bread', 'pasta', 'spaghetti', 'noodle', 'wheat', 'barley', 'rye', 'tortilla', 'pita', 'couscous', 'seitan'];
  const wheatKeywords = ['flour', 'bread', 'wheat', 'tortilla', 'pita', 'couscous', 'semolina'];
  const eggKeywords = ['egg'];
  const soyKeywords = ['soy', 'tofu', 'tempeh', 'edamame', 'miso'];
  const peanutKeywords = ['peanut', 'groundnut'];
  const treeNutKeywords = ['almond', 'walnut', 'cashew', 'pecan', 'pistachio', 'hazelnut', 'macadamia', 'chestnut', 'pine nut'];
  const sesameKeywords = ['sesame', 'tahini'];
  const celeryKeywords = ['celery', 'celeriac'];
  const mustardKeywords = ['mustard'];
  const lupineKeywords = ['lupine', 'lupin'];
  const sulfiteKeywords = ['wine', 'dried fruit', 'sulfite'];
  const alcoholKeywords = ['wine', 'beer', 'vodka', 'rum', 'whiskey', 'brandy', 'liqueur', 'sake', 'sherry', 'port', 'champagne'];

  const hasMeat = meatKeywords.some(m => ingredientStr.includes(m));
  const hasPork = porkKeywords.some(p => ingredientStr.includes(p));
  const hasRedMeat = redMeatKeywords.some(r => ingredientStr.includes(r));
  const hasFish = fishKeywords.some(f => ingredientStr.includes(f));
  const hasShellfish = shellfishKeywords.some(s => ingredientStr.includes(s));
  const hasMollusk = molluskKeywords.some(m => ingredientStr.includes(m));
  const hasCrustacean = crustaceanKeywords.some(c => ingredientStr.includes(c));
  const hasDairy = dairyKeywords.some(d => ingredientStr.includes(d));
  const hasGluten = glutenKeywords.some(g => ingredientStr.includes(g));
  const hasWheat = wheatKeywords.some(w => ingredientStr.includes(w));
  const hasEgg = eggKeywords.some(e => ingredientStr.includes(e));
  const hasSoy = soyKeywords.some(s => ingredientStr.includes(s));
  const hasPeanut = peanutKeywords.some(p => ingredientStr.includes(p));
  const hasTreeNut = treeNutKeywords.some(t => ingredientStr.includes(t));
  const hasSesame = sesameKeywords.some(s => ingredientStr.includes(s));
  const hasCelery = celeryKeywords.some(c => ingredientStr.includes(c));
  const hasMustard = mustardKeywords.some(m => ingredientStr.includes(m));
  const hasLupine = lupineKeywords.some(l => ingredientStr.includes(l));
  const hasSulfite = sulfiteKeywords.some(s => ingredientStr.includes(s));
  const hasAlcohol = alcoholKeywords.some(a => ingredientStr.includes(a));

  // Edamam health labels (exact format from your app)
  if (!hasAlcohol) labels.push('alcohol-free');
  if (!hasCelery) labels.push('celery-free');
  if (!hasCrustacean) labels.push('crustacean-free');
  if (!hasDairy) labels.push('dairy-free');
  if (!hasEgg) labels.push('egg-free');
  if (!hasFish) labels.push('fish-free');
  if (!hasGluten) labels.push('gluten-free');
  if (!hasLupine) labels.push('lupine-free');
  if (!hasMollusk) labels.push('mollusk-free');
  if (!hasMustard) labels.push('mustard-free');
  if (!hasPeanut) labels.push('peanut-free');
  if (!hasPork) labels.push('pork-free');
  if (!hasRedMeat) labels.push('red-meat-free');
  if (!hasSesame) labels.push('sesame-free');
  if (!hasShellfish) labels.push('shellfish-free');
  if (!hasSoy) labels.push('soy-free');
  if (!hasSulfite) labels.push('sulfite-free');
  if (!hasTreeNut) labels.push('tree-nut-free');
  if (!hasWheat) labels.push('wheat-free');

  // Diet labels
  if (!hasMeat && !hasFish && !hasShellfish) {
    if (category === 'Vegan' || (!hasDairy && !hasEgg)) {
      labels.push('vegan');
    }
    labels.push('vegetarian');
  }

  // Pescatarian: no meat except fish/shellfish
  if (!hasMeat && (hasFish || hasShellfish || (!hasFish && !hasShellfish))) {
    if (!meatKeywords.some(m => ingredientStr.includes(m))) {
      labels.push('pescatarian');
    }
  }

  return labels;
}

/**
 * Transform TheMealDB meal to Firestore-ready schema
 * Uses Edamam-compatible health labels for filtering
 */
function transformMeal(meal) {
  const { ingredients, ingredientLines } = extractIngredients(meal);
  const cuisine = areaToCuisine[meal.strArea] || meal.strArea?.toLowerCase() || 'world';
  const mealTypes = categoryToMealTypes[meal.strCategory] || ['lunch', 'dinner'];
  const healthLabels = detectHealthLabels(ingredients, meal.strCategory);

  return {
    id: `mealdb_${meal.idMeal}`,
    label: meal.strMeal,
    labelLower: meal.strMeal.toLowerCase(),
    cuisine: cuisine,
    mealTypes: mealTypes,
    category: meal.strCategory?.toLowerCase() || 'miscellaneous',
    ingredients: ingredients,
    ingredientLines: ingredientLines,
    instructions: meal.strInstructions || '',
    // TheMealDB doesn't provide nutrition - null until you enrich later
    calories: null,
    protein: null,
    carbs: null,
    fat: null,
    imageUrl: meal.strMealThumb || null,
    sourceUrl: meal.strSource || meal.strYoutube || null,
    // Use Edamam-compatible health labels
    healthLabels: healthLabels,
    source: 'themealdb',
  };
}

/**
 * Fetch all meals by iterating through alphabet
 */
async function fetchAllMeals() {
  const allMeals = [];
  const letters = 'abcdefghijklmnopqrstuvwxyz'.split('');
  const baseUrl = 'https://www.themealdb.com/api/json/v1/1';

  console.log('Fetching recipes from TheMealDB...\n');

  for (const letter of letters) {
    try {
      const url = `${baseUrl}/search.php?f=${letter}`;
      const response = await fetch(url);
      const data = await response.json();

      if (data.meals) {
        console.log(`Letter ${letter.toUpperCase()}: Found ${data.meals.length} recipes`);
        allMeals.push(...data.meals);
      } else {
        console.log(`Letter ${letter.toUpperCase()}: No recipes`);
      }

      // Small delay to be nice to the API
      await new Promise(resolve => setTimeout(resolve, 100));
    } catch (error) {
      console.error(`Error fetching letter ${letter}:`, error.message);
    }
  }

  return allMeals;
}

async function main() {
  const fs = await import('fs');
  
  try {
    const meals = await fetchAllMeals();
    console.log(`\n✅ Total meals fetched: ${meals.length}`);

    const recipes = meals.map(transformMeal);

    // Save to JSON file
    const outputPath = './recipes_for_firestore.json';
    fs.writeFileSync(outputPath, JSON.stringify(recipes, null, 2));
    console.log(`\n📁 Saved to: ${outputPath}`);

    // Print cuisine distribution
    const cuisineCounts = {};
    recipes.forEach(r => {
      cuisineCounts[r.cuisine] = (cuisineCounts[r.cuisine] || 0) + 1;
    });
    console.log('\n📊 Cuisine distribution:');
    Object.entries(cuisineCounts)
      .sort((a, b) => b[1] - a[1])
      .forEach(([cuisine, count]) => {
        console.log(`  ${cuisine}: ${count}`);
      });

    // Print health label distribution (Edamam format)
    const labelCounts = {};
    recipes.forEach(r => {
      r.healthLabels.forEach(label => {
        labelCounts[label] = (labelCounts[label] || 0) + 1;
      });
    });
    console.log('\n🏷️  Health labels (Edamam format):');
    Object.entries(labelCounts)
      .sort((a, b) => b[1] - a[1])
      .forEach(([label, count]) => {
        console.log(`  ${label}: ${count}`);
      });

    console.log('\n✨ Done! You can now manually import recipes_for_firestore.json to Firestore.');
    console.log('\nTo import to Firestore:');
    console.log('1. Go to Firebase Console → Firestore');
    console.log('2. Create collection named "recipes"');
    console.log('3. Use a tool like https://firestoregui.com or import via Admin SDK');

  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

main();
