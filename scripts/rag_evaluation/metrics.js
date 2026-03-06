/**
 * Metric calculations for RAG vs. No-RAG evaluation.
 *
 * All metrics return a value in [0, 1] where 1.0 is best.
 *
 * Metrics:
 *   1. hallucination     - % of recipes traceable to the real DB (RAG = 1.0, no-RAG = 0.0)
 *   2. calorieAccuracy   - how close recipe calories are to the scenario target
 *   3. macroAlignment    - deviation of protein/carbs/fat % from user macro goals
 *   4. restrictionCompliance - do recipes respect dietary restrictions?
 *   5. preferenceAdherence  - do recipes avoid dislikes and include likes?
 *   6. specificity          - does the Gemini response contain exact nutritional numbers?
 */

// ─── Meal weight distribution for calorie target calculation ─────────────────
const MEAL_WEIGHTS = {
  breakfast: 0.25,
  lunch: 0.30,
  dinner: 0.35,
  snack: 0.10,
};

/**
 * Calculate the calorie target for a specific meal in this scenario.
 * Mirrors the calculateSmartCalorieTarget logic in functions/src/index.ts.
 */
export function calculateCalorieTarget(scenario) {
  const { profile, ragParams } = scenario;
  const { dailyCalorieGoal } = profile;
  const { mealType, consumedCalories, consumedMealTypes } = ragParams;

  const remainingCalories = dailyCalorieGoal - (consumedCalories ?? 0);
  const consumedTypes = consumedMealTypes ?? [];

  // Calculate how many meal "slots" are remaining
  const allMealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
  const remainingMealTypes = allMealTypes.filter(
    (m) => !consumedTypes.includes(m) && m !== mealType
  );

  // Weight of current meal relative to all remaining meals
  const currentWeight = MEAL_WEIGHTS[mealType] ?? 0.30;
  const remainingWeight = remainingMealTypes.reduce(
    (sum, m) => sum + (MEAL_WEIGHTS[m] ?? 0.10),
    0
  );
  const totalRemainingWeight = currentWeight + remainingWeight;

  if (totalRemainingWeight <= 0) return remainingCalories;

  return Math.max(100, Math.round(remainingCalories * (currentWeight / totalRemainingWeight)));
}

// ─── 1. Hallucination ─────────────────────────────────────────────────────────

/**
 * Are the returned recipes traceable to the real database?
 * RAG recipes always have a DB id (score = 1.0).
 * No-RAG recipes have id = null (score = 0.0).
 */
export function hallucinationScore(recipes) {
  if (!recipes || recipes.length === 0) return 0;
  const traceable = recipes.filter((r) => r.id != null && r.id !== '').length;
  return traceable / recipes.length;
}

// ─── 2. Calorie Accuracy ──────────────────────────────────────────────────────

/**
 * How closely do recipe calories match the target for this meal?
 * score = max(0, 1 - |actual - target| / target)
 * Averaged across all returned recipes.
 */
export function calorieAccuracyScore(recipes, calorieTarget) {
  if (!recipes || recipes.length === 0 || calorieTarget <= 0) return 0;

  const scores = recipes.map((recipe) => {
    if (recipe.calories == null || recipe.calories <= 0) return 0;
    const relError = Math.abs(recipe.calories - calorieTarget) / calorieTarget;
    return Math.max(0, 1 - relError);
  });

  return scores.reduce((a, b) => a + b, 0) / scores.length;
}

// ─── 3. Macro Alignment ───────────────────────────────────────────────────────

/**
 * How well do macro % match user goals?
 * Mirrors the scoreRecipe macro scoring in functions/src/index.ts (maxDiff=30).
 * Per macro: max(0, 1 - |recipePct - goalPct| / 30)
 * Weighted composite: protein 40%, carbs 35%, fat 25%
 * Averaged across recipes.
 */
export function macroAlignmentScore(recipes, macroGoals) {
  if (!recipes || recipes.length === 0) return 0;

  const scores = recipes.map((recipe) => {
    if (!recipe.calories || recipe.calories <= 0) return 0;
    if (recipe.protein == null || recipe.carbs == null || recipe.fat == null) return 0;

    const cal = recipe.calories;
    const recipePctProtein = ((recipe.protein * 4) / cal) * 100;
    const recipePctCarbs = ((recipe.carbs * 4) / cal) * 100;
    const recipePctFat = ((recipe.fat * 9) / cal) * 100;

    const MAX_DIFF = 30;
    const proteinScore = Math.max(0, 1 - Math.abs(recipePctProtein - macroGoals.protein) / MAX_DIFF);
    const carbsScore = Math.max(0, 1 - Math.abs(recipePctCarbs - macroGoals.carbs) / MAX_DIFF);
    const fatScore = Math.max(0, 1 - Math.abs(recipePctFat - macroGoals.fat) / MAX_DIFF);

    return proteinScore * 0.40 + carbsScore * 0.35 + fatScore * 0.25;
  });

  return scores.reduce((a, b) => a + b, 0) / scores.length;
}

