# Manual camera hold — 27 October 2026

The playtest reported that the camera continued to fight manual adjustment. Command preserved `_yaw`, but its target midpoint, follow easing and obstruction search still changed the complete pose. The new regression reproduced this in stationary Command scenes.

The camera now records the controlled actor's position when it frames a manual view. With no new camera input and no actor travel beyond 1 mm, the full pose stays unchanged. The small threshold ignores floating-point noise; animation bones and actor rotation do not release the hold. Actual actor travel permits follow and obstruction correction. Orbit, zoom, explicit recenter, party switching and a restored scene remain operable. Flow uses the same hold rule. Exploration already preserved manual heading and passed its existing input/follow checks.

## Verification

| Check | Result | Evidence |
|---|---|---|
| Camera hold, movement, repeated drag, zoom, recenter and party switch | 20 checks passed | [Log](camera-hold.txt) |
| Travel, automatic camera clearance, manual exploration heading, paused rigs and grip | 309 checks passed | [Log](playtest-continuity.txt) |
| Command target cycling, possession and UI behavior | 28 checks passed | [Log](command-targeting.txt) |
| Combat pacing | 101 checks passed | [Log](combat-pacing.txt) |
| Flow trial | 294 checks passed | [Log](flow-trial.txt) |
| Exploration input, camera, collision and bridge | Passed | [Log](exploration.txt) |

The previous manual-orbit clearance assertion required automatic camera intervention while the user was choosing a view. Its replacement checks clearance after explicit recenter and allows the bounded search to examine candidates over several frames. The new hold test separately checks that manual views stay fixed, including when an adversary moves.

These are native Godot 4.3 headless behavior checks against the actual rigs and garden. Known dummy-renderer/exit diagnostics are retained; no unexpected engine errors passed review. Physical controller feel and every possible foliage angle are not covered. No Rust code, assets or project settings changed in this fix. The already-running play session was left open; it loads the new scripts on its next launch.
