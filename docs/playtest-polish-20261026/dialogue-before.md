# Playtest dialogue before revision

## mara_greeting (Mara)
The tower's gone dark. I heard glass breaking in the clerk's office just now. Would you check on her? The door is beside the tower.
[{'kind': 'flag', 'id': 'pay_returned', 'value': True}]
We've been paid, and the tower's burning again. I can see right across the quay from here.
[{'kind': 'flag', 'id': 'pay_recovered', 'value': True}]
The clerk needs that pouch back. Come on, I'll go to the office with you.
[{'kind': 'flag', 'id': 'mara_recruited', 'value': True}]
I'll meet you at the garden gate. Ivo will know where the thief went.
[{'kind': 'flag', 'id': 'robbery_known', 'value': True}]
The payroll? That's our whole week's wages. Is the clerk hurt?
- check_office: I'll check on the clerk. → mara_office (when=[], hide=[])
- accept_help: The payroll was stolen. Will you come with me? → mara_help (when=[{'kind': 'flag', 'id': 'mara_recruited', 'value': False}, {'kind': 'flag', 'id': 'robbery_known', 'value': True}], hide=[[{'kind': 'flag', 'id': 'mara_recruited', 'value': True}], [{'kind': 'flag', 'id': 'robbery_known', 'value': False}]])
- ask_theft: What happened? → mara_theft (when=[], hide=[])
- ask_pay: Do you work here? → mara_pay (when=[], hide=[])
- ask_for_favor: Where is Ivo? → tide_gate (when=[], hide=[])
- ask_lamp: Why is the tower dark? → mara_lamp (when=[], hide=[])
- share_oil: Share a flask of lantern oil. → mara_thanks (when=[{'kind': 'flag', 'id': 'oil_decided', 'value': False}], hide=[[{'kind': 'flag', 'id': 'oil_decided', 'value': True}], [{'kind': 'flag', 'id': 'pay_returned', 'value': True}]])
- keep_oil: Keep the oil for the road. → mara_farewell (when=[{'kind': 'flag', 'id': 'oil_decided', 'value': False}], hide=[[{'kind': 'flag', 'id': 'oil_decided', 'value': True}], [{'kind': 'flag', 'id': 'pay_returned', 'value': True}]])
- leave: Leave conversation. → $exit (when=[], hide=[])

## mara_help (Mara)
I'm coming. I mend dockhands as often as cargo nets. Tell Ivo we'll help him, and keep those machines off me while I tend your wounds.

## mara_theft (Mara)
A crash from the office, then someone running across the court. I couldn't see who it was. Ivo went after them.

## mara_pay (Mara)
I unload the boats and tend the tower lamp at night. The clerk pays us on Fridays. I was waiting for my wages when I heard the crash.

## mara_thanks (Mara)
That's enough to get the tower burning again. Give me a moment to fill the reservoir. We should be able to see anyone else crossing the quay.

## mara_farewell (Mara)
All right. Watch your footing by the water. Those boards are hard to see without the tower.

## mara_lamp (Mara)
The reservoir ran dry. I was going to buy oil with tonight's pay. I should've fetched it before sunset.

## tide_gate (Mara)
He ran east, towards the garden gate. It's the only way onto that terrace.

## ivo_gate (Ivo)
The man in red ran from the office into the garden. I've shut the gate behind him. There's no other way out, but he's got two mechanical guards.
[{'kind': 'flag', 'id': 'pay_returned', 'value': True}]
The clerk has the payroll and the quay has its light back. I'll keep watch here.
[{'kind': 'flag', 'id': 'pay_recovered', 'value': True}]
Take the money back to the clerk. I'll stay with the prisoner until the watch arrives.
[{'kind': 'flag', 'id': 'gate_open', 'value': True}]
Mara stays behind us. Keep the guards busy while we close on the thief.
- open_gate: Mara's ready. Let's get the payroll back. → ivo_gate_opened (when=[{'kind': 'flag', 'id': 'gate_open', 'value': False}, {'kind': 'flag', 'id': 'mara_recruited', 'value': True}], hide=[[{'kind': 'flag', 'id': 'gate_open', 'value': True}]])
- ask_about_gate: Why haven't you gone in? → ivo_gate_history (when=[], hide=[])
- ask_sentries: What are those machines? → ivo_sentries (when=[], hide=[])
- leave: Leave conversation. → $exit (when=[], hide=[])

## ivo_gate_opened (Ivo)
I'll lift the chain. Stay together. Those guards hit hard, and Mara needs room to work.

## ivo_gate_history (Ivo)
One of his guards nearly took my head off. I shut the gate and held my ground. Get Mara; we'll need someone who can mend a wound.

## ivo_sentries (Ivo)
Hired machines. They followed him off his boat and they're protecting him now. They'll attack anyone who gets near their master.