// ─── 4. Restriction Compliance ───────────────────────────────────────────────

/**
 * Do recipes comply with the user's dietary restrictions?
 *
 * For RAG: check the structured healthLabels array from the DB.
 * For no-RAG: use keyword violation heuristics on response text.
 *
 * Returns fraction of recipes that pass (0.0 to 1.0).
 */
// Violation keyword patterns — use \b word boundaries to avoid false positives
// like "butternut" triggering "butter", or "coconut milk" triggering "milk".
// Exceptions are handled by the safe-term exclusions below.
const VIOLATION_PATTERNS = {
  vegetarian: [/\bbeef\b/, /\bchicken\b/, /\bpork\b/, /\bfish\b/, /\bsalmon\b/, /\btuna\b/, /\bshrimp\b/, /\bturkey\b/, /\bbacon\b/, /\blamb\b/, /\bsteak\b/, /\b(meat)\b/, /\bprosciutto\b/, /\banchovies?\b/],
  vegan: [/\bbeef\b/, /\bchicken\b/, /\bpork\b/, /\bfish\b/, /\bsalmon\b/, /\btuna\b/, /\bshrimp\b/, /\bturkey\b/, /\bbacon\b/, /\blamb\b/, /\bsteak\b/, /\b(meat)\b/, /\begg(s)?\b/, /\bcow['']?s milk\b/, /\bdairy milk\b/, /\bwhole milk\b/, /\bskim milk\b/, /\b2% milk\b/, /\bcheese\b/, /\bbutter\b/, /\bwhipped cream\b/, /\bheavy cream\b/, /\bsour cream\b/, /\byogurt\b/, /\bhoney\b/, /\bghee\b/, /\bmayo(nnaise)?\b/, /\bwhey\b/, /\banchovies?\b/],
  'gluten-free': [/\bwheat\b/, /\bwhole wheat\b/, /\ball[- ]purpose flour\b/, /\bwheat flour\b/, /\bbread flour\b/, /\bflour tortilla/, /\bpasta\b/, /\bnoodles?\b/, /\bbarley\b/, /\brye\b/, /\bcouscous\b/, /\bcrackers?\b/, /\bcroutons?\b/, /\bsoy sauce\b/],
  'dairy-free': [/\bcow['']?s milk\b/, /\bdairy milk\b/, /\bwhole milk\b/, /\bskim milk\b/, /\b2% milk\b/, /\bbuttermilk\b/, /\bcheese\b/, /\bbutter\b/, /\bwhipped cream\b/, /\bheavy cream\b/, /\bsour cream\b/, /\bcream cheese\b/, /\byogurt\b/, /\bghee\b/, /\bwhey\b/, /\blactose\b/, /\bcasein\b/, /\bparmesan\b/, /\bmozzarella\b/, /\bcheddar\b/],
};

// Ingredients/phrases that look like violations but aren't
// (checked before running violation patterns)
const SAFE_TERMS = {
  vegan: ['coconut milk', 'oat milk', 'almond milk', 'soy milk', 'rice milk', 'cashew milk', 'coconut cream', 'plant butter', 'vegan butter', 'flax egg', 'chia egg', 'peanut butter', 'almond butter', 'tahini', 'butternut squash', 'buttercup squash', 'egg plant', 'eggplant'],
  'dairy-free': ['coconut milk', 'oat milk', 'almond milk', 'soy milk', 'rice milk', 'cashew milk', 'coconut cream', 'plant butter', 'vegan butter', 'peanut butter', 'almond butter', 'tahini', 'butternut squash', 'buttercup squash'],
  'gluten-free': ['rice flour', 'almond flour', 'coconut flour', 'tapioca flour', 'gluten-free oats', 'tamari', 'gluten-free soy sauce', 'gluten-free pasta', 'gluten-free bread'],
};

