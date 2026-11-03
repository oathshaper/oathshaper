# Music and garden confrontation

## Changes

- Integrated the user's selected clarity audition as a 28.5-second looping harbor instrumental. Music has its own persistent volume control and ducks during dialogue. Playback continues across rooms and pause menus. This is one exploration track used throughout the demo, including combat; no separate battle score was generated.
- Fixed the main menu's chapter entry, which still opened the old voiced text briefing. Command, Flow and Vanguard now play the same automatic confrontation used by the campaign: establishing shot, Ivo, Tessa, then the Crimson Raider. Subtitles and existing voices advance without choices. Skip is optional.
- The menu route stages the scene in its existing garden viewport. Combat input and simulation stay suspended until the scene ends. Temporary actors, poses, held weapons, HUD and camera state are restored before the handoff. The campaign retains its in-world gate sequence and does not play it twice.
- Removed the story speech from preparation/retry menus. Those menus still expose equipment and training controls.
- Matched the opening's 160-pixel subtitle panel, left-aligned speaker/dialogue, type sizes, padding and border treatment. The confrontation remains automatic; its footer offers Skip only.

## Verification

- [Rendered audio test](verification/audio.txt): **62 checks, zero failures**. Loop import, independent Music bus, continuous room transitions, speech ducking/recovery, mute, settings persistence, pause behavior and six sliders/buttons fitting 1280×800.
- [Rendered cutscene test](verification/confrontation.json): **73 checks, zero failures**. Natural timed campaign playback, exact voice clips, no choices, keyboard/controller skip, actor restoration, all three campaign routes and all three menu routes. Menu tests also exercise native mouse/controller Skip and confirm no input leaks into a combat menu.
- Inspected native captures: [Ivo](images/ivo.png), [Tessa](images/tessa.png), [raider](images/raider.png), [audio settings](images/audio-settings.png). Adjusted the menu scene's camera positions to keep faces clear of foreground actors and foliage. Its subtitle layer is above the menu's embedded viewport.
- Final music SHA-256 matches its [provenance manifest](../../godot/assets/audio/music/provenance.json).
- [Campaign route](verification/chapter-route.json): **224 checks, zero assertion failures**, including threshold entry, combat victory, payroll recovery and return to the quay. This headless run emits Godot dummy-renderer mesh cleanup diagnostics and a resource-exit warning, retained in its log; the rendered cutscene and audio checks exit without script errors.

Tests ran serially on the local Mac. No music model was loaded for integration. Listening balance in a full playthrough remains the user's next check.

## Try it

Run the project normally. Music begins on the title screen; use **Audio → Music** to adjust it. **The Quay Robbery** entry plays the confrontation before combat. A new or loaded journey plays it when the party crosses the garden gate. The existing campaign save format is unchanged.
