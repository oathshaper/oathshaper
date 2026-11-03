#!/usr/bin/env node
// Audit actual Godot control text using the adjacent Obelus installation.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const obelus = path.resolve(process.argv[2] ?? path.join(root, '../obelus'));
const { reviewDocument, sha256 } = await import(pathToFileURL(path.join(obelus, 'scripts/lib/review.mjs')));
const directory = path.join(root, 'docs/ui-copy-review/command-screens');
const pack = JSON.parse(fs.readFileSync(path.join(root, 'docs/ui-copy-review/menu-rules.json'), 'utf8'));
pack.rules.push({
  id: 'command.implementation-copy', reason: 'Player menus should name items and actions without internal identifiers.',
  direction: 'Use the item name, equipped character, or concrete action.',
  patterns: ['\\bInstance:', '\\bBound to:', '\\blearned:[a-z_]+:', '\\bPlans for\\b', '\\bNo [^.\\n]* exposed\\b'],
});
const controls = [
  ['The same garden. A different approach.', 'menu.fourth-wall-slogan'],
  ['Inspect kit', 'menu.ambiguous-preview-action'],
  ['05 · ATB', 'menu.inconsistent-card-category'],
  ['Instance: dressing-1', 'command.implementation-copy'],
];
for (const [copy, rule] of controls) {
  if (!reviewDocument(copy, { format: 'text', pack }).daggermarks.some(x => x.rule_id === rule)) {
    throw new Error(`Obelus missed positive control: ${rule}`);
  }
}
const reviews = fs.readdirSync(directory).filter(x => x.endsWith('.txt')).sort().map(file => {
  const copy = fs.readFileSync(path.join(directory, file), 'utf8');
  const result = reviewDocument(copy, { uri: file, format: 'text', pack });
  return { source: file, sha256: sha256(copy), coverage: result.coverage, findings: result.daggermarks };
});
const regressions = reviews.flatMap(x => x.findings.filter(y => y.producer === pack.id));
fs.writeFileSync(path.join(directory, 'obelus-review.json'), JSON.stringify({
  engine: 'Obelus', sources: 'Rendered Godot HUD, equipment, party and inventory control text at 1280x800.',
  positive_controls: controls.length, rejected_copy_matches: regressions.length, reviews,
  limitations: 'Deterministic copy checks do not establish interaction or visual correctness. Repeated tabs, action names and resource labels are intentional.',
}, null, 2) + '\n');
console.log(`OBELUS_COMMAND_COPY: ${reviews.length} screens, ${controls.length} positive controls, ${regressions.length} rejected-copy matches`);
for (const result of reviews) console.log(`${result.source}: ${result.findings.map(x => x.rule_id).join(', ') || 'no deterministic findings'}`);
if (regressions.length) process.exitCode = 1;
