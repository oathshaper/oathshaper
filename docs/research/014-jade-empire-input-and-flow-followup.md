# Jade Empire controls and the Flow playtest

Date: 1 November 2026. Depth: focused. Two primary documents, one hosted by the distributor and one preserved by a manual archive.

This is independent UX research under the [research and third-party rights notice](NOTICE.md), not an affiliation or an asset license. The repository includes original analysis and source links, not copies of the manuals.

## Research summary

Mouse attacks are consistent with Jade Empire's PC edition. The current Flow controller layout is substantially different from the Xbox original, and changing labels alone would not recover its combat feel. The playtest also exposed two independent defects: an incorrect weapon presentation and a target that remained selected after defeat.

## Verified reference controls

The original Xbox manual assigns A to attack, X to power, B to block, Y to Focus, the triggers to left/right targeting and the D-pad to styles. A+X performs an area attack; B plus movement evades. Both triggers release target lock. Back pauses and Start opens the menu. These are original Xbox controls, not a claim about the PC port's gamepad defaults. [Xbox manual, printed pp. 4–5 and 18–19](https://manualzz.com/doc/3320223/microsoft-jade-empire-user-manual).

The PC manual assigns LMB/RMB to normal/power attacks, both together to area attack, Space or MMB to block, directional double taps to evasion, Tab/Q/wheel to targeting and T to free targeting. Shift heals, E enhances attacks, F enables Focus and P pauses. Number keys select styles. [Special Edition PC manual, printed pp. 9–10 and 19–20](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/7110/manuals/Jade%20Empire%20manual%20revised.pdf?t=1729270453).

## What creates the rhythm

Normal attacks interrupt slower power attacks; power attacks defeat guards; guards stop normal and area attacks. Repeated attacks form combinations. Support or magic setups can lead into a martial power finisher. Weapon attacks consume Focus, while healing competes with magic for Chi. One follower accompanies the player and has Attack/Support behavior. [PC manual, printed pp. 11–12, 17–23](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/7110/manuals/Jade%20Empire%20manual%20revised.pdf?t=1729270453).

The Xbox manual also distinguishes locked combat movement from a free-target mode. This supports prioritizing target-facing movement and directional evasion in Flow; precise orbit and animation timing still need direct reference playtesting. [Xbox manual, printed pp. 18–19](https://manualzz.com/doc/3320223/microsoft-jade-empire-user-manual).

## Current Oathshaper differences

Verified in `flow_trial.gd`, `flow_hud.gd`, `flow_stage.gd` and the Rust `flow` module:

| Interaction | Current Flow | Consequence |
| --- | --- | --- |
| Controller attack / power | RT / Y | Face-button habits from the original do not transfer. |
| Controller guard / evade | LT / B | Guard-plus-direction is not one combined action. |
| Controller target / Focus | R3 / RB | Target cycling and time control are in different places. |
| Keyboard guard / evade / heal | Shift / Space / Q | Familiar PC verbs have different bindings. |
| Movement | Camera-relative movement; aim turns on attack | Target selection does not establish a complete locked movement mode. |
| Follow-up input | Attacks during an active action reject | Repeated input can produce error messages instead of continuing a combination. |
| Combo | Still-water setup into Stone-palm power exists | The small text status does not teach the setup/finisher relationship well. |
| Followers | Mara and Ivo together | An intentional story/party adaptation; retain both rather than silently dropping Ivo. |
| HUD | Large panels and clickable attack controls | Much of the fight is framed as menu operation; the central view needs more room. |

## Bounded fixes made in this follow-up

1. Harbor blade projects the sabre; Mara retains her staff. The HUD describes a sabre and the native test checks the actual equipped visual.
2. A fallen selected enemy hands off to a living opponent, preferring unobstructed opponents then proximity. A living manual choice is retained. The view and attack admission share this selection, including when restoring an older v2 save with a dead target.
3. The target display shows distance and obstruction. Range failure and obstruction now have separate explanations. With no surviving enemies, the display clears the target.
4. Mouse wheel and Shift+Tab cycle in opposite directions through a spatially ordered enemy list. These are Oathshaper adaptations; they are not evidence of exact source-game targeting behavior.

## Recommended next implementation

Retain mouse attacks. Offer an explicit classic controller preset with A attack, X power, B guard/directional evade, Y Focus, trigger targeting and D-pad styles. Map the original Black/White functions to modern shoulder buttons and keep a separately bound area attack for accessibility. Display the active preset before combat.

Then implement target-facing strafe versus free movement, a short bounded follow-up input buffer, readable setup/finisher feedback and attack/guard transition animation. Test the buffer at recovery boundaries, style changes, target death, pause, insufficient resources and scene transitions. Do not let a buffered action spend twice or execute after a menu closes unexpectedly.

These are recommendations, not implemented features. The current turn repairs the weapon and targeting bugs without silently remapping the controls Ben just tested.

## Research limits and method

The fixes passed 18 Rust Flow tests, 97 native presentation checks and 740 native encounter checks, including target validity through each defeat and clearing selection at victory. Clippy passed with warnings denied. Rendered output was inspected for the corrected equipment and HUD. This does not establish animation parity or human combat feel.

Searched for the official PC and Xbox combat controls, then read the control tables and combat sections of both manuals. The PC PDF is publisher material served through Steam; the Xbox text is an archived reproduction with imperfect icon extraction. The original Xbox Black/White icons need a visual reference before exact modern remapping.

The manuals establish intended controls and rules, not latency, dead zones, camera damping, target-death priority or animation timing. Automatic target handoff here is an Oathshaper usability decision. No physical controller/Steam Deck acceptance or full Jade Empire fidelity is claimed.

## Follow-up: pause and Focus

Jade Empire allows tactical pause: Back on the original Xbox and P on PC. The paused state permits changing styles and targets. Its weapon attacks consume Focus; the manuals describe replenishment from power-ups and shrines. [Xbox manual](https://manualzz.com/doc/3320223/microsoft-jade-empire-user-manual), [PC manual, printed pp. 19–20](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/7110/manuals/Jade%20Empire%20manual%20revised.pdf?t=1729270453).

The requested Flow adjustment deliberately makes ordinary sabre attacks free and adds timed Focus recovery; power attacks and slow time retain a cost. These are prototype balance decisions, not source-game findings. The [implementation receipt](../combat-implementation/garden-outcome-20261101.md) separates native input coverage from the reported, uncaptured preceding input sequence.
