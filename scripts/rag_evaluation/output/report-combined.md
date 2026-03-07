# RAG Accuracy Evaluation Report

**Generated:** All Runs Combined | **Scenarios:** 21 (21 completed) | **Model:** gemini-2.5-flash

This report compares the RAG-powered recipe recommendation pipeline against a direct Gemini baseline across 6 accuracy metrics.

## Executive Summary

| Metric                 | RAG Average | No-RAG Average | Delta (RAG - No-RAG) |
|------------------------|-------------|----------------|----------------------|
| Hallucination Rate     | 100.0%      | 0.0%           | +100.0%              |
| Calorie Accuracy       | 74.7%       | 69.1%          | +5.6%                |
| Macro Alignment        | 59.1%       | 67.4%          | -8.3%                |
| Restriction Compliance | 90.5%       | 100.0%         | -9.5%                |
| Preference Adherence   | 30.7%       | 31.7%          | -1.1%                |
| Response Specificity   | 100.0%      | 100.0%         | +0.0%                |

## Visual Comparison

```
Hallucination Rate        RAG    ████████████████████  100.0%
                          No-RAG ░░░░░░░░░░░░░░░░░░░░  0.0%

Calorie Accuracy          RAG    ███████████████░░░░░  74.7%
                          No-RAG ██████████████░░░░░░  69.1%

Macro Alignment           RAG    ████████████░░░░░░░░  59.1%
                          No-RAG █████████████░░░░░░░  67.4%

Restriction Compliance    RAG    ██████████████████░░  90.5%
                          No-RAG ████████████████████  100.0%

Preference Adherence      RAG    ██████░░░░░░░░░░░░░░  30.7%
                          No-RAG ██████░░░░░░░░░░░░░░  31.7%

Response Specificity      RAG    ████████████████████  100.0%
                          No-RAG ████████████████████  100.0%

```

## Hallucination Analysis

**RAG Pipeline:** 63 of 63 recipes are traceable to the recipe database (score: 1.00).
All RAG recipes have verified IDs, exact nutritional data, structured ingredient lists, and dietary health labels.

**No-RAG Baseline:** 0 of 56 recipes are traceable to the database (score: 0.00).
Gemini generates recipe names and estimates nutritional values from its training data.

**Sample invented recipes (not in our database):**
- "Southwestern Tofu Scramble" *(from scenario: alice-breakfast)* — nutrition unverifiable
- "Loaded Bean & Veggie Omelet" *(from scenario: alice-breakfast)* — nutrition unverifiable
- "Breakfast Burrito Bowl" *(from scenario: alice-breakfast)* — nutrition unverifiable
- "Mediterranean Tofu Quinoa Bowl" *(from scenario: alice-lunch)* — nutrition unverifiable
- "Lentil and Vegetable Stew" *(from scenario: alice-lunch)* — nutrition unverifiable
- "White Bean and Roasted Veggie Salad" *(from scenario: alice-lunch)* — nutrition unverifiable

---

## Aggregate Analysis (21 Scenarios, 3 Runs)

### Overall Weighted Score

Weights: Calorie Accuracy 30% · Macro Alignment 25% · Restriction Compliance 25% · Preference Adherence 10% · Specificity 10%
*(Hallucination excluded from weighted score as RAG always = 1.0 and No-RAG always = 0.0 by construction)*

| Pipeline | Weighted Score | vs. Baseline |
|----------|---------------|--------------|
| RAG      | 72.9% | -2.9pp (-3.8% relative) |
| No-RAG   | 75.7% | — |

### Scenario Win/Loss Count

How many of the 21 scenarios each pipeline won (higher = better) per metric:

| Metric                 | RAG Wins  | No-RAG Wins | Ties |
|------------------------|-----------|-------------|------|
| Hallucination Rate     | 21 (100%) | 0 (0%)      | 0    |
| Calorie Accuracy       | 9 (43%)   | 12 (57%)    | 0    |
| Macro Alignment        | 7 (33%)   | 14 (67%)    | 0    |
| Restriction Compliance | 0 (0%)    | 6 (29%)     | 15   |
| Preference Adherence   | 8 (38%)   | 8 (38%)     | 5    |
| Response Specificity   | 0 (0%)    | 0 (0%)      | 21   |

