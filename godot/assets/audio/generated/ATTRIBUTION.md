# Generated voice provenance and credits

These clips synthesize Oathshaper's authored dialogue using the voice sources credited below. No endorsement by the voice-source contributors is implied.

## Model and runtime

- Model: [Kyutai TTS 1.6B English/French](https://huggingface.co/kyutai/tts-1.6b-en_fr), revision `f65439609986c392cb12df63938abcc550c3fb15`. Model weights: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Credit: Kyutai.
- Runtime: `moshi-mlx 0.2.12`, MIT; `mlx 0.26.5`. Synthesis uses the existing local voice runtime worker at 8-bit quantization with default seed `299792458`. Two selected repair takes use seed `299792459`, recorded per clip in production provenance.
- Voice embeddings: [Kyutai TTS voices](https://huggingface.co/kyutai/tts-voices/blob/323332d33f997de8394f24a193e1a76df720e01a/README.md), revision `323332d33f997de8394f24a193e1a76df720e01a`. The production manifest records each embedding's SHA-256.

## Voice sources

Corsair (`vctk/p228_023.wav`), Mara (`vctk/p339_023.wav`), Clerk (`vctk/p231_023.wav`), Ivo (`vctk/p226_023.wav`), and Filing Cabinet/Narrator (`vctk/p255_023.wav`) use VCTK voice conditioning.

VCTK attribution: Junichi Yamagishi, Christophe Veaux, and Kirsten MacDonald (2019). *CSTR VCTK Corpus: English Multi-speaker Corpus for CSTR Voice Cloning Toolkit, version 0.92*. University of Edinburgh, Centre for Speech Technology Research. [Source and DOI](https://doi.org/10.7488/ds/2645). The [Kyutai voice repository](https://huggingface.co/kyutai/tts-voices/blob/323332d33f997de8394f24a193e1a76df720e01a/README.md) identifies these voice samples as CC BY 4.0.

Vendor uses `voice-donations/dwp_enhanced.wav`, from Kyutai's Unmute Voice Donation Project, licensed [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Credit: the voice contributor and Kyutai. Kyutai identifies enhanced references as cleaned using ai-coustics; the provided embedding is used unchanged.

Transformations: model synthesis of new dialogue conditioned on the listed embeddings, leading/trailing low-energy trimming with margins, bounded gain normalization, and 8 ms fades. Reference recordings and model weights are not bundled. Source labels establish the documented casting basis; no human listening or performance approval is claimed.

These credits record upstream model and voice-source licenses. Keep them with redistributed generated dialogue.

## Current character names and source details

The original credits above remain applicable. Tessa Ward uses the recording identity originally named Corsair. Crimson Raider and Vendor share the donated voice source.

| Role | Source in the pinned Kyutai voice repository |
| --- | --- |
| Tessa Ward / original Corsair | [vctk/p228_023.wav](https://huggingface.co/kyutai/tts-voices/blob/323332d33f997de8394f24a193e1a76df720e01a/vctk/p228_023.wav) |
| Mara | [vctk/p339_023.wav](https://huggingface.co/kyutai/tts-voices/blob/323332d33f997de8394f24a193e1a76df720e01a/vctk/p339_023.wav) |
| Civic clerk | [vctk/p231_023.wav](https://huggingface.co/kyutai/tts-voices/blob/323332d33f997de8394f24a193e1a76df720e01a/vctk/p231_023.wav) |
| Ivo | [vctk/p226_023.wav](https://huggingface.co/kyutai/tts-voices/blob/323332d33f997de8394f24a193e1a76df720e01a/vctk/p226_023.wav) |
| Filing Cabinet / Narrator | [vctk/p255_023.wav](https://huggingface.co/kyutai/tts-voices/blob/323332d33f997de8394f24a193e1a76df720e01a/vctk/p255_023.wav) |
| Crimson Raider / Vendor | [voice-donations/dwp_enhanced.wav](https://huggingface.co/kyutai/tts-voices/blob/323332d33f997de8394f24a193e1a76df720e01a/voice-donations/dwp_enhanced.wav) |

The VCTK source recordings are provided under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), including its [warranty and liability provisions](https://creativecommons.org/licenses/by/4.0/legalcode.en#s5). Kyutai selected microphone 1 recordings of sentence 23 and supplied cleaned conditioning embeddings. The generated dialogue receives the transformations recorded above and Godot's import conversion for playback.

For the donated CC0 source, attribution is a courtesy rather than a license condition. The source's requested academic citation is Václav Volhejn (2025), *Unmute Voice Donation Project*, [unmute.sh/voice-donation](https://unmute.sh/voice-donation).

These source credits do not imply that the source speakers performed or endorsed the game's dialogue. Source and model licenses do not automatically assign CC BY, CC0, or the engine's code license to every generated recording. Per-clip production and history provenance accompany these credits in the release archive's `licenses/` directory.
