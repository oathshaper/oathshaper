# Combat performance and movement

Measured on 27 October 2026 on the local workstation: Apple M4 Pro, 24 GiB RAM, Godot 4.3 stable, OpenGL compatibility renderer, 1280 × 800 window. The benchmark caps rendering at 60 FPS with VSync disabled. These are desktop measurements; Steam Deck performance remains unmeasured for this change.

## What changed

1. **Spread character movement across each combat tick.** Command publishes positions every 100 ms. Previously, presentation moved at 6 m/s until it reached the new position, then stopped. A character walking at about 1.7 m/s consequently alternated between a short movement burst and a longer standstill. Presentation now interpolates between the previous and current committed snapshots using the host accumulator. Walk animation uses the interval's velocity. Facing eases toward movement or the active target. Pause commits the current position and freezes animation; restores and large relocations snap without a travel streak. Flow uses its own tick interval through the shared stage's elapsed-time fallback.
2. **Keep time owed to combat.** Admitting an action can require a zero-time simulation pump. The host previously discarded the accumulated 100 ms when that pump returned `complete` without consuming a tick. It now services the next pump, up to eight per frame, and carries unspent time forward. The regression fixture advances six real host intervals and checks that all six gameplay ticks occur.
3. **Bound camera search work.** An obstructed view could try 40 camera angles in one frame. Search now evaluates at most four per frame and retains progress. The current view still gets collision and visibility checks every frame. Camera yaw chosen by the player remains separate from the obstacle adjustment.
4. **Remove expensive sphere sweeps against detailed foliage.** The garden has approximately 900,000 triangles. Sweeping a sphere against its concave collision mesh produced stalls measured in seconds. The camera still sweeps a sphere against authored solid boxes. Five lens probes check the imported mesh; subject rays check the controlled character and target. This preserves the rendered mesh and avoids the expensive triangle shape casts. The five probes approximate lens clearance around fine foliage; they are not a full volume intersection test.
5. **Optimize the local development extension.** Cargo's development profile uses optimization level 2, including dependencies. Debug symbols and assertions remain enabled. The release profile is unchanged. Fresh development builds take longer; incremental gameplay uses the optimized library installed atomically by `scripts/build-host.sh`.

No mesh, rig, material, shadow setting, encounter rule or narrative content was changed in this pass.

## Measured result

| Measurement | Before | After |
|---|---:|---:|
| Average frame interval | 36.88 ms | 16.98 ms |
| Median frame interval | 16.88 ms | 16.67 ms |
| 95th-percentile frame interval | 83.43 ms | 19.45 ms |
| Longest sampled frame | 2,535.58 ms | 88.01 ms |
| Stage presentation, 95th percentile | 37.12 ms | 0.25 ms |
| `advance` bridge call, average | 8.08 ms | 2.47 ms |
| Wall time for the engine's 12-second timer | 17.74 s | 12.00 s |
| Rendered frames sampled | 479 | 706 |
| Final gameplay tick | 111 | 119 |

The 95th-percentile frame interval improved by about 77% in this fixture. There are still occasional frames longer than the 16.7 ms budget. This does not establish a locked 60 FPS rate or a general speedup for every location and combat style.

Raw measurements: [before](before.json), [after](after.json). Native output: [before](before.txt), [after](after.txt). Rendered captures: [before](before.png), [after](after.png). The camera selects different views, and the final simulation ticks differ, so the captures are not pixel comparisons. Rendering counters remain substantial: roughly 7.6 million submitted primitives and 502 MB of reported video memory. The improvement comes mainly from CPU work and movement scheduling, rather than reduced artwork.

The baseline used source commit `4ddf3b5c2ab3fcdd3a97c7f94c12a560e77b60fa` and the original unoptimized development extension. The after run includes the changes listed above. Preexisting local `project.godot` edits were retained for both measurements and are excluded from this change's commit. The continuity report records hashes of the effective source files, including that configuration.

### Measurement method

The fixture instantiates the actual Command preview, its party rigs, adversaries, HUD and garden. It allows three seconds of warmup, resumes combat, and acknowledges pauses when the controlled character needs orders so combat remains active during sampling. The preview uses its existing deterministic seed. It neither reads nor writes a campaign save.

Frame intervals use wall-clock timestamps. The sample window uses a 12-second Godot timer; long stalls can make that take longer in wall time because engine frame delta is bounded. This is why the before/after frame counts and final ticks differ. The timed window excludes initial scene construction and asset loading. It is one local run per reported configuration, not a statistical study.

The probe times host processing and stage processing explicitly; model animation, rendering and other children remain active. Method timings are inclusive and overlap, so they must not be added together as independent costs. The renderer counters are not GPU timings. Benchmarks ran without concurrent builds or our headless test suites; unrelated desktop activity was not isolated.

## Run it

From the repository root, using a Godot 4.3 stable executable:

```sh
sh scripts/build-host.sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot --resolution 1280x800 \
  --script res://tools/profile_combat.gd -- --output=/tmp/combat-profile.json
```

The tool writes JSON and a PNG beside it, then closes its own window. Use an existing output directory. It rejects headless mode because the dummy renderer cannot measure visible gameplay performance. Close other game instances and avoid concurrent builds when comparing runs. Keep the same machine, window size, renderer, fixture and frame cap.

## Verification

- Rust formatting, [Clippy](clippy.txt), and [138 workspace tests including the documentation test](rust-tests.txt) passed.
- The [current chapter continuity run](current-game/README.md) passed: narrative matrix, dialogue scan, authored replays, native build/import, and 1,201 native assertions. These include 101 new pacing assertions, camera obstruction samples, preserved manual yaw, pause controls, stable paused poses, staff grip, three story routes and voice playback.
- Additional [native regression results](regression/report.json) passed: Command targeting (28), Command trial (45), Flow trial (294), Vanguard trial (23).
- `combat_pacing_test.gd` is included in the normal check script, chapter manifest and Linux check script. The Linux container checks were not run in this pass.
- Existing Godot 4.3 dummy-renderer and exit-resource diagnostics remain in the raw headless logs. The continuity runner reports them separately; no unexpected engine errors were accepted.

The rendered capture was inspected. The automated camera tests sample authored positions; they do not prove every foliage angle is clear. Smooth movement has deterministic regression coverage, but subjective animation quality and physical Steam Deck responsiveness still need playtesting.

## How to teach the diagnosis

Ask students to distinguish slow frame delivery from uneven motion at a steady frame rate. Here both were present: expensive camera queries stalled frames, while a 10 Hz position stream was presented as repeated bursts. Plot or inspect frame percentiles, then inspect motion across a single tick. Change one source of work at a time and preserve the same fixture and artwork.

The retained tests demonstrate the distinction: a wall-clock benchmark measures cost, while deterministic assertions check tick accounting, motion intervals and pause behavior without relying on machine speed. Camera work has a per-frame limit rather than a timing assertion that would vary across student machines.

Godot's [jitter and stutter guide](https://docs.godotengine.org/en/4.3/tutorials/misc/jitter_stutter.html) explains the difference between uneven motion and frame stalls. Its [CPU optimization guide](https://docs.godotengine.org/en/4.3/tutorials/performance/cpu_optimization.html) describes profiling before optimizing. Oathshaper's interpolation applies to its custom combat snapshot clock; it does not enable engine physics interpolation for the entire project.
