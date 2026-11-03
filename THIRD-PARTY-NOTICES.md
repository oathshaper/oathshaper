# Credits and third-party notices

Oathshaper contains original code and generated media alongside third-party assets. The root MIT license does not replace the licenses below. Native downloads include these records under `licenses/`.

| Material | Creator / source | Terms and records |
| --- | --- | --- |
| Game engine | Godot contributors, Godot 4.3 | MIT; engine `LICENSE` and `COPYRIGHT` are bundled with downloads |
| Rust bindings | godot-rust contributors, 0.2.4 | MPL 2.0; dependency notices and exact unmodified MPL crate sources are bundled |
| Other Rust dependencies | Authors listed in resolved crate packages | `Cargo.lock`; downloads include `licenses/rust-dependencies.json` and individual notices |
| Display font | Libre Baskerville Project Authors / Impallari Type | [SIL OFL 1.1](godot/assets/fonts/OFL-LibreBaskerville.txt); [source/hash](godot/assets/fonts/README.md) |
| UI and combat effects | Kenney: Interface Sounds, RPG Audio, Impact Sounds, Sci-fi Sounds | CC0; original license files and [per-file provenance](godot/assets/audio/cc0/provenance.json) |
| Harbor ambience | clif_creates, *Harbor Ambience 1*; TRP, *Waves gentle distant gulls lake good water detail LAKE ONTARIO TO 180522.wav* | CC0; [source links and processing](godot/assets/audio/cc0/README.md) |
| Animation donors | Quaternius, Universal Animation Libraries 1 and 2 | [CC0 dedication](tools/rigging/sources/quaternius/LICENSE.txt); [source hashes and clips](tools/rigging/sources/quaternius/manifest.json) |
| Dialogue conditioning | CSTR VCTK 0.92; Kyutai Unmute voice donation | CC BY 4.0 and CC0 respectively; exact credits below |
| Voice synthesis | Kyutai TTS 1.6B English/French; Moshi MLX | Model CC BY 4.0, runtime MIT; model/runtime are not bundled |
| Music synthesis | ACE-Step 1.5, ACE Studio / StepFun; Audante MLX conversion | Generator/model MIT; no model or reference recording is bundled; [generation provenance](godot/assets/audio/music/provenance.json) |
| Models and embedded textures | Project-owner Meshy paid/private generations | [Provider distribution terms and import provenance](godot/assets/meshes/README.md) |
| Concept art, portraits and material maps | Project-specific OpenAI image generation | [Concept provenance](art/concepts/README.md), [material provenance](godot/assets/textures/materials/README.md) |

## Dialogue voice credits

Junichi Yamagishi, Christophe Veaux, and Kirsten MacDonald (2019). *CSTR VCTK Corpus: English Multi-speaker Corpus for CSTR Voice Cloning Toolkit, version 0.92*. University of Edinburgh, Centre for Speech Technology Research. [DOI: 10.7488/ds/2645](https://doi.org/10.7488/ds/2645). Licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), including its warranty and liability provisions.

Kyutai supplied cleaned conditioning embeddings. Tessa Ward uses `p228_023`, Mara `p339_023`, the civic clerk `p231_023`, Ivo `p226_023`, and the narrator/filing cabinet `p255_023`. The Crimson Raider and vendor use the CC0 donated `dwp_enhanced` voice. Courtesy credit: the voice contributor, Kyutai, and Václav Volhejn (2025), *[Unmute Voice Donation Project](https://unmute.sh/voice-donation)*.

New dialogue was synthesized, trimmed, gain-adjusted, faded and converted for Godot playback. The source speakers did not perform or endorse this game's dialogue. [Full attribution](godot/assets/audio/generated/ATTRIBUTION.md) includes pinned source links and model revisions; production/history manifests map the generated recordings to those sources. No source recordings, conditioning embeddings or model weights ship in the executable package.

## Research references

BioWare and other game names identify design influences. Their game assets are not licensed by this project. See the [research notice](docs/research/NOTICE.md).
