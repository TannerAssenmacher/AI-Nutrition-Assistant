/**
 * Generates a combined RAG evaluation report across all run files.
 *
 * Usage:
 *   node generate-combined-report.js
 *
 * Reads all results-*.json files in the output/ directory, merges them,
 * and writes output/report-combined.md.
 */

import { readFileSync, writeFileSync, readdirSync } from 'fs';
import { generateReport } from './report.js';

const OUTPUT_DIR = new URL('./output', import.meta.url).pathname;

// ─── Load & merge all results files ──────────────────────────────────────────

const resultFiles = readdirSync(OUTPUT_DIR)
  .filter((f) => f.startsWith('results-') && f.endsWith('.json'))
  .sort();

if (resultFiles.length === 0) {
  console.error('No results-*.json files found in output/');
  process.exit(1);
}

console.log(`Loading ${resultFiles.length} result file(s):`);
const allResults = [];
for (const file of resultFiles) {
  const data = JSON.parse(readFileSync(`${OUTPUT_DIR}/${file}`, 'utf8'));
  console.log(`  ${file}: ${data.length} scenarios`);
  allResults.push(...data);
}
console.log(`Total scenarios: ${allResults.length}\n`);

// ─── Generate base report ─────────────────────────────────────────────────────

const baseReport = generateReport(allResults, 'All Runs Combined');

// ─── Additional aggregate statistics ─────────────────────────────────────────

const METRIC_ORDER = [
  'hallucination',
  'calorieAccuracy',
  'macroAlignment',
  'restrictionCompliance',
  'preferenceAdherence',
  'specificity',
];
const METRIC_LABELS = {
  hallucination: 'Hallucination Rate',
  calorieAccuracy: 'Calorie Accuracy',
  macroAlignment: 'Macro Alignment',
  restrictionCompliance: 'Restriction Compliance',
  preferenceAdherence: 'Preference Adherence',
  specificity: 'Response Specificity',
};

function pct(v) {
  return v == null ? 'N/A' : `${(v * 100).toFixed(1)}%`;
}

function avg(arr) {
  return arr.reduce((s, x) => s + x, 0) / arr.length;
}

// Per-scenario win/loss/tie for each metric
const winCounts = Object.fromEntries(METRIC_ORDER.map((m) => [m, { rag: 0, noRag: 0, tie: 0 }]));
for (const r of allResults) {
  if (!r.rag.metrics || !r.noRag.metrics) continue;
  for (const m of METRIC_ORDER) {
    const ragVal = r.rag.metrics[m];
    const noRagVal = r.noRag.metrics[m];
    if (Math.abs(ragVal - noRagVal) < 0.001) winCounts[m].tie++;
    else if (ragVal > noRagVal) winCounts[m].rag++;
    else winCounts[m].noRag++;
  }
}

// Per-profile averages
const profileIds = [...new Set(allResults.map((r) => r.scenario.profile.id))];
const profileSummaryRows = profileIds.map((pid) => {
  const pResults = allResults.filter((r) => r.scenario.profile.id === pid && r.rag.metrics && r.noRag.metrics);
  const label = pResults[0]?.scenario.profile.label ?? pid;
  const ragCal = avg(pResults.map((r) => r.rag.metrics.calorieAccuracy));
  const noRagCal = avg(pResults.map((r) => r.noRag.metrics.calorieAccuracy));
  const ragMacro = avg(pResults.map((r) => r.rag.metrics.macroAlignment));
  const noRagMacro = avg(pResults.map((r) => r.noRag.metrics.macroAlignment));
  const ragRestrict = avg(pResults.map((r) => r.rag.metrics.restrictionCompliance));
  const noRagRestrict = avg(pResults.map((r) => r.noRag.metrics.restrictionCompliance));
  const d = (ragCal - noRagCal) * 100;
  return [
    label,
    pResults.length,
    pct(ragCal),
    pct(noRagCal),
    `${d >= 0 ? '+' : ''}${d.toFixed(1)}%`,
    pct(ragMacro),
    pct(noRagMacro),
    pct(ragRestrict),
    pct(noRagRestrict),
  ];
});

