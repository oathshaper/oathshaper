# Audio provenance

Local voice production uses Kyutai TTS with the documented VCTK and donated cast in [the production record](../../../docs/voice-production.md). Missing clips still fall back to subtitles and reading time.

Current artifact status: 45 runtime clips contain 207.02 seconds of dialogue, plus six audition clips under `generated/auditions/`. The runtime WAVs passed independent PCM, format, hash, and manifest checks. Production transcription flags are recorded separately, with no human listening or acting-quality claim.

All 45 runtime clips received local automated transcription checks. Twenty-three matched the expected words in at least one check; 22 retain unresolved spelling, pronunciation, or wording flags. The exact transcripts and flagged lookup keys are preserved under `generated/` and summarized in the production record. Those flags have not been accepted or cleared.

`scripts/export-voice-script.py` exports the current dialogue, conditional responses, spoken player choices, and garden briefing/resolution into `godot/content/voice_script.json`. The current script contains 76 unique lines across eight recording identities: Corsair (Tessa Ward), Mara, Crimson Raider, Ivo, Clerk, Vendor, Filing Cabinet, and Narrator. The last two share one neutral voice. Closing the cabinet has no spoken player farewell. The exporter makes no provider calls. Speaker plus exact displayed text identifies the lookup; the asset filename also hashes the spoken text, so changes to either text cannot silently reuse old audio.

`voice_library.gd` resolves imported WAV files under `generated/`. The dialogue panel plays the accepted player response before showing the NPC reply. Back skips the current line, opening the Ledger pauses playback, and closing/loading cancels a pending reply. Chapter modals sequence their named dialogue lines and stop when closed.

Voice generation runs as a local MLX subprocess with pinned cached Kyutai weights. No paid speech service is used. Audition and production manifests under `generated/` record the model, voice embeddings, source text, audio hashes, and objective checks. [Upstream credits and licenses](generated/ATTRIBUTION.md) cover the model and selected voices; public release is a separate owner decision.

Validation: `player_voice_test.gd` passed eight presentation checks using an in-memory silent WAV, and `dialogue_response_test.gd` retained its timed-response checks. These establish playback lifecycle behavior, not voice quality or generated-audio acceptance.
