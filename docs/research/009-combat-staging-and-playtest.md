# Combat staging and the first playthrough

Date: 2026-10-22. Scope: Command combat, the quay-to-garden story, and presentation feedback.

This is independent UX research. See [research and rights notice](NOTICE.md). No reference-game code, art, animations or sounds were imported.

## What KOTOR documents

BioWare's original developers describe an over-the-shoulder camera that focuses on the hostile target during combat. They also describe paired attack/defense choreography, with 1.5-second animation sequences inside individual three-second combat rounds. This is evidence that staging and camera composition were designed together. It does not establish exact camera offsets or a particular crowd-separation algorithm. Source: Casey Hudson, Ray Muzyka and James Ohlen, [2003 combat postmortem, republished by Game Developer](https://www.gamedeveloper.com/design/classic-postmortem-bioware-s-i-star-wars-knights-of-the-old-republic-i-), sections “Combat Without Compromise” and combat animation.

The [official PC manual](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/32370/manuals/KOTORI_Manual.pdf?t=1681144833) documents target cycling, leader switching, pause, queued actions and mouse camera control. The user's supplied screenshots also show perspective depth, visible ground and readable bodies. Neither source calls for a fixed isometric view.

Dragon Age: Origins offers a wider camera range, including an elevated tactical view. That is a useful comparison, not the camera specification for Command. Source: [official PC manual](https://eaassets-a.akamaihd.net/eahelp/manuals/dragon-age-origins-manuals_PC.pdf), camera controls.

## Oathshaper decisions

These values are project choices, not measurements of KOTOR:

- Keep a perspective camera. Frame the controlled actor and selected enemy together at an oblique angle, with a modest elevation and visible horizon.
- Reserve screen space for the command bar and keep the fighters' feet above it. Increase distance for a remote target without framing the entire battlefield.
- Try nearby camera positions when blocked. Model tree crowns with rounded bounds; the previous boxes occupied empty air under branches. Sweep the near-plane volume after smoothing as well as before it.
- Give approaching melee actors a choice of positions within reach. Query the existing geometry adapter for the approach and its fallback.
- Apply bounded separation in authoritative combat coordinates. Rooted and stunned actors stay put; casts in windup do not slide. Reject unobserved/blocked separation paths and prevent steps from tunneling through another actor.
- Keep possession and manual orders authoritative over companion AI. A healer prioritizes a reachable injured ally, considers health fraction, avoids an already pending heal, and can spend its emergency reserve.

The current animation system remains additive, individual posing. It does not yet implement synchronized attacker/defender clips, foot locking, contact-matched parries or finger articulation. These are separate content and animation tasks.

## Story review

The actual dialogue and chapter were exported to [the before snapshot](../playtest-review/story-before.md). Obelus's fiction review was executed and its [raw findings](../playtest-review/obelus-before.json) retained. That deterministic pass only flagged weak lexical candidates; it did not diagnose plot causality. Its findings were not used as proof that the plot was sound.

The Humanizer route selected a fiction critic. The critic identified five material gaps:

1. The oil choice preceded any clear person or problem worth helping.
2. The player was sent for records before learning what the records would solve.
3. A light/safety problem became a property dispute without connecting the two.
4. The sentries, their command seal and the reason to fight were unexplained.
5. The ending claimed a forgery more strongly than the evidence established.

One structural revision addresses those gaps: a skippable opening introduces Mara's stranded crew, the flooded road and the hostile watch machines. Optional questions explain the lamp, the public route and the command seal. The ledger establishes access; Ivo guides the crossing; defeating the machines clears the route. The ending identifies a private seal used to close a public walk rather than inventing proof of forgery. Keeping the oil still leaves a playable route.

The embedding audit ran locally and found no sentence/paragraph pairs above its configured repetition thresholds. That is a repetition check, not a comprehension study. A new first-time playthrough, especially by the original young tester, remains the acceptance test for whether the story is understandable and compelling.

## Feedback and assets

Command now has original synthesized select, queue, rejection, pause, hit, miss, healing and power cues. Committed log IDs suppress repeats when a view is repainted; menu previews are muted. The controls entry is available from the combat header and camp.

[Equipment mounts](../equipment-mounts.md) define primary and supporting grips and effect sockets. Final weapon art is still pending. The current character GLBs have hand bones but no finger bones, so a socket alone cannot close their fingers around a handle.

## Verification

See [playtest acceptance](../playtest-review/acceptance.md) for the executed checks and rendered evidence. Research findings, implementation choices, automated assertions and human acceptance are distinct evidence.
