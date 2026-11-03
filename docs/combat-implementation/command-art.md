# Command equipment and ward art

Date: 2026-10-22. Status: **original procedural presentation implemented and rendered; stage integration pending**. Owned scripts: `godot/scripts/command_weapon.gd` and `godot/scripts/command_construct.gd`. No character, garden, collision, stage, HUD or core file is changed by this slice.

## Weapon attachment

```gdscript
const COMMAND_WEAPON := preload("res://scripts/command_weapon.gd")
# actor already has a rigged ModelSlot, with the existing imported model scale 2x.
var weapon := COMMAND_WEAPON.new()
weapon.name = "Weapon"
actor.add_child(weapon)
weapon.configure("sabre", "buckler")
weapon.set_readied(true)
# On an authoritative new attack animation event, never on an animation impact callback:
weapon.strike()
# Root keeps its existing pause handling:
weapon.pose.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
```

Public interface:

- `configure(main_kind: String, secondary_kind: String = "")`: canonical kinds `sabre`, `staff`, `mace`, `crossbow`, `buckler`, `unarmed` or empty. Root maps authoritative equipment definitions to these visual kinds. Unknown kinds warn and render no invented substitute. Reconfiguration preserves the current readied flag.
- `set_readied(bool)`: hides/shows both equipment attachments and updates the pose. It does not request a draw/sheathe gameplay action.
- `strike() -> bool`: starts bounded presentation motion; a repeated request during the current local strike returns false. This result is not gameplay authorization.
- `pose`, `grip`, `visual`, `offhand_grip`, `offhand_visual`, `kind`, `offhand_kind` remain accessible for the composing stage. `pose` derives from the existing `combat_pose.gd` and preserves its readied/strike-time/count interface.

The right-hand mesh follows `RHand`; the buckler follows an independent `LHand` attachment, with its outward face stabilized relative to the actor. Right/left attachments and modifier are removed when this component leaves the tree. The component assumes the existing rig-local 2x model scale; do not multiply the component again.

Geometry distinguishes:

- Sabre: curved tapered diamond-section blade, bronze guard/knuckle bow and dark grip.
- Buckler: rounded plate, separate rim, central boss, brace and eight rivets.
- Staff: mapped timber shaft, collars, ferrule and original restrained luminous finial.
- Mace: mapped handle and six distinct metal flanges around a bronze head.
- Crossbow: stock, grip, rail/bolt, paired limbs and visible strings. Its brief flash is an aesthetic cue, not an impact event.

Staff and crossbow use their own additive stance, bring the primary grip toward the body, and solve the left arm toward an explicit mesh support grip with a bounded two-joint iteration. Right-hand orientation remains authored. This avoids an unreachable support point while retaining locomotion beneath the upper-body layer. The imported rigs' skin weighting and finger closure remain their existing authored quality; this is not a new production animation set or exact contact solution for every strike phase.

## Construct factory

```gdscript
var art := preload("res://scripts/command_construct.gd").new()
art.name = "Art"
actor.add_child(art)
art.configure("hound") # or "sentinel"
# Root owns actor position/facing/collision and passes committed presentation inputs.
art.set_motion(actor.velocity, current_tick, paused)
# Trigger once for a new authoritative attack presentation:
art.show_attack()
```

Both silhouettes face local `-Z` and stand on local `y=0`; root applies the actor's world pose. They contain no collision, navigation, target selection, resources, damage or gameplay timers.

The hound has four separate hip/knee/paw chains, hydraulic rods, overlapping mapped stone carapace plates, exposed bronze ribs, an articulated jaw, ears, eyes and counterweight tail. The sentinel has three splayed articulated supports, rounded stone/bronze armor, a neck bearing, independent swivel turret and a ringed emitter with recoil. Their scale is authored in meters, unlike rig-local humanoid weapon geometry.

`set_motion(velocity: Vector3, tick: int, paused: bool)` derives gait from the supplied tick and speed, without translating the actor. Paused calls freeze articulation and flash. `show_attack()` records only a cosmetic pulse/recoil origin; it neither advances time nor resolves an effect. A backwards tick clears the earlier flash, so a restored low tick cannot inherit a long future pulse. `configure` replaces the visual parts without retaining stale leg arrays.

The old stage's primitive `Art/Leg_*` loop should be replaced with `Art.set_motion`. Invoke `show_attack()` alongside the stage's new-action animation cue for non-humanoids. Nameplate height, selection rings and health effects stay owned by the stage.

## Provenance and UVs

All new shapes, proportions and articulation code were authored in these two scripts for this task. There are no new downloaded models, generated raster textures, external licenses or GLB files.

Existing repository textures are reused without modification:

- `res://assets/textures/materials/weathered_timber_albedo.png` on weapon shafts/stocks.
- `res://assets/textures/materials/coastal_rock_albedo.png` on ward stone plates.

Their existing provenance remains in `godot/assets/textures/materials/README.md` and `SECONDARY_PROVENANCE.md`. Primitive sphere/cylinder/torus meshes provide ordinary UV coordinates; the custom sabre surface supplies planar UVs and generated normals explicitly. No pixel texture was created and no material relies on a missing UV channel. Bronze, steel, dark metal and small ward lights use scalar material parameters; the stone and wood surfaces use the mapped assets.

## Verification and captures

Godot 4.3 parsed both scripts. A separate short-lived fixture process instantiated all four existing rigged party models, attached the five requested kinds, and rendered front and rear checks. It verified RHand/LHand attachment, geometry presence, readied/sheath visibility, local duplicate-strike suppression, four/three support chains, paused articulation and host-triggered pulse behavior. The first grip-distance check correctly failed because the support target exceeded the left arm length; the stance/solve repair then passed.

Final rendered run: **zero failures**. Measured skeleton support-grip gaps in the captured ready stance were approximately **0.4 mm for the staff** and **11.3 mm for the crossbow**. These measure attachment targets, not fingertip mesh contact or all animation phases. The visible weapons and constructs were inspected in the actual Godot renderer at 1440×900.

Current local artifacts:

- `/tmp/oathshaper_command_art_test.gd`: bounded fixture/capture driver.
- `/tmp/oathshaper-command-weapons.png`: front view of actual rigs and all weapon types.
- `/tmp/oathshaper-command-constructs.png`: hound and sentinel studio view.

Re-run the existing driver with:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot --resolution 1440x900 \
  --script /tmp/oathshaper_command_art_test.gd
```

No resident was restarted and no full project build or external asset generation was performed. Root owns integration and commits only these two scripts plus this note. Remaining gates: map actual equipment definitions, trigger visuals once from authoritative actions, validate in the garden's lighting/camera, check restored/paused presentation, and profile draw/skin costs in the integrated scene. This is readable tech-demo art, not AAA character/animation acceptance.
