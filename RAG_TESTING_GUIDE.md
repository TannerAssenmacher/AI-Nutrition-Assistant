# 🧪 RAG System Testing Guide
**Date:** 2026-01-27
**App URL:** http://localhost:8080

---

## 🎯 Testing Objectives

Test the complete RAG-based recipe recommendation system:
1. ✅ Recipe search with meal type & cuisine selection
2. ✅ Personalized filtering based on user profile
3. ✅ Health restriction compliance
4. ✅ Dietary goal integration (Lose/Maintain/Gain Weight)
5. ✅ Calorie and macro goal filtering
6. ✅ Ingredient like/dislike filtering
7. ✅ Recipe display with complete nutrition data
8. ✅ "Show more recipes" functionality

---

## 👥 Test Users Available

Your database has **6 test users** with different profiles:

### User 1: Alex Nash (Balanced Weight Loss)
```
Profile:
- Goal: Lose Weight
- Activity: Moderately Active
- Height: 73", Weight: 210 lbs
- Macros: 48% carbs, 20% protein, 32% fat
- Dietary: Balanced
- Restrictions: None
- Likes/Dislikes: None specified

Best For Testing:
- Basic weight loss recommendations
- Balanced macro distribution
- No dietary restrictions
```

### User 2: Anand Patel (High-Protein Vegetarian)
```
Profile:
- Goal: Maintain Weight
- Activity: Very Active
- Height: 70", Weight: 180 lbs
- Calories: 2500/day
- Macros: 40% carbs, 30% protein, 30% fat
- Dietary: High-protein
- Restrictions: Vegetarian ⭐
- Likes: Pizza, curry
- Dislikes: Eggs, eggplant ⭐

Best For Testing:
- Health restriction filtering (vegetarian)
- Ingredient dislikes (eggs, eggplant)
- High calorie goals
- Food preferences
```

### User 3: Catalina Ocampo (Aggressive Weight Loss)
```
Profile:
- Goal: Lose Weight
- Activity: Sedentary
- Height: 63", Weight: 555 lbs
- Calories: 1000/day ⭐
- Macros: 46% protein, 24% carbs, 30% fat
- Dietary: None
- Restrictions: None

Best For Testing:
- Very low calorie filtering (1000 cal)
- High protein recommendations
- Weight loss optimization
```

### User 4: Denis Irala (Low Calorie)
```
Profile:
- Goal: Lose Weight
- Activity: Sedentary
- Height: 10" (data issue), Weight: 80 lbs
- Calories: 1000/day
- Macros: 75% carbs, 7% protein, 19% fat
- Dietary: None
- Restrictions: None

Best For Testing:
- Low calorie scenarios
- Carb-heavy recommendations
```

### User 5: Tanner Assenmacher (Low-Fat, Alcohol-Free)
```
Profile:
- Goal: Lose Weight
- Activity: Moderately Active
- Height: 122", Weight: 144 lbs
- Calories: 1000/day
- Macros: 40% carbs, 30% protein, 30% fat
- Dietary: Low-fat ⭐
- Restrictions: Alcohol-free ⭐
- Likes: Rice ⭐
- Dislikes: Broccoli ⭐

Best For Testing:
- Multiple filters (low-fat + alcohol-free)
- Ingredient preferences (rice)
- Ingredient exclusions (broccoli)
```

### User 6: Hugo Putigna (Balanced Maintenance)
```
Profile:
- Goal: Lose Weight
- Activity: Moderately Active
- Height: 72", Weight: 220 lbs
- Calories: 2100/day
- Macros: 35% carbs, 30% protein, 35% fat
- Dietary: None
- Restrictions: None

Best For Testing:
- Moderate calorie filtering
- Balanced recommendations
```

---

## 🧪 Test Scenarios

### Test 1: Basic Recipe Search ⭐ START HERE

**User:** Alex Nash (simplest profile)

**Steps:**
1. Open app: http://localhost:8080
2. Sign in as Alex Nash
3. Navigate to Chat/Recipe Generator screen
4. Select **Meal Type:** Dinner
5. Select **Cuisine:** Italian
6. Confirm profile when prompted
7. Wait for recipe results

**Expected Results:**
- ✅ Shows 3 Italian dinner recipes
- ✅ Each recipe has: title, image, nutrition (calories, protein, carbs, fat, fiber, sugar, sodium)
- ✅ Ingredients list displayed
- ✅ Instructions available
- ✅ Calorie range appropriate for dinner (~30-35% of daily goal)

