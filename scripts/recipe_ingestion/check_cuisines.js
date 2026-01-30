import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

initializeApp({ projectId: 'ai-nutrition-assistant-e2346' });
const db = getFirestore();

const snapshot = await db.collection('recipes').get();
const cuisines = {};

snapshot.docs.forEach(doc => {
  const cuisine = doc.data().cuisine || 'unknown';
  cuisines[cuisine] = (cuisines[cuisine] || 0) + 1;
});

console.log('\n📊 Cuisine Distribution (Total recipes: ' + snapshot.size + ')\n');
Object.entries(cuisines)
  .sort((a, b) => b[1] - a[1])
  .forEach(([cuisine, count]) => {
    const percent = ((count / snapshot.size) * 100).toFixed(1);
    const paddedCuisine = cuisine.padEnd(20);
    const paddedCount = count.toString().padStart(4);
    console.log(`   ${paddedCuisine} ${paddedCount} (${percent}%)`);
  });

console.log('\n✅ Database updated!\n');