### Per-Profile Calorie Accuracy, Macro Alignment & Restriction Compliance

| Profile                                              | N | Cal (RAG) | Cal (No-RAG) | Cal Δ  | Macro (RAG) | Macro (No-RAG) | Restrict (RAG) | Restrict (No-RAG) |
|------------------------------------------------------|---|-----------|--------------|--------|-------------|----------------|----------------|-------------------|
| Alice — 35F, Vegetarian, Lose Weight                 | 4 | 71.2%     | 61.0%        | +10.3% | 50.8%       | 64.7%          | 83.3%          | 100.0%            |
| Bob — 27M, No Restrictions, Gain Muscle              | 4 | 68.7%     | 76.0%        | -7.4%  | 51.9%       | 72.7%          | 100.0%         | 100.0%            |
| Carol — 40F, Gluten-Free + Dairy-Free, Maintain      | 3 | 81.9%     | 75.0%        | +6.9%  | 59.5%       | 72.3%          | 77.8%          | 100.0%            |
| Derek — 51M, Vegan, BMI 36, Lose Weight              | 3 | 71.1%     | 72.0%        | -0.9%  | 56.7%       | 58.9%          | 77.8%          | 100.0%            |
| Eve — 22F, No Restrictions, Maintain Weight          | 3 | 85.9%     | 70.8%        | +15.2% | 63.3%       | 55.4%          | 100.0%         | 100.0%            |
| Frank — 46M, Sedentary, Overweight, Lose Weight      | 3 | 73.4%     | 78.0%        | -4.6%  | 70.5%       | 71.8%          | 100.0%         | 100.0%            |
| Isabelle — 26F, Vegan + Gluten-Free, Maintain Weight | 1 | 71.3%     | 15.4%        | +55.9% | 80.0%       | 90.9%          | 100.0%         | 100.0%            |

## Per-Profile Results

### Alice — 35F, Vegetarian, Lose Weight

| Meal      | Cal. Target | Cal. Acc (RAG) | Cal. Acc (No-RAG) | Restrict (RAG) | Restrict (No-RAG) | Macro (RAG) | Macro (No-RAG) |
|-----------|-------------|----------------|-------------------|----------------|-------------------|-------------|----------------|
| breakfast | 400 kcal    | 77.7%          | 85.0%             | 66.7%          | 100.0%            | 53.9%       | 63.7%          |
| lunch     | 488 kcal    | 71.2%          | 86.1%             | 100.0%         | 100.0%            | 50.1%       | 56.1%          |
| dinner    | 544 kcal    | 67.5%          | 71.6%             | 100.0%         | 100.0%            | 48.7%       | 78.3%          |
| snack     | 163 kcal    | 68.5%          | 1.2%              | 66.7%          | 100.0%            | 50.7%       | 60.7%          |

**alice-breakfast** — *Alice's first meal of the day — vegetarian breakfast*
RAG returned:
  1. **Corn Bread** *(id: spoonacular_640067)* | 363 cal, 11g P, 55g C, 12g F
  2. **White Cheddar Grits with Veggies** *(id: spoonacular_1096024)* | 332 cal, 18g P, 27g C, 19g F
  3. **Apple Pie Smoothie** *(id: spoonacular_632575)* | 238 cal, 7g P, 38g C, 8g F
No-RAG returned (invented by Gemini):
  1. **Southwestern Tofu Scramble** *(no DB id)* | ~440 cal (estimated)
  2. **Loaded Bean & Veggie Omelet** *(no DB id)* | ~460 cal (estimated)
  3. **Breakfast Burrito Bowl** *(no DB id)* | ~480 cal (estimated)

