/**
 * Count Recipes Script
 *
 * Shows statistics about recipes in Firestore.
 */

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

initializeApp({ projectId: 'ai-nutrition-assistant-e2346' });
const db = getFirestore();

async function countRecipes() {
  console.log('\n📊 Recipe Database Statistics\n' + '='.repeat(50));

  try {
    // Get all recipes
    const allRecipes = await db.collection('recipes').select().get();
    console.log(`\n✅ Total Recipes: ${allRecipes.size}`);

    // Get spoonacular recipes
    const spoonacularRecipes = await db.collection('recipes')
      .where('source', '==', 'spoonacular')
      .select()
      .get();
    console.log(`✅ Spoonacular Recipes: ${spoonacularRecipes.size}`);

    // Sample cuisine distribution (first 100 recipes)
    const sampleRecipes = await db.collection('recipes')
      .where('source', '==', 'spoonacular')
      .limit(100)
      .get();

    const cuisines = {};
    const mealTypes = {};
    const healthLabels = {};

    sampleRecipes.docs.forEach(doc => {
      const data = doc.data();

      // Count cuisines
      const cuisine = data.cuisine || 'unknown';
      cuisines[cuisine] = (cuisines[cuisine] || 0) + 1;

      // Count meal types
      (data.mealTypes || []).forEach(meal => {
        mealTypes[meal] = (mealTypes[meal] || 0) + 1;
      });

      // Count health labels
      (data.healthLabels || []).forEach(label => {
        healthLabels[label] = (healthLabels[label] || 0) + 1;
      });
    });

    console.log('\n📋 Cuisine Distribution (sample of 100):');
    Object.entries(cuisines)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .forEach(([cuisine, count]) => {
        console.log(`   ${cuisine}: ${count}`);
      });

    console.log('\n🍽️  Meal Type Distribution (sample of 100):');
    Object.entries(mealTypes)
      .sort((a, b) => b[1] - a[1])
      .forEach(([meal, count]) => {
        console.log(`   ${meal}: ${count}`);
      });

    console.log('\n🏷️  Top Health Labels (sample of 100):');
    Object.entries(healthLabels)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .forEach(([label, count]) => {
        console.log(`   ${label}: ${count}`);
      });

    console.log('\n' + '='.repeat(50));
    console.log('✅ Statistics Complete\n');

  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

countRecipes().catch(console.error);