**What to Check:**
```
Recipe 1:
- Label: [Recipe name]
- Cuisine: italian
- Calories: [Check if reasonable for dinner]
- Protein: [grams]
- Carbs: [grams]
- Fat: [grams]
- Fiber: [grams] ⭐
- Sugar: [grams] ⭐
- Sodium: [mg] ⭐
- Ingredients: [Should list all ingredients]
- Instructions: [Should show cooking steps]
```

---

### Test 2: Vegetarian with Dislikes ⭐ IMPORTANT

**User:** Anand Patel

**Steps:**
1. Sign in as Anand Patel
2. Navigate to Recipe Generator
3. Select **Meal Type:** Lunch
4. Select **Cuisine:** Indian (or World)
5. Confirm profile

**Expected Results:**
- ✅ ALL recipes must be vegetarian
- ✅ NO recipes contain eggs or eggplant
- ✅ Recipes should include curry-style dishes (matches "likes")
- ✅ Higher calorie range (2500 cal goal, lunch = ~750 cal target)

**Critical Checks:**
- 🔍 Open each recipe's ingredients
- 🔍 Verify NO eggs, NO eggplant
- 🔍 Verify health labels include "vegetarian"

**If you see eggs/eggplant:** ❌ Bug - dislikes filter not working

---

### Test 3: Very Low Calorie Filtering

**User:** Catalina Ocampo (1000 cal/day)

**Steps:**
1. Sign in as Catalina
2. Select **Meal Type:** Dinner
3. Select **Cuisine:** Mexican
4. Confirm profile

**Expected Results:**
- ✅ All recipes between 175-455 calories
  - Calculation: Dinner = 35% of 1000 = 350 cal target
  - Range: 350 × 0.5 to 350 × 1.3 = 175-455 cal
- ✅ High protein recipes preferred (46% protein goal)
- ✅ Lower carb options (24% carbs)

**What to Check:**
```
Recipe Calories:
Recipe 1: [Should be 175-455 range]
Recipe 2: [Should be 175-455 range]
Recipe 3: [Should be 175-455 range]

If any recipe > 455 cal: ⚠️ Calorie filter may have relaxed (check isExactMatch)
```

---

### Test 4: Multiple Health Restrictions

**User:** Tanner Assenmacher

**Steps:**
1. Sign in as Tanner
2. Select **Meal Type:** Breakfast
3. Select **Cuisine:** American
4. Confirm profile

**Expected Results:**
- ✅ ALL recipes must be alcohol-free (health restriction)
- ✅ Recipes should favor low-fat options (dietary habit)
- ✅ Recipes with rice preferred (likes)
- ✅ NO broccoli in any recipe (dislikes)

**Critical Checks:**
- 🔍 Health labels should include "alcohol-free"
- 🔍 Check each recipe for broccoli in ingredients
- 🔍 Verify fat content is reasonable for low-fat diet

---

### Test 5: High-Protein Diet

**User:** Anand Patel (30% protein)

**Steps:**
1. Sign in as Anand
2. Select **Meal Type:** Dinner
3. Select **Cuisine:** None (to test broader search)
4. Confirm profile

**Expected Results:**
- ✅ Recipes should have high protein content
- ✅ Protein provides ≥20% of recipe calories
  - Formula: (protein_g × 4 cal/g) / total_calories ≥ 0.20
- ✅ Example: 30g protein, 600 cal recipe = (30×4)/600 = 20% ✅

**What to Check:**
```
For each recipe, calculate:
(Protein grams × 4) / Calories = Protein %

Recipe 1: (25 × 4) / 500 = 20% ✅
Recipe 2: (15 × 4) / 450 = 13.3% ❌ (too low)
Recipe 3: (35 × 4) / 600 = 23.3% ✅
```

---

### Test 6: Show More Recipes

**User:** Any user (recommend Alex Nash)

**Steps:**
1. Complete Test 1 (Basic Recipe Search)
2. After seeing 3 recipes, click **"Show More Recipes"** button
3. Repeat 2-3 times

**Expected Results:**
- ✅ Each click shows 3 NEW recipes (no duplicates)
- ✅ Recipes maintain same filters (meal type, cuisine, restrictions)
- ✅ System tracks shown recipes to avoid repeats

**What to Check:**
```
First batch: Recipe A, B, C
Second batch: Recipe D, E, F (not A, B, or C)
Third batch: Recipe G, H, I (not A-F)

If you see duplicates: ❌ Bug - excludeIds not working
```

---

### Test 7: Relaxed Search (No Exact Matches)

**User:** Create a very restrictive scenario

**Steps:**
1. Sign in as Anand Patel
2. Select **Meal Type:** Breakfast
3. Select **Cuisine:** Thai
4. Confirm profile

