# Party motion, grips, and garden victory — October 29, 2026

## Changes

- Tessa's normal keyboard travel selected the old Meshy Run above 2.8 m/s, even though the slower Walk had already been replaced. Run now uses the CC0 Quaternius `Jog_Fwd_Loop`, retargeted onto her existing 72-joint skin. Its phase matches Walk; calibrated travel is 3.537 m/cycle. Walk remains 1.138 m/cycle. The original texture payloads, triangle counts, and joint counts are preserved for all three edited actors ([receipt](asset-preservation.json)).
- Readied arms start from each actor's authored Idle pose before guard/strike changes. The legs continue their locomotion clip. This prevents the running arm swing from combining with the weapon pose.
- The sabre's blade and knuckle guard are rotated around its grip to follow the fingers. Tessa's finger curl now closes toward the handle. Bucklers have a separate orientation from weapon shafts and follow the wrist; the former per-frame world-orientation override is removed.
- Ivo's generic wrist joints lay below his hands and ignored the different depths of his left and right arms. Arm landmarks are fitted to the source mesh and the skin is regenerated. Mara also has fitted wrists; her coat-weight correction excludes the curved sleeves with a tapered distance from the arm bones. Their leg animation authoring remains unchanged.
- A two-handed staff still occupies both inventory slots, but draws only one physical weapon. Mara's support-hand reach now aligns the palm with `SupportGrip`, rather than putting her wrist at that point.
- A campaign victory in Command, Flow, or Vanguard automatically leaves combat. In the cleared garden, Ivo and Mara deliver their existing resolution lines as a choiceless scene. It uses the opening's 160px, left-aligned subtitle bar. Completion or Skip releases exploration beside the raider. The payroll remains uncollected until the player interacts with it. Standalone practice encounters retain their camp/retry flow.

## Verification

Godot 4.3 on the local Mac, run serially:

| Check | Result |
| --- | --- |
| Party assets, gaits, duplicate staff, hand contact at rest/strike/movement | 54 checks, 0 failures; native rendered run |
| Full Command campaign, earned victory, timed resolution, loot, return and save/load | 230 checks, 0 failures; native rendered run |
| Precombat scene and both chapter entry routes for all three styles | 73 checks, 0 failures |
| Attachment callback lifecycle, sockets, and physical scale | 12 checks, 0 failures |
| Weighted GLB imports | All five rigs pass structure, weights, and clip checks |

The hand-contact check skins vertices with the final bone matrices during `skeleton_updated`. It requires the grip to be within 5 cm of a hand surface with more than half its weight on that hand bone. This caught Ivo's missing hand influence; comparing a weapon socket only with its own attachment transform did not. The signal timing follows Godot's [Skeleton3D contract](https://docs.godotengine.org/en/4.3/classes/class_skeleton3d.html#signals).

The campaign test advances the cinematic timers to verify automatic completion, checks that both exact voice clips exist, then collects and returns the payroll. It does not substitute an arbitrary victory flag for winning the encounter. Character approaches use fixture positions. The headless precombat suite emits the previously observed dummy-renderer null-mesh cleanup diagnostics; its assertions pass. No physical Steam Deck run was performed.

## Rendered evidence

- [Tessa's grip](images/tessa-grip.png)
- [Ivo's weapons and Mara's staff](images/ivo-grip.png)
- [Party moving with readied weapons](images/party-moving-armed.png)
- [Party walking with weapons sheathed](images/party-walking.png)
- [Retargeted jog, front and side phases](images/run-cycle.png)
- [Ivo's resolution shot](images/resolution-ivo.png)
- [Mara's resolution shot](images/resolution-mara.png)

These are runtime captures, not concept illustrations. The NPC rigs still have one bone per hand, so their fingers remain sculpted poses. Fine hand animation and cloth simulation remain future art work; Tessa has articulated fingers. The imported assets and generated attack poses should still be reviewed in motion before treating them as production animation.

Reproduction commands and source licensing are in the [animation library notes](../../tools/rigging/sources/quaternius/README.md). Rebuild the NPC derivatives with `blender -b --python-exit-code 1 --python tools/rigging/rig_characters.py -- ivo mara`, then import the project in Godot.
