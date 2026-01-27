/**
 * Cleanup Old Recipes Script
 *
 * Deletes all recipes in Firestore where the document ID does NOT start with 'spoonacular_'.
 * This preserves all Spoonacular recipes and removes any legacy/old recipes.
 *
 * Usage:
 *   export GOOGLE_APPLICATION_CREDENTIALS=serviceAccountKey.json
 *   node cleanup_old_recipes.js
 */

import { initializeApp, applicationDefault, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import process from 'process';

// Initialize Firebase
initializeApp({
  credential: process.env.GOOGLE_APPLICATION_CREDENTIALS
    ? cert(process.env.GOOGLE_APPLICATION_CREDENTIALS)
    : applicationDefault(),
  projectId: 'ai-nutrition-assistant-e2346',
});
const db = getFirestore();

async function main() {
  const BATCH_SIZE = 500;
  let deleted = 0;
  let lastDoc = null;
  let hasMore = true;

  console.log('🔍 Scanning for old recipes to delete...');

  while (hasMore) {
    let query = db.collection('recipes')
      .orderBy('__name__')
      .limit(BATCH_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);
    const snapshot = await query.get();
    if (snapshot.empty) break;

    const batch = db.batch();
    let batchCount = 0;
    snapshot.docs.forEach(doc => {
      if (!doc.id.startsWith('spoonacular_')) {
        batch.delete(doc.ref);
        batchCount++;
      }
    });
    if (batchCount > 0) {
      await batch.commit();
      deleted += batchCount;
      console.log(`🗑️ Deleted ${batchCount} old recipes in this batch...`);
    }
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    hasMore = snapshot.size === BATCH_SIZE;
  }

  console.log(`✅ Cleanup complete. Total old recipes deleted: ${deleted}`);
}

main().catch(e => { console.error(e); process.exit(1); });
