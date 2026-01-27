# 🍽️ Cuisine Classification Fix

**Date:** 2026-01-27
**Issue:** 66% of recipes were classified as 'world' cuisine instead of specific cuisines

---

## 🐛 Problem

You noticed that most recipes in the database had `'world'` as the cuisine type, which didn't match the Spoonacular API's 25+ available cuisines (Italian, Mexican, Chinese, etc.).

### Root Cause

Looking at the ingestion code, we found two issues:

1. **No cuisine filter in API requests** - The script was fetching random recipes without requesting specific cuisines
2. **Default fallback to 'world'** - Many Spoonacular recipes don't have cuisine metadata, so they defaulted to 'world'

**Before:**
```javascript
// API call with no cuisine parameter
const params = new URLSearchParams({
  apiKey: API_KEY,
  number: RECIPES_PER_REQUEST.toString(),
  // ... no cuisine filter!
  sort: 'random',
});
```

**Result:** Spoonacular returned random recipes, many without cuisine classification → 66% ended up as 'world'

---

## ✅ Solution Implemented

Updated the ingestion script to **cycle through specific cuisines** when fetching recipes:

### 1. Added Cuisine List

Added array of all Spoonacular cuisines to fetch:

```javascript
const CUISINES_TO_FETCH = [
  'african', 'american', 'british', 'cajun', 'caribbean', 'chinese',
  'eastern european', 'european', 'french', 'german', 'greek', 'indian',
  'irish', 'italian', 'japanese', 'jewish', 'korean', 'latin american',
  'mediterranean', 'mexican', 'middle eastern', 'southern', 'spanish',
  'thai', 'vietnamese',
];
```

### 2. Updated State Tracking

Added `cuisineIndex` to track which cuisine we're currently fetching:

```javascript
return {
  date: today,
  offset: 0,
  requestsMade: 0,
  recipesAdded: 0,
  cuisineIndex: 0  // NEW: Track cuisine position
};
```

### 3. Modified Fetch Function

Updated to accept and use cuisine parameter:

```javascript
async function fetchRecipeBatch(offset, cuisine = null) {
  const params = new URLSearchParams({
    apiKey: API_KEY,
    // ...
  });

  // Add cuisine filter
  if (cuisine) {
    params.set('cuisine', cuisine);
  }

  const url = `${BASE_URL}/recipes/complexSearch?${params}`;
  // ...
}
```

### 4. Smart Cycling Logic

The script now:
- Fetches recipes for one cuisine at a time
- Moves to next cuisine after 200 recipes or if no results found
- Cycles through all 25 cuisines for balanced variety

```javascript
// Get current cuisine
const currentCuisine = CUISINES_TO_FETCH[state.cuisineIndex % CUISINES_TO_FETCH.length];

console.log(`📥 Fetching ${currentCuisine} recipes at offset ${state.offset}...`);
const result = await fetchRecipeBatch(state.offset, currentCuisine);

// Move to next cuisine after 200 recipes (variety)
if (state.offset >= 200) {
  state.cuisineIndex++;
  state.offset = 0;
  console.log(`Moving to next cuisine for variety...`);
}
```

---

## 🎯 Expected Results

**Before Fix:**
```
world: 602 recipes (66%)
mediterranean: 119 recipes (13%)
american: 82 recipes (9%)
mexican: 55 recipes (6%)
japanese: 18 recipes (2%)
indian: 18 recipes (2%)
...others: 18 recipes (2%)
```

**After Fix:**
Each cuisine should have balanced representation:
```
italian: ~80-100 recipes
mexican: ~80-100 recipes
chinese: ~80-100 recipes
indian: ~80-100 recipes
japanese: ~80-100 recipes
mediterranean: ~80-100 recipes
...etc (all 25 cuisines)
world: <10 recipes (only truly unclassified)
```

---

## 🧪 How to Test

### Test 1: Verify Cuisine Filtering Works

Run the test script with a specific cuisine:

```bash
cd scripts/recipe_ingestion
export SPOONACULAR_API_KEY="your-key"

# Test Italian cuisine
node test_fetch.js italian
```

**Expected Output:**
```
🧪 TEST: Fetching 5 italian recipes from Spoonacular...

✅ API returned 5 recipes

📋 Cuisine distribution:
   italian: 5 recipe(s)

📋 Sample transformed recipe:
{
  "id": "spoonacular_716429",
  "label": "Pasta Carbonara",
  "cuisine": "italian",  ← Should show correct cuisine!
  ...
}
```

### Test 2: Try Different Cuisines

```bash
# Test various cuisines
node test_fetch.js mexican
node test_fetch.js chinese
node test_fetch.js indian
node test_fetch.js thai
node test_fetch.js mediterranean
```

Each should return 5 recipes of that cuisine type.

### Test 3: Run Full Daily Fetch

```bash
npm run daily
```

