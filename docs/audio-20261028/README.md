# CC0 audio integration and local music trial

## Implemented

- Kenney UI confirmations, targeting/queue feedback, rejection, pause, swings, impacts, healing accents, doors and weapon draw.
- Wood and stone footsteps follow actual grounded travel. Standing, blocked movement, disabled exploration and teleporting do not emit steps. They use measured stride spacing, **not skeletal contact markers**; NPC footsteps remain future work.
- Two looping CC0 water/harbor recordings. One mixer persists across the quay, office and garden encounter. The office attenuates the beds by 15 dB. Speech ducks them another 8 dB, with a gradual release.
- Master, Music, UI, SFX, Ambience and Dialogue sliders, saved independently of the campaign. Audio settings are reachable from the title, exploration Ledger and combat menus. Opening settings pauses gameplay and preserves the prior pause state on return. Music was added October 29.
- A bounded pool of 12 effect players, cue cooldowns and sample variation. Command uses committed event IDs; Flow and Vanguard compare committed health pools and shot counters. Rendering the same view again produces no new event sound. Preview combat remains muted.

See [asset provenance](../../godot/assets/audio/cc0/README.md). This pass uses 2D mixing, not positional water emitters or a complete weapon-specific sound design. Bell clips are temporary power/healing accents. Musical quality and ambience balance still need a listening pass in a normal playthrough.

## Verification

- Native Godot audio integration test: **49 checks, 0 failures**; imports, singleton ownership, bounded playback, event deduplication, preview mute, dialogue routing/duck/release, saved volume, mute and settings pause restoration.
- Command targeting regression: **28 checks, 0 assertion failures**. The headless dummy renderer emitted mesh cleanup warnings at shutdown; the native audio test exited cleanly.
- Flow regression: **294 checks, 0 failures**; Vanguard regression: **23 checks, 0 failures**. These headless scene tests also emit dummy-renderer/resource cleanup diagnostics, retained in the verification files.
- Grounded movement test: **7 checks, 0 failures**; wood/stone selection, stopping, disabled movement and teleport suppression.
- All **28** source licenses and final SHA-256 hashes checked against the manifest.
- Main scene launches headlessly without script errors.
- [1280 × 800 settings capture](audio-settings.png).

```sh
godot --headless --path godot --script res://tests/game_audio_test.gd
godot --headless --path godot --script res://tests/footstep_audio_test.gd
```

## ACE-Step installation

