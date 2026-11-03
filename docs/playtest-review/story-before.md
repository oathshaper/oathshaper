# Lantern Quay: current playable dialogue

Audience: first-time player, including age 12. Read in play order; optional answers can be skipped.

## mara_greeting
Mara: The harbor wind keeps finding my lantern's last wick.
On return: That should keep the pier lamp burning until morning. Thank you.
On return: Mind the edge of the pier. The lamp is nearly out.
- Share a flask of lantern oil. → mara_thanks
- Keep the oil for the road. → mara_farewell
- Ask where Ivo stands watch. → tide_gate
- Leave conversation. → $exit

## mara_thanks
Mara: I can light the pier now. Ivo needs that marker to watch the channel.

## mara_farewell
Mara: Keep to the middle of the boards. You will need that oil farther out.

## tide_gate
Mara: Ivo keeps watch by the east gate. Tell him you came from my pier.

## ivo_gate
Ivo: The east gate has been chained since the last high water. I won't send another cart into the channel.
On return: The chain is raised. Stay on the garden walk; the lower road is still flooded.
On return: That ledger bears the civic stamp. The new seal on the garden sentries has a different mark. Let me see the entry.
On return: Mara says you gave her oil. A lit pier makes this channel safer.
- Show Ivo the entry reserving the garden walk for public passage. → ivo_records_passage
- Ask Ivo to unbar the east gate. → ivo_gate_opened
- Ask why the gate is chained. → ivo_gate_history
- Leave conversation. → $exit

## ivo_gate_opened
Ivo: With the pier marker lit, I can watch your crossing. I'll raise the chain. Stay on the raised garden walk; the cart road is still flooded.

## ivo_gate_history
Ivo: At high water you could mistake the road for the sea. We lost a wagon that way last winter.

## clerk_greeting
Clerk: The civic office has two doors. Only one still leads where the signs claim.
On return: Here: the garden walk is reserved for public passage. Show this entry to Ivo at the east gate. I will meet you and Mara at the sentries; we need their seal to contest the closure.
On return: The west archive door is marked on your map. The flood ledger is in the iron cabinet inside.
On return: The market side passage is unlatched for you. Mind the low lintel.
On return: I saw Mara's pier lamp from my desk. Perhaps I can open the market passage.
- Ask to use the market side passage. → clerk_shortcut_opened
- Ask about the old harbor records. → clerk_records
- Leave conversation. → $exit

## clerk_shortcut_opened
Clerk: I'll leave the side door unlatched. It cuts from this court to the market.

## clerk_records
Clerk: The flood ledger is in the west archive, beside the tower. I have marked its records door on your map. Look in the iron cabinet inside.

## cabinet_greeting
Filing Cabinet: The bottom drawer slides open. A leather-bound flood ledger rests beneath its dividers.
On return: The Old Harbor Records are safe in your satchel. The cabinet holds nothing else.
- Take the Old Harbor Records. → cabinet_taken
- Close the drawer for now. → cabinet_left
- Leave cabinet. → $exit

## cabinet_taken
Narrator: One entry reserves the raised garden walk for the quay's workers. It bears the civic stamp. You place the ledger in your satchel.
- Close the drawer. → cabinet_left
- Leave cabinet. → $exit

## cabinet_left
Narrator: You close the drawer.
- Open the drawer again. → cabinet_greeting
- Leave cabinet. → $exit

## vendor_greeting
Vendor: Fresh rope, dry matches, and a map that has never met the tide.
On return: With the east road open, people may finally buy something besides rope.
On return: The clerk's passage is open? That saves me the long walk around to the court.
- Ask for directions through town. → vendor_directions
- Ask about the lantern tower. → vendor_tower
- Leave conversation. → $exit

## vendor_directions
Vendor: The market runs west, the office sits by the northern tower, and Ivo watches the east gate. Find the tower when you lose your bearings.

## vendor_tower
Vendor: The tower's been patched so often no one recalls its first shape. Still, every path around here finds it.

## ivo_records_passage
Ivo: Public passage, even at high water. That settles the chain. I will let you through, but the sentries still answer to that new seal. Bring it back for the clerk to compare. Mara has gone ahead to meet you.

# Garden chapter
id: disputed_charter
title: The Disputed Charter
location: Lantern Garden
premise: The flood ledger names Lantern Garden as a public right of passage. A new seal has turned its sentries against the quay's workers. Mara and the civic clerk accompany you to recover it.
briefing: Clerk: "The ledger grants passage to every worker on the quay. That seal is not the one we issued."

Mara: "My crew is waiting outside. Keep the sentries off us while we reach the gate."
objective: Recover the seal from the garden sentries.
discovery: The seal carries a private owner's mark where the civic stamp should be.
resolution: Clerk: "Someone replaced this by hand. I'll lodge the seal with the ledger. They cannot close a public passage on a forged claim."

Mara: "I'll bring the crew through. We've lost half a day's work already."
records: The flood ledger reserves the garden walk as a public right of passage, even when the lower road floods. Its civic stamp differs from the seal now fitted to the garden gate. The entry gives the clerk grounds to contest the closure.
map_note: The raised garden walk lies beyond the east gate. The lower road floods at high tide.
