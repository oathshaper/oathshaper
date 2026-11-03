#!/usr/bin/env node
// Review text exported from the rendered Godot menus with the local Obelus.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const obelus = path.resolve(process.argv[2] ?? path.join(root, '../obelus'));
const { reviewDocument, sha256 } = await import(pathToFileURL(path.join(obelus, 'scripts/lib/review.mjs')));
const directory = path.join(root, 'docs/ui-copy-review');
const pack = JSON.parse(fs.readFileSync(path.join(directory, 'menu-rules.json'), 'utf8'));
const fixtures = [
  ['The same garden. A different approach.', 'menu.fourth-wall-slogan'],
  ['Inspect kit', 'menu.ambiguous-preview-action'],
  ['05 · ATB', 'menu.inconsistent-card-category'],
  ['A playable RPG foundation', 'menu.development-filler'],
];
// Prove the rules catch the reported regressions, not just that new text passes.
for (const [text, rule] of fixtures) {
  const report = reviewDocument(text, { format: 'text', pack });
  if (!report.daggermarks.some(finding => finding.rule_id === rule)) {
    throw new Error(`Obelus missed the positive control: ${rule}`);
  }
}
const screens = ['picker', 'confluence-picker', 'command-menu-overview', 'command-menu-equipment', 'vanguard-menu-equipment'];
const reviews = screens.map(screen => {
  const filename = `menu-${screen}.txt`;
  const text = fs.readFileSync(path.join(directory, filename), 'utf8');
  const report = reviewDocument(text, { uri: filename, format: 'text', pack });
  return {
    screen, source: filename, sha256: sha256(text), coverage: report.coverage,
    findings: report.daggermarks,
  };
});
const regressions = reviews.flatMap(review => review.findings.filter(finding => finding.producer === pack.id));
const result = {
  engine: 'Obelus', pack: pack.id, pack_version: pack.version,
  positive_controls: fixtures.length, rejected_copy_matches: regressions.length,
  scope: 'Five rendered menu text exports; embedded combat HUD uses a separate viewport and is not extracted here.',
  limitations: 'Deterministic findings require editorial review; this is not semantic approval or a visual layout verdict.',
  reviews,
};
fs.writeFileSync(path.join(directory, 'menu-obelus-review.json'), JSON.stringify(result, null, 2) + '\n');
console.log(`OBELUS_MENU_COPY: ${reviews.length} rendered screens, ${fixtures.length} positive controls, ${regressions.length} rejected-copy matches`);
for (const review of reviews) {
  console.log(`${review.screen}: ${review.findings.map(finding => finding.rule_id).join(', ') || 'no deterministic findings'}`);
}
if (regressions.length) process.exitCode = 1;