**alice-lunch** — *Alice's lunch after consuming 380 cal at breakfast*
RAG returned:
  1. **Traditional Panzanella** *(id: spoonacular_663771)* | 356 cal, 10g P, 45g C, 16g F
  2. **Lemony Greek Lentil Soup** *(id: spoonacular_649886)* | 368 cal, 23g P, 64g C, 4g F
  3. **Panzanella Salad** *(id: spoonacular_1005368)* | 657 cal, 23g P, 97g C, 20g F
No-RAG returned (invented by Gemini):
  1. **Mediterranean Tofu Quinoa Bowl** *(no DB id)* | ~410 cal (estimated)
  2. **Lentil and Vegetable Stew** *(no DB id)* | ~430 cal (estimated)
  3. **White Bean and Roasted Veggie Salad** *(no DB id)* | ~420 cal (estimated)

**alice-dinner** — *Alice's dinner — only ~490 cal remaining for the day*
RAG returned:
  1. **Caramelized Tofu & Gala Apple Salad** *(id: spoonacular_637067)* | 380 cal, 20g P, 33g C, 21g F
  2. **Tuscan Style Bread Salad** *(id: spoonacular_664144)* | 352 cal, 6g P, 55g C, 10g F
  3. **Spicy Salad with Kidney Beans, Cheddar, and Nuts** *(id: spoonacular_157344)* | 719 cal, 27g P, 51g C, 49g F
No-RAG returned (invented by Gemini):
  1. **Spicy Tofu & Edamame Quinoa Bowl** *(no DB id)* | ~705 cal (estimated)
  2. **Hearty Black Bean & Corn Salad with Avocado** *(no DB id)* | ~692 cal (estimated)

**alice-snack** — *Alice's afternoon snack — ~160 cal vegetarian snack*
RAG returned:
  1. **Fresh Black Bean Dip** *(id: spoonacular_643443)* | 113 cal, 7g P, 22g C, 1g F
  2. **Black Bean and Peppers Taco Filling** *(id: spoonacular_635058)* | 118 cal, 5g P, 19g C, 3g F
  3. **Mexican Quinoa Bowl** *(id: spoonacular_1646941)* | 222 cal, 10g P, 31g C, 7g F
No-RAG returned (invented by Gemini):
  1. **Tofu & Black Bean Salad** *(no DB id)* | ~380 cal (estimated)
  2. **Edamame Hummus with Veggies** *(no DB id)* | ~320 cal (estimated)
  3. **Spiced Chickpea Lettuce Wraps** *(no DB id)* | ~350 cal (estimated)

### Bob — 27M, No Restrictions, Gain Muscle

| Meal      | Cal. Target | Cal. Acc (RAG) | Cal. Acc (No-RAG) | Restrict (RAG) | Restrict (No-RAG) | Macro (RAG) | Macro (No-RAG) |
|-----------|-------------|----------------|-------------------|----------------|-------------------|-------------|----------------|
| breakfast | 800 kcal    | 92.5%          | 93.8%             | 100.0%         | 100.0%            | 28.9%       | 52.8%          |
| lunch     | 1020 kcal   | 62.5%          | 89.0%             | 100.0%         | 100.0%            | 55.9%       | 88.9%          |
| dinner    | 1244 kcal   | 52.3%          | 71.4%             | 100.0%         | 100.0%            | 59.3%       | 99.8%          |
| snack     | 422 kcal    | 67.5%          | 49.9%             | 100.0%         | 100.0%            | 63.4%       | 49.2%          |

**bob-breakfast** — *Bob's high-protein breakfast to start the day*
RAG returned:
  1. **Blueberry Stuffed Croissant French Toast with Bacon** *(id: spoonacular_673440)* | 783 cal, 14g P, 59g C, 55g F
  2. **Cinnamon French Toast Sticks** *(id: spoonacular_764752)* | 695 cal, 23g P, 98g C, 26g F
  3. **Pecan Waffles** *(id: spoonacular_655537)* | 859 cal, 8g P, 69g C, 63g F
