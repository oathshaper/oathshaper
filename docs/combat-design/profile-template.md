# Profile design packet contract

This file defines the authoring/review packet. It is not a runtime schema and does not impose a universal combat mechanic. See [LCD](lcd.md), the [run contract](README.md) and [research notice](../research/NOTICE.md).

Each branch owns `docs/combat-design/profiles/<id>/`. Do not edit another profile, core source, the LCD or the preview catalog in this design milestone. Flag required changes in the packet. Keep all original content/numbers distinct from source-game claims.

## Files

- `design.md`: substantive design and direct sources. Link `../../../research/NOTICE.md` near the top.
- `scenarios.json`: machine-readable proposed acceptance cases, using the shape below.
- `evaluation.md`: initial author evaluation, subsequently independent findings and repair dispositions. Never call an author pass independent review.

## Design sections

Use these exact level-two headings so a simple completeness check can locate them. Subheadings and content are unrestricted. Write enough to make the design implementable; generic headings and lists are insufficient.

1. `## Identity and reference boundary` — exact edition/platform and source facts vs original defaults/deviations. Direct primary URLs and access dates. Source gaps remain explicit.
2. `## Play loop and time` — state transitions, decision windows, clocks/pauses, cancellation, invalid targets, costs/refunds, AI, failure, recovery, victory and rewards.
3. `## Archetypes, skills and progression` — mechanically distinct starting builds and coverage beyond four demo actors, acquisition/investment/prerequisites/respec, exploration/social skills, multiclass or equivalent where applicable. No invented universal hybrid class.
4. `## Equipment, inventory and economy` — slots/eligibility/sets/grants, upgrades/socketing, capacity vs browser layout, loot/transfers/consumables/vendors/crafting policy, transactional edge cases and meaningful comparisons.
5. `## Abilities, resources and resolution` — actionable examples with costs, targeting/delivery, resources, magic/tech distinction, defense/condition interactions, stacking, cooldowns, recovery and interrupt policy.
6. `## Party and companion behavior` — roster/deployment/selection/possession/order distinctions, AI rules, summons/support, control precedence, dialogue and morality boundaries.
7. `## Native UX and input` — concrete HUD, menus, actor sheet, quickbars/radials/diamonds/timelines as appropriate; keyboard/controller bindings, modal/cancel priority, readability and accessibility.
8. `## Worked examples` — one garden encounter with specific transitions and checked numerical costs; one equipment/grant transaction including failure; one progression/respec choice. Numbers are prototype choices, not source-game parity claims.
9. `## LCD mapping and persistence` — owned namespaces, optional capabilities, actual profile hooks, hidden-state rules, save checkpoint/restore, profile-switch policy and any LCD pressure.
10. `## Acceptance and implementation slice` — falsifiable scenarios, concrete first implementation slice, animation/assets, instrumentation, risks and missing coverage.
11. `## Sources and research gaps` — source register, what was verified, inaccessible/unsupported claims, research depth and method.

## Scenario record

```json
{
  "schema": "oathshaper.design-scenarios/v1",
  "profile": "example",
  "status": "proposed_acceptance",
  "cases": [
    {
      "id": "EX-01",
      "category": "equipment",
      "given": "Concrete starting state with item/source/actor identity.",
      "when": ["Ordered player or system operation."],
      "then": ["Observable outcome including numerical changes where applicable."],
      "invariants": ["Property that must survive the operation."],
      "failure_probe": "A specific counterexample or input that must be rejected or handled."
    }
  ]
}
```

Use at least eight cases covering `timing`, `equipment`, `progression`, `ability`, `party`, `ui`, `persistence`, and `failure`. Extra categories/cases are allowed. Every case needs a meaningful failure probe and expected observables. They are design acceptance cases, not tests that have executed in Godot.

## Independent evaluation contract

Evaluate the design against the source evidence, the LCD and its own scenarios. Seek information leaks, contradictions, resource/ownership exploits, dead-end UX, shallow archetype differentiation and false reference claims. Work at least two counterexamples through a concrete trace. Report file/line citations, impact, required change and disposition. Preserve the initial proposal commit, then record repair commits and re-review findings separately.

The author may include small executable arithmetic/state probes when they address a real uncertainty. Describe exactly what those prove. A document checker or toy simulator never demonstrates controller feel, game balance or working gameplay.
