# Local voice production

The owner authorized local speech production using the existing local voice runtime Kyutai installation. The generator reads that installation and its cached model without modifying local voice runtime. It creates a private cache under `/tmp/oathshaper-voice-production`, links the existing pinned model files, downloads only the selected small voice embeddings, then runs one local worker per voice sequentially. There are no paid API calls, new model installations, or network speech services.

## Cast and evidence

| Character | Preset | Official selector label | Voice-source license |
| --- | --- | --- | --- |
| Corsair | `vctk/p228_023.wav` | Anna, female, conversation | CC BY 4.0 |
| Mara | `vctk/p339_023.wav` | Jane, female, conversation | CC BY 4.0 |
| Clerk | `vctk/p231_023.wav` | VCTK 231, UK, female | CC BY 4.0 |
| Ivo | `vctk/p226_023.wav` | VCTK 226, UK, male | CC BY 4.0 |
| Vendor | `voice-donations/dwp_enhanced.wav` | Voice donation dwp, Australian, male | CC0 |
| Filing Cabinet and Narrator | `vctk/p255_023.wav` | VCTK 255, UK, male | CC BY 4.0 |

The labels were checked in [Kyutai's official voice selector](https://kyutai.org/tts/) on 2026-10-22. Its VCTK labels appear on enhanced versions of the same speakers; this pinned TTS 1.6B cache supplies compatible embeddings for the original VCTK names. The cast uses those original embeddings. [The pinned voice repository documents the distinct source licenses](https://huggingface.co/kyutai/tts-voices/blob/323332d33f997de8394f24a193e1a76df720e01a/README.md).

These are documented cast choices, not listening judgments. Age impression, timbre, emotional delivery, accent consistency, and suitability for each character require listening. No Expresso or EARS samples are used. Complete source credits and transformations are in [the generated-audio attribution](../godot/assets/audio/generated/ATTRIBUTION.md).

## Reproduce and resume

The optional generator requires an existing Kyutai JSON-lines worker, its Python environment at `tmp/kyutai-venv/bin/python`, its worker at `src/providers/kyutai_mlx_worker.py`, and the pinned model under `tmp/hf-cache/hub`. Set `VOICE_RUNTIME_ROOT` to that installation. The game uses bundled recordings and needs none of these synthesis tools at runtime. No sibling checkout is selected automatically.

```sh
python3 scripts/generate-local-voices.py auditions --runtime-root "$VOICE_RUNTIME_ROOT"
python3 scripts/generate-local-voices.py batch --runtime-root "$VOICE_RUNTIME_ROOT"
```

For a fresh production, the first command produces six comparable audition WAVs in `godot/assets/audio/generated/auditions/`. The second requires those auditions to have passed objective PCM checks and produces the current 45 dialogue assets at the exact paths in `godot/content/voice_script.json`. Run the second command alone to verify/resume the checked-in production; the historical audition record belongs to its original script and generator. The generator preserves the subtitle lookup identity while checking that the asset filename hashes the speaker, displayed text, and spoken text. The current longest line has 204 characters; longer text is split at sentence or word boundaries to respect the worker's 500-character input limit.

Each worker stays loaded for all lines assigned to its voice, then exits before the next worker loads. Generated audio is 24 kHz mono, signed 16-bit PCM in WAV containers. Processing trims low-energy edges with 120/180 ms margins, applies a bounded gain, and adds 8 ms fades. Empty/silent output, insufficient active audio, implausible duration, clipping, missing frames, and worker errors fail visibly. A synthesis request has a five-minute timeout.

The Oathshaper wrapper resets the language model's transformer caches before every utterance. The installed local voice runtime worker resets Mimi's audio decoder, but its installed `moshi-mlx` version retains model-owned language context across new `LmGen` instances. A first production attempt exposed this through worsening transcripts and a nine-word question reduced to 0.96 seconds. That attempt was retired outside the game assets. The wrapper fixes the issue without modifying local voice runtime, its environment, or installed packages; its identity and the generator source hash are recorded in production provenance. A text-to-duration check also rejects implausibly short results.

`audition-provenance.json` and `production-provenance.json` record the pinned model and voice revisions, model/embedding/worker hashes, exact source text, chunking, output hashes, timing, and PCM measurements. Successfully recorded clips can be resumed without regenerating them. Existing files without matching provenance are not overwritten. Changed scripts or casts require reconciliation before reuse.

Objective audio checks establish format and non-silent content, not intelligibility or acting quality. Any automated transcription comparison is a separate spot check, not human listening. In-game sequencing and playback acceptance belong to the game validation pass.

## Validation record

On 2026-10-22, six audition WAVs completed: Corsair 5.28 s, Mara 4.08 s, Clerk 3.68 s, Ivo 4.50 s, Vendor 3.74 s, and Filing Cabinet 4.14 s. Total: 25.42 seconds, 1,220,424 bytes. All six passed energy, duration, clipping, frame-order, WAV-format, and independent output-hash checks. A silent PCM fixture was rejected; the long-text splitter preserved all words across the 500-character boundary.

An offline transcription spot check used the already-cached Whisper base model on CPU. All six transcriptions recovered the expected words; some used the British spelling `harbour` for `harbor`. The raw transcripts and unadjusted word-error measurements remain in `generated/audition-transcription-check.json`. Neither this check nor the official casting labels establish human listening or performance acceptance.

The workstation was confirmed to be the local workstation, and the owner authorized the full local batch. The corrected run produced 46 clips. A subsequent script correction removed Corsair's farewell when closing the filing cabinet, leaving 45 runtime clips. After the bounded repair pass below, the bank contains **207.02 seconds and 9,938,940 WAV bytes**. `production-provenance.json` preserves the original generation manifest hash, current 45-line manifest hash, and the omitted action's identity. The rejected first attempt and omitted clip are outside the game assets.

All 45 remaining clips passed independent WAV-format, PCM energy/peak, duration, output-hash, and exact-manifest mapping checks; they have 45 distinct waveform hashes. The measurements are in `generated/production-validation.json`. Current voice-script SHA-256: `5f79071d87323ef9f920df8c51bfe434e4081277c97376bb1fa8fa640107e08f`.

Offline Whisper base transcribed every production clip. The current primary report matches 21 lines exactly after ignoring punctuation/case; 24 have differences, totaling 42 word edits across 654 reference words (6.42%). A follow-up used 0.5-second silent padding at each edge and beam search, with no expected-text prompt. Across the checks, 23 clips match exactly at least once; **22 transcription flags remain unresolved and have not been accepted or cleared**. Raw outputs and unadjusted scores are preserved in `generated/production-transcription-check.json` and `generated/production-transcription-followup.json`, with their keys listed in production provenance.

The remaining flags include spelling/homophones (`harbour`, `pier`/`peer`, `quay`/`key`), proper names (`Ivo`/`Evo`), and wording concerns: Corsair's `east gate` is recognized as `escape`, and Mara's `pier lamp` remains unclear to the recognizer. These are automated recognition results, not determinations of what a listener hears. No performance-quality acceptance is claimed.

### Bounded repair comparison

One alternate take was generated for each of four flagged lines, with the exact text, cast, model, and quantization unchanged. Each take used a fresh worker and alternate seed `299792459`. Both unprompted transcription methods were compared with the baseline. Only the two objectively improved takes replaced runtime assets; their per-clip seeds, adapter hash, superseded hashes, and comparison evidence are recorded in `generated/production-repair-comparison.json` and production provenance. The manifest is unchanged.

| Line | Decision | Automated evidence |
| --- | --- | --- |
| Corsair's lantern-tower question | Replace | Both transcripts recover the full question, including `What`. |
| Mara's direction to Ivo | Replace | Both comparisons improve; the padded check recovers all words apart from the `Ivo`/`Evo` spelling. |
| Corsair's east-gate question | Retain original | Candidate changes the question to `We will open the escape`; it is worse. |
| Mara's pier-lamp response | Retain original | Both candidate checks render `pier lamp` as `Peerland`; no improvement. |

The selection comparison treated only `Ivo`/`Evo` and `pier`/`peer` as spelling equivalents; raw transcripts and scores remain unchanged. The original WAVs and unused candidates are outside runtime assets. No further attempts were made. The two unresolved target phrases remain flagged.

The batch resume command completed successfully after filtering the nonspoken cabinet action. It verified the source, generator, model/embedding, and output hashes and generated no new clips. Native game import, sequencing, and pause/skip acceptance are recorded by the separate integration pass.

Auditions were each produced in a fresh worker, so they did not reuse language context. No local voice runtime files, environment, or model cache were modified. Preserve the [voice source credits](../godot/assets/audio/generated/ATTRIBUTION.md) and per-clip provenance when distributing these recordings.