**Expected Results:**
- ⚠️ Likely triggers relaxed search (vegetarian + Thai breakfast is rare)
- ✅ System shows message: "I couldn't find recipes that match all your preferences exactly. Here are some close alternatives..."
- ✅ Still respects dislikes (eggs, eggplant) for safety
- ✅ May not be Thai or breakfast, but still vegetarian

**What to Check:**
- 🔍 Did you see the "close alternatives" message?
- 🔍 Are recipes still safe (no eggs/eggplant)?
- 🔍 Are recipes still vegetarian (safety critical)?

---

### Test 8: Recipe Detail Verification

**User:** Any user

**Steps:**
1. Get any recipe results
2. Select one recipe to view details
3. Check all fields are populated

**Expected Results:**
```
✅ Label: [Recipe name]
✅ Image: [Should display recipe photo]
✅ Cuisine: [italian/mexican/etc.]
✅ Meal Types: [breakfast/lunch/dinner]
✅ Calories: [number] cal
✅ Protein: [number]g
✅ Carbs: [number]g
✅ Fat: [number]g
✅ Fiber: [number]g ⭐ NEW FIELD
✅ Sugar: [number]g ⭐ NEW FIELD
✅ Sodium: [number]mg ⭐ NEW FIELD
✅ Servings: [number]
✅ Ready Time: [number] minutes
✅ Ingredients: [Full list with measurements]
✅ Instructions: [Step-by-step cooking directions]
```

**Critical Checks:**
- 🔍 Are fiber, sugar, sodium populated? (Not null/0)
- 🔍 Are instructions readable and formatted?
- 🔍 Are ingredient lines showing quantities (e.g., "1 cup flour")?

---

### Test 9: Different Meal Types & Cuisines

**User:** Alex Nash (simple profile)

**Try Multiple Combinations:**

| Meal Type | Cuisine | Expected Result |
|-----------|---------|-----------------|
| Breakfast | American | Pancakes, eggs, bacon dishes |
| Lunch | Mexican | Tacos, burritos, enchiladas |
| Dinner | Italian | Pasta, pizza, risotto |
| Snack | Mediterranean | Hummus, olives, small plates |
| Breakfast | World | International breakfast options |
| Dinner | Asian | Stir-fry, noodles, rice dishes |

**What to Check:**
- ✅ Results match meal type (breakfast items for breakfast)
- ✅ Results match cuisine (Italian recipes for Italian)
- ✅ Good variety across different selections
- ✅ No repeated recipes across different searches

---

### Test 10: Database Growth Verification

**Steps:**
1. Navigate to Recipe Generator
2. Try multiple searches
3. Note recipe variety

**Expected Results:**
- ✅ With 912 recipes in database, you should see good variety
- ✅ Different searches return different recipes
- ✅ Minimal repetition when requesting more recipes
- ✅ Coverage across different cuisines and meal types

**What to Check:**
```
Database Status:
- Total recipes: 912 ✅
- Cuisines: 66% world, 13% mediterranean, 9% american, 6% mexican
- Coverage: Good variety expected
```

---

## 🐛 Common Issues & Troubleshooting

### Issue 1: No Recipes Returned
**Symptoms:** "I couldn't find any recipes right now"

**Possible Causes:**
1. Cloud Function error (check browser console)
2. PostgreSQL not accessible (embeddings missing)
3. Filters too restrictive (should trigger relaxed search)

**Debug Steps:**
```bash
# Check Cloud Functions logs
firebase functions:log --only searchRecipes

# Verify recipes exist
cd scripts/recipe_ingestion
npm run count

# Check embeddings (requires Cloud SQL Proxy)
npm run verify-embeddings
```

### Issue 2: Wrong Recipes Returned
**Symptoms:** Non-vegetarian for vegetarian user, wrong cuisine, etc.

**Possible Causes:**
1. Health labels not properly set in database
2. Cuisine mapping incorrect
3. Filter not applied in Cloud Function

**Debug Steps:**
- Check recipe in Firestore for correct labels
- Verify PostgreSQL has correct health_labels array
- Check Cloud Function logs for filter parameters

### Issue 3: Disliked Ingredients Appear
**Symptoms:** User sees eggs when they dislike eggs

**This is a CRITICAL bug** - dislikes filter must work for allergies

**Debug Steps:**
```javascript
// Check Cloud Function searchRecipes
// Line 346-349 in functions/src/index.ts
if (dislikes.length > 0) {
  sql += ` AND NOT (ingredients && $${paramIndex}::text[])`;
  params.push(dislikes.map(d => d.toLowerCase()));
}
```

### Issue 4: Duplicate Recipes
**Symptoms:** Same recipe appears multiple times

**Possible Causes:**
1. excludeIds not being tracked properly
2. Client-side filtering not working