export function restrictionComplianceScore(recipes, restrictions) {
  if (!restrictions || restrictions.length === 0) return 1.0;
  if (!recipes || recipes.length === 0) return 0;

  const scores = recipes.map((recipe) => {
    // Check only this recipe's label and ingredients.
    // responseText is intentionally excluded: it contains all recipes combined,
    // which causes cross-contamination (one recipe's violation flags all others).
    // RAG recipes have a real ingredient list; no-RAG recipes only have a label.
    const textToSearch = [
      recipe.label ?? '',
      ...(recipe.ingredients ?? []),
    ]
      .join(' ')
      .toLowerCase();

    for (const restriction of restrictions) {
      const patterns = VIOLATION_PATTERNS[restriction.toLowerCase()] ?? [];
      const safeTerms = SAFE_TERMS[restriction.toLowerCase()] ?? [];

      // Build a cleaned version of the text with safe terms neutralized
      let cleanedText = textToSearch;
      for (const safeTerm of safeTerms) {
        cleanedText = cleanedText.replace(new RegExp(safeTerm, 'gi'), '');
      }

      const hasViolation = patterns.some((pattern) => pattern.test(cleanedText));
      if (hasViolation) return 0.0;
    }

    return 1.0;
  });

  return scores.reduce((a, b) => a + b, 0) / scores.length;
}

// ─── 5. Preference Adherence ─────────────────────────────────────────────────

/**
 * Does the recipe avoid dislikes and include likes?
 * - Any dislike found in recipe → score 0 for that recipe
 * - Score = (fraction of likes found) if no dislikes
 * Averaged across recipes.
 */
export function preferenceAdherenceScore(recipes, likes, dislikes) {
  if ((!likes || likes.length === 0) && (!dislikes || dislikes.length === 0)) return 1.0;
  if (!recipes || recipes.length === 0) return 0;

  const scores = recipes.map((recipe) => {
    // Check only this recipe's label and ingredients — same reason as
    // restrictionComplianceScore: responseText cross-contaminates all recipes.
    const searchable = [
      recipe.label ?? '',
      ...(recipe.ingredients ?? []),
    ]
      .join(' ')
      .toLowerCase();

    // Dislikes: if any found → 0
    if (dislikes && dislikes.length > 0) {
      const hasDislike = dislikes.some((d) => searchable.includes(d.toLowerCase()));
      if (hasDislike) return 0.0;
    }

    // Likes: what fraction of preferred ingredients appear?
    if (!likes || likes.length === 0) return 1.0;
    const found = likes.filter((l) => searchable.includes(l.toLowerCase())).length;
    return found / likes.length;
  });

  return scores.reduce((a, b) => a + b, 0) / scores.length;
}

// ─── 6. Specificity ──────────────────────────────────────────────────────────

/**
 * Does the response include exact nutritional numbers?
 * RAG Gemini quotes exact DB values. No-RAG Gemini estimates vaguely.
 * Returns fraction of patterns matched (0.0 to 1.0).
 */
const SPECIFICITY_PATTERNS = [
  /\d{3,4}\s*(calories|cal|kcal)/i,
  /\d+\.?\d*\s*g?\s*(of\s*)?(protein)/i,
  /\d+\.?\d*\s*g?\s*(of\s*)?(carbs?|carbohydrates?)/i,
  /\d+\.?\d*\s*g?\s*(of\s*)?(fat)/i,
];

export function specificityScore(responseText) {
  if (!responseText) return 0;
  const matched = SPECIFICITY_PATTERNS.filter((p) => p.test(responseText)).length;
  return matched / SPECIFICITY_PATTERNS.length;
}

// ─── Combined Metric Calculator ───────────────────────────────────────────────

/**
 * Calculate all 6 metrics for a given pipeline response.
 *
 * @param {object} pipelineResult - { recipes, geminiResponseText }
 * @param {object} scenario       - the EvalScenario
 * @param {number} calorieTarget  - precomputed from calculateCalorieTarget()
 * @returns {object} MetricScores
 */
export function calculateAllMetrics(pipelineResult, scenario, calorieTarget) {
  const { recipes, geminiResponseText } = pipelineResult;
  const { profile } = scenario;

  return {
    hallucination: hallucinationScore(recipes),
    calorieAccuracy: calorieAccuracyScore(recipes, calorieTarget),
    macroAlignment: macroAlignmentScore(recipes, profile.macroGoals),
    restrictionCompliance: restrictionComplianceScore(recipes, profile.healthRestrictions),
    preferenceAdherence: preferenceAdherenceScore(recipes, profile.likes, profile.dislikes),
    specificity: specificityScore(geminiResponseText),
  };
}
