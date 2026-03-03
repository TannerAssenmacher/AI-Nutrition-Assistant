/**
 * RAG Accuracy Evaluation — Main Orchestrator
 *
 * Runs all 12 test scenarios through two pipelines:
 *   1. RAG:    searchRecipes Cloud Function (real DB recipes with exact nutrition)
 *   2. No-RAG: Direct Gemini API call (Gemini invents recipes from knowledge)
 *
 * Then calculates 6 metrics for each and writes a comparison report.
 *
 * Usage:
 *   export GEMINI_API_KEY="your-key"
 *   node evaluate.js
 *
 * No Cloud SQL Proxy needed. Requires gcloud CLI logged in (for Cloud Run auth).
 */

import { writeFileSync, mkdirSync, readFileSync } from 'fs';
import { createSign } from 'crypto';
import { scenarios } from './test-scenarios.js';
import { calculateAllMetrics, calculateCalorieTarget } from './metrics.js';
import { generateReport } from './report.js';

// ─── Config ──────────────────────────────────────────────────────────────────

const SEARCH_RECIPES_URL = 'https://searchrecipes-h6ifougfsq-uc.a.run.app';
const GEMINI_MODEL = 'gemini-2.5-flash';

const METRIC_NAMES = [
  'hallucination',
  'calorieAccuracy',
  'macroAlignment',
  'restrictionCompliance',
  'preferenceAdherence',
  'specificity',
];
const GEMINI_API_BASE = 'https://generativelanguage.googleapis.com/v1beta/models';

// Firebase Web API key (from lib/firebase_options.dart)
const FIREBASE_API_KEY = 'AIzaSyC3ffg9dqgDmQ-FNO7O5IJ_uBdybOoCWrA';

// Path to service account key (relative to this script's location)
const SERVICE_ACCOUNT_KEY_PATH = '../recipe_ingestion/serviceAccountKey.json';

const DELAY_MS = 2500; // between API calls to respect rate limits

// ─── Firebase Auth: get ID token via service account custom token ─────────────

/**
 * Creates a Firebase custom token signed with the service account private key,
 * then exchanges it for a Firebase ID token via the REST API.
 * Uses only Node's built-in crypto module — no npm install needed.
 */
async function getFirebaseIdToken() {
  const serviceAccount = JSON.parse(readFileSync(SERVICE_ACCOUNT_KEY_PATH, 'utf8'));

  // Build the custom token JWT
  const now = Math.floor(Date.now() / 1000);
  const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify({
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
    iat: now,
    exp: now + 3600,
    uid: 'rag-evaluation-bot',
  })).toString('base64url');

  const sign = createSign('RSA-SHA256');
  sign.update(`${header}.${payload}`);
  const signature = sign.sign(serviceAccount.private_key, 'base64url');
  const customToken = `${header}.${payload}.${signature}`;

  // Exchange custom token for Firebase ID token
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${FIREBASE_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    }
  );

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Firebase auth exchange failed ${res.status}: ${body.slice(0, 200)}`);
  }

  const json = await res.json();
  return json.idToken;
}

// ─── RAG Pipeline ─────────────────────────────────────────────────────────────

/**
 * Call the deployed searchRecipes Cloud Function.
 * Mirrors the fetch pattern from scripts/recipe_ingestion/test_rag_search.js.
 * Returns { recipes, isExactMatch, geminiResponseText }
 */
async function callRagPipeline(scenario, identityToken) {
  const res = await fetch(SEARCH_RECIPES_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${identityToken}`,
    },
    body: JSON.stringify({ data: scenario.ragParams }),
  });

  if (!res.ok) {
    throw new Error(`searchRecipes HTTP ${res.status}: ${res.statusText}`);
  }

  const json = await res.json();

  if (!json.result || !json.result.recipes) {
    throw new Error(`searchRecipes returned unexpected format: ${JSON.stringify(json).slice(0, 200)}`);
  }

  const { recipes, isExactMatch } = json.result;

  // For RAG, the "Gemini response text" is the structured recipe data.
  // Since the data comes from the DB with exact numbers, we format it as text
  // to simulate what the callGemini response would contain.
  const geminiResponseText = formatRagRecipesAsText(recipes);

  return { recipes, isExactMatch, geminiResponseText, pipelineType: 'rag' };
}