No-RAG returned (invented by Gemini):
  1. **Hearty Breakfast Burrito** *(no DB id)* | ~750 cal (estimated)
  2. **Chicken & Rice Breakfast Bowl** *(no DB id)* | ~780 cal (estimated)
  3. **Protein Pancakes with Berries** *(no DB id)* | ~720 cal (estimated)

**bob-lunch** — *Bob's post-workout lunch, high protein (35% goal)*
RAG returned:
  1. **Japanese Chicken Donburi** *(id: spoonacular_648460)* | 626 cal, 25g P, 87g C, 19g F
  2. **Best Chicken Parmesan** *(id: spoonacular_634891)* | 636 cal, 53g P, 44g C, 26g F
  3. **Rice with Fried Egg and Sausage** *(id: spoonacular_658290)* | 649 cal, 17g P, 75g C, 30g F
No-RAG returned (invented by Gemini):
  1. **Chicken & Black Bean Rice Bowl** *(no DB id)* | ~905 cal (estimated)
  2. **High-Protein Chicken & Egg Scramble with Rice** *(no DB id)* | ~910 cal (estimated)

**bob-dinner** — *Bob's dinner — still needs ~1600 cal to hit daily goal*
RAG returned:
  1. **Baked Ziti Or Rigatoni** *(id: spoonacular_633884)* | 869 cal, 45g P, 101g C, 32g F
  2. **Chicken Noodle Casserole Dish** *(id: spoonacular_982376)* | 659 cal, 43g P, 52g C, 31g F
  3. **Fried Rice - Chinese comfort food** *(id: spoonacular_643786)* | 422 cal, 16g P, 47g C, 19g F
No-RAG returned (invented by Gemini):
  1. **Giant Chicken & Rice Power Bowl** *(no DB id)* | ~1600 cal (estimated)
  2. **Hearty Chicken & Egg Fried Rice** *(no DB id)* | ~1600 cal (estimated)

**bob-snack** — *Bob's mid-afternoon snack — high-protein to stay in surplus*
RAG returned:
  1. **Chocolate Java Protein Shake** *(id: spoonacular_511738)* | 257 cal, 27g P, 29g C, 5g F
  2. **Rice Pudding** *(id: spoonacular_658276)* | 404 cal, 12g P, 66g C, 10g F
  3. **Scotch Egg** *(id: spoonacular_716363)* | 651 cal, 28g P, 70g C, 28g F
No-RAG returned (invented by Gemini):
  1. **Chicken & Rice Power Bowl** *(no DB id)* | ~655 cal (estimated)
  2. **Loaded Scrambled Eggs with Quinoa** *(no DB id)* | ~600 cal (estimated)
  3. **Creamy Chicken & Rice Soup** *(no DB id)* | ~645 cal (estimated)

### Carol — 40F, Gluten-Free + Dairy-Free, Maintain

| Meal      | Cal. Target | Cal. Acc (RAG) | Cal. Acc (No-RAG) | Restrict (RAG) | Restrict (No-RAG) | Macro (RAG) | Macro (No-RAG) |
|-----------|-------------|----------------|-------------------|----------------|-------------------|-------------|----------------|
| breakfast | 475 kcal    | 93.5%          | 67.4%             | 100.0%         | 100.0%            | 57.9%       | 53.4%          |
| lunch     | 592 kcal    | 85.9%          | 86.1%             | 66.7%          | 100.0%            | 51.2%       | 64.4%          |
| dinner    | 793 kcal    | 66.3%          | 71.4%             | 66.7%          | 100.0%            | 69.5%       | 99.1%          |

**carol-breakfast** — *Carol's breakfast — must be gluten-free AND dairy-free*
RAG returned:
  1. **Vegan Cacao Crunch Granola** *(id: spoonacular_1095752)* | 451 cal, 8g P, 54g C, 25g F
  2. **Your Basic Low Carb Breakfast** *(id: spoonacular_1747693)* | 510 cal, 21g P, 15g C, 42g F
  3. **Peaches & Coconut Cream Steel Cut Oatmeal** *(id: spoonacular_655181)* | 508 cal, 13g P, 63g C, 25g F
