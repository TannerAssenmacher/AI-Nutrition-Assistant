/**
 * Test scenarios for RAG accuracy evaluation.
 * 9 user profiles × 3–4 queries each = 32 total test cases.
 *
 * Profiles are designed to stress different pipeline capabilities:
 *   Alice    — vegetarian, lose weight, restricted calorie budget
 *   Bob      — no restrictions, gain muscle, high protein demand
 *   Carol    — gluten-free + dairy-free dual restriction
 *   Derek    — vegan, high BMI, lose weight + dislikes
 *   Eve      — young adult, maintenance, light preferences only
 *   Frank    — sedentary, overweight, no restrictions, lose weight
 *   Grace    — senior, low-sodium preference, maintain weight
 *   Henry    — keto macros (very low carb / high fat), active
 *   Isabelle — vegan + gluten-free, athletic, maintain weight
 */

// ─── User Profiles ────────────────────────────────────────────────────────────

const alice = {
  id: 'alice',
  label: 'Alice — 35F, Vegetarian, Lose Weight',
  sex: 'female', age: 35, height: 65, weight: 175,
  activityLevel: 'Moderately Active',
  dietaryGoal: 'Lose Weight',
  dailyCalorieGoal: 1600,
  macroGoals: { protein: 30, carbs: 40, fat: 30 },
  healthRestrictions: ['vegetarian'],
  dietaryHabits: ['vegetarian'],
  likes: ['salad', 'beans', 'tofu'],
  dislikes: ['mushrooms', 'eggplant'],
};

const bob = {
  id: 'bob',
  label: 'Bob — 27M, No Restrictions, Gain Muscle',
  sex: 'male', age: 27, height: 72, weight: 170,
  activityLevel: 'Very Active',
  dietaryGoal: 'Gain Muscle',
  dailyCalorieGoal: 3200,
  macroGoals: { protein: 35, carbs: 45, fat: 20 },
  healthRestrictions: [],
  dietaryHabits: [],
  likes: ['chicken', 'rice', 'eggs'],
  dislikes: ['tofu', 'tempeh'],
};

const carol = {
  id: 'carol',
  label: 'Carol — 40F, Gluten-Free + Dairy-Free, Maintain',
  sex: 'female', age: 40, height: 63, weight: 130,
  activityLevel: 'Lightly Active',
  dietaryGoal: 'Maintain Weight',
  dailyCalorieGoal: 1900,
  macroGoals: { protein: 20, carbs: 50, fat: 30 },
  healthRestrictions: ['gluten-free', 'dairy-free'],
  dietaryHabits: ['gluten-free'],
  likes: ['salmon', 'quinoa', 'avocado'],
  dislikes: ['shellfish', 'peanuts'],
};

const derek = {
  id: 'derek',
  label: 'Derek — 51M, Vegan, BMI 36, Lose Weight',
  sex: 'male', age: 51, height: 68, weight: 240,
  activityLevel: 'Sedentary',
  dietaryGoal: 'Lose Weight',
  dailyCalorieGoal: 1800,
  macroGoals: { protein: 25, carbs: 45, fat: 30 },
  healthRestrictions: ['vegan'],
  dietaryHabits: ['vegan'],
  likes: ['lentils', 'sweet potato'],
  dislikes: ['spicy', 'coconut'],
};

// 5'4", 130 lbs → BMI ~22.3 | college-age, no hard restrictions
const eve = {
  id: 'eve',
  label: 'Eve — 22F, No Restrictions, Maintain Weight',
  sex: 'female', age: 22, height: 64, weight: 130,
  activityLevel: 'Moderately Active',
  dietaryGoal: 'Maintain Weight',
  dailyCalorieGoal: 2000,
  macroGoals: { protein: 25, carbs: 50, fat: 25 },
  healthRestrictions: [],
  dietaryHabits: [],
  likes: ['pasta', 'vegetables', 'fruit'],
  dislikes: ['liver', 'anchovies'],
};

