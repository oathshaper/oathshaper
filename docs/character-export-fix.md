# Character placeholders in exported demos

The November 3 Mac download displayed colored oval bodies over the character models in the quay and office. The models and textures were present. The exported scene loaded an empty `placeholder_names` list for every character, so the model slot never hid the primitive bodies and accessories.

## Cause and correction

`character_model_slot.gd` declared an exported `PackedStringArray` with an Array-literal default (`[]`). Godot's conversion of text scenes into binary resources discarded the scene's saved values for that declaration. Export and runtime completed without an error.

A minimal export with the project's exact Godot 4.3 version reproduced the loss: the saved `Body, Mantle` list became empty. Changing the initializer to `PackedStringArray()` preserved both entries in the exported pack. This matches the behavior described in [Godot issue 124452](https://github.com/godotengine/godot/issues/124452), whose report uses a later engine version. The project contains one exported packed-array declaration using this initializer pattern.

The correction uses the explicit packed-array constructor. Scene content, models, textures, and saved-game format remain the same.

## Regression coverage

The new `character_presentation_test.gd` exercises the actual packaged story scene. It checks the expected placeholder names independently of the runtime list, checks that every primitive body/accessory is hidden, and verifies the imported rig and visible textured surfaces. It covers the opening, quay, office, and a reloaded fixture journey. Rendered runs capture screenshots of the first three states.

The test reproduced **52 failures in 109 checks** on the original release. Its existing checks had validated story progression and combat UI without checking for visible story-character placeholders. The new suite is required by both native packaged acceptance and the publication gate. Release notes record results for the replacement downloads.

Acceptance logs and fixture saves use the run's own output directory, preserving the player's normal log and save locations.
