# Nine-style drill-down

2026-10-22 · `evaluation/combat-systems` · base `a868076`

## Scope and behavior

The user requested a separate detail screen per combat style, a tabbed demo menubar, and an Overview defining its interface and other facets. Follow-up steering keeps detailed play-system UI work in the later profile branches and requires checking the shared engine before those branches start. The user also reported only seven styles visible.

- The picker now exposes **all nine cards together** in a three-column layout at 1280×800, with the total stated above them. The earlier two-column scroll hid choices below the fold. Command, Flow, Vanguard, Tactics, Momentum, Confluence, Cadence, Orders and Oathbound are selectable.
- **Explore style** opens a full-screen inspector. Overview describes timing, party/control, HUD/input, equipment/inventory, roles and progression.
- The tab bar contains Overview, Character, Equipment, Abilities, Party, Inventory, Map, Journal and Saves. The four portraits change the selected actor's existing catalog build; gear, skills, resources, ability sources and costs remain distinct.
- The selected portrait and sample morality/outlook stay beside the pages. Neutral Mercy is explicitly a preview; unknown companion outlook and relationships are not fabricated.
- Mouse, keyboard and controller navigation work. B/Esc returns to the same picker selection and button. Q/E or shoulder buttons change tabs, Y changes member, right stick or Page Up/Down scrolls. Tab/Shift-Tab, including held-key repeats, stay within the inspector.
- **Choose this style** follows the existing new/load/apply route, including the existing in-game New Journey confirmation. Browsing itself creates no journey, save or inventory changes.
- These are menu previews backed by the existing read-only catalog. HUD-specific widgets, transactions and executable combat remain later branch work. The Map page is a location capture, not a live tactical map. Saves describes the current persistence route without dummy save actions.

## Verification

Godot 4.3, macOS Apple M4 Pro, Compatibility renderer:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot --resolution 1280x800 \
  --script res://tests/combat_frontend_test.gd
```

Final behavioral run: `COMBAT_FRONTEND_OK: 10782 checks`, exit 0, log `/tmp/oathshaper-style-test-reviewed.log`. Coverage includes all nine visible cards and their text bounds, all nine inspector pages per style, distinct equipment/abilities across all four actors, tab/member navigation, scrolling, keyboard modal focus, preview non-mutation, inspector acceptance and existing journey/save/input regressions. Many checks are individual bounds assertions, not independent gameplay scenarios.

The first inspector import caught one inferred Variant type; an explicit String fixed it. The first visual review caught Momentum's caption wrapping outside its card; shortening the card copy and adding containment assertions fixed it. Independent non-editing review by `flow_design` found a held-Tab event could escape into underlying picker controls; consuming repeated key events and testing both focus boundaries fixed that finding. Narrow re-review found no remaining issue. A final cosmetic change makes the Choose button's text dark across focus/hover/pressed states; reviewed and rendered afterward without repeating the behavioral suite.

Capture command: `Godot --path godot --script res://tools/capture_frontend.gd`. Seven captures are generated with actual dimensions in their filenames. The host constrains requested 1920×1080 windows to 1728×1080. The headed suite logs one macOS texture-driver diagnostic; captured artwork renders. No physical Deck or exported-package validation is claimed.

- [All nine styles](../images/launcher-profiles-1280x800.png)
- [Command overview](../images/launcher-command-overview-1280x800.png)
- [Mara's Vanguard equipment](../images/launcher-vanguard-equipment-1280x800.png)
- [Ivo's Flow abilities](../images/launcher-flow-abilities-1280x800.png)

## Shared-engine gate

The separate [LCD audit](../combat-design/lcd-implementation-audit.md) evaluates the unmerged `ee7b134` foundation. Its required repairs and contrasting-adapter tests precede profile implementation goals. This UI milestone does not pass that gate or resume the paused combat implementation goal. workflow automation remains disabled under the user's instruction.