No-RAG returned (invented by Gemini):
  1. **Salmon & Avocado Quinoa Bowl** *(no DB id)* | ~640 cal (estimated)
  2. **Berry & Spinach Protein Smoothie** *(no DB id)* | ~620 cal (estimated)
  3. **Loaded Breakfast Scramble** *(no DB id)* | ~630 cal (estimated)

**carol-lunch** — *Carol's lunch — dual restriction compliance stress test*
RAG returned:
  1. **salmon fried rice** *(id: spoonacular_667701)* | 444 cal, 26g P, 57g C, 12g F
  2. **The "Even my picky bf will eat it" Salad** *(id: spoonacular_469862)* | 674 cal, 28g P, 38g C, 49g F
  3. **Japanese Sushi** *(id: spoonacular_648506)* | 571 cal, 70g P, 38g C, 13g F
No-RAG returned (invented by Gemini):
  1. **Lemon Herb Salmon & Quinoa Bowl** *(no DB id)* | ~510 cal (estimated)
  2. **Mediterranean Chickpea & Quinoa Salad** *(no DB id)* | ~520 cal (estimated)
  3. **Avocado & Black Bean Sweet Potato Bowl** *(no DB id)* | ~500 cal (estimated)

**carol-dinner** — *Carol's dinner — salmon/quinoa preference + restrictions*
RAG returned:
  1. **The "Even my picky bf will eat it" Salad** *(id: spoonacular_469862)* | 674 cal, 28g P, 38g C, 49g F
  2. **salmon fried rice** *(id: spoonacular_667701)* | 444 cal, 26g P, 57g C, 12g F
  3. **Quinoa Salad with Barberries & Nuts** *(id: spoonacular_1098387)* | 459 cal, 14g P, 60g C, 19g F
No-RAG returned (invented by Gemini):
  1. **Lemon Herb Salmon with Quinoa & Roasted Veggies** *(no DB id)* | ~1020 cal (estimated)
  2. **Chicken & Sweet Potato Power Bowl** *(no DB id)* | ~1020 cal (estimated)

### Derek — 51M, Vegan, BMI 36, Lose Weight

| Meal      | Cal. Target | Cal. Acc (RAG) | Cal. Acc (No-RAG) | Restrict (RAG) | Restrict (No-RAG) | Macro (RAG) | Macro (No-RAG) |
|-----------|-------------|----------------|-------------------|----------------|-------------------|-------------|----------------|
| breakfast | 450 kcal    | 91.7%          | 84.4%             | 100.0%         | 100.0%            | 53.7%       | 65.0%          |
| lunch     | 560 kcal    | 74.5%          | 88.7%             | 66.7%          | 100.0%            | 69.9%       | 61.1%          |
| dinner    | 700 kcal    | 47.2%          | 42.9%             | 66.7%          | 100.0%            | 46.6%       | 50.5%          |

**derek-breakfast** — *Derek's vegan breakfast — low calorie, lose weight goal*
RAG returned:
  1. **Cranberry-Ginger Oatmeal With Toasted Hazelnuts** *(id: spoonacular_640443)* | 382 cal, 10g P, 43g C, 21g F
  2. **Vegan Cacao Crunch Granola** *(id: spoonacular_1095752)* | 451 cal, 8g P, 54g C, 25g F
  3. **Country Breakfast: Tofu and Veggie Scramble With Home Fries** *(id: spoonacular_640194)* | 493 cal, 30g P, 20g C, 34g F
No-RAG returned (invented by Gemini):
  1. **Sweet Potato & Lentil Scramble** *(no DB id)* | ~520 cal (estimated)
  2. **Hearty Lentil & Veggie Bowl** *(no DB id)* | ~530 cal (estimated)
  3. **Chickpea Flour Pancakes with Berries** *(no DB id)* | ~510 cal (estimated)

