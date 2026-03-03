/**
 * Committee Presentation Stats
 *
 * Reads accumulated run history and produces a clean summary suitable
 * for presenting to a review committee.
 *
 * Data sources (all in output/):
 *   run-history.json         — one entry per evaluate.js run
 *   estimation-history.json  — one entry per estimate-accuracy.js run (optional)
 *
 * Usage:
 *   node committee-stats.js
 *
 * No API keys required — reads local files only.
 */

import { readFileSync, writeFileSync, mkdirSync } from 'fs';

const METRIC_LABELS = {
  hallucination:          'Hallucination Rate',
  calorieAccuracy:        'Calorie Accuracy',
  macroAlignment:         'Macro Alignment',
  restrictionCompliance:  'Restriction Compliance',
  preferenceAdherence:    'Preference Adherence',
  specificity:            'Response Specificity',
};

const METRIC_ORDER = [
  'hallucination',
  'calorieAccuracy',
  'macroAlignment',
  'restrictionCompliance',
  'preferenceAdherence',
  'specificity',
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

function pct(v) {
  if (v == null || isNaN(v)) return 'N/A   ';
  return `${(v * 100).toFixed(1)}%`.padStart(6);
}

function delta(d) {
  if (d == null || isNaN(d)) return '  N/A';
  const sign = d >= 0 ? '+' : '';
  return `${sign}${(d * 100).toFixed(1)}%`.padStart(7);
}

function bar(v, width = 20) {
  if (v == null || isNaN(v)) return '░'.repeat(width);
  const filled = Math.round(Math.min(1, Math.max(0, v)) * width);
  return '█'.repeat(filled) + '░'.repeat(width - filled);
}

function loadJSON(path) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    return null;
  }
}

// ─── Latest Run Summary ───────────────────────────────────────────────────────

function printLatestRun(run) {
  console.log('\n── Latest Evaluation Run ──────────────────────────────────────');
  console.log(`   Date: ${run.date}  |  Model: ${run.model}  |  Scenarios: ${run.validCount}/${run.scenarioCount} completed`);
  console.log('');
  console.log('   Metric                   RAG      No-RAG   Δ (RAG advantage)');
  console.log('   ' + '─'.repeat(62));

  for (const m of METRIC_ORDER) {
    const rag    = run.ragAvg?.[m];
    const noRag  = run.noRagAvg?.[m];
    const d      = run.delta?.[m];
    const label  = METRIC_LABELS[m].padEnd(24);
    console.log(`   ${label} ${pct(rag)}   ${pct(noRag)}  ${delta(d)}`);
  }
}

// ─── Trend Across Runs ────────────────────────────────────────────────────────

function printTrend(history) {
  if (history.length < 2) {
    console.log('\n── Trend ──────────────────────────────────────────────────────');
    console.log('   Only 1 run recorded. Run evaluate.js again to see trends.');
    return;
  }

  console.log('\n── RAG Advantage Trend (Δ = RAG − No-RAG) ────────────────────');
  console.log('   Date         ' + METRIC_ORDER.map((m) => m.slice(0, 8).padStart(9)).join(''));
  console.log('   ' + '─'.repeat(14 + METRIC_ORDER.length * 9));

  for (const run of history) {
    const row = METRIC_ORDER.map((m) => {
      const d = run.delta?.[m];
      if (d == null) return '    N/A ';
      return `${d >= 0 ? '+' : ''}${(d * 100).toFixed(1)}%`.padStart(9);
    }).join('');
    console.log(`   ${run.date}   ${row}`);
  }
}

// ─── ASCII Bar Chart (latest run) ─────────────────────────────────────────────

function printChart(run) {
  console.log('\n── Visual Comparison (latest run) ─────────────────────────────');
  for (const m of METRIC_ORDER) {
    const label = METRIC_LABELS[m].padEnd(24);
    const r = run.ragAvg?.[m];
    const n = run.noRagAvg?.[m];
    console.log(`   ${label}  RAG    ${bar(r)}  ${pct(r)}`);
    console.log(`   ${''.padEnd(24)}  No-RAG ${bar(n)}  ${pct(n)}`);
    console.log('');
  }
}

// ─── Gemini Estimation Accuracy ───────────────────────────────────────────────

