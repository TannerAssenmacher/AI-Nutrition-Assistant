# RAG Recipe Search - How It Works

## Overview

When a user requests recipes, the Flutter client sends their full profile and today's consumption data to the `searchRecipes` Cloud Function. The function generates a semantic embedding for the query, runs a two-tier filter+score pipeline against PostgreSQL, then enriches top results from Firestore.

---

## User Profile Data Usage

| Field | Recipe Search | General Chat |
|-------|--------------|--------------|
| dietaryHabits | Semantic query | Gemini prompt |
| activityLevel | Semantic query | Gemini prompt |
| dob (age) | Semantic query | Not included |
| height | BMI -> semantic query | Gemini prompt |
| weight | BMI -> semantic query | Gemini prompt |
| dailyCalorieGoal | Smart calorie target + scoring | Gemini prompt |
| dietaryGoal | Scoring (0.25 weight) + semantic query | Gemini prompt |
| healthRestrictions | Hard SQL filter | Gemini prompt |
| protein % | Scoring (0.08 weight) + semantic query | Gemini prompt |
| carbs % | Scoring (0.06 weight) + semantic query | Gemini prompt |
| fat % | Scoring (0.06 weight) + semantic query | Gemini prompt |
| sex | Logged for context | Gemini prompt |
| dislikes [] | Hard SQL filter (ingredients) + hard TS filter (label) | Gemini prompt |
| likes [] | Scoring (0.10 weight) + semantic query | Gemini prompt |

Today's consumption data (consumedCalories, consumedMealTypes, consumedMacros) is sent to enable smart per-meal calorie targeting.

---

## Tier 1: Hard Filters (must pass or recipe is excluded)

1. **mealType** - SQL: recipe must support the requested meal type
2. **cuisine** - SQL: exact match when specified
3. **healthRestrictions** - SQL: recipe health_labels must contain ALL user restrictions
4. **dislikes (ingredients)** - SQL: recipe must NOT contain any disliked ingredient
5. **dislikes (label)** - TypeScript: recipe label must not contain any dislike string
6. **excludeIds** - SQL: skip already-shown recipes

---

## Tier 2: Scoring (ranks what passes Tier 1)

| Factor | Weight | Description |
|--------|--------|-------------|
| Dietary goal alignment | 0.25 | Composite sub-score tailored to Lose Weight / Gain Muscle / Maintain Weight |
| Calorie proximity | 0.25 | How close recipe calories are to the smart per-meal target |
| Protein % proximity | 0.08 | Recipe protein % vs user's protein goal % |
| Carbs % proximity | 0.06 | Recipe carbs % vs user's carbs goal % |
| Fat % proximity | 0.06 | Recipe fat % vs user's fat goal % |
| Semantic similarity | 0.10 | pgvector cosine similarity from the embedding query |
| Likes match | 0.10 | Fraction of user's liked foods found in recipe ingredients or label |
| Servings | 0.05 | Preference for 1-4 servings |
| Prep time | 0.05 | Preference for <=30 min |

**Total: 1.00** (70% goal-driven, 30% preference/context)

---

## Dietary Goal Sub-Scores

**Lose Weight**: calories at/below target (0.35), fiber >=5g (0.15), protein% meets goal (0.25), fat% at/below goal (0.15), sugar <=10g (0.10)

**Gain Muscle**: protein% meets goal (0.35), calories at/above target (0.30), absolute protein >=25g (0.20), carbs% meets goal (0.15)

**Maintain Weight**: calories within 10% of target (0.40), all macros within 5pp of goals (0.30), fiber >=3g (0.15), sodium <800mg (0.15)

---

## Smart Calorie Targeting

Standard meal allocations: breakfast 25%, lunch 30%, dinner 35%, snack 10%.

- If consumption data is available: remaining calories are distributed proportionally across remaining meals
- If no consumption data: fixed percentage of daily goal is used

---

## Recipe DB Schema (PostgreSQL)

All fields queried and used: id, embedding (vector 768), label, cuisine, meal_types, health_labels, ingredients, calories, protein, carbs, fat, fiber, sugar, sodium, servings, ready_in_minutes.

---

## Pipeline Flow

```
Client sends profile + consumption data
  -> Cloud Function builds semantic query text
  -> Generates embedding via gemini-embedding-001
  -> SQL: hard filters + vector similarity, fetches 3x candidates
  -> TypeScript: label dislikes filter
  -> TypeScript: score all candidates (9 factors)
  -> Sort by score, take top N
  -> Firestore enrichment (instructions, image, full ingredients)
  -> Return scored recipes to client
```

If no results pass strict filters, a relaxed fallback runs (drops mealType, cuisine, healthRestrictions filters but keeps dislikes and scoring).
