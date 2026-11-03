# Continuity run

Status: **passed** within **narrative and current Godot fixtures**.

| Check | Result | Known / unexpected diagnostics | Evidence |
|---|---|---|---|
| matrix | passed | 0 / 0 | [Open](matrix.json) |
| dialogue-script | passed | 0 / 0 | [Open](dialogue-script.json) |
| replay | passed | 0 / 0 | [Open](replay.json) |
| host-build | passed | 0 / 0 | [Open](host-build.txt) |
| import | passed | 0 / 0 | [Open](import.txt) |
| chapter-oil-shared | passed | 208 / 0 | [Open](chapter-oil-shared.json) |
| chapter-oil-kept | passed | 208 / 0 | [Open](chapter-oil-kept.json) |
| chapter-oil-undecided | passed | 208 / 0 | [Open](chapter-oil-undecided.json) |
| travel-camera-grip | passed | 162 / 0 | [Open](travel-camera-grip.json) |
| command-controls | passed | 99 / 0 | [Open](command-controls.json) |
| combat-pacing | passed | 68 / 0 | [Open](combat-pacing.json) |
| camera-hold | passed | 93 / 0 | [Open](camera-hold.json) |
| garden-confrontation | passed | 449 / 0 | [Open](garden-confrontation.json) |
| companion-focus | passed | 94 / 0 | [Open](companion-focus.json) |
| voice-playback | passed | 95 / 0 | [Open](voice-playback.json) |

**dialogue-script: 1 findings to review.** A passed scope does not mean the writing was approved.

## Coverage limits

- No LLM, Humanizer or Obelus is required. Authored rules still need human review.
- Menu-state matrix is not reachability proof. Narrative journeys assume host entry access.
- Command fixtures earn combat outcomes but position the player at some approaches; this is not a navigation bot.
- Camera checks are geometric samples. Headless checks do not judge appearance, acting or physical controls.
- No exhaustive scene/branch coverage or labor-saving percentage is claimed.
- Known Godot 4.3 dummy-renderer null-mesh and exit resource diagnostics are counted and retained; these checks do not establish clean resource teardown. Unexpected errors fail the run.
