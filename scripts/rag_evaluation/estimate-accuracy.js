/**
 * Gemini Nutrition Estimation Accuracy Test
 *
 * Answers: "How accurate is Gemini's nutrition knowledge compared to real recipe data?"
 *
 * Method:
 *   1. Read RAG results (which contain verified DB nutrition as ground truth)
 *   2. Ask Gemini to estimate nutrition for those exact same recipe names
 *   3. Compare estimates to verified values
 *   4. Report Mean Absolute Percentage Error (MAPE) per nutrient
 *
 * Usage:
 *   export GEMINI_API_KEY="your-key"
 *   node estimate-accuracy.js
 *
 * Or pass a specific results file:
 *   node estimate-accuracy.js output/results-2026-02-27.json
 */

import { readFileSync, writeFileSync, mkdirSync, readdirSync } from 'fs';

const GEMINI_MODEL = 'gemini-2.5-flash';
const GEMINI_API_BASE = 'https://generativelanguage.googleapis.com/v1beta/models';
const DELAY_MS = 1500;

// ─── Load verified recipes from RAG results ───────────────────────────────────

function loadVerifiedRecipes(resultsPath) {
  const results = JSON.parse(readFileSync(resultsPath, 'utf8'));
  const recipes = [];

  for (const r of results) {
    for (const recipe of r.rag.recipes) {
      if (
        recipe.calories != null &&
        recipe.protein != null &&
        recipe.carbs != null &&
        recipe.fat != null &&
        recipe.calories > 0
      ) {
        recipes.push({
          label: recipe.label,
          actual: {
            calories: Math.round(recipe.calories),
            protein: Math.round(recipe.protein),
            carbs: Math.round(recipe.carbs),
            fat: Math.round(recipe.fat),
          },
          scenarioId: r.scenario.id,
        });
      }
    }
  }

  // Deduplicate by recipe label
  const seen = new Set();
  return recipes.filter((r) => {
    if (seen.has(r.label)) return false;
    seen.add(r.label);
    return true;
  });
}

// ─── Ask Gemini to estimate nutrition for a named recipe ─────────────────────

async function estimateNutrition(recipeName, apiKey) {
  const prompt = `What is the approximate nutritional content per serving of "${recipeName}"?
Output ONLY one line in exactly this format (no other text):
X calories | Pg protein | Cg carbs | Fg fat

Example:
420 calories | 24g protein | 52g carbs | 8g fat`;

  const res = await fetch(`${GEMINI_API_BASE}/${GEMINI_MODEL}:generateContent?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.3, maxOutputTokens: 128 },
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Gemini API ${res.status}: ${body.slice(0, 150)}`);
  }

  const json = await res.json();
  const text = json.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? '';
  return parseEstimate(text);
}

function parseEstimate(text) {
  // Expected: "420 calories | 24g protein | 52g carbs | 8g fat"
  // Also handle: "420 cal | 24g protein | ..."
  const parts = text.split('|').map((p) => p.trim());
  if (parts.length < 4) return null;

  const calories = extractNum(parts[0]);
  const protein = extractNum(parts[1]);
  const carbs = extractNum(parts[2]);
  const fat = extractNum(parts[3]);

  if (calories == null || protein == null || carbs == null || fat == null) return null;
  if (calories <= 0 || calories > 5000) return null; // sanity check

  return { calories, protein, carbs, fat };
}

function extractNum(str) {
  const m = str.match(/(\d+\.?\d*)/);
  return m ? parseFloat(m[1]) : null;
}

// ─── Error metrics ────────────────────────────────────────────────────────────

/** Absolute percentage error: |estimate - actual| / actual * 100 */
function ape(estimate, actual) {
  if (!actual || actual === 0) return null;
  return (Math.abs(estimate - actual) / actual) * 100;
}

/** Mean of an array, ignoring nulls */
function mean(arr) {
  const valid = arr.filter((x) => x != null);
  if (valid.length === 0) return null;
  return valid.reduce((a, b) => a + b, 0) / valid.length;
}