/**
 * Format RAG recipe results as text (simulates the Gemini response text
 * that would include exact nutritional numbers from the DB).
 */
function formatRagRecipesAsText(recipes) {
  return recipes
    .map((r, i) => {
      const lines = [`${i + 1}. ${r.label}`];
      if (r.calories != null) lines.push(`   ${Math.round(r.calories)} calories per serving`);
      if (r.protein != null) lines.push(`   ${Math.round(r.protein)}g protein`);
      if (r.carbs != null) lines.push(`   ${Math.round(r.carbs)}g carbs`);
      if (r.fat != null) lines.push(`   ${Math.round(r.fat)}g fat`);
      if (r.healthLabels && r.healthLabels.length > 0) {
        lines.push(`   Dietary labels: ${r.healthLabels.join(', ')}`);
      }
      return lines.join('\n');
    })
    .join('\n\n');
}

// ─── No-RAG Baseline ─────────────────────────────────────────────────────────

/**
 * Call the Gemini API directly — no database lookup, no recipe retrieval.
 * Gemini invents recipes from its own knowledge.
 * Returns { recipes, geminiResponseText }
 */
async function callNoRagBaseline(scenario, apiKey) {
  const prompt = buildNoRagPrompt(scenario);

  const res = await fetch(`${GEMINI_API_BASE}/${GEMINI_MODEL}:generateContent?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.7, maxOutputTokens: 2048 },
    }),
  });

  if (!res.ok) {
    const errorBody = await res.text();
    throw new Error(`Gemini API HTTP ${res.status}: ${errorBody.slice(0, 200)}`);
  }

  const json = await res.json();
  const geminiResponseText = json.candidates?.[0]?.content?.parts?.[0]?.text ?? '';

  const recipes = parseNoRagRecipes(geminiResponseText);

  return { recipes, geminiResponseText, pipelineType: 'no-rag' };
}

/**
 * Prompt that asks Gemini to suggest recipes without any DB context.
 * Uses the same profile information the RAG pipeline has access to.
 */
function buildNoRagPrompt(scenario) {
  const { profile, ragParams } = scenario;
  const {
    mealType,
    cuisineType,
    consumedCalories,
    healthRestrictions,
    dislikes,
    likes,
  } = ragParams;

  const restrictionText =
    healthRestrictions && healthRestrictions.length > 0
      ? healthRestrictions.join(', ')
      : 'none';
  const dislikeText = dislikes && dislikes.length > 0 ? dislikes.join(', ') : 'none';
  const likeText = likes && likes.length > 0 ? likes.join(', ') : 'none';
  const cuisineText = cuisineType && cuisineType !== 'none' ? cuisineType : 'any';

  return `You are a nutrition assistant. Suggest 3 ${mealType} recipes for this person.

User Profile:
- Dietary goal: ${profile.dietaryGoal}
- Daily calorie target: ${profile.dailyCalorieGoal} kcal
- Already consumed today: ${consumedCalories ?? 0} kcal
- Macro goals: ${profile.macroGoals.protein}% protein, ${profile.macroGoals.carbs}% carbs, ${profile.macroGoals.fat}% fat
- Dietary restrictions: ${restrictionText}
- Dislikes: ${dislikeText}
- Preferred ingredients: ${likeText}
- Cuisine preference: ${cuisineText}

IMPORTANT: Skip all introductory text. Output ONLY the 3 recipes, one per line, in EXACTLY this format:
RecipeName | X calories | Pg protein | Cg carbs | Fg fat

Example:
Lentil Soup | 420 calories | 24g protein | 52g carbs | 8g fat
Bean Tacos | 380 calories | 18g protein | 48g carbs | 10g fat
Veggie Stir Fry | 340 calories | 15g protein | 42g carbs | 9g fat`;
}

/**
 * Parse Gemini's free-text response into a recipe array.
 * All recipes get id=null and healthLabels=[] since they're invented.
 */
function parseNoRagRecipes(responseText) {
  const recipes = [];

  // Try to find lines matching "Name | X calories | Pg protein | Cg carbs | Fg fat"
  const lines = responseText.split('\n');

  for (const line of lines) {
    const trimmed = line.trim().replace(/^\d+\.\s*/, '').replace(/^\*+\s*/, '');
    if (!trimmed.includes('|')) continue;

    const parts = trimmed.split('|').map((p) => p.trim());
    if (parts.length < 3) continue;

    const label = parts[0].replace(/^\*+|\*+$/g, '').trim();
    if (!label || label.length < 3) continue;

    const calories = extractNumber(parts[1] ?? '') ?? extractNumber(parts.join(' '), 'cal');
    const protein = extractNumber(parts[2] ?? '', 'protein') ?? extractNumber(parts[2] ?? '');
    const carbs = extractNumber(parts[3] ?? '', 'carb') ?? extractNumber(parts[3] ?? '');
    const fat = extractNumber(parts[4] ?? '', 'fat') ?? extractNumber(parts[4] ?? '');

    if (label) {
      recipes.push({
        id: null,
        label,
        calories,
        protein,
        carbs,
        fat,
        healthLabels: [],
        ingredients: [],
        isTraceable: false,
      });
    }

    if (recipes.length >= 3) break;
  }

  // If structured parsing failed, try a simpler number extraction pass
  if (recipes.length === 0) {
    const fallback = extractRecipesFromUnstructuredText(responseText);
    return fallback;
  }

  return recipes;
}

/**
 * Fallback parser for when Gemini doesn't use the pipe format.
 * Extracts recipe names from numbered list items.
 */
function extractRecipesFromUnstructuredText(text) {
  const recipes = [];
  const blocks = text.split(/\n\s*\n/);

  for (const block of blocks) {
    if (!block.trim()) continue;

    const nameMatch = block.match(/^\d+\.\s+\*?\*?([^*\n:]+)\*?\*?/);
    if (!nameMatch) continue;

    const label = nameMatch[1].trim();
    const calories = extractNumber(block, 'cal');
    const protein = extractNumber(block, 'protein');
    const carbs = extractNumber(block, 'carb');
    const fat = extractNumber(block, 'fat');

    recipes.push({ id: null, label, calories, protein, carbs, fat, healthLabels: [], ingredients: [], isTraceable: false });
    if (recipes.length >= 3) break;
  }

  return recipes;
}

/**
 * Extract a number from text, optionally near a keyword.
 * Returns null if not found.
 */
function extractNumber(text, keyword = null) {
  if (!text) return null;

  if (keyword) {
    const pattern = new RegExp(`(\\d+\\.?\\d*)\\s*g?\\s*(?:of\\s*)?${keyword}|${keyword}[:\\s]*[~≈]?(\\d+\\.?\\d*)`, 'i');
    const match = text.match(pattern);
    if (match) return parseFloat(match[1] ?? match[2]);
  }

  const match = text.match(/(\d+\.?\d*)/);
  return match ? parseFloat(match[1]) : null;
}

// ─── Delay helper ─────────────────────────────────────────────────────────────

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ─── Run History ─────────────────────────────────────────────────────────────

/**
 * Compute average metrics across all valid results for one pipeline.
 * Returns null if no valid results.
 */
function avgMetrics(results, pipeline) {
  const valid = results.filter((r) => r[pipeline].metrics != null);
  if (!valid.length) return null;
  const avgs = {};
  for (const m of METRIC_NAMES) {
    avgs[m] = valid.reduce((s, r) => s + r[pipeline].metrics[m], 0) / valid.length;
  }
  return avgs;
}

/**
 * Append a summary of this evaluation run to run-history.json.
 * The file accumulates one entry per run, enabling trend analysis over time.
 */
function appendRunToHistory(outputDir, today, results) {
  const historyPath = `${outputDir}/run-history.json`;

  const validResults = results.filter((r) => r.rag.metrics && r.noRag.metrics);
  const ragAvg = avgMetrics(results, 'rag');
  const noRagAvg = avgMetrics(results, 'noRag');
  const delta =
    ragAvg && noRagAvg
      ? Object.fromEntries(METRIC_NAMES.map((m) => [m, ragAvg[m] - noRagAvg[m]]))
      : null;

  let history = [];
  try {
    history = JSON.parse(readFileSync(historyPath, 'utf8'));
  } catch {
    // First run — start fresh
  }

  history.push({
    date: today,
    runId: new Date().toISOString(),
    model: GEMINI_MODEL,
    scenarioCount: results.length,
    validCount: validResults.length,
    ragAvg,
    noRagAvg,
    delta,
  });

  writeFileSync(historyPath, JSON.stringify(history, null, 2));
  return historyPath;
}

// ─── Scenario Queue ───────────────────────────────────────────────────────────

const SCENARIOS_PER_RUN = 10;

/**
 * Load the list of scenario IDs that have already been run.
 * Returns an array of string IDs.
 */
function loadCompletedScenarioIds(outputDir) {
  const queuePath = `${outputDir}/scenario-queue.json`;
  try {
    const data = JSON.parse(readFileSync(queuePath, 'utf8'));
    return Array.isArray(data.completedIds) ? data.completedIds : [];
  } catch {
    return [];
  }
}

/**
 * Persist the updated list of completed scenario IDs.
 * If all scenarios have been run, resets the queue and logs a notice.
 */
function saveCompletedScenarioIds(outputDir, completedIds, allScenarioIds) {
  const queuePath = `${outputDir}/scenario-queue.json`;
  const allDone = allScenarioIds.every((id) => completedIds.includes(id));

  if (allDone) {
    console.log('\n  All scenarios have been run at least once. Resetting queue for next cycle.');
    writeFileSync(queuePath, JSON.stringify({ completedIds: [], cyclesCompleted: (loadCycleCount(outputDir) + 1) }, null, 2));
  } else {
    writeFileSync(queuePath, JSON.stringify({ completedIds }, null, 2));
  }
}

function loadCycleCount(outputDir) {
  try {
    const data = JSON.parse(readFileSync(`${outputDir}/scenario-queue.json`, 'utf8'));
    return data.cyclesCompleted ?? 0;
  } catch {
    return 0;
  }
}

/**
 * Select the next N scenarios that haven't been run yet.
 * Preserves the original order in test-scenarios.js.
 */
function selectNextScenarios(allScenarios, completedIds, n) {
  const remaining = allScenarios.filter((s) => !completedIds.includes(s.id));
  return remaining.slice(0, n);
}

// ─── Main Orchestrator ────────────────────────────────────────────────────────

async function main() {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.error('Error: GEMINI_API_KEY environment variable is required.');
    console.error('Usage: export GEMINI_API_KEY="your-key" && node evaluate.js');
    process.exit(1);
  }

  const outputDir = './output';
  mkdirSync(outputDir, { recursive: true });

  // ── Select scenarios for this run ─────────────────────────────────────────
  const allScenarioIds = scenarios.map((s) => s.id);
  const completedIds   = loadCompletedScenarioIds(outputDir);
  const batch          = selectNextScenarios(scenarios, completedIds, SCENARIOS_PER_RUN);

  if (batch.length === 0) {
    console.log('No new scenarios to run — all scenarios have been completed this cycle.');
    console.log('Delete output/scenario-queue.json to force a reset.');
    process.exit(0);
  }

  console.log('RAG ACCURACY EVALUATION');
  console.log('='.repeat(60));
  console.log(`Total scenarios: ${scenarios.length} | Running today: ${batch.length} | Model: ${GEMINI_MODEL}`);
  console.log(`Already completed this cycle: ${completedIds.length}/${allScenarioIds.length}`);
  console.log(`RAG endpoint: ${SEARCH_RECIPES_URL}`);
  console.log('='.repeat(60));
  console.log('Scenarios this run:');
  batch.forEach((s, i) => console.log(`  ${i + 1}. ${s.id} — ${s.description}`));

  // Get Firebase ID token once — reused for all searchRecipes calls
  process.stdout.write('\nGetting Firebase ID token (service account auth)... ');
  const identityToken = await getFirebaseIdToken();
  console.log('done');

  const results = [];
  let scenarioIndex = 0;

  for (const scenario of batch) {
    scenarioIndex++;
    console.log(`\n[${scenarioIndex}/${batch.length}] ${scenario.id}`);
    console.log(`  ${scenario.description}`);

    const calorieTarget = calculateCalorieTarget(scenario);
    console.log(`  Calorie target for this meal: ${calorieTarget} kcal`);

    // ── RAG pipeline ──────────────────────────────────────────────────────────
    let ragResult = null;
    let ragError = null;
    try {
      process.stdout.write('  RAG pipeline... ');
      ragResult = await callRagPipeline(scenario, identityToken);
      console.log(`done (${ragResult.recipes.length} recipes, ${ragResult.isExactMatch ? 'exact' : 'relaxed'} match)`);
    } catch (err) {
      ragError = err.message;
      console.log(`FAILED: ${err.message}`);
    }

    await sleep(DELAY_MS);

    // ── No-RAG baseline ───────────────────────────────────────────────────────
    let noRagResult = null;
    let noRagError = null;
    try {
      process.stdout.write('  No-RAG baseline... ');
      noRagResult = await callNoRagBaseline(scenario, apiKey);
      console.log(`done (${noRagResult.recipes.length} recipes parsed)`);
    } catch (err) {
      noRagError = err.message;
      console.log(`FAILED: ${err.message}`);
    }

    await sleep(DELAY_MS);

    // ── Calculate metrics ─────────────────────────────────────────────────────
    const ragMetrics = ragResult
      ? calculateAllMetrics(ragResult, scenario, calorieTarget)
      : null;
    const noRagMetrics = noRagResult
      ? calculateAllMetrics(noRagResult, scenario, calorieTarget)
      : null;

    if (ragMetrics && noRagMetrics) {
      console.log('  Metrics:');
      console.log(`    Hallucination:  RAG=${(ragMetrics.hallucination * 100).toFixed(0)}%  No-RAG=${(noRagMetrics.hallucination * 100).toFixed(0)}%`);
      console.log(`    Cal. Accuracy:  RAG=${(ragMetrics.calorieAccuracy * 100).toFixed(0)}%  No-RAG=${(noRagMetrics.calorieAccuracy * 100).toFixed(0)}%`);
      console.log(`    Restriction:    RAG=${(ragMetrics.restrictionCompliance * 100).toFixed(0)}%  No-RAG=${(noRagMetrics.restrictionCompliance * 100).toFixed(0)}%`);
    }

    results.push({
      scenario: {
        id: scenario.id,
        description: scenario.description,
        profile: scenario.profile,
        ragParams: scenario.ragParams,
      },
      calorieTarget,
      rag: ragResult
        ? { recipes: ragResult.recipes, isExactMatch: ragResult.isExactMatch, geminiResponseText: ragResult.geminiResponseText, metrics: ragMetrics, error: null }
        : { recipes: [], isExactMatch: false, geminiResponseText: '', metrics: null, error: ragError },
      noRag: noRagResult
        ? { recipes: noRagResult.recipes, geminiResponseText: noRagResult.geminiResponseText, metrics: noRagMetrics, error: null }
        : { recipes: [], geminiResponseText: '', metrics: null, error: noRagError },
    });
  }

  // ── Save completed scenario IDs so they aren't run again ─────────────────
  const nowCompleted = [...completedIds, ...batch.map((s) => s.id)];
  saveCompletedScenarioIds(outputDir, nowCompleted, allScenarioIds);

  // ── Write output ─────────────────────────────────────────────────────────────
  const today = new Date().toISOString().split('T')[0];
  const jsonPath = `${outputDir}/results-${today}.json`;
  const reportPath = `${outputDir}/report-${today}.md`;

  writeFileSync(jsonPath, JSON.stringify(results, null, 2));
  console.log(`\nRaw results written to: ${jsonPath}`);

  const historyPath = appendRunToHistory(outputDir, today, results);
  console.log(`Run history updated: ${historyPath}`);

  const reportText = generateReport(results, today);
  writeFileSync(reportPath, reportText);
  console.log(`Report written to: ${reportPath}`);

  // ── Print summary ─────────────────────────────────────────────────────────────
  const validResults = results.filter((r) => r.rag.metrics && r.noRag.metrics);
  if (validResults.length > 0) {
    const metricNames = ['hallucination', 'calorieAccuracy', 'macroAlignment', 'restrictionCompliance', 'preferenceAdherence', 'specificity'];
    console.log('\n' + '='.repeat(60));
    console.log('SUMMARY');
    console.log('='.repeat(60));
    for (const metric of metricNames) {
      const ragAvg = validResults.reduce((s, r) => s + r.rag.metrics[metric], 0) / validResults.length;
      const noRagAvg = validResults.reduce((s, r) => s + r.noRag.metrics[metric], 0) / validResults.length;
      const delta = ragAvg - noRagAvg;
      const label = metric.padEnd(22);
      console.log(`${label} RAG=${(ragAvg * 100).toFixed(1)}%  No-RAG=${(noRagAvg * 100).toFixed(1)}%  Δ=${delta >= 0 ? '+' : ''}${(delta * 100).toFixed(1)}%`);
    }
  }

  console.log('\nEvaluation complete.');
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
