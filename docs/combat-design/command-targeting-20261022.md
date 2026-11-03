# Command: targeting and companion control

Follow-up to the rendered Command encounter, based on the player's playtest.

## Behavior

- A single screen-space name per visible conscious actor replaces Command's
  Label3D names. Labels avoid each other and the HUD; crowded/offscreen labels
  are omitted. Shifted labels have a short leader line. Party portraits remain
  available when a world label cannot fit.
- The selected target has four inward arrowheads forming a broken X at its torso,
  plus the selected ground ring and the target panel's name/health.
- LB/RB cycle enemies; T and Shift+T do the same on keyboard. L3/R3 and Tab/F1–F3
  switch companions. Changing the target clears the manual orbit delay and turns
  the shoulder camera toward it. Possession updates persistent camera ownership.
- Enemy actions use the selected target directly. Area powers and healing use
  paused in-world aim: bumpers cycle eligible actors, A/Enter/trigger confirms,
  and B/Esc cancels. Clicking the floor places an area power. Inventory healing
  hides the ledger during aim and restores it afterward. There is no target list
  dialog.
- Uncontrolled companions use the existing role AI. A rejected preferred power
  now falls back to a legal attack instead of retrying indefinitely. The same
  admission/reservation rules apply to both AI and player actions.
- Portraits identify AI companions; current and queued orders expose AI ownership.
  Taking possession permits clearing an AI order. New manual orders replace AI
  future orders and an unpaid approach. Paid windup/recovery needs explicit Clear
  or Disengage; spent resources are not refunded.
- Completion, interruption or removal of the controlled actor's final order
  pauses with a named "needs orders" message. Resume acknowledges that event;
  remaining idle does not cause an endless pause loop. The behavior follows the
  possessed actor, not always the Corsair. Existing journey/Command v4 saves
  remain compatible.

## Findings during validation

The native targeting check exposed a second controller action firing on a focused
HUD button after A confirmed a target. Key/controller handling now runs inside
the combat SubViewport before GUI dispatch, consuming the event there and in the
parent. Bumper selection, ally confirmation, cancellation, pause ownership and
possession are exercised through native input events.

A second edge case combined manual pause with the automatic empty-order pause.
One Resume now acknowledges both, while ledger/targeting pauses remain owned by
their respective menus.

## Evidence

- Rust Command tests cover uncommanded companion actions, legal AI fallback,
  takeover reservations, empty-order pause persistence, and resume without a loop.
- Native Command trial: 45 checks, no failures.
- Native targeting/camera/label capture: 34 checks, no failures. Pairwise label
  checks vary with rendered placement; the required reticle and camera checks
  are fixed. Capture: `docs/images/command-targeting-1280x800.png`.
- Obelus: eight exported screens, four positive controls, no rejected-copy
  matches. Humanizer routed the new HUD/hint sample as generic with no forks;
  its parallel-navigation finding is intentionally retained.
- Existing Vanguard regression passes; its own label builder remains local to
  that presentation. Physical controller/Steam Deck testing is not claimed.

The supplied KOTOR references remain comparative interface research. This change
uses original shapes, text and assets; it adds no third-party game art or data.

Final verification: `scripts/check.sh` exited 0 (117 Rust tests plus one doctest,
strict Clippy, and the complete listed Godot checks). Command trial 45, controls
35, targeting 22 headless / 34 rendered, ledger 275 and equipment 273 all passed.
The native controls rerun also passed 35 checks, including combined manual/empty
pause acknowledgement. The existing headless dummy-renderer mesh diagnostics
remain; rendered Command checks passed without that renderer error.
