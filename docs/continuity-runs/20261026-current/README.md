# Continuity run

Status: **passed** within **narrative and current Godot fixtures**.

| Check | Result | Known / unexpected diagnostics | Evidence |
|---|---|---|---|
| matrix | passed | 0 / 0 | [Open](matrix.json) |
| replay | passed | 0 / 0 | [Open](replay.json) |
| host-build | passed | 0 / 0 | [Open](host-build.txt) |
| import | passed | 0 / 0 | [Open](import.txt) |
| chapter-oil-shared | passed | 206 / 0 | [Open](chapter-oil-shared.json) |
| chapter-oil-kept | passed | 205 / 0 | [Open](chapter-oil-kept.json) |
| chapter-oil-undecided | passed | 205 / 0 | [Open](chapter-oil-undecided.json) |
| travel-camera-grip | passed | 162 / 0 | [Open](travel-camera-grip.json) |
| voice-playback | passed | 95 / 0 | [Open](voice-playback.json) |

## Coverage limits

- No LLM, Humanizer or Obelus is required. Authored rules still need human review.
- Menu-state matrix is not reachability proof. Narrative journeys assume host entry access.
- Command fixtures earn combat outcomes but position the player at some approaches; this is not a navigation bot.
- Camera checks are geometric samples. Headless checks do not judge appearance, acting or physical controls.
- No exhaustive scene/branch coverage or labor-saving percentage is claimed.
- Known Godot 4.3 dummy-renderer null-mesh and exit resource diagnostics are counted and retained; these checks do not establish clean resource teardown. Unexpected errors fail the run.
