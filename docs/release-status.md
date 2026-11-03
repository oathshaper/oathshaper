# Lantern Quay release candidate

The first demo contains one story and three playable combat styles. Styles 04–09 have design previews and are marked **Coming soon**. The release notes identify the published revision, downloadable archives and platform test results.

## Playable scope

| Style | Implemented in this slice | Remaining work |
| --- | --- | --- |
| 01 Command | Party control, pause, action queues, companion decisions, equipment, powers, inventory and chapter saves | Broader progression, encounters and animation polish |
| 02 Flow | Four fighting styles, guard/dodge/healing, Chi/Focus, party support, equipment and chapter saves | More styles and progression, animation and balance polish |
| 03 Vanguard | Center-reticle aiming, firearm heat, shields, planter cover, squad powers and commands | Dedicated cover animations, enemy movement, progression and encounter saves |
| 04–09 | Numbered cards, Coming soon pills and tabbed design previews | Playable combat runtimes |

All three use **The Quay Robbery**: the dark tower, the clerk's ransacked office, Mara and Ivo joining at the garden, the Crimson Raider and his guards, recovery of the payroll pouch, and its return to the clerk. Surrender and the aftermath use shared cutscenes. Donating oil can light the tower earlier. Standalone combat and menu previews do not write journey progress.

Recent native checks and the edited showcase exercise these paths. They are development evidence, not acceptance of a separately exported binary. See the [Flow repairs](flow-playtest-repair-20261101.md), [shared outcomes](combat-implementation/garden-outcome-20261101.md), [Vanguard presentation](combat-implementation/vanguard-presentation-20261101.md), and [build contract](release-builds.md). Historical reports retain their original scope and dates.

## Publication requirements

- **Code:** first-party code uses [MIT](../LICENSE). Third-party licenses and notices remain separate.
- **Media:** Kenney audio, the harbor recordings and animation donors have their own recorded licenses. Fonts retain OFL notices. Generated voice credits identify every conditioning source, model and processing step; preserve them with redistributed audio.
- **Owner-supplied models:** the owner reports paid-plan, private Meshy generation. Meshy-origin distribution permission is cleared under its paid-plan terms. The account status is an owner report; generation inputs have not been independently inspected. See [model provenance](../godot/assets/meshes/README.md) and [voice attribution](../godot/assets/audio/generated/ATTRIBUTION.md).
- **Native archives:** build from a clean captured revision. Retain `BUILD-MANIFEST.json`, checksums and `licenses/`. Startup checks cover only the host that ran them; verify gameplay on each advertised platform before distribution.
- **Platform limits:** macOS is ad-hoc signed, not notarized; Windows is unsigned. Linux, Windows, Intel Mac, physical controller and Steam Deck acceptance must be recorded for the actual candidate. Older evidence does not certify newer bytes.

## Before building

```sh
python3 scripts/check-public-tree.py
python3 -m unittest discover -s scripts -p test_public_tree.py
python3 -m unittest discover -s scripts -p test_release_packaging.py
GODOT_BIN=godot sh scripts/check.sh
```

The public-tree guard reports workstation paths, private hosts/networks, private filenames and unsafe archive members without echoing matched values. It inspects GLB JSON and compressed text, but excludes other binary payloads. It complements a credential scanner and manual media/provenance review. Private planning, backups, local credentials, saves and build caches belong outside public source and release archives.

The build workflow runs hygiene and packaging checks, exports on native runners and tests the extracted executable. Windows can be selected for a standalone manual run. Candidate artifacts remain available when later acceptance fails. The milestone release workflow publishes tagged downloads only after all three platforms and the independent artifact/acceptance gate succeed. See [native builds and milestone releases](release-builds.md) for triggers, commands and testing limits. Workflow implementation is not evidence of a completed hosted CI run.
