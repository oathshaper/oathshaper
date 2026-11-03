# reference prototype reuse audit

Reference inspected read-only at commit `778159cee98bb07a3e7dd70e8f01b9190a18bbaf`; working tree was clean. No files were copied.

| Surface | Decision | Provenance |
| --- | --- | --- |
| Camera | Adapt the bounded yaw/pitch/zoom concept; Oathshaper's mouse orbit, planar pan, wheel zoom, and controller camera handling are original code. No source copied. | `rules/core/camera_controller.gd` |
| Ownership | Adapt presentation/rules separation. | `rules/core/visual_prototype.gd` |
| Tests | Adapt scene/UI contract testing style. | `rules/tests/test_visual_prototype.gd` |
| Pixel volumes | Keep cache/readability lessons for later; M1 uses primitive geometry. | `scenes/pixel_volume_builder.gd`, ADR-0004 |
| Mesh prior | Exclude as asset-specific. | `scenes/mesh_prior_pixel_volume_builder.gd` |

Starfinder/Pathfinder rules, characters, settings, art, textures, GLBs, dialogue and audio remain excluded pending rights verification. M1 source, geometry and dialogue are original and MIT licensed.
