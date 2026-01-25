const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'ai-nutrition-assistant-e2346'
});

const db = admin.firestore();

async function retriggerEmbeddings() {
  console.log('Reading recipes from JSON file...');
  const recipesPath = path.join(__dirname, 'recipes_for_firestore.json');
  const recipes = JSON.parse(fs.readFileSync(recipesPath, 'utf-8'));
  
  console.log(`Found ${recipes.length} recipes to re-trigger`);
  
  // Process in smaller batches to avoid overwhelming the function
  const batchSize = 20;
  let processed = 0;
  
  for (let i = 0; i < recipes.length; i += batchSize) {
    const batch = recipes.slice(i, i + batchSize);
    
    // Delete and re-create each recipe to trigger onCreate
    for (const recipe of batch) {
      const recipeId = recipe.id;
      const docRef = db.collection('recipes').doc(recipeId);
      
      try {
        // Delete the existing document
        await docRef.delete();
        
        // Small delay to ensure delete is processed
        await new Promise(resolve => setTimeout(resolve, 100));
        
        // Re-create the document (triggers onCreate)
        await docRef.set({
          ...recipe,
          recreatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        processed++;
      } catch (error) {
        console.error(`Error processing recipe ${recipeId}:`, error.message);
      }
    }
    
    console.log(`Processed ${processed}/${recipes.length} recipes...`);
    
    // Wait between batches to let Cloud Functions process
    if (i + batchSize < recipes.length) {
      console.log('Waiting 5 seconds before next batch...');
      await new Promise(resolve => setTimeout(resolve, 5000));
    }
  }
  
  console.log('\n✅ All recipes re-triggered for embedding generation!');
  console.log('Check Cloud Functions logs to monitor progress.');
}

retriggerEmbeddings().catch(console.error);
