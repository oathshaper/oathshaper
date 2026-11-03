# Chooser and menu preview correction — 2026-10-22

The reported screen showed an older running game with “Inspect kit,” numbered ATB suffixes, and the rejected garden slogan. The current source already contained a tabbed inspector, but still recolored the chooser on selection and used ATB in a card caption. Source changes alone had not updated the visible application.

## Changes

- **Preview menus** is the highlighted action. Confirming a style card focuses it. It opens Overview, Character, Equipment, Abilities, Party, Inventory, Map, Journal and Saves.
- The chooser and menu preview retain the same brass palette across all nine styles. Combat resource colors are unaffected.
- Cards use plain numbers. Styles 04–09 retain Coming soon pills. All nine cards and their captions fit at 1280×800.
- Removed ATB/category terminology from chooser copy, development positioning, and redundant preview encouragement. Preserved mechanical explanations in research and detailed catalog data.
- The full combat image, including its bottom action bar, fits on the first Overview screen for Command, Flow and Vanguard.

## Obelus and humanizer

Both tools were run. Humanizer routed the bounded source inventory to its nonfiction critic; essay-specific suggestions were rejected because these are interface labels. The review covered four causes: development framing, redundant encouragement, ambiguous preview labels, and inconsistent card categories. “Choose how you fight” remains as the requested mockup's section heading, which identifies the selection task.

Obelus's generic publication pack did **not** identify the rejected slogans. The added [menu rule pack](menu-rules.json) encodes those explicit requirements. Four positive controls prove that it catches the reported text; they are not included in the game.

The [Obelus report](menu-obelus-review.json) covers text exported from five rendered screens, with source hashes and exact finding locations. It reports zero matches against the rejected-copy rules. Remaining heuristic findings were reviewed:

| Finding | Evidence | Disposition |
| --- | --- | --- |
| Qualification/transition words | “then,” “Back,” “Read,” “can” | Keep: sequencing, a navigation label, an action instruction and an available control. |
| Repeated syntax | “Corsair,” “Mara,” “Ivo” | Keep: party member names in a consistent selector. |
| Imperative density | “COMBAT STYLES,” “Choose how you fight,” “Command,” tab names | Keep: headings, controls and a style name. These are not consecutive prose instructions. |

The humanizer semantic pass used the cached local embedding model before and after revision. Its remaining medium/low heuristic groups concern those same short interface patterns and concrete three-part mechanics. No authorship classifier was used. Obelus's semantic and factual verification fields remain `not-run`; the deterministic report is not an automated editorial approval.

Reproduce the rendered export and Obelus review:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot --resolution 1280x800 --script tests/combat_frontend_test.gd -- review_capture
node scripts/review-menu-copy.mjs ../obelus
```

## Verification

The native Godot run passed **10,731 checks**, including controller navigation, every preview tab, actor-specific equipment/abilities, uniform numbers and colors, removed copy, modal focus, and save/journey behavior. The separate playable-profile test passed all **16 checks** for Command, Flow and Vanguard entry and return. An initial run caught a two-line caption overflowing its card; the corrected run passed. The renderer emitted its existing texture-binding diagnostic; no Godot script/error assertion remained.

Rendered captures inspected directly:

- [Chooser](../images/combat-picker-1280x800.png)
- [Confluence selection, same palette](../images/combat-confluence-picker-1280x800.png)
- [Command Overview](../images/combat-command-menu-overview-1280x800.png)
- [Command equipment](../images/combat-command-menu-equipment-1280x800.png)
- [Vanguard equipment](../images/combat-vanguard-menu-equipment-1280x800.png)

The text export excludes the embedded combat viewport, which has its own coordinate system. Screenshots verify that view's fit; the export does not claim a new review of every combat HUD sentence. Physical Steam Deck testing remains separate.