**derek-lunch** — *Derek's vegan lunch — dislikes coconut and spicy food*
RAG returned:
  1. **Lentils and Apples with Acorn Squash** *(id: spoonacular_649942)* | 608 cal, 21g P, 91g C, 19g F
  2. **Indian Lentil Dahl** *(id: spoonacular_647830)* | 400 cal, 17g P, 42g C, 20g F
  3. **Tomato and lentil soup** *(id: spoonacular_663559)* | 340 cal, 18g P, 51g C, 8g F
No-RAG returned (invented by Gemini):
  1. **Sweet Potato & Black Bean Bowl** *(no DB id)* | ~495 cal (estimated)
  2. **Lentil Shepherd's Pie (vegan)** *(no DB id)* | ~510 cal (estimated)
  3. **Chickpea & Veggie Wraps** *(no DB id)* | ~485 cal (estimated)

**derek-dinner** — *Derek's dinner — vegan + dislikes combined (tests fallback relaxation)*
RAG returned:
  1. **Black Bean and Sweet Potato Enchiladas with Avocado Cream Sauce** *(id: spoonacular_684981)* | 370 cal, 9g P, 51g C, 17g F
  2. **Sweet Potato, Kale & White Bean Soup** *(id: spoonacular_662604)* | 261 cal, 10g P, 42g C, 4g F
  3. **Easy Roasted Vegetables** *(id: spoonacular_642085)* | 360 cal, 9g P, 76g C, 5g F
No-RAG returned (invented by Gemini):
  1. **Lentil & Sweet Potato Shepherd's Pie** *(no DB id)* | ~300 cal (estimated)
  2. **Sweet Potato & Black Bean Bowl** *(no DB id)* | ~300 cal (estimated)
  3. **Vegan Lentil Loaf with Roasted Broccoli** *(no DB id)* | ~300 cal (estimated)

### Eve — 22F, No Restrictions, Maintain Weight

| Meal      | Cal. Target | Cal. Acc (RAG) | Cal. Acc (No-RAG) | Restrict (RAG) | Restrict (No-RAG) | Macro (RAG) | Macro (No-RAG) |
|-----------|-------------|----------------|-------------------|----------------|-------------------|-------------|----------------|
| breakfast | 500 kcal    | 94.6%          | 78.7%             | 100.0%         | 100.0%            | 61.5%       | 41.7%          |
| lunch     | 608 kcal    | 84.8%          | 90.5%             | 100.0%         | 100.0%            | 65.3%       | 81.9%          |
| dinner    | 778 kcal    | 78.4%          | 43.1%             | 100.0%         | 100.0%            | 63.1%       | 42.5%          |

**eve-breakfast** — *Eve's casual breakfast — no restrictions, maintenance calories*
RAG returned:
  1. **Peanut Butter And Chocolate Oatmeal** *(id: spoonacular_655219)* | 470 cal, 19g P, 73g C, 14g F
  2. **Easy Berry French Toast** *(id: spoonacular_1444543)* | 544 cal, 19g P, 66g C, 23g F
  3. **Country Breakfast: Tofu and Veggie Scramble With Home Fries** *(id: spoonacular_640194)* | 493 cal, 30g P, 20g C, 34g F
No-RAG returned (invented by Gemini):
  1. **Protein-Packed Scramble with Veggies & Toast** *(no DB id)* | ~630 cal (estimated)
  2. **Berry Banana Smoothie Bowl** *(no DB id)* | ~580 cal (estimated)
  3. **Apple Cinnamon Cottage Cheese Pancakes** *(no DB id)* | ~610 cal (estimated)

**eve-lunch** — *Eve's lunch — Mediterranean cuisine preference*
RAG returned:
  1. **Chicken Parmesan With Pasta** *(id: spoonacular_638235)* | 557 cal, 43g P, 57g C, 17g F
  2. **Ratatouille Pasta** *(id: spoonacular_657933)* | 691 cal, 25g P, 69g C, 37g F
  3. **Italian Tuna Pasta** *(id: spoonacular_648279)* | 464 cal, 38g P, 70g C, 3g F