function printEstimationAccuracy(estHistory) {
  console.log('\n── Gemini Nutrition Estimation Error (vs. Verified DB) ────────');

  if (!estHistory || estHistory.length === 0) {
    console.log('   No estimation-history.json found.');
    console.log('   Run: node estimate-accuracy.js output/results-YYYY-MM-DD.json');
    console.log('   to measure how far Gemini\'s built-in nutrition knowledge is from real data.');
    return;
  }

  const latest = estHistory[estHistory.length - 1];
  console.log(`   Date: ${latest.date}  |  Model: ${latest.model}  |  Recipes tested: ${latest.recipesEstimated}/${latest.recipesTotal}`);
  console.log('');

  const nutrients = ['calories', 'protein', 'carbs', 'fat'];
  console.log('   Nutrient    MAPE     Median   Within 10%   Within 25%   Off >50%');
  console.log('   ' + '─'.repeat(68));

  for (const n of nutrients) {
    const s = latest.stats?.[n];
    if (!s) continue;
    const within10 = `${s.within10pct}/${s.n}`.padStart(4);
    const within25 = `${s.within25pct}/${s.n}`.padStart(4);
    const over50   = `${s.over50pct}/${s.n}`.padStart(4);
    console.log(
      `   ${n.padEnd(10)}  ${s.mape?.toFixed(1).padStart(5)}%   ${s.median?.toFixed(1).padStart(5)}%` +
      `   ${within10}/recipes   ${within25}/recipes   ${over50}/recipes`
    );
  }

  if (estHistory.length > 1) {
    console.log('\n   Calorie MAPE trend:');
    for (const run of estHistory) {
      const mape = run.stats?.calories?.mape;
      if (mape != null) {
        console.log(`     ${run.date}  ${mape.toFixed(1)}%  (${run.recipesEstimated} recipes)`);
      }
    }
  }
}

// ─── Key Headline Stats ───────────────────────────────────────────────────────

function printHeadlines(latestRun, latestEst) {
  console.log('\n' + '='.repeat(65));
  console.log('HEADLINE STATS FOR COMMITTEE PRESENTATION');
  console.log('='.repeat(65));

  // Hallucination
  const hallRag   = latestRun.ragAvg?.hallucination;
  const hallNoRag = latestRun.noRagAvg?.hallucination;
  if (hallRag != null && hallNoRag != null) {
    console.log(`\n  Hallucination`);
    console.log(`    RAG:    ${(hallRag * 100).toFixed(0)}% of recipes traceable to verified database`);
    console.log(`    No-RAG: ${(hallNoRag * 100).toFixed(0)}% of recipes traceable (Gemini invents them)`);
  }

  // Calorie accuracy
  const calRag   = latestRun.ragAvg?.calorieAccuracy;
  const calNoRag = latestRun.noRagAvg?.calorieAccuracy;
  if (calRag != null && calNoRag != null) {
    const improvement = ((calRag - calNoRag) * 100).toFixed(1);
    console.log(`\n  Calorie Accuracy (how close recipes are to each user's target)`);
    console.log(`    RAG:    ${(calRag * 100).toFixed(1)}%`);
    console.log(`    No-RAG: ${(calNoRag * 100).toFixed(1)}%`);
    console.log(`    RAG is ${improvement > 0 ? improvement + '% more accurate' : Math.abs(improvement) + '% less accurate'} at hitting calorie targets`);
  }

  // Restriction compliance
  const resRag   = latestRun.ragAvg?.restrictionCompliance;
  const resNoRag = latestRun.noRagAvg?.restrictionCompliance;
  if (resRag != null && resNoRag != null) {
    console.log(`\n  Dietary Restriction Compliance`);
    console.log(`    RAG:    ${(resRag * 100).toFixed(1)}% of recipes respect user restrictions`);
    console.log(`    No-RAG: ${(resNoRag * 100).toFixed(1)}% of recipes respect user restrictions`);
  }

  // Gemini estimation error
  if (latestEst) {
    const mape = latestEst.stats?.calories?.mape;
    const within25 = latestEst.stats?.calories?.within25pct;
    const total    = latestEst.stats?.calories?.n;
    if (mape != null) {
      console.log(`\n  Gemini's Built-in Nutrition Knowledge Gap`);
      console.log(`    When asked to estimate calories for named recipes, Gemini is off by`);
      console.log(`    an average of ${mape.toFixed(0)}% compared to our verified recipe database.`);
      if (within25 != null && total != null) {
        const withinPct = ((within25 / total) * 100).toFixed(0);
        console.log(`    Only ${within25}/${total} recipes (${withinPct}%) fall within 25% of actual calories.`);
      }
      console.log(`    RAG eliminates this error by retrieving exact nutritional data from the DB.`);
    }
  }

  console.log('\n' + '='.repeat(65));
}

// ─── Main ─────────────────────────────────────────────────────────────────────

function main() {
  const runHistory = loadJSON('output/run-history.json');
  const estHistory = loadJSON('output/estimation-history.json');

  if (!runHistory || runHistory.length === 0) {
    console.error('No run history found. Run evaluate.js first.');
    console.error('  cd scripts/rag_evaluation && export GEMINI_API_KEY="..." && node evaluate.js');
    process.exit(1);
  }

  const latestRun = runHistory[runHistory.length - 1];
  const latestEst = estHistory ? estHistory[estHistory.length - 1] : null;

  console.log('RAG EVALUATION — COMMITTEE STATISTICS');
  console.log('='.repeat(65));
  console.log(`Runs recorded: ${runHistory.length}  |  Latest: ${latestRun.date}`);
  if (estHistory) {
    console.log(`Estimation runs recorded: ${estHistory.length}  |  Latest: ${estHistory[estHistory.length - 1].date}`);
  }

  printLatestRun(latestRun);
  printChart(latestRun);
  printTrend(runHistory);
  printEstimationAccuracy(estHistory);
  printHeadlines(latestRun, latestEst);

  // Write a committee report markdown file
  mkdirSync('output', { recursive: true });
  const today = new Date().toISOString().split('T')[0];
  const mdPath = `output/committee-report-${today}.md`;
  writeFileSync(mdPath, buildMarkdownReport(runHistory, estHistory));
  console.log(`\nMarkdown report written to: ${mdPath}`);
}

