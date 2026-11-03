# Playtest correction acceptance

## Scope

Perspective combat framing, authoritative actor spacing, healer triage, a voiced opening, causal dialogue options, audible feedback, visible controls, and a weapon attachment contract. Final weapon meshes, finger rigging and paired melee animation clips remain content work.

## Executed evidence

- Rust: 120 workspace tests passed, including deterministic encounter replay, healing reaching impact with the last available focus, bounded actor separation, blocked planter movement, and root immobility. Formatting and Clippy also passed.
- Native checks: all 22 scripts in the combined `scripts/check.sh` gate passed, covering the route, menu, three combat profiles, targeting, companion control, inventory, save/load, generated speech and opening. The gate returned exit 0; headless renderer diagnostics are qualified below.
- Rendered Command targeting: 40 checks, zero failures at 1280×800. Includes whole-fighter framing above the command bar, separate projected silhouettes, bumper targeting, possession, healing aim, controls visibility, and suppression of repeated audio on view refresh.
- Rendered opening: 12 checks, zero failures. Three actual adversary meshes are visible; every opening line has matching speech; automatic completion and B-to-skip restore movement without changing story state.
- Equipment mount fixture: 12 checks, zero failures. An intentionally offset primary grip aligns at two character scales; a supporting grip remains the IK target at the authored distance. Hand followers update with the skeleton, disconnect on removal, and reconnect once.
- Voice generation: all 56 current lines have matching PCM clips and objective QC. Unchanged clips were hash-verified and reused; previous provenance was archived before reconciliation.
- Actual Obelus and Humanizer artifacts are in this directory. See [editorial disposition](editorial-disposition.md) for rejected false positives and retained navigational repetition.

## Rendered captures

[Command melee framing](images/command-melee-1280x800.png)

[Opening: the blocked garden](images/opening-garden-1280x800.png)

## Limits

The first Linux package passed all 40 targeting assertions but emitted native `BoneAttachment3D` disconnect errors. A minimal skeleton-only reproduction isolated this from combat logic. Equipment now uses an explicit script callback after skeleton updates. The pinned Linux release binary passed the 12 mount checks and 40 rendered targeting checks against the corrected loose project without those errors; final package verification is retained with the local build artifacts. Linux checks run in Docker through x86_64 emulation and software OpenGL, not on a physical Deck.

Headless Godot's dummy renderer emits `mesh_get_surface_count` null-mesh diagnostics and shutdown resource warnings in several scene tests; an assertion pass is not a clean-renderer claim. The focused macOS rendered tests completed without script/render errors. Linux package checks and device performance are separate checks; no physical Steam Deck performance result is claimed.

The new plot has not yet been tested again with the original first-time player. Weapons still use procedural fallback art until authored socket-equipped meshes are supplied. Current character hand bones have no finger joints. The crew's return is described by Mara after the encounter; a crowd procession is not implemented.