No-RAG returned (invented by Gemini):
  1. **Mediterranean Chicken & Veggie Pasta** *(no DB id)* | ~555 cal (estimated)
  2. **Lemon Herb Salmon with Quinoa & Roasted Veggies** *(no DB id)* | ~545 cal (estimated)

**eve-dinner** — *Eve's dinner — any cuisine, balanced macros*
RAG returned:
  1. **Colorful Tomato and Spinach Seafood Pasta** *(id: spoonacular_639957)* | 470 cal, 34g P, 58g C, 10g F
  2. **Ratatouille Pasta** *(id: spoonacular_657933)* | 691 cal, 25g P, 69g C, 37g F
  3. **Pasta With Italian Sausage** *(id: spoonacular_654928)* | 886 cal, 32g P, 73g C, 49g F
No-RAG returned (invented by Gemini):
  1. **Lemon Herb Chicken Quinoa Bowl** *(no DB id)* | ~340 cal (estimated)
  2. **Hearty Chickpea & Veggie Pasta** *(no DB id)* | ~360 cal (estimated)
  3. **Baked Salmon with Sweet Potato & Asparagus** *(no DB id)* | ~307 cal (estimated)

### Frank — 46M, Sedentary, Overweight, Lose Weight

| Meal      | Cal. Target | Cal. Acc (RAG) | Cal. Acc (No-RAG) | Restrict (RAG) | Restrict (No-RAG) | Macro (RAG) | Macro (No-RAG) |
|-----------|-------------|----------------|-------------------|----------------|-------------------|-------------|----------------|
| breakfast | 425 kcal    | 76.8%          | 65.9%             | 100.0%         | 100.0%            | 58.0%       | 93.0%          |
| lunch     | 528 kcal    | 84.1%          | 93.8%             | 100.0%         | 100.0%            | 79.4%       | 59.6%          |
| dinner    | 661 kcal    | 59.5%          | 74.4%             | 100.0%         | 100.0%            | 73.9%       | 62.8%          |

**frank-breakfast** — *Frank's breakfast — low calorie start for weight loss*
RAG returned:
  1. **Corn Bread** *(id: spoonacular_640067)* | 363 cal, 11g P, 55g C, 12g F
  2. **Easy Berry French Toast** *(id: spoonacular_1444543)* | 544 cal, 19g P, 66g C, 23g F
  3. **Peanut Butter Banana French Toast** *(id: spoonacular_655239)* | 540 cal, 20g P, 67g C, 24g F
No-RAG returned (invented by Gemini):
  1. **Lean Beef & Egg Scramble with Home Fries and Toast** *(no DB id)* | ~580 cal (estimated)
  2. **Hearty Breakfast Sandwich with Turkey Bacon & Apple** *(no DB id)* | ~560 cal (estimated)

**frank-lunch** — *Frank's lunch — must stay under budget after breakfast*
RAG returned:
  1. **Hungarian Beef Goulash** *(id: spoonacular_647645)* | 516 cal, 35g P, 62g C, 14g F
  2. **Shredded Roast Beef Stuffed Sweet Potatoes (Whole 30 & PALEO)** *(id: spoonacular_1044252)* | 486 cal, 44g P, 55g C, 9g F
  3. **Mexican Stuffed Potatoes** *(id: spoonacular_651707)* | 330 cal, 21g P, 40g C, 10g F
No-RAG returned (invented by Gemini):
  1. **Lean Beef & Roasted Potato Bowl** *(no DB id)* | ~485 cal (estimated)
  2. **Roast Beef & Veggie Sandwich** *(no DB id)* | ~490 cal (estimated)
  3. **Beef & Black Bean Chili with Whole Wheat Bread** *(no DB id)* | ~510 cal (estimated)

