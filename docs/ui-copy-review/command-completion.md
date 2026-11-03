# Command menus — 2026-10-22

The review uses text exported from the actual Godot HUD and ledger controls at 1280×800. It includes the selected enemy, party portraits, action bar, orders, each character's equipment, companion selection and the usable inventory. It does not substitute mock data for the live Command bridge.

## Obelus

Run `node scripts/review-command-copy.mjs ../obelus` to reproduce the local Obelus review. The [report](command-screens/obelus-review.json) records source hashes, coverage and exact finding locations for eight screens. Four positive controls establish that the rules catch the previously rejected slogan, misleading preview label, card suffix and internal item identifier. No rejected-copy matches remained.

The retained heuristic findings were reviewed:

| Finding | Actual text | Decision |
| --- | --- | --- |
| Repeated phrases / imperative density | Character names, tab labels, "Equipped by", action buttons | Keep. These identify controls and actual equipment ownership. |
| Repeated syntax template | Weapons / Powers / Devices / Items / Movement | Keep parallel navigation labels. |
| Confidence fog | "Close", "All", "All" in Inventory | Keep. Close is a button; All is the selected filter and container scope. They make no confidence claim. |

Removed internal item IDs and raw learned-power source IDs from item details and the powers page. Companion confirmation now names the entering party. Item use explains when the item is consumed. Repeated item-name/category descriptions are omitted.

## Humanizer and manual review

Humanizer was run on the rendered combat HUD. Its [route](command-screens/humanizer-route.json) selected a social critic solely because the text is short (98 words). That venue is a poor fit for interface controls. The requested independent critic applied the named skill, rejected the parallel-label repetition finding, and found no material copy issue. No social-post structure or marketing copy was added. This was a deterministic audit plus bounded editorial review, not an authorship classifier or automated semantic approval.

Native screenshots inspected:

- [Command HUD](../images/command-hud-1280x800.png)
- [Mara's equipment](../images/command-equipment-mara-1280x800.png)
- [Usable inventory](../images/command-inventory-1280x800.png)
- [Gate rendezvous](../images/gate-rendezvous-1280x800.png)

Interaction evidence is separate: the actual control test deploys Ivo, selects an enemy, queues attacks and Mara's power, then uses a field dressing through Inventory. The chapter route earns the records and victory before checking the saved outcome. These tests run at Steam Deck resolution; physical handheld testing is not claimed.

## Targeting and companion orders follow-up

The updated HUD and in-world targeting hint were exported from native tests and
reviewed by Obelus: eight screens, four positive controls, zero rejected-copy
matches. The new Humanizer run selected the generic profile with low routing
confidence and no specialist forks. Its one syntax-template finding is the
intentional Weapons / Powers / Devices / Items / Movement navigation. Retain it.
The pause message names the character who needs orders; AI identifies an
uncontrolled companion and the source of its current order.

[Targeting capture](../images/command-targeting-1280x800.png) shows the broken-X
reticle, separated names and shoulder camera. Input tests exercise both bumpers,
ally confirmation, cancellation and possession; copy findings do not certify
those behaviors.
