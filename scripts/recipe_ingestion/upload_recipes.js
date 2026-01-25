/**
 * Upload recipes to Firestore "recipes" collection
 * 
 * SAFE: This script ONLY writes to the "recipes" collection
 * It will NOT touch the Users collection
 * 
 * Run: node upload_recipes.js
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// SAFETY CHECK: Only this collection will be written to
const TARGET_COLLECTION = 'recipes';

// Initialize Firebase Admin
// Uses Application Default Credentials from gcloud auth
initializeApp({
  projectId: 'ai-nutrition-assistant-e2346',
});

const db = getFirestore();

async function uploadRecipes() {
  // Load recipes from JSON
  const recipesPath = path.join(__dirname, 'recipes_for_firestore.json');
  
  if (!fs.existsSync(recipesPath)) {
    console.error('Error: recipes_for_firestore.json not found');
    console.log('Run "npm run fetch" first to generate the recipes file');
    process.exit(1);
  }

  const recipes = JSON.parse(fs.readFileSync(recipesPath, 'utf8'));
  console.log(`Loaded ${recipes.length} recipes from JSON\n`);

  // Confirm before proceeding
  console.log('='.repeat(50));
  console.log('SAFETY CHECK');
  console.log('='.repeat(50));
  console.log(`Target collection: ${TARGET_COLLECTION}`);
  console.log(`Recipes to upload: ${recipes.length}`);
  console.log('This will NOT modify the Users collection');
  console.log('='.repeat(50));
  console.log('\nStarting upload in 3 seconds... (Ctrl+C to cancel)\n');
  
  await new Promise(resolve => setTimeout(resolve, 3000));

  // Upload in batches of 500 (Firestore limit)
  const BATCH_SIZE = 500;
  let uploaded = 0;
  let failed = 0;

  for (let i = 0; i < recipes.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = recipes.slice(i, i + BATCH_SIZE);

    for (const recipe of chunk) {
      // Use the recipe's id as the document ID
      const docRef = db.collection(TARGET_COLLECTION).doc(recipe.id);
      
      // Add createdAt timestamp
      const recipeData = {
        ...recipe,
        createdAt: new Date(),
      };

      batch.set(docRef, recipeData);
    }

    try {
      await batch.commit();
      uploaded += chunk.length;
      console.log(`Uploaded ${uploaded}/${recipes.length} recipes`);
    } catch (error) {
      console.error(`Batch failed:`, error.message);
      failed += chunk.length;
    }
  }

  console.log('\n' + '='.repeat(50));
  console.log('UPLOAD COMPLETE');
  console.log('='.repeat(50));
  console.log(`Successfully uploaded: ${uploaded}`);
  console.log(`Failed: ${failed}`);
  console.log(`\nThe onRecipeCreated trigger will now generate embeddings.`);
  console.log(`This may take a few minutes for ${uploaded} recipes.`);
  console.log('\nCheck Cloud Functions logs:');
  console.log('firebase functions:log --only onRecipeCreated');
}

uploadRecipes().catch(console.error);