// 5'10", 210 lbs → BMI ~30.1 | desk job, sedentary, no restrictions
const frank = {
  id: 'frank',
  label: 'Frank — 46M, Sedentary, Overweight, Lose Weight',
  sex: 'male', age: 46, height: 70, weight: 210,
  activityLevel: 'Sedentary',
  dietaryGoal: 'Lose Weight',
  dailyCalorieGoal: 1700,
  macroGoals: { protein: 30, carbs: 40, fat: 30 },
  healthRestrictions: [],
  dietaryHabits: [],
  likes: ['beef', 'potatoes', 'bread'],
  dislikes: ['tofu', 'fish'],
};

// 5'4", 145 lbs → BMI ~24.9 | senior, lightly active
const grace = {
  id: 'grace',
  label: 'Grace — 68F, Senior, Lightly Active, Maintain Weight',
  sex: 'female', age: 68, height: 64, weight: 145,
  activityLevel: 'Lightly Active',
  dietaryGoal: 'Maintain Weight',
  dailyCalorieGoal: 1700,
  macroGoals: { protein: 25, carbs: 45, fat: 30 },
  healthRestrictions: [],
  dietaryHabits: [],
  likes: ['chicken', 'vegetables', 'soup'],
  dislikes: ['spicy', 'fried food'],
};

// 5'11", 185 lbs → BMI ~25.8 | keto-style macros (very low carb, high fat)
const henry = {
  id: 'henry',
  label: 'Henry — 33M, Keto Macros, Very Active, Maintain',
  sex: 'male', age: 33, height: 71, weight: 185,
  activityLevel: 'Very Active',
  dietaryGoal: 'Maintain Weight',
  dailyCalorieGoal: 2600,
  macroGoals: { protein: 30, carbs: 10, fat: 60 },
  healthRestrictions: [],
  dietaryHabits: [],
  likes: ['eggs', 'bacon', 'avocado', 'cheese'],
  dislikes: ['bread', 'pasta', 'sugar'],
};

// 5'6", 135 lbs → BMI ~21.8 | dual restriction, athletic build
const isabelle = {
  id: 'isabelle',
  label: 'Isabelle — 26F, Vegan + Gluten-Free, Maintain Weight',
  sex: 'female', age: 26, height: 66, weight: 135,
  activityLevel: 'Moderately Active',
  dietaryGoal: 'Maintain Weight',
  dailyCalorieGoal: 1900,
  macroGoals: { protein: 20, carbs: 55, fat: 25 },
  healthRestrictions: ['vegan', 'gluten-free'],
  dietaryHabits: ['vegan', 'gluten-free'],
  likes: ['chickpeas', 'rice', 'spinach'],
  dislikes: ['mushrooms', 'olives'],
};

// ─── Helper: Build ragParams from a profile ────────────────────────────────────

function buildRagParams(profile, mealType, cuisineType, consumedCalories, consumedMealTypes, limit = 3) {
  return {
    mealType,
    cuisineType,
    limit,
    healthRestrictions: profile.healthRestrictions,
    dietaryGoal: profile.dietaryGoal,
    dailyCalorieGoal: profile.dailyCalorieGoal,
    consumedCalories: consumedCalories ?? 0,
    consumedMealTypes: consumedMealTypes ?? [],
    macroGoals: profile.macroGoals,
    dislikes: profile.dislikes,
    likes: profile.likes,
    activityLevel: profile.activityLevel,
    sex: profile.sex,
    age: profile.age,
    height: profile.height,
    weight: profile.weight,
  };
}

// ─── Test Scenarios ─────────────────────────────────────────────────────────
// 32 total scenarios across 9 profiles.
// evaluate.js runs 10 per day in order, never repeating until all are exhausted.