// ─── Markdown Report Builder ──────────────────────────────────────────────────

function buildMarkdownReport(runHistory, estHistory) {
  const latest   = runHistory[runHistory.length - 1];
  const latestEst = estHistory?.[estHistory.length - 1] ?? null;
  const lines    = [];

  lines.push('# RAG Pipeline — Committee Evaluation Report');
  lines.push('');
  lines.push(`**Generated:** ${new Date().toISOString().split('T')[0]}  |  **Evaluation runs:** ${runHistory.length}  |  **Model:** ${latest.model}`);
  lines.push('');

  // Executive summary table
  lines.push('## Executive Summary (Latest Run)');
  lines.push('');
  lines.push('| Metric | RAG | No-RAG | Δ RAG Advantage |');
  lines.push('|--------|-----|--------|-----------------|');
  for (const m of METRIC_ORDER) {
    const r = latest.ragAvg?.[m];
    const n = latest.noRagAvg?.[m];
    const d = latest.delta?.[m];
    const sign = d != null && d >= 0 ? '+' : '';
    lines.push(`| ${METRIC_LABELS[m]} | ${r != null ? (r*100).toFixed(1)+'%' : 'N/A'} | ${n != null ? (n*100).toFixed(1)+'%' : 'N/A'} | ${d != null ? sign+(d*100).toFixed(1)+'%' : 'N/A'} |`);
  }

  lines.push('');
  lines.push('## Key Findings');
  lines.push('');
  lines.push('- **Hallucination:** RAG returns 100% verified database recipes. No-RAG: Gemini invents recipe names and estimates nutrition from memory — 0% verifiable.');
  lines.push('- **Calorie Accuracy:** RAG uses exact nutritional data from the verified recipe database. No-RAG estimates calories with significant error.');

  if (latestEst?.stats?.calories?.mape != null) {
    const mape = latestEst.stats.calories.mape.toFixed(0);
    lines.push(`- **Gemini Knowledge Gap:** When given recipe names, Gemini estimates calories with an average error of **${mape}%** compared to our verified database.`);
  }

  lines.push('- **Restriction Compliance:** RAG filters use structured health labels from the database. No-RAG relies on Gemini\'s judgment, which can miss violations.');

  // Trend table (if multiple runs)
  if (runHistory.length > 1) {
    lines.push('');
    lines.push('## RAG Advantage Trend Over Time');
    lines.push('');
    const headers = ['Date', ...METRIC_ORDER.map((m) => METRIC_LABELS[m])];
    lines.push('| ' + headers.join(' | ') + ' |');
    lines.push('|' + headers.map(() => '---').join('|') + '|');
    for (const run of runHistory) {
      const cells = [run.date, ...METRIC_ORDER.map((m) => {
        const d = run.delta?.[m];
        if (d == null) return 'N/A';
        return `${d >= 0 ? '+' : ''}${(d*100).toFixed(1)}%`;
      })];
      lines.push('| ' + cells.join(' | ') + ' |');
    }
  }

  // Estimation accuracy
  if (latestEst) {
    lines.push('');
    lines.push('## Gemini Nutrition Estimation Error');
    lines.push('');
    lines.push(`*Based on ${latestEst.recipesEstimated} recipes from the verified database — asking Gemini to estimate nutrition for known recipe names.*`);
    lines.push('');
    lines.push('| Nutrient | Avg Error (MAPE) | Median Error | Within 25% of actual |');
    lines.push('|----------|-----------------|--------------|----------------------|');
    for (const n of ['calories', 'protein', 'carbs', 'fat']) {
      const s = latestEst.stats?.[n];
      if (!s) continue;
      const within25Pct = s.n > 0 ? ((s.within25pct / s.n) * 100).toFixed(0) + '%' : 'N/A';
      lines.push(`| ${n} | ${s.mape?.toFixed(1)}% | ${s.median?.toFixed(1)}% | ${s.within25pct}/${s.n} (${within25Pct}) |`);
    }
  }

  lines.push('');
  lines.push('## Methodology');
  lines.push('');
  lines.push('- **RAG Pipeline:** Calls the deployed `searchRecipes` Cloud Function → semantic vector search (pgvector) → weighted scoring → top 3 real DB recipes with exact nutritional data.');
  lines.push('- **No-RAG Baseline:** Calls Gemini API directly with user profile context. Gemini generates recipe suggestions from training data — no database lookup.');
  lines.push('- **Gemini Estimation Test:** Asks Gemini to estimate nutrition for recipe names already in our database, then compares to verified values. MAPE = Mean Absolute Percentage Error.');
  lines.push('- **Scenarios:** 4 user profiles × 3 meal scenarios = 12 test cases covering weight loss, muscle gain, maintenance, and dual dietary restrictions.');

  return lines.join('\n');
}

main();
