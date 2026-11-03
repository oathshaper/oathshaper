# Native demo builds

The `Native demo builds` workflow builds and tests Linux x86_64, Windows x86_64, and macOS Universal (Apple Silicon and Intel). Pull requests and pushes to `main` or `release/**` run all platforms. Manual runs can select Windows alone, another platform, or all three. Its downloads stay in Actions artifacts.

The `Milestone demo release` workflow calls that same build pipeline for an existing tag, verifies the resulting archives and acceptance reports, and attaches the downloads to a GitHub Release. It runs when a `demo-*` or `milestone-*` tag is pushed, when a GitHub Release is published, or when dispatched manually with an existing tag. Here a milestone release means a tagged source revision; closing an issue milestone does not publish a game.

Release notes identify the exact published revision and artifact checksums. The current source includes asset provenance and third-party notices; each newly built archive still needs candidate-specific acceptance.

## Test Windows on demand

Once the workflows are on the default branch, open **Actions → Native demo builds → Run workflow**, select the branch and choose **windows**. The job compiles the MSVC extension, runs Rust tests, exports the Windows game, starts the exported executable, then tests its extracted scene/rules routes. Download the `oathshaper-demo-windows-<commit>` artifact, unzip the Actions wrapper and then the game archive, and run `Oathshaper.exe` with the other files beside it.

The equivalent CLI command is:

```sh
gh workflow run demo-builds.yml --ref main -f platform=windows
```

The build download is retained after a successful export even if a later acceptance check fails, so you can reproduce failures on your machine. Check the job result and the corresponding `oathshaper-acceptance-windows-<commit>` artifact; a downloadable archive alone is not a passing release gate. Build logs, per-suite runtime logs, reports and rendered screenshots are retained for 14 days. Windows pixel/controller/audio-listening tests remain manual.

## Release a milestone

Tag the intended commit containing these workflows and their helper scripts, then push that tag:

```sh
git tag -a demo-milestone-1 -m "Lantern Quay milestone 1"
git push origin demo-milestone-1
```

Alternatively, publish a GitHub Release for an existing tag, or rerun the workflow explicitly:

```sh
gh workflow run demo-release.yml --ref main -f tag=demo-milestone-1
```

All three platforms build the same resolved commit. Publication requires every build job to succeed, then independently checks archive checksums, all manifest file hashes, bundled code/voice notices, required suites, renderer coverage and the hash of the executable actually tested. Missing platforms, skipped required suites, script errors and shutdown-resource errors stop publication. The existing narrowly recorded Godot dummy-renderer diagnostic remains visible in Windows acceptance.

For a new tag, the workflow creates a draft prerelease, uploads all three archives, their checksum sidecars, `SHA256SUMS`, `release-manifest.json` and `TESTING.md`, verifies GitHub's asset digests, then publishes. Existing release titles, notes and prerelease settings are preserved. Failed uploads leave a draft for recovery. Already-uploaded identical bytes are reused; changed or unverifiable assets are never overwritten. Rebuilding may produce different archive bytes, so use a new tag for replacement binaries. Immutable published releases cannot accept new assets: push the milestone tag first so CI can populate the draft before publication.

The build jobs have read-only repository permission. Only the publication job receives `contents: write`; no personal access token is needed. Configure repository Actions to allow these workflows and the pinned official actions. The workflows do not create an organization or repository.

GitHub's [release events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#release), [reusable workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows), and [release asset digests](https://docs.github.com/en/rest/releases/assets#get-a-release-asset) define these behaviors. A release created using the workflow's `GITHUB_TOKEN` does not trigger another release workflow run.

## Build contract

| Platform | Runner | Native extension | Download |
| --- | --- | --- | --- |
| Linux x86_64 | Ubuntu 22.04 | `liboathshaper_godot.so` | `.tar.gz`, preserving executable permissions |
| Windows x86_64 | Windows Server 2022 | `oathshaper_godot.dll` | `.zip` |
| macOS Universal | macOS 14 | Universal `liboathshaper_godot.dylib` built with `lipo` | `.zip` containing `.app` |