Installed [ACE-Step 1.5](https://github.com/ace-step/ACE-Step-1.5) at upstream commit `ca1e85fe9430179831e6bc6be790c332190a3866`. Python dependencies use the upstream frozen uv lock. The environment, checkpoint bundle and caches are in an external data directory. No service or startup job was enabled; the game never loads the music model.

The initial full-precision trial ended in a system restart with low swap headroom. That attempt did not produce audio. The subsequent supervised retry succeeded using **8-bit MLX diffusion, CPU conditioning, and float16 VAE decoding in 192-frame windows**. See the [restart investigation and all retry outcomes](restart-review.md).

The successful audition is **30 seconds, stereo, 48 kHz**. Model initialization took 14.5 seconds; generation took 8.5 seconds. Peak child RSS was 6.61 GiB and peak MLX allocation was 4.20 GiB (overlapping measurements). Swap did not grow during the final run. Sampled memory pressure reached warning but never critical. This is one successful local audition, not a sustained workload benchmark. The user subsequently selected the clarity version for the game; see the integration note below.

The [community conversion](https://huggingface.co/Audante/ACE-Step-1.5-mlx-8bit) is pinned to revision `7a59458c6a193af37a107fc2c0f6e7c03333b118`. It retains ACE-Step's MIT notice; its patch is installed in a separate checkout. The setup helper verifies the downloaded checksums and the reviewed patch hash. The official checkpoint installation is retained, with unchanged components linked into the smaller bundle. The original planner is linked for the upstream bundle check but is never loaded by this trial.

```sh
DATA="${OATHSHAPER_AUDIO_DATA:-$HOME/Library/Caches/oathshaper/ace-step-data}"
REPO="$HOME/Library/Caches/oathshaper/ace-step-1.5"

# One-time setup (also checks an existing installation):
"$DATA/.venv/bin/python" tools/audio/prepare_ace_step_mlx8.py \
  --repo "$REPO" --data "$DATA"

# Lightweight resource check; no model is imported:
"$DATA/.venv/bin/python" tools/audio/guarded_ace_step.py \
  --repo "${REPO}-mlx8" --data "$DATA" \
  --checkpoint-dir "$DATA/models-mlx8" --quantized-mlx --preflight-only

# A single supervised audition; five seconds is the default:
"$DATA/.venv/bin/python" tools/audio/guarded_ace_step.py \
  --repo "${REPO}-mlx8" --data "$DATA" \
  --checkpoint-dir "$DATA/models-mlx8" --quantized-mlx --seconds 30

# Regression checks use no model memory:
"$DATA/.venv/bin/python" tools/audio/test_guarded_ace_step.py
```

Each attempt writes its own directory under `$DATA/outputs/`: `guard.json`, `trial.log`, `resources.jsonl`, and, if generation completes, `trial.json` and a WAV. Inference runs with the external data directory as its working directory, so ACE-Step's progress cache also stays outside the game repository. No inference server or background service remains running after completion.

The quantized retry requires at least 4 GiB available RAM, 30 GiB free on the system disk, at most 12 GiB existing swap, and normal or warning pressure. It stops its dedicated process group at critical/unknown pressure, more than 12 GiB RSS, less than 1 GiB available RAM, more than 4 GiB additional swap, more than 12 GiB total swap, less than 25 GiB disk reserve, or ten minutes elapsed. The full-precision path retains its stricter start policy. These bounds reduce exposure; they cannot guarantee recovery from an OS/driver stall. The RSS limit is supplemented by system pressure and swap checks because RSS alone does not account for all Metal allocations and compressed memory.

The successful sample used an original instrumental harbor prompt, a fixed seed, one Turbo sample, eight diffusion steps and no language-model planner. It was opened in QuickTime for audition. Numerical validation found finite samples, audible signal level and no clipping. The runner now records those checks on subsequent outputs as well. Four lightweight supervisor regressions pass, including the macOS process-exit accounting race.

Memory API references: [PyTorch MPS limit](https://docs.pytorch.org/docs/stable/generated/torch.mps.set_per_process_memory_fraction.html), [MLX allocation limit](https://ml-explore.github.io/mlx/build/html/python/_autosummary/mlx.core.set_memory_limit.html), and [Apple's macOS pressure-level export](https://github.com/apple-oss-distributions/xnu/blob/xnu-11215.81.4/bsd/kern/kern_memorystatus_notify.c). `vm.memory_pressure` is not the discrete pressure-level enum; the guard reads `kern.memorystatus_vm_pressure_level`.

## Clarity audition

The user liked the composition but reported a muffled/distorted sound. The original measured −1.00 dBTP without clipped samples. Inspection found no conspicuous sample discontinuities at the 2.56-second VAE chunk boundaries. Neither check rules out distortion generated into the music, and neither establishes that model quantization or decoder precision caused the reported sound.

`tools/audio/clean_music.py` makes a reversible EQ comparison, using FFmpeg without loading a model:

- 30 Hz high-pass, 12 dB/octave.
- Broad 240 Hz cut of 2.5 dB to reduce low-mid buildup.
- Broad 1.9 kHz lift of 2 dB and a 5 kHz high shelf of 2.5 dB.
- Fixed gain to match both auditions at −20 LUFS, preserving headroom. No dynamics processing, denoising or harmonic synthesis.

The matched original measured −20.00 LUFS / −4.77 dBTP; the clarity pass measured −20.01 LUFS / −5.36 dBTP. Both retain the full 30-second stereo duration at 48 kHz. The processed copies use 24-bit PCM to retain the filtered result; this does not restore detail absent from the 16-bit source. The source hash is unchanged. [Measurement record](verification/music-cleanup.json).

```sh
"$DATA/.venv/bin/python" tools/audio/clean_music.py "$SOURCE_WAV" \
  --output "$DATA/outputs/harbor-clarity-audition"
```

The output directory must be new. It contains a matched original, the full clarity pass, and a 21-second comparison: the first ten seconds of the original, one second of silence, then the same passage processed. The comparison was opened in QuickTime. EQ can alter tonal balance but cannot reconstruct lost detail or reliably remove generated warbling.

## Game integration — October 29

The user selected the latter, cleaned audition. It is now shipped as [lantern_quay.ogg](../../godot/assets/audio/music/lantern_quay.ogg), with a 1.5-second wrap crossfade and a dedicated Music bus. Default music volume is 80%; title gain is −4 dB, quay/combat −8 dB, office −11 dB. Speech adds 8 dB of ducking. Music continues across room transitions and pause menus; the Audio menu exposes a persistent Music slider. Integration uses the existing recording and does not run inference.

See [asset provenance](../../godot/assets/audio/music/provenance.json) for the approved source and final hashes, and the [integration verification](../music-cutscene-20261029/README.md).