## clerk_greeting (Clerk)
I'm all right. He shoved past me and smashed the lock off the payroll chest. I couldn't even see his face until he was through the door.
[{'kind': 'flag', 'id': 'pay_returned', 'value': True}]
I've counted it twice. Nobody will lose their wages. We'll have that lock replaced in the morning.
[{'kind': 'flag', 'id': 'pay_recovered', 'value': True}]
That pouch has the quay stamp on it. You found him! Let me count the money.
[{'kind': 'flag', 'id': 'robbery_known', 'value': True}]
Mara was waiting for her pay outside. Tell her I'm safe. Ivo chased the thief east, towards the garden.
- ask_robbery: Who was he? What did he take? → clerk_robbery (when=[], hide=[])
- return_pay: Return the stolen payroll. → clerk_paid (when=[{'kind': 'flag', 'id': 'pay_returned', 'value': False}, {'kind': 'flag', 'id': 'pay_recovered', 'value': True}], hide=[[{'kind': 'flag', 'id': 'pay_returned', 'value': True}], [{'kind': 'flag', 'id': 'pay_recovered', 'value': False}]])
- open_shortcut: Could I use the market side passage? → clerk_shortcut_opened (when=[{'kind': 'flag', 'id': 'shortcut_open', 'value': False}], hide=[[{'kind': 'flag', 'id': 'shortcut_open', 'value': True}]])
- ask_about_records: May I look through the harbor archive? → clerk_records (when=[], hide=[])
- ask_town: Do robberies happen often here? → clerk_town (when=[], hide=[])
- leave: Leave conversation. → $exit (when=[], hide=[])

## clerk_shortcut_opened (Clerk)
I'll leave the side door unlatched. It cuts from this court to the market.

## clerk_records (Clerk)
The cabinet over there holds the harbor history. You can take the visitor's copy. Thankfully the thief wasn't interested in books.

## clerk_town (Clerk)
Pickpockets, sometimes. Armed robbery in my office? Never. With the tower out he got across the court before I saw him coming.

## cabinet_greeting (Filing Cabinet)
A visitor's copy of the harbor history lies in the bottom drawer.
[{'kind': 'flag', 'id': 'records_collected', 'value': True}]
You already have the visitor's copy. The remaining volumes belong in the archive.
- take_records: Take the harbor history. → cabinet_taken (when=[{'kind': 'flag', 'id': 'records_collected', 'value': False}], hide=[[{'kind': 'flag', 'id': 'records_collected', 'value': True}]])
- leave_records: Close the drawer. → cabinet_left (when=[], hide=[])
- leave: Leave cabinet. → $exit (when=[], hide=[])

## cabinet_taken (Narrator)
The booklet describes the building of Lantern Quay and the little garden planted above its eastern sea wall.

## cabinet_left (Narrator)
You close the drawer.
- look_again: Open the drawer again. → cabinet_greeting (when=[], hide=[])
- leave: Leave cabinet. → $exit (when=[], hide=[])

## pay_taken (Narrator)
Silver coins and folded wage slips fill the pouch. The clerk can account for them.
- leave: Return to the clerk. → $exit (when=[], hide=[])

## vendor_greeting (Vendor)
Fresh rope, dry matches, and a map that has never met the tide.
[{'kind': 'flag', 'id': 'pay_returned', 'value': True}]
Mara has her money back? Good. Tell her the matches are on me.
- ask_directions: Ask for directions through town. → vendor_directions (when=[], hide=[])
- ask_about_tower: Ask about the lantern tower. → vendor_tower (when=[], hide=[])
- leave: Leave conversation. → $exit (when=[], hide=[])

## vendor_directions (Vendor)
The market is west, the clerk's office is by the northern tower, and the garden is east. Ivo is at its gate.

## vendor_tower (Vendor)
Mara tends it after the last boat unloads. When it burns, you can see clear from my stall to the garden gate.

## mara_office (Mara)
Thank you. I'll stay here in case someone else needs help. Call if she's hurt.

## clerk_robbery (Clerk)
A red coat, with two iron guards behind him. He emptied the chest into a pouch and ran east. That's the dockworkers' pay. Tell Mara what happened, then find Ivo. He went after the thief.

## clerk_paid (Clerk)
The whole payroll. Thank you. Mara, here's your week's wages. Buy the tower oil before anything else; I don't want another night like this.

## pay_loot (Narrator)
The raider is down. A heavy pouch hangs from his belt, stamped with the quay's mark.
- take_pay: Take the stolen payroll. → pay_taken (when=[{'kind': 'flag', 'id': 'pay_recovered', 'value': False}], hide=[[{'kind': 'flag', 'id': 'pay_recovered', 'value': True}]])
- leave: Leave it for now. → $exit (when=[], hide=[])

## office_chest (Narrator)
The chest has been forced open. Its broken lock lies on the floor. Scraps of wage envelopes are all that's left inside.
[{'kind': 'flag', 'id': 'pay_returned', 'value': True}]
The recovered payroll is back in the chest. The broken lock still needs replacing.
- leave: Leave the chest. → $exit (when=[], hide=[])