**Debug Steps:**
- Check `_shownRecipeUris` in chat service
- Verify excludeIds parameter in Cloud Function call

### Issue 5: Missing Nutrition Data
**Symptoms:** Fiber, sugar, or sodium showing as null/0

**Expected:** Most recipes should have these fields populated

**Debug Steps:**
```bash
# Check a few recipes in Firestore
# Verify they have fiber, sugar, sodium fields

# If missing, re-run ingestion with current schema
npm run daily
```

### Issue 6: Very High/Low Calories
**Symptoms:** 100-cal dinner or 2000-cal breakfast

**Possible Causes:**
1. Calorie filter not applied correctly
2. Per-serving calculation issue in API data
3. Estimation fallback providing incorrect values

**Debug Steps:**
- Check recipe servings count
- Verify calories are per-serving, not total
- Check Cloud Function logs for calorie range

---

## 📊 Success Metrics

### Must Pass (Critical)
- ✅ Vegetarian filter works (Test 2)
- ✅ Dislikes filter works - NO disliked ingredients (Test 2, 4)
- ✅ Recipes display complete nutrition (Test 8)
- ✅ No duplicate recipes in pagination (Test 6)
- ✅ Fiber, sugar, sodium populated (Test 8)

### Should Pass (Important)
- ✅ Calorie filtering appropriate for meal type (Test 3)
- ✅ High-protein filter for high-protein diets (Test 5)
- ✅ Multiple health restrictions work together (Test 4)
- ✅ Relaxed search triggers when needed (Test 7)
- ✅ Good variety across cuisines (Test 9)

### Nice to Have
- ✅ Likes influence results (recipes with liked ingredients)
- ✅ Cuisine variety in "World" category
- ✅ Instructions are well-formatted
- ✅ Images load quickly

---

## 🎯 Test Results Template

Copy this and fill in your results:

```markdown
## Test Results - [Date]

### Test 1: Basic Recipe Search (Alex Nash)
- Status: ✅ / ⚠️ / ❌
- Meal Type: Dinner
- Cuisine: Italian
- Recipes Returned: [3/0]
- Nutrition Complete: [Yes/No]
- Fiber/Sugar/Sodium: [Yes/No]
- Notes: [Any observations]

### Test 2: Vegetarian with Dislikes (Anand Patel)
- Status: ✅ / ⚠️ / ❌
- Meal Type: Lunch
- Cuisine: Indian
- Recipes Returned: [3/0]
- All Vegetarian: [Yes/No]
- No Eggs/Eggplant: [Yes/No] ⭐ CRITICAL
- Notes: [Any observations]

### Test 3: Very Low Calorie (Catalina Ocampo)
- Status: ✅ / ⚠️ / ❌
- Meal Type: Dinner
- Cuisine: Mexican
- Recipes Returned: [3/0]
- Calorie Range OK (175-455): [Yes/No]
- High Protein: [Yes/No]
- Notes: [Any observations]

[Continue for all tests...]

### Overall Summary
- Critical Tests Passed: [X/5]
- Important Tests Passed: [X/5]
- Nice to Have Passed: [X/3]
- **RAG System Status:** [✅ Production Ready / ⚠️ Needs Fixes / ❌ Major Issues]

### Bugs Found
1. [Bug description]
2. [Bug description]

### Recommendations
1. [Recommendation]
2. [Recommendation]
```

---

## 🚀 Quick Start Testing

**Fastest way to verify everything works:**

1. **Open App:** http://localhost:8080
2. **Sign in as:** Anand Patel (most complex profile)
3. **Select:** Lunch + Indian
4. **Verify:**
   - ✅ Gets 3 recipes
   - ✅ All vegetarian
   - ✅ No eggs or eggplant
   - ✅ Complete nutrition (including fiber, sugar, sodium)
5. **Click:** "Show More Recipes"
6. **Verify:** 3 new recipes, no duplicates

**If all above pass:** 🎉 Your RAG system is working correctly!

---

## 📞 Need Help?

**If tests fail:**
1. Check browser console for errors
2. Check Cloud Function logs: `firebase functions:log`
3. Verify database: `npm run count`
4. Check daily_state.json for ingestion status

**Documentation:**
- [VERIFICATION_SUMMARY.md](scripts/recipe_ingestion/VERIFICATION_SUMMARY.md)
- [INGESTION_GUIDE.md](scripts/recipe_ingestion/INGESTION_GUIDE.md)
- [RAG_VERIFICATION_REPORT.md](scripts/recipe_ingestion/RAG_VERIFICATION_REPORT.md)

---

**Good luck testing!** 🧪🚀

Your RAG system has been thoroughly verified on the backend. Now it's time to see it in action through the UI!
