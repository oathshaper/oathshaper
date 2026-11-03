# Game audio libraries and music generation

Checked October 28, 2026. The subsequent [implementation report](../audio-20261028/README.md) records the CC0 sound integration and ACE-Step installation. The initial music trial was interrupted by a system restart; generation remains unverified. See the [research notice](NOTICE.md).

## Suggested starting point

Use CC0 sound effects for the engine's editable examples, with a per-file source manifest. Test local ACE-Step music generation separately from the game's existing dialogue voices. Keep generated music optional so students can also supply recordings or compositions.

| Source | Useful for | Verified terms / practical boundary |
| --- | --- | --- |
| [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio) | Foley, footsteps, weapons; 50 files | CC0 on the pack page |
| [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Impacts; 130 files | CC0 on the pack page |
| [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | Selection, confirmation, menu feedback; 100 files | CC0 on the pack page |
| [Freesound](https://freesound.org/help/faq/) | Waves, gulls, wood creaks, wind | Per-upload licenses. Prefer CC0; CC BY needs attribution; exclude NC from a commercially reusable starter set |
| [Incompetech](https://web.incompetech.com/music/royalty-free/licenses/) | Existing instrumental compositions | Free Creative Commons option requires attribution; preserve the selected track's specific license and credit |
| [ACE-Step 1.5](https://github.com/ace-step/ACE-Step-1.5) | Local AI music generation | MIT project; official [model card](https://huggingface.co/ACE-Step/acestep-v15-base) explicitly permits commercial output. Upstream documents Apple Silicon/MLX. the local workstation performance and musical quality remain untested |
| [Abundant Music](https://pernyblom.github.io/abundant-music/index.html) | Non-ML procedural composition and MIDI export | The author's FAQ dedicates generated songs to CC0. Useful for a lesson in seeded musical rules; browser operation and the chosen rendering instruments still need testing |
| [Suno](https://about.suno.com/terms) | Hosted AI music generation | Commercial use depends on a permitted download and applicable service tier. [September 2026 update](https://suno.com/blog/suno-updates-tos) restricts trial downloads to personal use; do not assume free previews have release rights |

CC0 is useful here because editable engine examples distribute the audio files themselves. Permission to include stock audio in a finished game does not automatically authorize a reusable source library. Generated output rights also remain separate from the model's code license; the ACE-Step commercial-output statement comes from its model card.

## Lantern Quay audio plan (proposed)

- **UI:** quiet selection, confirmed queued action, rejection, pause and resume cues. Repeated focus changes need a cooldown.
- **Movement:** several variations each for timber and stone, triggered at foot contact rather than on a fixed timer.
- **Combat:** separate swings, armor impacts, shield blocks, misses, healing and mechanical adversary sounds. Limit simultaneous voices and vary samples modestly.
- **Environment:** a restrained harbor bed, local water/rope/wood sources, and a lantern ignition cue. Avoid a constant foreground gull loop.
- **Music:** related exploration, tension and combat cues, plus a short resolution. Try instrumental strings, sparse woodwinds and restrained hand percussion; judge results in the scene before choosing a palette.
- **Mix:** separate Music, Ambience, SFX, UI and Dialogue buses; duck music while characters speak. Pre-render and loop/crossfade music in Godot. Do not require live model inference on a Steam Deck.

For AI music, generation does not itself establish a seamless loop or interchangeable stems. Verify the loop boundary, tempo, key and transitions; author a crossfade if independent generations do not align. Record model/version, prompt, seed, source references, output hash and any editing. Use original descriptions rather than asking for a named game's score.

## Teaching extension

The first project can offer a small licensed sound palette and an optional local generation adapter. Later lessons expose event-to-sound mapping, foot-contact markers, spatial attenuation, voice limits, mixing, loop editing and provenance. A useful exercise compares a technically valid but poorly mixed combat scene with one where dialogue and confirmation cues remain audible.
