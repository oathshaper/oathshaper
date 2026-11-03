# Story reset — 2026-10-25

**Final status:** revision7 implemented and verified. The pending decisions below are historical and superseded by the final approval. See [acceptance.md](acceptance.md) for the office/payroll/tower route, 23 passing Godot suites, rendered lighting, 218-check story route, and 72 regenerated voice clips. No premise decision remains pending.

User decision: **Dockside robbery**, confirmed through native question reply. It is current and authorizes the replacement premise, dialogue, runtime quest changes, and regenerated voices. No pending premise decision remains.

Humanizer initially routed the ambiguous request to review. One fiction critic completed a review-only pass. The subsequent explicit plot choice authorizes one revision against that consolidated review; no second autonomous story revision is planned.

Protected facts: garden is a garden with one quay approach, not a route out of town; existing Mara, Ivo, clerk, vendor, raider and two mechanical guards; player/companion roles; author rejects the ledger as motivation or combat prerequisite. Preserve user's pre-existing change to godot/project.godot.

Accepted structural changes (agent-editable under the approved premise):
1. Replace nonexistent rescue geography with a visible stolen pay chest in the existing garden.
2. Remove paperwork/morality gates to helping Ivo; meeting him and agreeing to help opens the encounter.
3. Establish raider and his own mechanical bodyguards as the opposition; no ownership seal or ledger controls hostility.
4. Make winning, collecting the chest, and returning it separate observable persisted outcomes.
5. Make archive lore optional; align every menu, objective, voice, and ending with the new story.

Implementation/verification in progress. Existing game process and saves have not been replaced.

## Pending author decision — clerk and lantern integration

The author objected that making the archive optional removed an interesting interior demo and reduced the lantern's role. The dockside robbery premise remains authorized. Native question sent: paymaster/office handoff/lantern payoff (recommended), clerk provides lamp repairs before combat, or another central connection. No reply yet. Further story text, quest-flow changes dependent on that choice, and additional voice regeneration are parked. Current revision6 is an intermediate implementation, not an accepted final story. Continue independent technical validation of the physical chest, dialogue controls, and existing gameplay. Do not declare the story complete while this decision is pending.

Current evidence: revised Command route passed 212 checks before correcting the test's opening-skip setup; Rust suite passed 120 tests including doctest. Voice batch generated 61 clips with objective QC; no listening acceptance claimed. Obelus rerun produced three heuristic findings (repeated branch guidance, ordinary words, and concrete lists); semantic audit adds two related branch-repetition pairs. Tool scores do not constitute plot acceptance.

### Clarification received on the pending decision

The author replied “visit the office about what stolen chest? I don't get it” to the clerk/lantern question. This is a request for clarification, not approval. Explained that the chest was Mara's stolen pay and withdrew the newly invented paymaster/reporting errand because it added no necessary action. The role of the office and lantern is still unresolved; do not implement or generate more story voices on that assumption.

## Current author direction — cohesive sequence requested, implementation held

The author clarified: visiting the clerk/her office should establish that the chest there was ransacked; the loot is on the Crimson Raider. They requested a cohesive list of steps and involved actors, then added that darkness may have aided the theft. This supersedes the earlier optional-archive premise and the rejected errand to report an already-known stolen chest. The physical chest belongs in the office, and recoverable payroll belongs to the raider; the intermediate garden chest/return-to-Mara implementation above is not the accepted final route.

Next response provides a proposed sequence: dark quay/Mara -> clerk and ransacked office chest -> Mara joins because her wages were taken -> Ivo holding the garden entrance -> fight raider and his mechanical bodyguards -> loot payroll from raider -> return payroll to clerk in office -> payout and restored quay light. Early oil sharing can restore the light sooner, without changing the theft or becoming a combat permission gate. User has requested the steps, not another implementation pass. Further story implementation and voice regeneration remain held. Previous clerk/lantern question has been superseded by this concrete direction; do not repeat it.

## Approved final sequence and tower lighting

The author approved the sequence with "there we go", then specified that the **tower lantern** supplies the environment illumination. Implementation is authorized. Revision7 replaces the intermediate revision6: Mara hears the crash on a dark quay; clerk in her office establishes the ransacked payroll chest; Mara joins; Ivo holds the garden gate; raider and two hired mechanical guards fight; payroll pouch is looted from the raider; return money to the clerk; wages paid and tower relit. Oil donation can light it earlier. Chest remains in the office. Mara has no personal orange spill light. Preserve existing resident game and user project.godot settings.
