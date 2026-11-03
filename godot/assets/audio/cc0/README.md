# CC0 sound palette

All 28 files in this directory are distributed under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Source pages were checked October 28, 2026. The per-file [provenance manifest](provenance.json) records authors, source filenames, download hashes, processing, and final hashes. Kenney's original license files are included beside those clips.

| Creator | Collection / recording | Included use |
| --- | --- | --- |
| Kenney | [Interface Sounds](https://kenney.nl/assets/interface-sounds) | UI confirmation, selection, rejection, pause |
| Kenney | [RPG Audio](https://kenney.nl/assets/rpg-audio) | Weapon draw/swing, doors |
| Kenney | [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Impacts, bell accents, wood and masonry footsteps |
| Kenney | [Sci-fi Sounds](https://kenney.nl/assets/sci-fi-sounds) | Vanguard weapon shots |
| clif_creates | [Harbor Ambience1](https://freesound.org/people/clif_creates/sounds/254125/) | Quiet secondary dock bed; boats, waves and flapping sails/flags |
| TRP | [Waves gentle distant gulls lake good water detail LAKE ONTARIO TO180522.wav](https://freesound.org/people/TRP/sounds/573192/) | Primary gentle-water bed; recorded at a lake, used as dock water |

The Freesound sources are their public HQ MP3 previews, not the original WAV downloads. Both individual recording pages specify CC0. The preview files were trimmed, converted to stereo 44.1 kHz Vorbis, peak adjusted, and given a two-second wrap crossfade. Kenney Ogg files are unchanged.

Rebuild from the local source cache with:

```sh
python3 tools/audio/prepare_cc0.py "$HOME/Library/Caches/oathshaper/audio-downloads"
```

That command needs ffmpeg. It does not download files or require a Freesound account. The cache contains the four unmodified Kenney packs, two public MP3 previews and `sources.json`.

This license covers these sound assets. It does not change the engine license, dialogue voice terms, or any generated music's provenance.
