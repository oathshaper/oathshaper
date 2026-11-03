# Party presentation and camera repairs

## Changes

### Walking and equipment

Tessa used the retargeted Quaternius walk and jog, while Mara and Ivo still used a procedural walk with no run clip. At the same travel speed they therefore selected different gaits and very different playback rates.

All three now use the same CC0 animation sources and a 2.8 m/s walk-to-run threshold. Playback rates use each rig's measured stride. Walk/run phases are aligned to preserve the leading leg through a transition. Existing model geometry, textures and joints are retained; motion and retarget sidecars record the calibration.

Mara's rear coat weights now follow the pelvis with a limited thigh contribution. The repair is an explicit retarget option because repeatedly applying the weight blend would compound it. This reduces the leg-driven coat fold; it is not a cloth simulation or a guarantee against every material shimmer.

The sabre's axial orientation is corrected. Buckler poses use bent-arm reach and align the shield face with the forearm. Mara holds the full staff diagonally with two hands, using its support grip. Shield bash retains the same guard alignment while extending the arm.

### Dialogue

- Mara asks whether the clerk is hurt before Tessa reports the stolen payroll.
- The clerk describes a man in a red coat.
- Recruitment, gate opening, victory, recovery and payment retire completed instructions and stale questions across the cast.
- Ivo and the vendor refer to the visible tower light rather than assuming knowledge of an offscreen payment.
- Changed spoken lines were regenerated with the existing voice sources. Source credits and earlier audio files are retained.

The authored continuity rules now cover these cases. Humanizer routing, its fiction critic and the local Obelus CLI reviewed the dialogue. The critic identified stale clerk instructions, Mara's premature knowledge of the guards and a repeated discovery topic; these were corrected. The gated Ivo option remains intentional: it is disabled until Mara joins. Four remaining deterministic prose findings concern condition metadata, the consistent “Leave conversation” label and ordinary speech about hearing the crash. They were reviewed and retained. Obelus findings alone do not prove narrative continuity.

### Camera

Command previously recalculated its angle as the target moved, applied intermediate obstruction candidates, and could jump directly to a clearer view. It now:

- Chooses an automatic angle when the controlled character or target changes.
- Requires a sustained obstruction before searching and completes the bounded search before choosing a new view.
- Eases focus and camera movement, with travel limits and collision checks from the previous lens position.
- Preserves manual orbit/zoom while the controlled character is stationary.

Flow also eases its camera and retains its selected target angle. Explicit recenter reacquires that angle.

### Showcase audio

The title, nine-style menu, Command inspector and opening cinematic were recaptured as one continuous take. This removes the edit boundary that clipped the music. Capture markers confirm the same music-player instance remains active throughout those screens; playback advances normally, including the existing 28.5-second loop. The runtime audio service did not require a change.

## Verification

| Check | Result |
| --- | --- |
| Party asset checks, native renderer | 69 checks, 0 failures |
| Command camera motion with staged paths in the actual garden | 723 checks, 0 failures; maximum 0.0833 m translation and 0.601° rotation per frame at 60 fps in this fixture |
| Command/Flow manual camera hold | 20 checks, 0 failures |
| Playtest continuity and obstruction recovery | 309 checks, 0 failures |
| Targeting | 28 checks, 0 failures |
| Combat pacing | 101 checks, 0 failures |
| Audio service | 62 checks, 0 failures |
| Generated voice playback | 92 checks, 0 failures |
| Chapter route with oil kept | 230 checks, 0 failures |
| Narrative matrix, dialogue repetition and journey replay | Passed within their declared scope |
| Revised showcase | 2:44.75, 1280×800, 30 fps, H.264/AAC stereo; full decode passed |

Same-speed front/rear gait captures cover 1.5 m/s and 4.5 m/s. Equipment poses and new gameplay captures were visually inspected. Camera measurements describe the test fixture, not every possible camera path. The narrative matrix is not reachability proof. Known Godot 4.3 headless-renderer and exit-resource diagnostics remain recorded; these checks do not establish clean resource teardown or Steam Deck performance.

The original showcase and asset backups are retained locally. Capture uses separate saves. The revised video is an edited showcase with staged entry points and actual game actions, not an uninterrupted human playthrough. No upload or publication was performed.

## Reproduce focused checks

From the repository root, with Godot 4.3 available as `godot`:

```sh
godot --headless --path godot --script res://tests/camera_motion_test.gd
godot --headless --path godot --script res://tests/camera_hold_test.gd
godot --path godot --script res://tests/party_asset_test.gd -- --capture
python3 scripts/check-continuity.py --logic-only
```

`godot/tools/capture_party_gaits.gd` records the same-speed party comparison through Godot Movie Maker. Supply the output directory as its user argument and an external `--write-movie` path when disk space is limited.