function stddev(arr) {
  const valid = arr.filter((x) => x != null);
  if (valid.length < 2) return null;
  const avg = mean(valid);
  const variance = valid.reduce((s, x) => s + (x - avg) ** 2, 0) / valid.length;
  return Math.sqrt(variance);
}

function median(arr) {
  const valid = arr.filter((x) => x != null).sort((a, b) => a - b);
  if (valid.length === 0) return null;
  const mid = Math.floor(valid.length / 2);
  return valid.length % 2 !== 0 ? valid[mid] : (valid[mid - 1] + valid[mid]) / 2;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.error('Error: GEMINI_API_KEY environment variable is required.');
    process.exit(1);
  }

  function findMostRecentResultsFile() {
    try {
      const files = readdirSync('output')
        .filter((f) => f.startsWith('results-') && f.endsWith('.json'))
        .sort()
        .reverse();
      return files.length > 0 ? `output/${files[0]}` : null;
    } catch {
      return null;
    }
  }

  const resultsPath = process.argv[2] ?? findMostRecentResultsFile();
  if (!resultsPath) {
    console.error('No results file found. Run evaluate.js first, or pass a path explicitly.');
    process.exit(1);
  }

  console.log('GEMINI NUTRITION ESTIMATION ACCURACY TEST');
  console.log('='.repeat(60));
  console.log(`Results file: ${resultsPath}`);
  console.log(`Model: ${GEMINI_MODEL}`);
  console.log('='.repeat(60));

  const verifiedRecipes = loadVerifiedRecipes(resultsPath);
  console.log(`\nLoaded ${verifiedRecipes.length} unique verified recipes from RAG results\n`);

  const comparisons = [];
  let idx = 0;

  for (const recipe of verifiedRecipes) {
    idx++;
    process.stdout.write(`[${idx}/${verifiedRecipes.length}] "${recipe.label}"... `);

    let estimate = null;
    let error = null;
    try {
      estimate = await estimateNutrition(recipe.label, apiKey);
      if (estimate) {
        const calError = ape(estimate.calories, recipe.actual.calories);
        const proError = ape(estimate.protein, recipe.actual.protein);
        const carbError = ape(estimate.carbs, recipe.actual.carbs);
        const fatError = ape(estimate.fat, recipe.actual.fat);

        console.log(
          `actual ${recipe.actual.calories}cal vs Gemini ${estimate.calories}cal ` +
          `(off ${calError != null ? calError.toFixed(0) : '?'}%)`
        );

        comparisons.push({
          label: recipe.label,
          actual: recipe.actual,
          estimate,
          errors: { calories: calError, protein: proError, carbs: carbError, fat: fatError },
        });
      } else {
        console.log('parse failed');
        comparisons.push({ label: recipe.label, actual: recipe.actual, estimate: null, errors: null });
      }
    } catch (err) {
      error = err.message;
      console.log(`FAILED: ${err.message.slice(0, 60)}`);
      comparisons.push({ label: recipe.label, actual: recipe.actual, estimate: null, errors: null, error });
    }

    await sleep(DELAY_MS);
  }

  // ── Compute summary stats ──────────────────────────────────────────────────
  const valid = comparisons.filter((c) => c.errors != null);
  console.log(`\n${valid.length} of ${comparisons.length} recipes successfully estimated\n`);

  const nutrients = ['calories', 'protein', 'carbs', 'fat'];
  const stats = {};
  for (const n of nutrients) {
    const errors = valid.map((c) => c.errors[n]);
    stats[n] = {
      mape: mean(errors),
      median: median(errors),
      stddev: stddev(errors),
      within10pct: errors.filter((e) => e != null && e <= 10).length,
      within25pct: errors.filter((e) => e != null && e <= 25).length,
      over50pct: errors.filter((e) => e != null && e > 50).length,
      n: errors.filter((e) => e != null).length,
    };
  }

  // ── Print results ──────────────────────────────────────────────────────────
  console.log('='.repeat(60));
  console.log('RESULTS: How accurate are Gemini\'s nutrition estimates?');
  console.log('='.repeat(60));
  console.log(`(Based on ${valid.length} recipes with verified nutritional data from the recipe database)\n`);

  for (const n of nutrients) {
    const s = stats[n];
    console.log(`${n.padEnd(10)} MAPE: ${s.mape?.toFixed(1)}%  Median: ${s.median?.toFixed(1)}%  StdDev: ±${s.stddev?.toFixed(1)}%`);
    console.log(`           Within 10%: ${s.within10pct}/${s.n} recipes  Within 25%: ${s.within25pct}/${s.n}  Off >50%: ${s.over50pct}/${s.n}`);
  }

  // ── Worst offenders ────────────────────────────────────────────────────────
  const sorted = valid
    .filter((c) => c.errors.calories != null)
    .sort((a, b) => b.errors.calories - a.errors.calories);

  console.log('\n── Largest calorie estimation errors ──────────────────────────');
  sorted.slice(0, 5).forEach((c) => {
    const dir = c.estimate.calories > c.actual.calories ? 'over' : 'under';
    console.log(
      `  ${c.label}\n    Actual: ${c.actual.calories} cal  |  Gemini: ${c.estimate.calories} cal  |  Error: ${c.errors.calories?.toFixed(0)}% ${dir}`
    );
  });

  console.log('\n── Most accurate calorie estimates ────────────────────────────');
  sorted.slice(-5).reverse().forEach((c) => {
    console.log(
      `  ${c.label}\n    Actual: ${c.actual.calories} cal  |  Gemini: ${c.estimate.calories} cal  |  Error: ${c.errors.calories?.toFixed(0)}%`
    );
  });

  // ── Calorie bias check (systematic over/under-estimation?) ────────────────
  const signedErrors = valid
    .filter((c) => c.errors.calories != null)
    .map((c) => c.estimate.calories - c.actual.calories);
  const avgBias = mean(signedErrors);
  console.log(`\n── Systematic bias ────────────────────────────────────────────`);
  console.log(`  Average signed error: ${avgBias >= 0 ? '+' : ''}${avgBias?.toFixed(0)} kcal per recipe`);
  console.log(`  (positive = Gemini overestimates on average, negative = underestimates)`);

  // ── Write output ──────────────────────────────────────────────────────────
  mkdirSync('output', { recursive: true });
  const today = new Date().toISOString().split('T')[0];
  const outPath = `output/estimation-accuracy-${today}.json`;
  writeFileSync(outPath, JSON.stringify({ stats, comparisons }, null, 2));
  console.log(`\nFull comparison data written to: ${outPath}`);

  // ── Append to persistent estimation history ───────────────────────────────
  const historyPath = 'output/estimation-history.json';
  let estHistory = [];
  try { estHistory = JSON.parse(readFileSync(historyPath, 'utf8')); } catch { /* first run */ }
  estHistory.push({
    date: today,
    runId: new Date().toISOString(),
    model: GEMINI_MODEL,
    recipesTotal: comparisons.length,
    recipesEstimated: valid.length,
    stats,
  });
  writeFileSync(historyPath, JSON.stringify(estHistory, null, 2));
  console.log(`Estimation history updated: ${historyPath}`);

  // ── One-liner for presentation ─────────────────────────────────────────────
  const calMAPE = stats.calories.mape;
  const calWithin25 = stats.calories.within25pct;
  const calTotal = stats.calories.n;
  console.log('\n='.repeat(60));
  console.log('PRESENTATION HEADLINE STAT:');
  console.log(`  Gemini's calorie estimates average ${calMAPE?.toFixed(0)}% error`);
  console.log(`  compared to verified recipe database values.`);
  console.log(`  Only ${calWithin25}/${calTotal} recipes (${((calWithin25/calTotal)*100).toFixed(0)}%) are within 25% of the actual calories.`);
  console.log('='.repeat(60));
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