// Win/loss table
const validCount = allResults.filter((r) => r.rag.metrics && r.noRag.metrics).length;
const winTableRows = METRIC_ORDER.map((m) => {
  const w = winCounts[m];
  const ragWinPct = ((w.rag / validCount) * 100).toFixed(0);
  const noRagWinPct = ((w.noRag / validCount) * 100).toFixed(0);
  return [METRIC_LABELS[m], `${w.rag} (${ragWinPct}%)`, `${w.noRag} (${noRagWinPct}%)`, w.tie];
});

// Weighted overall score: calorie 30%, macro 25%, restriction 25%, preference 10%, specificity 10%
const WEIGHTS = { calorieAccuracy: 0.30, macroAlignment: 0.25, restrictionCompliance: 0.25, preferenceAdherence: 0.10, specificity: 0.10 };
const ragScores = allResults.filter((r) => r.rag.metrics).map((r) =>
  Object.entries(WEIGHTS).reduce((s, [m, w]) => s + (r.rag.metrics[m] ?? 0) * w, 0)
);
const noRagScores = allResults.filter((r) => r.noRag.metrics).map((r) =>
  Object.entries(WEIGHTS).reduce((s, [m, w]) => s + (r.noRag.metrics[m] ?? 0) * w, 0)
);
const ragOverall = avg(ragScores);
const noRagOverall = avg(noRagScores);
const overallDeltaNum = (ragOverall - noRagOverall) * 100;
const overallDelta = `${overallDeltaNum >= 0 ? '+' : ''}${overallDeltaNum.toFixed(1)}`;
const relImpNum = ((ragOverall - noRagOverall) / noRagOverall) * 100;
const relativeImprovement = `${relImpNum >= 0 ? '+' : ''}${relImpNum.toFixed(1)}`;

function mdTable(headers, rows) {
  const colWidths = headers.map((h, i) =>
    Math.max(h.length, ...rows.map((r) => String(r[i] ?? '').length))
  );
  const headerRow = '| ' + headers.map((h, i) => h.padEnd(colWidths[i])).join(' | ') + ' |';
  const sep = '|' + colWidths.map((w) => '-'.repeat(w + 2)).join('|') + '|';
  const dataRows = rows.map(
    (r) => '| ' + r.map((c, i) => String(c ?? '').padEnd(colWidths[i])).join(' | ') + ' |'
  );
  return [headerRow, sep, ...dataRows].join('\n');
}

// ─── Assemble aggregate section ───────────────────────────────────────────────

const aggregateSection = `---

## Aggregate Analysis (${allResults.length} Scenarios, ${resultFiles.length} Runs)

### Overall Weighted Score

Weights: Calorie Accuracy 30% · Macro Alignment 25% · Restriction Compliance 25% · Preference Adherence 10% · Specificity 10%
*(Hallucination excluded from weighted score as RAG always = 1.0 and No-RAG always = 0.0 by construction)*

| Pipeline | Weighted Score | vs. Baseline |
|----------|---------------|--------------|
| RAG      | ${pct(ragOverall)} | ${overallDelta}pp (${relativeImprovement}% relative) |
| No-RAG   | ${pct(noRagOverall)} | — |

### Scenario Win/Loss Count

How many of the ${validCount} scenarios each pipeline won (higher = better) per metric:

${mdTable(
  ['Metric', 'RAG Wins', 'No-RAG Wins', 'Ties'],
  winTableRows
)}

### Per-Profile Calorie Accuracy, Macro Alignment & Restriction Compliance

${mdTable(
  ['Profile', 'N', 'Cal (RAG)', 'Cal (No-RAG)', 'Cal Δ', 'Macro (RAG)', 'Macro (No-RAG)', 'Restrict (RAG)', 'Restrict (No-RAG)'],
  profileSummaryRows
)}
`;

// ─── Write combined report ────────────────────────────────────────────────────

// Insert aggregate section before the per-profile section in the base report
const insertBefore = '## Per-Profile Results';
const combinedReport = baseReport.includes(insertBefore)
  ? baseReport.replace(insertBefore, `${aggregateSection}\n${insertBefore}`)
  : baseReport + '\n' + aggregateSection;

const outPath = `${OUTPUT_DIR}/report-combined.md`;
writeFileSync(outPath, combinedReport);
console.log(`Combined report written to: output/report-combined.md`);
console.log(`\nOverall: RAG ${pct(ragOverall)} vs No-RAG ${pct(noRagOverall)} (${overallDelta}pp, ${relativeImprovement}% relative)`);
