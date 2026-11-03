# Dialogue branches after revision

These are alternative branches, not one continuous conversation. Node IDs identify source locations.

## mara_greeting
Mara: The tower's gone dark. I heard glass breaking in the clerk's office just now. Would you check on her? The door is beside the tower.
Variant 0: We've been paid, and the tower's burning again. I can see right across the quay from here.
Variant 1: The clerk needs that pouch back. Come on, I'll go to the office with you.
Variant 2: Let's find that pouch. The clerk will need every coin back.
Variant 3: I'll meet you at the garden gate. Ivo will know where the thief went.
Variant 4: The payroll? That's our whole week's wages. Is the clerk hurt?
Variant 5: The tower's burning again. Would you check on the clerk? I heard glass breaking in her office. The door is beside the tower.
Corsair (check_office → mara_office): I'll check on the clerk.
Corsair (accept_help → mara_help): She's safe. He stole the payroll. Will you come with me?
Corsair (ask_theft → mara_theft): What happened?
Corsair (ask_pay → mara_pay): Do you work here?
Corsair (ask_for_favor → tide_gate): Where is Ivo?
Corsair (ask_lamp → mara_lamp): Why is the tower dark?
Corsair (share_oil → mara_thanks): Here. This should get the tower burning again.
Corsair (keep_oil → mara_farewell): I need to keep the oil for the road.
Corsair (leave → $exit): Until next time.

## mara_help
Mara: I'm coming. I mend dockhands as often as cargo nets. Tell Ivo we'll help him, and keep those machines off me while I tend your wounds.

## mara_theft
Mara: A crash from the office, then someone running across the court. I couldn't see who it was. Ivo went after them.

## mara_pay
Mara: I unload the boats and tend the tower lamp at night. The clerk pays us on Fridays. I was waiting for my wages when I heard the crash.

## mara_thanks
Mara: Thank you. Give me a moment to fill the reservoir. We should be able to see anyone else crossing the quay.

## mara_farewell
Mara: All right. Watch your footing by the water. Those boards are hard to see without the tower.

## mara_lamp
Mara: The reservoir ran dry. I was going to buy oil with tonight's pay. I should've fetched it before sunset.

## tide_gate
Mara: He ran east, towards the garden gate. It's the only way onto that terrace.

## ivo_gate
Ivo: The man in red ran from the office into the garden. I've shut the gate behind him. There's no other way out, but he's got two mechanical guards.
Variant 0: The clerk has the payroll and the quay has its light back. I'll keep watch here.
Variant 1: Take the money back to the clerk. I'll stay with the prisoner until the watch arrives.
Variant 2: The guards are down. Check the raider for the payroll; I'll keep watch.
Variant 3: Mara stays behind us. Keep the guards busy while we close on the thief.
Corsair (open_gate → ivo_gate_opened): Mara's ready. Let's get the payroll back.
Corsair (ask_about_gate → ivo_gate_history): Why haven't you gone in?
Corsair (ask_sentries → ivo_sentries): What are those machines?
Corsair (leave → $exit): Until next time.

## ivo_gate_opened
Ivo: I'll lift the chain. Stay together. Those guards hit hard, and Mara needs room to work.

## ivo_gate_history
Ivo: One of his guards nearly took my head off. I couldn't fight both at once. Get Mara.

We'll need someone who can tend a wound.

## ivo_sentries
Ivo: They're the raider's guards. He gives the orders; they do the fighting. Don't let them surround us.

## clerk_greeting
Clerk: I'm all right. He shoved past me and smashed the lock off the payroll chest. I couldn't even see his face until he was through the door.
Variant 0: I've counted it twice. Nobody will lose their wages. We'll have that lock replaced in the morning.
Variant 1: That pouch has the quay stamp on it. You found him! Let me count the money.
Variant 2: Did you find the money? We can't pay anyone until it comes back.
Variant 3: Mara was waiting for her pay outside. Tell her I'm safe. Ivo chased the thief east, towards the garden.
Corsair (ask_robbery → clerk_robbery): Who was he? What did he take?
Corsair (return_pay → clerk_paid): Here is the stolen payroll.
Corsair (open_shortcut → clerk_shortcut_opened): Could I use the market side passage?
Corsair (ask_about_records → clerk_records): May I look through the harbor archive?
Corsair (ask_town → clerk_town): Do robberies happen often here?
Corsair (leave → $exit): Until next time.

## clerk_shortcut_opened
Clerk: I'll leave the side door unlatched. It cuts from this court to the market.

## clerk_records
Clerk: The cabinet over there holds the harbor history. You can take the visitor's copy. Thankfully the thief wasn't interested in books.

## clerk_town
Clerk: Pickpockets, sometimes. Armed robbery in my office? Never. With the tower out he got across the court before I saw him coming.

## cabinet_greeting
Filing Cabinet: A visitor's copy of the harbor history lies in the bottom drawer.
Variant 0: You already have the visitor's copy. The remaining volumes belong in the archive.
Corsair (take_records → cabinet_taken): A history of the harbor. I'll take a look.

## cabinet_taken
Narrator: The booklet describes the building of Lantern Quay and the little garden planted above its eastern sea wall.

## cabinet_left
Narrator: You close the drawer.

## pay_taken
Narrator: Silver coins and folded wage slips fill the pouch. The clerk can account for them.

## vendor_greeting
Vendor: Fresh rope, dry matches, and a map that has never met the tide.
Variant 0: Mara has her money back? Good. Tell her the matches are on me.
Corsair (ask_directions → vendor_directions): Can you point me through town?
Corsair (ask_about_tower → vendor_tower): What can you tell me about the lantern tower?
Corsair (leave → $exit): Until next time.

## vendor_directions
Vendor: The market is west, the clerk's office is by the northern tower, and the garden is east.

## vendor_tower
Vendor: Mara tends it after the last boat unloads. When it burns, you can see clear from my stall to the garden gate.

## mara_office
Mara: Thank you. I'll stay here in case someone else needs help. Call if she's hurt.

## clerk_robbery
Clerk: A red coat, with two iron guards behind him. He emptied the chest into a pouch and ran east. That's the dockworkers' pay. Tell Mara what happened, then find Ivo. He went after the thief.

## clerk_paid
Clerk: The whole payroll. Thank you. Mara, here's your week's wages. Buy the tower oil before anything else; I don't want another night like this.

## pay_loot
Narrator: The raider is down. A heavy pouch hangs from his belt, stamped with the quay's mark.

## office_chest
Narrator: The chest has been forced open. Its broken lock lies on the floor. Scraps of wage envelopes are all that's left inside.
Variant 0: The recovered payroll is back in the chest. The broken lock still needs replacing.