export const scenarios = [

  // ── Alice (vegetarian, lose weight) ───────────────────────────────────────
  {
    id: 'alice-breakfast',
    description: "Alice's first meal of the day — vegetarian breakfast",
    profile: alice,
    ragParams: buildRagParams(alice, 'breakfast', 'american', 0, []),
  },
  {
    id: 'alice-lunch',
    description: "Alice's lunch after consuming 380 cal at breakfast",
    profile: alice,
    ragParams: buildRagParams(alice, 'lunch', 'mediterranean', 380, ['breakfast']),
  },
  {
    id: 'alice-dinner',
    description: "Alice's dinner — only ~490 cal remaining for the day",
    profile: alice,
    ragParams: buildRagParams(alice, 'dinner', 'none', 900, ['breakfast', 'lunch']),
  },
  {
    id: 'alice-snack',
    description: "Alice's afternoon snack — ~160 cal vegetarian snack",
    profile: alice,
    ragParams: buildRagParams(alice, 'snack', 'none', 380, ['breakfast']),
  },

  // ── Bob (no restrictions, gain muscle) ────────────────────────────────────
  {
    id: 'bob-breakfast',
    description: "Bob's high-protein breakfast to start the day",
    profile: bob,
    ragParams: buildRagParams(bob, 'breakfast', 'american', 0, []),
  },
  {
    id: 'bob-lunch',
    description: "Bob's post-workout lunch, high protein (35% goal)",
    profile: bob,
    ragParams: buildRagParams(bob, 'lunch', 'none', 650, ['breakfast']),
  },
  {
    id: 'bob-dinner',
    description: "Bob's dinner — still needs ~1600 cal to hit daily goal",
    profile: bob,
    ragParams: buildRagParams(bob, 'dinner', 'none', 1600, ['breakfast', 'lunch']),
  },
  {
    id: 'bob-snack',
    description: "Bob's mid-afternoon snack — high-protein to stay in surplus",
    profile: bob,
    ragParams: buildRagParams(bob, 'snack', 'none', 1300, ['breakfast', 'lunch']),
  },

  // ── Carol (gluten-free + dairy-free, maintain) ────────────────────────────
  {
    id: 'carol-breakfast',
    description: "Carol's breakfast — must be gluten-free AND dairy-free",
    profile: carol,
    ragParams: buildRagParams(carol, 'breakfast', 'none', 0, []),
  },
  {
    id: 'carol-lunch',
    description: "Carol's lunch — dual restriction compliance stress test",
    profile: carol,
    ragParams: buildRagParams(carol, 'lunch', 'none', 420, ['breakfast']),
  },
  {
    id: 'carol-dinner',
    description: "Carol's dinner — salmon/quinoa preference + restrictions",
    profile: carol,
    ragParams: buildRagParams(carol, 'dinner', 'none', 880, ['breakfast', 'lunch']),
  },

  // ── Derek (vegan, lose weight, high BMI) ──────────────────────────────────
  {
    id: 'derek-breakfast',
    description: "Derek's vegan breakfast — low calorie, lose weight goal",
    profile: derek,
    ragParams: buildRagParams(derek, 'breakfast', 'none', 0, []),
  },
  {
    id: 'derek-lunch',
    description: "Derek's vegan lunch — dislikes coconut and spicy food",
    profile: derek,
    ragParams: buildRagParams(derek, 'lunch', 'none', 400, ['breakfast']),
  },
  {
    id: 'derek-dinner',
    description: "Derek's dinner — vegan + dislikes combined (tests fallback relaxation)",
    profile: derek,
    ragParams: buildRagParams(derek, 'dinner', 'none', 900, ['breakfast', 'lunch']),
  },

  // ── Eve (no restrictions, maintenance, young adult) ───────────────────────
  {
    id: 'eve-breakfast',
    description: "Eve's casual breakfast — no restrictions, maintenance calories",
    profile: eve,
    ragParams: buildRagParams(eve, 'breakfast', 'american', 0, []),
  },
  {
    id: 'eve-lunch',
    description: "Eve's lunch — Mediterranean cuisine preference",
    profile: eve,
    ragParams: buildRagParams(eve, 'lunch', 'mediterranean', 480, ['breakfast']),
  },
  {
    id: 'eve-dinner',
    description: "Eve's dinner — any cuisine, balanced macros",
    profile: eve,
    ragParams: buildRagParams(eve, 'dinner', 'none', 1000, ['breakfast', 'lunch']),
  },

  // ── Frank (sedentary, overweight, lose weight) ────────────────────────────
  {
    id: 'frank-breakfast',
    description: "Frank's breakfast — low calorie start for weight loss",
    profile: frank,
    ragParams: buildRagParams(frank, 'breakfast', 'american', 0, []),
  },
  {
    id: 'frank-lunch',
    description: "Frank's lunch — must stay under budget after breakfast",
    profile: frank,
    ragParams: buildRagParams(frank, 'lunch', 'none', 380, ['breakfast']),
  },
  {
    id: 'frank-dinner',
    description: "Frank's dinner — likes beef/potatoes but needs low calorie options",
    profile: frank,
    ragParams: buildRagParams(frank, 'dinner', 'none', 850, ['breakfast', 'lunch']),
  },

  // ── Grace (senior, lightly active, maintain weight) ───────────────────────
  {
    id: 'grace-breakfast',
    description: "Grace's light breakfast — gentle start, easy digestion",
    profile: grace,
    ragParams: buildRagParams(grace, 'breakfast', 'american', 0, []),
  },
  {
    id: 'grace-lunch',
    description: "Grace's lunch — likes soup and chicken, no spicy or fried",
    profile: grace,
    ragParams: buildRagParams(grace, 'lunch', 'none', 390, ['breakfast']),
  },
  {
    id: 'grace-dinner',
    description: "Grace's dinner — moderate calories, heart-healthy preference",
    profile: grace,
    ragParams: buildRagParams(grace, 'dinner', 'none', 860, ['breakfast', 'lunch']),
  },
  {
    id: 'grace-snack',
    description: "Grace's afternoon snack — light ~170 cal snack",
    profile: grace,
    ragParams: buildRagParams(grace, 'snack', 'none', 390, ['breakfast']),
  },

  // ── Henry (keto macros, very active) ──────────────────────────────────────
  {
    id: 'henry-breakfast',
    description: "Henry's keto breakfast — high fat, low carb (10% carb goal)",
    profile: henry,
    ragParams: buildRagParams(henry, 'breakfast', 'none', 0, []),
  },
  {
    id: 'henry-lunch',
    description: "Henry's keto lunch — eggs/avocado/cheese preferred, no bread",
    profile: henry,
    ragParams: buildRagParams(henry, 'lunch', 'none', 600, ['breakfast']),
  },
  {
    id: 'henry-dinner',
    description: "Henry's keto dinner — high fat, protein, almost no carbs",
    profile: henry,
    ragParams: buildRagParams(henry, 'dinner', 'none', 1400, ['breakfast', 'lunch']),
  },

  // ── Isabelle (vegan + gluten-free, maintain, athletic) ────────────────────
  {
    id: 'isabelle-breakfast',
    description: "Isabelle's breakfast — vegan AND gluten-free, highest dual-restriction test",
    profile: isabelle,
    ragParams: buildRagParams(isabelle, 'breakfast', 'none', 0, []),
  },
  {
    id: 'isabelle-lunch',
    description: "Isabelle's lunch — chickpeas/rice/spinach preferred, dual restriction",
    profile: isabelle,
    ragParams: buildRagParams(isabelle, 'lunch', 'none', 440, ['breakfast']),
  },
  {
    id: 'isabelle-dinner',
    description: "Isabelle's dinner — vegan + gluten-free + dislikes mushrooms/olives",
    profile: isabelle,
    ragParams: buildRagParams(isabelle, 'dinner', 'none', 950, ['breakfast', 'lunch']),
  },
  {
    id: 'isabelle-snack',
    description: "Isabelle's snack — tiny vegan + gluten-free snack ~190 cal",
    profile: isabelle,
    ragParams: buildRagParams(isabelle, 'snack', 'none', 440, ['breakfast']),
  },
];