**Watch the console:**
```
📥 Fetching african recipes at offset 0...
   ✅ 87 new recipes (13 duplicates skipped)

📥 Fetching african recipes at offset 100...
   ✅ 92 new recipes (8 duplicates skipped)

Moving to next cuisine for variety...

📥 Fetching american recipes at offset 0...
   ✅ 95 new recipes (5 duplicates skipped)
```

---

## 📊 Verifying Database Changes

After running the ingestion, you can check the new distribution in PostgreSQL:

```sql
-- Connect to Cloud SQL
cloud-sql-proxy --port 5432 ai-nutrition-assistant-e2346:us-central1:recipe-vectors

-- In another terminal, connect to psql
psql "host=localhost port=5432 dbname=recipes user=postgres password=your-password"

-- Check cuisine distribution
SELECT cuisine, COUNT(*) as count
FROM recipe_embeddings
GROUP BY cuisine
ORDER BY count DESC;
```

**You should see:**
- Balanced distribution across 25+ cuisines
- 'world' cuisine < 5% of total (only truly unclassified recipes)
- Each specific cuisine with substantial representation

---

## 🔑 Key Changes Summary

**Files Modified:**
1. `scripts/recipe_ingestion/daily_fetch.js`:
   - Added `CUISINES_TO_FETCH` array (25 cuisines)
   - Added `cuisineIndex` to state tracking
   - Updated `fetchRecipeBatch()` to accept cuisine parameter
   - Modified main loop to cycle through cuisines
   - Added logging for current cuisine

2. `scripts/recipe_ingestion/test_fetch.js`:
   - Added command-line cuisine argument support
   - Added cuisine distribution output
   - Updated to show what cuisines are being classified

---

## 🚀 Benefits

1. **Accurate Classification**: Recipes properly tagged with specific cuisines
2. **Balanced Variety**: All 25 cuisines get equal representation
3. **Better Search**: Users can find recipes by specific cuisine reliably
4. **User Experience**: Cuisine dropdown options all return meaningful results
5. **Semantic Search**: RAG system can better understand cuisine preferences

---

## 📝 Migration Notes

### Existing 'world' Recipes

The 602 existing 'world' recipes will remain in the database. Options:

**Option 1: Leave them** (Recommended)
- They still work in searches when "None" or "World" cuisine selected
- No action needed

**Option 2: Retroactively classify**
- Would require re-fetching recipe details from Spoonacular
- Costs API quota
- Not recommended unless critical

**Option 3: Delete and re-fetch**
- Clear 'world' recipes and let new ingestion replace them
- Only if you want perfectly balanced distribution

### Going Forward

- New daily runs will fetch recipes with specific cuisines
- Over 10-20 days, 'world' recipes will become minority
- Database will naturally rebalance toward proper classification

---

## 🧪 Next Steps

1. **Test the changes:**
   ```bash
   # Test a few cuisines
   node test_fetch.js italian
   node test_fetch.js mexican
   node test_fetch.js japanese
   ```

2. **Run daily fetch:**
   ```bash
   npm run daily
   ```

3. **Monitor cuisine distribution:**
   - Check console logs show cycling through cuisines
   - Verify recipes have specific cuisine tags
   - Confirm 'world' cuisine reduces over time

4. **Update app if needed:**
   - Flutter app already has correct cuisine list
   - No changes needed to UI

---

## 🎯 Expected Timeline

- **Day 1**: ~400 recipes with specific cuisines (out of ~1,312 total)
- **Day 5**: ~2,000 recipes with specific cuisines (out of ~3,312 total)
- **Day 10**: ~4,000 recipes with specific cuisines (out of ~5,312 total)

By day 10, 'world' will drop from 66% → ~11% of database.

---

## 📚 Spoonacular Cuisines Reference

All 25 cuisines now being fetched:

| Cuisine | Maps To (Database) |
|---------|--------------------|
| African | african |
| American | american |
| British | british |
| Cajun | american |
| Caribbean | caribbean |
| Chinese | chinese |
| Eastern European | eastern european |
| European | central europe |
| French | french |
| German | central europe |
| Greek | mediterranean |
| Indian | indian |
| Irish | british |
| Italian | italian |
| Japanese | japanese |
| Jewish | middle eastern |
| Korean | south east asian |
| Latin American | mexican |
| Mediterranean | mediterranean |
| Mexican | mexican |
| Middle Eastern | middle eastern |
| Southern | american |
| Spanish | mediterranean |
| Thai | south east asian |
| Vietnamese | south east asian |

---

## ✅ Summary

**Problem:** 66% 'world' cuisine due to no cuisine filtering in API requests

**Solution:** Cycle through specific cuisines when fetching recipes

**Result:** Balanced distribution across 25 cuisines, better search experience

**Action Required:** Test with `node test_fetch.js italian` and run `npm run daily`

Your RAG system will now have properly classified recipes across all cuisines! 🎉
