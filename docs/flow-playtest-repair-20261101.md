# Flow playtest repair — 1 November 2026

## Report and cause

The native playtest exposed three identical Lantern Sentinels, missing Ivo, an opening that overwhelmed Tessa and Mara, and overlapping style buttons.

Flow still used a separate prototype cast. Its enemies lacked model identifiers, so all three fell back to the Lantern Sentinel mesh. Ivo was only staged for the confrontation cinematic. The prototype's runner specifically hunted Mara, whose support behavior restored Chi but never healed Health. Button text and theme margins exceeded the space allotted to the four-button style selector.

## Changes

- Use the story's cast throughout the cinematic and fight: Tessa, Mara and Ivo against the Crimson Corsair, Iron Sentinel and Lantern Sentinel. Each enemy specifies its actual model.
- Begin with the party separated from the enemies. After the cinematic, wait for **Begin**. Allow style selection before starting and provide a visible **Pause / Resume** button during combat.
- Give the opening three seconds before AI begins. Reduce hostile movement to 1.8 m/s, increase attack windups to 0.9–1.2 seconds, and leave a recovery beat between attacks. Increase enemy Health to allow time to use different styles.
- Have Ivo engage nearby enemies and draw more of their attention. Mara in Support mode retreats from nearby enemies and heals the most injured eligible ally within eight metres and line of sight. Healing spends six of her own Chi for twenty Health, at most once every three seconds; she can run out.
- Separate the four style buttons. Keep the keyboard number visible for the selected style; switch to D-pad hints when a controller is active.
- Show attack cost, range and readiness using the same admission rules that accept or reject attacks. Show mouse bindings in keyboard mode and controller bindings in controller mode.

## Save compatibility

The changed roster uses Flow profile version 2 and `flow.save/v2`. Local chapter saves now use `oathshaper_flow_trial_v2.json`. The old `oathshaper_flow_trial.json` remains untouched and is not migrated or loaded into the new roster. The campaign save format is unchanged.

## Verification

- Full `oathshaper-core` suite: 141 tests passed, including the documentation test and 16 Flow tests.
- Added tests against the actual encounter for the opening grace period, party survival while the player is idle, Mara spending her own Chi on support, and a complete victory route. The automated victory took 13.2 simulated seconds; that is not a human playtest duration or a balance verdict.
- Native Godot Flow route: 500 checks passed, covering resource costs, menu/save restoration, geometry, combat and victory.
- Native presentation: 90 checks passed, including cinematic-to-combat continuity, actual enemy models, Ivo remaining visible, style selection while waiting to begin, nonoverlapping button rectangles, keyboard hints and pause ownership. Inspected rendered captures of the 1280 × 800 canvas in 1280 × 800 and 1280 × 720 windows.
- Input latch regression: 7 checks passed. Command/Flow manual camera-hold regression: 20 checks passed.
- Clippy passed for all core targets with warnings denied; formatting and scoped diff checks passed.
- Godot still reports resources retained at test shutdown; headless mesh tests also emit dummy-renderer null-mesh warnings. These checks do not establish physical Steam Deck behavior.

The reported Vanguard cinematic, menu, cover and pacing problems remain open. This repair changes Flow; another human playtest is needed to judge its feel.