Godot **4.3.stable**, Rust **1.95.0**, and godot-rust **0.2.4** (`api-4-3`) match the project. Rust dependencies use `Cargo.lock`. Editor/template downloads use hashes pinned from [Godot's 4.3 SHA512 manifest](https://github.com/godotengine/godot-builds/releases/download/4.3-stable/SHA512-SUMS.txt). Actions use full commit IDs from the official checkout, upload-artifact and download-artifact repositories.

The script compiles the extension on the target OS, stages only tracked Godot files, imports assets, exports with the platform preset, checks that the library was included, and runs the exported executable headlessly through its main scene for five frames, then uses the application audio service to close gracefully. Godot `ERROR` and `SCRIPT ERROR` messages fail the build even if its exit code is zero. The Rust core test suite also runs. A startup smoke is not full gameplay, visual, controller, or target hardware performance acceptance.

The staged macOS project enables `rendering/textures/vram_compression/import_etc2_astc`; Godot 4.3 requires that import variant for a universal export. This does not change the working project's settings. Template paths are supplied explicitly in the staged presets, so no user-wide template installation is required.

macOS includes both CPU architectures and uses Godot's built-in ad-hoc signing. It is **not notarized**. Windows is unsigned. OS download warnings are expected; distribution signing is a separate release task. Linux is built on Ubuntu 22.04 and requires a compatible Linux runtime; older glibc distributions are not promised. There is no browser build: this project ships a native Rust GDExtension.

Release Rust builds remap source, dependency-cache and build-directory prefixes so panic locations do not embed workstation paths. Target flags are set by the build recipe; interactive shell Rust flags are not inherited.

The Windows extension enables Rust's [`crt-static` target feature](https://doc.rust-lang.org/reference/linkage.html#static-and-dynamic-c-runtimes) to link its C runtime into the DLL. Validate the resulting DLL imports and launch it on a clean Windows machine before publishing; the hosted runner's installed developer tools can mask a missing runtime dependency.

## Packaged-game acceptance

After export, `scripts/test-exported-demo.py` verifies the archive checksum, extracts it independently, verifies every manifest entry and runs external test drivers against the packaged executable/resources. The source revision must match the archive. Tests exercise all three profile entries, Flow controls, Vanguard aiming, Command's story route, and Flow/Vanguard combat outcomes and return to the garden.

Linux CI uses Xvfb with Mesa software rendering; macOS uses its native renderer. Both include Vanguard HUD pixel/cover checks. Windows CI uses headless scene/rules checks; the pixel suite is explicitly skipped. Godot 4.3's exact dummy-renderer mesh teardown diagnostic is recorded separately in headless reports; other engine errors fail the job, and no diagnostic exemption applies to rendered runs. Automated fixtures are not physical-controller, human-listening or target-GPU certification.

```sh
python3 scripts/test-exported-demo.py --archives-dir /tmp/oathshaper-release-artifacts \
  --output /tmp/oathshaper-release-acceptance --rendered
```

Use a fresh output directory. Keep the per-suite logs and `acceptance.json` with the release's evidence.

## Run locally

Use a native OS with Git, Python 3.10+, Rust/rustup, and its native linker installed (Xcode command-line tools on macOS, Visual Studio C++ tools on Windows, GCC on Linux). Install the pinned toolchain, then run the matching platform:

```sh
rustup toolchain install 1.95.0 --profile minimal
python3 scripts/export-release.py --platform macos \
  --work-dir /tmp/oathshaper-release-build \
  --output /tmp/oathshaper-release-artifacts
```

For Linux use `--platform linux`. On Windows use `python`, `--platform windows`, and dedicated paths such as `C:/Temp/oathshaper-release-build` and `C:/Temp/oathshaper-release-artifacts`. The build directory must be outside the repository. Reusing it reuses checked downloads and Cargo artifacts, and replaces its `project` and `package` subdirectories. It does not change the working project's `godot/bin`, import cache, installed Godot, or export template directory. Build from a clean checkout: the source commit is captured before compilation, and any dirty files or changed HEAD reject the candidate before manifest creation. Commit new Godot files first; the staging allowlist comes from `git ls-files`. Use a dedicated detached checkout for long builds.

The official template archive is approximately 1.07 GB; each runner downloads it and extracts only its required template. The tracked source snapshot at checkpoint `daaee1c` totals 309,698,719 bytes; its largest file is the 39,040,004-byte garden GLB. Ordinary checkout is adequate for that snapshot, and no LFS migration is needed for these files. Each build job has a 60-minute limit and artifacts expire after 14 days. No shared Cargo or Godot cache is restored between jobs.

## Candidate contents and verification

Each archive has a platform and source revision in its name. A sidecar `.sha256` lets you check its bytes against the build's recorded digest; retain the checksum with the archive. `BUILD-MANIFEST.json` records the commit, whether tracked files were dirty, versions, targets, native smoke outcome, and package file hashes. A clean source commit is required when choosing a public release candidate.

`licenses/` contains root license/notices, the Godot engine license and third-party copyright notices, runtime Rust dependency license texts, exact unmodified MPL-covered crate sources, font OFL text, and asset README/provenance files. `rust-dependencies.json` lists all resolved build and runtime dependencies and marks the normal dependency closure. Runtime license files absent from published crate packages cause failure unless the known Godot MPL text is fetched with its pinned hash. Asset provenance records document origin; they do not grant missing rights.

The staging allowlist excludes untracked files, local caches, native build output, and user saves. Export filters exclude test/tool directories, logs, and user data. Runtime JSON content is included explicitly. Archives contain the exported game and notices, not the repository, credential files, or a player's save state.

After all three CI jobs pass, download each artifact, verify its SHA-256, and run the full gameplay acceptance on that operating system before manually attaching the archive and checksum to a release. The macOS job smoke-tests its host CPU only; the second architecture requires a separate Intel or Apple Silicon gameplay run. Keep the successful CI run URL, exact source SHA, checksums, and acceptance results with release notes. Rollback consists of retaining the previous release assets and withdrawing the new candidate; the workflow does not deploy or replace installations.

## Historical local candidate: corrected chooser and menu preview

The following results describe the October 22 candidate. Those native archives are no longer available locally and have not been revalidated against the current source. They are historical evidence, not the current release candidate.

Clean source `909993724d9a` produced `/tmp/oathshaper-release-artifacts/oathshaper-demo-macos-universal-909993724d9a.zip` on 2026-10-22. It includes the [menu corrections and rendered Obelus review](ui-copy-review/menu-correction.md), with the existing three playable styles and voices. The archive is **414,693,986 bytes**, SHA-256 **`2b252edb4e67bcc08ea55db1a16b0418cbf6129812241bd767e53bb1d6c8c005`**.

The native source passed 10,731 frontend checks and all 16 playable-profile entry/return checks. The universal export, packaged startup smoke and strict ad-hoc signature verification passed. Extracted archive evidence is at `/tmp/oathshaper-release-acceptance/909993724d9a/`; export log is `/tmp/oathshaper-chooser-review/export.log`. This UI-only correction did not repeat every combat acceptance run below. Distribution signing and publication remain pending.

## Earlier candidate: three styles with voices

On 2026-10-22, clean detached source `c0281cf9de6f0c3f57fd6ffa63001a154bacef14` produced the three-style, 45-line voiced macOS Universal candidate. Both arm64 and x86_64 release extensions compiled; the exported library passed `lipo` architecture checks. The archive is **414,694,458 bytes**, with SHA-256 **`f23716dcb810d291489d0d41c56f1068e7037bd87a166bc5b7a67bab4bbcd5b7`**.

Local download: `/tmp/oathshaper-release-artifacts/oathshaper-demo-macos-universal-c0281cf9de6f.zip`, with its `.sha256` sidecar. Build log: `/tmp/oathshaper-release-build/build-three-styles-voiced-final.log`.

The archive was extracted independently with `ditto`. All **66** manifest file hashes matched, and `codesign --verify --deep --strict` passed. The **extracted release executable**, using external acceptance scripts from the same frozen revision, then passed at 1280×800 on Apple Silicon:

| Check | Result |
| --- | --- |
| All three overview Play entries and returns | 16 checks, zero failures |
| Flow combat, costs, follower, victory and rewards | 294 checks, zero failures |
| Vanguard aim, cover, squad powers and victory | 23 checks, zero failures |
| Records → public passage → earned Command victory → quay save/load | 14 checks, zero failures |
| All 45 imported recordings, player/NPC handoff, pause and chapter speaker sequencing | 59 checks, zero failures |

All five processes exited 0 with no engine/script errors in their native logs. Raw receipt and logs: `/tmp/oathshaper-release-acceptance/c0281cf9de6f/acceptance.json` and sibling `.log` files. The test scripts are deliberately excluded from the PCK; they loaded the packaged runtime/resources. Existing campaign saves were not used.

This is ad-hoc signing, not notarization. Intel execution, physical Steam Deck/controller play and Windows/Linux CI remain unverified. The [voice audit](voice-production.md) retains 22 raw transcription flags and does not claim human performance acceptance. Later documentation-only commits do not change this archive's recorded source revision.

## Early Command candidate (historical)

On 2026-10-22, Actionlint 1.7.12 accepted the workflow, Python syntax and export-preset parsing passed, and the native macOS pipeline produced an early Command-chapter candidate from clean detached source `4605fc725ccad35469b1d9b77b9029c4cb3d51ac`. That source contains gameplay checkpoint `63f62f3` plus packaging corrections; it does not claim later Flow/Vanguard acceptance.

- Rust core suite: 78 passed, including one doctest.
- Rust extension: release builds for arm64 and x86_64 passed; `lipo` verified both architectures in the staged and exported libraries.
- Godot: clean asset import, universal release export, and five-frame headless launch passed on Apple Silicon.
- Archive: 405,602,415 bytes; SHA-256 `2943a7adb5fd3dc18fb5e569b761ecf66e13401d8d815610952674df688af3c1`.
- Extracted archive: all 63 manifest file hashes matched; `codesign --verify --deep --strict` and another native startup passed. This verifies ad-hoc signing, not notarization.

The archive and checksum are at `/tmp/oathshaper-release-artifacts/oathshaper-demo-macos-universal-4605fc725cca.zip` and its `.sha256` sidecar. The successful build log is `/tmp/oathshaper-release-build/build-macos-final.log`. Earlier failed logs remain there: stale narrative assertions were corrected by the gameplay owner, and packaging fixes addressed `lipo` argument order and the required ASTC import setting.

Windows and Linux native execution still require their corresponding CI runners or native machines. Intel macOS runtime, full gameplay on the exported build, and later gameplay checkpoints remain unverified by this build. GitHub publication and native CI remain pending until the repository exists and the workflow runs there. The build configuration has been implemented and locally exercised; it has not been independently reviewed or operated in GitHub CI yet.

Primary implementation references: [Godot 4.3 project export](https://docs.godotengine.org/en/4.3/tutorials/export/exporting_projects.html), [macOS export and signing](https://docs.godotengine.org/en/4.3/tutorials/export/exporting_for_macos.html), and [the exact macOS exporter source](https://github.com/godotengine/godot/blob/77dcf97d82cbfe4e4615475fa52ca03da645dbd8/platform/macos/export/export_plugin.cpp). References checked 2026-10-22.

Independent packaging review found and repaired late source-identity capture. A temporary Git fixture verified that a clean revision passes while dirty input and a newly committed revision reject. Audio provenance JSON accompanies asset notices; audition clips are excluded from runtime exports. This repair does not change the recorded earlier archive.
