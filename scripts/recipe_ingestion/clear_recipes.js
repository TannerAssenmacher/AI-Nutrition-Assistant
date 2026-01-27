/**
 * Clear all recipes from Firestore "recipes" collection
 * and optionally from PostgreSQL embeddings table
 * 
 * SAFE: This script ONLY deletes from the "recipes" collection
 * It will NOT touch the Users collection
 * 
 * Run: npm run clear-recipes
 */

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

// SAFETY CHECK: Only this collection will be modified
const TARGET_COLLECTION = 'recipes';

// Initialize Firebase Admin
initializeApp({
  projectId: 'ai-nutrition-assistant-e2346',
});

const db = getFirestore();

async function clearRecipes() {
  console.log('='.repeat(50));
  console.log('⚠️  RECIPE COLLECTION CLEAR');
  console.log('='.repeat(50));
  console.log(`Target collection: ${TARGET_COLLECTION}`);
  console.log('This will DELETE ALL recipes from Firestore');
  console.log('Users collection will NOT be affected');
  console.log('='.repeat(50));
  console.log('\n⏳ Starting in 5 seconds... (Ctrl+C to cancel)\n');
  
  await new Promise(resolve => setTimeout(resolve, 5000));
  
  // Get all recipes
  console.log('📊 Counting existing recipes...');
  const snapshot = await db.collection(TARGET_COLLECTION).get();
  const totalDocs = snapshot.size;
  
  if (totalDocs === 0) {
    console.log('✅ Collection is already empty!');
    return;
  }
  
  console.log(`Found ${totalDocs} recipes to delete\n`);
  
  // Delete in batches of 500 (Firestore limit)
  const BATCH_SIZE = 500;
  let deleted = 0;
  
  // Process in batches
  const docs = snapshot.docs;
  
  for (let i = 0; i < docs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = docs.slice(i, i + BATCH_SIZE);
    
    for (const doc of chunk) {
      batch.delete(doc.ref);
    }
    
    await batch.commit();
    deleted += chunk.length;
    console.log(`🗑️  Deleted ${deleted}/${totalDocs} recipes`);
  }
  
  console.log('\n' + '='.repeat(50));
  console.log('✅ CLEAR COMPLETE');
  console.log('='.repeat(50));
  console.log(`Deleted: ${deleted} recipes`);
  console.log('\nNote: PostgreSQL embeddings will be updated when new recipes are added');
  console.log('(Old embeddings with no matching Firestore doc are harmless)');
}

clearRecipes().catch(console.error);