**frank-dinner** — *Frank's dinner — likes beef/potatoes but needs low calorie options*
RAG returned:
  1. **Mexican Stuffed Potatoes** *(id: spoonacular_651707)* | 330 cal, 21g P, 40g C, 10g F
  2. **Pasta With Roasted Vegetables & Greek Olives** *(id: spoonacular_654939)* | 266 cal, 23g P, 26g C, 10g F
  3. **Butter-Bread** *(id: spoonacular_636523)* | 583 cal, 12g P, 67g C, 30g F
No-RAG returned (invented by Gemini):
  1. **Lean Beef & Roasted Potato Dinner** *(no DB id)* | ~820 cal (estimated)
  2. **Lean Beef & Potato Hash with Whole Wheat Toast** *(no DB id)* | ~840 cal (estimated)
  3. **Steak with Garlic Herb Potatoes & Side Salad** *(no DB id)* | ~830 cal (estimated)

### Isabelle — 26F, Vegan + Gluten-Free, Maintain Weight

| Meal  | Cal. Target | Cal. Acc (RAG) | Cal. Acc (No-RAG) | Restrict (RAG) | Restrict (No-RAG) | Macro (RAG) | Macro (No-RAG) |
|-------|-------------|----------------|-------------------|----------------|-------------------|-------------|----------------|
| snack | 195 kcal    | 71.3%          | 15.4%             | 100.0%         | 100.0%            | 80.0%       | 90.9%          |

**isabelle-snack** — *Isabelle's snack — tiny vegan + gluten-free snack ~190 cal*
RAG returned:
  1. **Cinnamon & Sugar Roasted Chickpeas** *(id: spoonacular_639433)* | 153 cal, 5g P, 24g C, 4g F
  2. **Channa-Chickpea, Potato & Cauliflower Curry** *(id: spoonacular_637426)* | 144 cal, 5g P, 21g C, 5g F
  3. **Chickpea and Pumpkin Curry** *(id: spoonacular_638496)* | 270 cal, 9g P, 36g C, 12g F
No-RAG returned (invented by Gemini):
  1. **Spiced Chickpea & Spinach Rice Cakes** *(no DB id)* | ~357 cal (estimated)
  2. **Mini Spinach & Edamame Rice Bowl** *(no DB id)* | ~363 cal (estimated)

## Methodology

**RAG Pipeline:**
The RAG pipeline calls the deployed `searchRecipes` Cloud Function, which:
1. Builds a contextual query string from the user profile (meal type, cuisine, dietary goal, macro goals, food likes/dislikes, activity level, BMI, age)
2. Embeds the query using Gemini Embedding 001 (768 dimensions)
3. Performs semantic similarity search in PostgreSQL with pgvector
4. Scores candidates using a weighted algorithm: dietary goal alignment (25%), calorie proximity (25%), macro alignment (20%), semantic similarity (10%), likes match (10%), other (10%)
5. Returns top 3 ranked recipes with exact nutritional data from the database

**No-RAG Baseline:**
The baseline calls the Gemini 1.5 Flash API directly with a structured prompt containing the user profile. Gemini generates recipe suggestions from its training data — no database lookup occurs.

**Metrics:**
- **Hallucination Rate**: Whether returned recipes have a verified database ID (RAG always = 1.0; No-RAG always = 0.0 since recipes are invented)
- **Calorie Accuracy**: `max(0, 1 - |actual_cal - target_cal| / target_cal)` where target uses smart remaining-calorie calculation
- **Macro Alignment**: Per-macro deviation from goals using `max(0, 1 - |diff| / 30)` (mirrors production scoring), weighted protein 40%, carbs 35%, fat 25%
- **Restriction Compliance**: RAG uses structured DB health labels; No-RAG uses keyword violation heuristics (intentionally generous to no-RAG)
- **Preference Adherence**: Checks recipe ingredients/text for dislike violations and like-ingredient matches
- **Response Specificity**: Regex detection of exact nutritional figures in the response text

**Note on fairness**: The restriction compliance metric for No-RAG uses keyword heuristics that may miss some violations, meaning No-RAG compliance scores are likely *overestimated*. The actual compliance gap is likely larger.