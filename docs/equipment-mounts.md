# Weapon mesh handoff

The runtime contract is `godot/content/equipment_mounts.json`, applied by `godot/scripts/equipment_mount.gd` to Command weapons. The same `ModelSlot`/`Art` skeleton interface can be used by party members and rigged adversaries.

The October 28 supplied sabre, buckler, staff and mace are now imported through this contract. See [source manifest](../godot/assets/meshes/equipment/manifest.json) and [rendered integration evidence](party-assets-20261028/README.md). Tessa's new 72-joint rig supplies finger landmarks for palm placement and finger curl; the legacy rigs retain their configured hand transforms. Imported weapons keep metre dimensions across both rig scales.

## Asset requirements

- GLB or Godot scene in meters, with a normalized root and applied object scale.
- A child node named `PrimaryGrip`: origin at the palm contact point; orientation establishes the grip frame. For the supplied rigs, the configured mount corrects the imported hand axes.
- Two-handed weapons require `SupportGrip`, placed where the other palm contacts the weapon. The existing arm solver consumes this socket.
- Sword: `ImpactBase` and `ImpactTip`, on the blade edge. Staff/mace: `ImpactTip`. Bow/gun: `Muzzle`. Shield: `GuardCenter`.
- A shield's primary grip belongs behind the shield face, at its handle. Leave hand clearance between grip and shell.
- Separate moving parts from the weapon root when they need animation. Include material textures, authorship/provider provenance, dimensions and redistribution terms.

Set the weapon's `scene` in the manifest after import. The mount aligns the primary grip with the configured palm transform and compensates for the character rig's scale. An imported two-handed asset missing a support socket is rejected. Existing procedural weapons remain fallback art and expose named markers for inspection.

Sockets describe presentation. Damage, reach, resource costs and hit timing remain engine-owned; moving an impact marker cannot change a combat outcome.

## Original art brief

| Asset | Dimensions | Pose / contacts |
| --- | --- | --- |
| Harbor sabre | about 95 cm overall; handle 11–13 cm | Straight grip reference, guard clear of knuckles; edge and tip marked |
| Dock buckler | about 55 cm diameter | Rear handle and palm clearance; rim separate from forearm |
| Storm staff | about 175 cm overall | Two grips about 35–50 cm apart, both reachable |
| Light crossbow | about 70 cm long | Trigger grip, foregrip, muzzle and string plane |

Create clean side/front reference views before meshing. Keep loose straps and decorative protrusions away from hand contacts. Review the imported asset on player, Mara and Ivo at rest, during a strike and while walking.

The legacy NPC rigs contain `RHand` and `LHand`, but **no finger bones**. Tessa now has finger bones; closed NPC grips still need weighted finger joints or an authored alternate hand mesh. Hand attachment and arm IK cannot supply missing finger deformation.

Synchronized paired melee animations, contact timing, sheath meshes and secondary-hand release during gestures are not implemented by this contract.
