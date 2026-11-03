# Attribution and third-party notices

Dedicated to the people of BioWare, whose worlds made companions, conversations, and difficult choices central to so many adventures. Oathshaper is an independent homage, with no affiliation, sponsorship, endorsement, or permission to use BioWare's names or assets implied. The [research and third-party rights notice](docs/research/NOTICE.md) explains how the project treats references to other games and tools.

## Project work

The [MIT license](LICENSE) covers Oathshaper code and, [to the extent contributors hold the applicable rights](ASSET-LICENSE.md), project-owned artwork, models, textures, dialogue, generated voice recordings, music, and locally authored animation. The project includes AI-generated media. A project license does not replace the separate terms for third-party material or establish rights in an owner-supplied asset whose inputs and terms have not been verified.

Original project concept art and prompts are documented in [concept provenance](art/concepts/README.md). The [material-map notes](godot/assets/textures/materials/README.md), [music provenance](godot/assets/audio/music/README.md), [procedural combat-sound notes](godot/assets/audio/combat/README.md), and [UI provenance](godot/assets/ui/README.md) describe their respective sources and transformations.

## Third-party material

| Material | Credit and applicable terms | Detailed record |
| --- | --- | --- |
| Sound effects and ambience | Kenney's Interface Sounds, RPG Audio, Impact Sounds, and Sci-fi Sounds; `clif_creates`'s *Harbor Ambience1*; and TRP's Lake Ontario waves recording. These 28 included clips are identified as [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/); included Kenney license files and per-file transformations remain recorded. | [CC0 sound palette](godot/assets/audio/cc0/README.md) and [manifest](godot/assets/audio/cc0/provenance.json) |
| Display font | Libre Baskerville, by the Libre Baskerville Project Authors / Impallari Type, retains the SIL Open Font License 1.1. | [Font provenance](godot/assets/fonts/README.md) and [full OFL text](godot/assets/fonts/OFL-LibreBaskerville.txt) |
| Animation donors | Quaternius's free Standard editions of *Universal Animation Library* and *Universal Animation Library 2* are supplied under CC0 1.0. The installed player walk and run derive from library clips. | [Source and transformation notes](tools/rigging/sources/quaternius/README.md), [CC0 notice](tools/rigging/sources/quaternius/LICENSE.txt), and [manifest](tools/rigging/sources/quaternius/manifest.json) |
| Generated voices | Kyutai's TTS model weights are credited under CC BY 4.0. The VCTK voice-conditioning recordings are credited to Junichi Yamagishi, Christophe Veaux, and Kirsten MacDonald (2019), *CSTR VCTK Corpus*, version 0.92, [DOI:10.7488/ds/2645](https://doi.org/10.7488/ds/2645), under CC BY 4.0. The donated Vendor/Crimson Raider source is credited to its contributor and Kyutai under CC0 1.0; its requested citation is Václav Volhejn (2025), *Unmute Voice Donation Project*. The voice record identifies each role's source, the model, and the changes made during synthesis and processing. No source speaker performed or endorsed the game's dialogue. | [Full voice credits and change notices](godot/assets/audio/generated/ATTRIBUTION.md) and [production provenance](godot/assets/audio/generated/production-provenance.json) |

## Owner-supplied 3D assets

The owner reports that the supplied Meshy characters, weapons, tower, and garden were generated privately on a paid plan. The [model provenance](godot/assets/meshes/README.md), [equipment record](godot/assets/meshes/equipment/README.md), and [adversary record](godot/assets/meshes/adversaries/README.md) identify original exports, local derivatives, and remaining verification limits. The [tower texture extracts](godot/assets/textures/README.md#stonewatch-beacon-atlas-extracts) inherit their source model's terms. These records do not claim that Oathshaper's MIT license independently grants rights in the supplied meshes or their embedded textures.

Software dependencies retain their own licenses and notices. The [release packaging record](docs/release-builds.md#candidate-contents-and-verification) describes the engine, Rust dependency, font, and asset notices included beside exported builds. This document is an index to the project's source records; preserve the applicable source notices and provenance when redistributing the assets.
