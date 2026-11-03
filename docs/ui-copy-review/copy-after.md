# Oathshaper UI copy inventory

Source-literal extraction. Repeated strings are deduplicated; references identify their screen source. Dynamic values, runtime visibility and layout require Godot verification.

## godot/scripts/character_model_slot.gd:60

Character model must import as a PackedScene: 

## godot/scripts/character_model_slot.gd:64

Character model must have a Node3D root: 

## godot/scripts/character_model_slot.gd:72

Character model has no visible mesh; using primitive art: 

## godot/scripts/character_model_slot.gd:79

Rigged character needs a weighted skin and required clips; using fallback: 

## godot/scripts/combat_frontend.gd:35

Pause, queue, act

Also: godot/scripts/combat_profiles.gd:27

## godot/scripts/combat_frontend.gd:35

Melee, magic, styles

Also: godot/scripts/combat_profiles.gd:33

## godot/scripts/combat_frontend.gd:36

Aim, cover, command

Also: godot/scripts/combat_profiles.gd:39

## godot/scripts/combat_frontend.gd:36

Initiative & reactions

## godot/scripts/combat_frontend.gd:37

Build ATB, command

## godot/scripts/combat_frontend.gd:37

Plan, then resolve

## godot/scripts/combat_frontend.gd:38

Steel, spells & tactics

## godot/scripts/combat_frontend.gd:38

Live time, linked arts

## godot/scripts/combat_frontend.gd:39

Ready, choose, resolve

Also: godot/scripts/combat_profiles.gd:15

## godot/scripts/combat_frontend.gd:42

Weapons, armor & powers

## godot/scripts/combat_frontend.gd:42

Styles, amulets & charms

## godot/scripts/combat_frontend.gd:43

Firearms, shields & tech

## godot/scripts/combat_frontend.gd:43

Gear & prepared spells

## godot/scripts/combat_frontend.gd:44

Weapons, sockets & commands

## godot/scripts/combat_frontend.gd:44

Tactical kits & gadgets

## godot/scripts/combat_frontend.gd:45

Arms, armor & spellcraft

## godot/scripts/combat_frontend.gd:45

Arms, charms & linked arts

## godot/scripts/combat_frontend.gd:46

Relics, roles & learned magic

## godot/scripts/combat_frontend.gd:121

LANTERN QUAY
A playable RPG foundation

## godot/scripts/combat_frontend.gd:176

The disputed charter

## godot/scripts/combat_frontend.gd:176

Recover the seal closing the public passage.

## godot/scripts/combat_frontend.gd:228

LANTERN QUAY

Also: godot/scripts/journal_menu.gd:271

## godot/scripts/combat_frontend.gd:229

The garden gate
is closed.

## godot/scripts/combat_frontend.gd:230

Find the flood ledger. Establish who has the right to bar the passage.

## godot/scripts/combat_frontend.gd:232

New game   →

## godot/scripts/combat_frontend.gd:236

Load game

## godot/scripts/combat_frontend.gd:236

Load game  ·  No saved journey

## godot/scripts/combat_frontend.gd:240

The Disputed Charter   →

## godot/scripts/combat_frontend.gd:245

Beyond the harbor gate

## godot/scripts/combat_frontend.gd:245

Lantern Garden

Also: godot/scripts/command_hud.gd:83, godot/content/garden_chapter.json#/location

## godot/scripts/combat_frontend.gd:246

OLD HARBOR RECORDS

Also: godot/scripts/journal_menu.gd:433, godot/scripts/objective_tracker.gd:5

## godot/scripts/combat_frontend.gd:247

The civic clerk knows where the flood ledger is kept. Its entry for the garden may settle the claim.

## godot/scripts/combat_frontend.gd:254

NEW JOURNEY

## godot/scripts/combat_frontend.gd:254

LOAD JOURNEY

Also: godot/scripts/journal_menu.gd:463

## godot/scripts/combat_frontend.gd:254

YOUR JOURNEY

Also: godot/scripts/combat_style_inspector.gd:304

## godot/scripts/combat_frontend.gd:254


Combat & equipment styles

## godot/scripts/combat_frontend.gd:255

COMBAT STYLES

## godot/scripts/combat_frontend.gd:256

Choose how you fight.

## godot/scripts/combat_frontend.gd:289

Choose controls, party commands and equipment rules.

## godot/scripts/combat_frontend.gd:300

Start journey   →

## godot/scripts/combat_frontend.gd:300

Load journey   →

## godot/scripts/combat_frontend.gd:300

Apply style   →

## godot/scripts/combat_frontend.gd:303

Explore style

## godot/scripts/combat_frontend.gd:346

Explore the menus, then take this style into the quay.
You can revisit this choice in the Ledger.

## godot/scripts/combat_frontend.gd:396

Leave this journey?

## godot/scripts/combat_frontend.gd:397

Unsaved progress will be lost. Your existing save will remain until you choose to save again.

## godot/scripts/combat_frontend.gd:398

KEEP PLAYING

## godot/scripts/combat_frontend.gd:399

START NEW JOURNEY

Also: godot/scripts/journal_menu.gd:425

## godot/scripts/combat_frontend.gd:412

D-pad  Browse     Ⓐ  Select     Ⓑ  Back

## godot/scripts/combat_frontend.gd:412

↑ ↓ ← →  Browse     Enter  Select     Esc  Back

## godot/scripts/combat_profiles.gd:9

Live time, linked techniques

## godot/scripts/combat_profiles.gd:9

Live ATB · coordinated party techniques

## godot/scripts/combat_profiles.gd:10

You + 2 companions

Also: godot/scripts/combat_profiles.gd:28, godot/scripts/combat_profiles.gd:52

## godot/scripts/combat_profiles.gd:11

Fight where you stand. Let readiness build, watch enemy positions, and unite two or three allies in a linked technique.

## godot/scripts/combat_profiles.gd:15

Classic ATB · Active / Wait

## godot/scripts/combat_profiles.gd:16

You + 3 companions

Also: godot/scripts/combat_profiles.gd:22, godot/scripts/combat_profiles.gd:46, godot/scripts/combat_profiles.gd:58

## godot/scripts/combat_profiles.gd:17

Guide four distinct roles as their gauges fill. Choose Attack, Arts, Magic or Item, with Active or Wait menu timing.

## godot/scripts/combat_profiles.gd:21

Party tactics, steel & spells

## godot/scripts/combat_profiles.gd:21

Command family · dark fantasy

## godot/scripts/combat_profiles.gd:23

Pause to direct a four-person party. Build warrior, rogue, and mage roles around companion tactics.

## godot/scripts/combat_profiles.gd:27

Real time with pause

## godot/scripts/combat_profiles.gd:29

Plan short orders, then let the party carry them out.

## godot/scripts/combat_profiles.gd:33

Direct action

## godot/scripts/combat_profiles.gd:34

You + 1 follower

## godot/scripts/combat_profiles.gd:35

Read attacks, guard or evade, and change styles in motion.

## godot/scripts/combat_profiles.gd:39

Squad shooter

## godot/scripts/combat_profiles.gd:40

You + 2 squadmates

## godot/scripts/combat_profiles.gd:41

Aim from cover, direct squad powers, and strip defenses.

## godot/scripts/combat_profiles.gd:45

Initiative, actions, reactions

## godot/scripts/combat_profiles.gd:45

Three-action tactical rules

## godot/scripts/combat_profiles.gd:47

Spend actions deliberately and keep a reaction ready.

## godot/scripts/combat_profiles.gd:51

Action builds commands

## godot/scripts/combat_profiles.gd:51

Action / ATB hybrid

## godot/scripts/combat_profiles.gd:53

Attack and guard to build two ATB segments. Slow the action to choose a command, switch allies, and exploit a staggered foe.

## godot/scripts/combat_profiles.gd:57

Plan together, resolve together

## godot/scripts/combat_profiles.gd:57

Simultaneous planning

## godot/scripts/combat_profiles.gd:59

Commit a short plan, then see both sides resolve it.

## godot/scripts/combat_profiles.gd:72

Techniques & links

## godot/scripts/combat_profiles.gd:72

Commands & relics

## godot/scripts/combat_profiles.gd:73

Talents & tactics

## godot/scripts/combat_profiles.gd:74

Powers & queues

## godot/scripts/combat_profiles.gd:74

Styles & training

## godot/scripts/combat_profiles.gd:75

Powers & modules

## godot/scripts/combat_profiles.gd:75

Actions & preparation

## godot/scripts/combat_profiles.gd:76

Commands & sockets

## godot/scripts/combat_profiles.gd:76

Plans & reserves

## godot/scripts/combat_profiles.gd:88

Aim from cover, manage weapon heat, and direct distinct combat, tech and biotic squad powers.

## godot/scripts/combat_style_inspector.gd:78

  /  Style preview

## godot/scripts/combat_style_inspector.gd:80

← All styles

## godot/scripts/combat_style_inspector.gd:129

Choose this style  →

## godot/scripts/combat_style_inspector.gd:166

Build preview

Also: godot/scripts/combat_style_inspector.gd:269, godot/scripts/combat_style_inspector.gd:288, godot/scripts/journal_menu.gd:343, godot/scripts/journal_menu.gd:366

## godot/scripts/combat_style_inspector.gd:168

Mercy · Neutral

Also: godot/scripts/command_ledger.gd:265

## godot/scripts/combat_style_inspector.gd:177

Ruthless                    Merciful

## godot/scripts/combat_style_inspector.gd:179

Outlook · Unknown
Relationship · Not established

## godot/scripts/combat_style_inspector.gd:219

COMBAT & TIMING

## godot/scripts/combat_style_inspector.gd:220

PARTY & CONTROL

## godot/scripts/combat_style_inspector.gd:221

HUD & INPUT

## godot/scripts/combat_style_inspector.gd:222

EQUIPMENT & INVENTORY

## godot/scripts/combat_style_inspector.gd:223

ROLES & ARCHETYPES

## godot/scripts/combat_style_inspector.gd:224

SKILLS & PROGRESSION

## godot/scripts/combat_style_inspector.gd:226

Combat preview · Not yet playable

## godot/scripts/combat_style_inspector.gd:229

Play The Disputed Charter  →

## godot/scripts/combat_style_inspector.gd:249

Command · Pause, queue orders and switch companions.

## godot/scripts/combat_style_inspector.gd:258

PLAY PATTERN

## godot/scripts/combat_style_inspector.gd:276

Source: 

Also: godot/scripts/command_hud.gd:403

## godot/scripts/combat_style_inspector.gd:286

CARRYING & ORGANIZATION

## godot/scripts/combat_style_inspector.gd:297

LANTERN GARDEN

Also: godot/scripts/command_hud.gd:80

## godot/scripts/combat_style_inspector.gd:300

THE DISPUTED CHARTER

Also: godot/scripts/command_hud.gd:91

## godot/scripts/combat_style_inspector.gd:304

Save or load from the title menu or journal.

## godot/scripts/combat_style_inspector.gd:307

LB/RB Tabs · Ⓨ Member · R Scroll · Ⓐ Select · Ⓑ Back

## godot/scripts/combat_style_inspector.gd:307

Q/E Tabs · Tab Focus · PgUp/PgDn Scroll · Enter Select · Esc Back

## godot/scripts/command_construct.gd:102

Unknown ward construct: 

## godot/scripts/command_hud.gd:86

Paused · Space

## godot/scripts/command_hud.gd:87

Party sheet · I / C

Also: godot/scripts/command_hud.gd:154

## godot/scripts/command_hud.gd:122

Tab Party · F1–F3 Portraits · I / C Ledger · Space Pause · 1–6 Hotbar · Q Actions · E Attack

Also: godot/scripts/command_hud.gd:243

## godot/scripts/command_hud.gd:126

Command · Combat preview

Also: godot/scripts/command_hud.gd:239

## godot/scripts/command_hud.gd:152

 · Space

## godot/scripts/command_hud.gd:154

Party sheet · Menu

## godot/scripts/command_hud.gd:160

   ·   Focus %d / %d   ·   %d reserved   ·   %d free

## godot/scripts/command_hud.gd:162

   ·   Tool charges %d   ·   %d reserved

## godot/scripts/command_hud.gd:241

LB / RB Party · X Actions · Menu Ledger · View Pause · D-pad Focus · A Choose · B Back

## godot/scripts/command_hud.gd:263

 · Select and possess

## godot/scripts/command_hud.gd:272

Hold after orders

## godot/scripts/command_hud.gd:272

Companion AI

## godot/scripts/command_hud.gd:273

 · %d queued

## godot/scripts/command_hud.gd:296

No resource cost

Also: godot/scripts/command_ledger.gd:434

## godot/scripts/command_hud.gd:315

No known 

## godot/scripts/command_hud.gd:315

 for this character.

## godot/scripts/command_hud.gd:340

Clear future

## godot/scripts/command_hud.gd:342

Release all future reservations. The active action is unchanged.

## godot/scripts/command_hud.gd:343

Confirm interruption. Paid costs and recovery remain.

## godot/scripts/command_hud.gd:350

Selected: 

## godot/scripts/command_hud.gd:352

← Earlier

## godot/scripts/command_hud.gd:358

Remove order

## godot/scripts/command_hud.gd:392

Queue full

## godot/scripts/command_hud.gd:392

Source unavailable

## godot/scripts/command_hud.gd:392

Still recovering

## godot/scripts/command_hud.gd:392

Armor restriction

## godot/scripts/command_hud.gd:399

Bound source

## godot/scripts/command_hud.gd:406

Target: 

## godot/scripts/command_hud.gd:408

Range: %s m

## godot/scripts/command_hud.gd:410

Radius: %s m

## godot/scripts/command_hud.gd:412

Recovery: %.1f s

## godot/scripts/command_hud.gd:421


Target: 

## godot/scripts/command_hud.gd:423


Target: selected ground point

## godot/scripts/command_hud.gd:426


Source: 

## godot/scripts/command_hud.gd:429


Reserved: %s %s

## godot/scripts/command_hud.gd:432


Select to move earlier, move later or remove.

## godot/scripts/command_ledger.gd:53

Party ledger

## godot/scripts/command_ledger.gd:55

Close · Esc / B

## godot/scripts/command_ledger.gd:90

LB / RB Tabs  ·  L3 / R3 Inspect party  ·  D-pad / Tab Focus  ·  A / Enter Choose  ·  B Back

## godot/scripts/command_ledger.gd:232

Waiting for the current Command session.

## godot/scripts/command_ledger.gd:233

No character data has been received.

## godot/scripts/command_ledger.gd:237

Party ledger · 

## godot/scripts/command_ledger.gd:238

Inspecting %s  ·  Orders remain with %s  ·  %s

## godot/scripts/command_ledger.gd:268

Tool charges

## godot/scripts/command_ledger.gd:271

%s  %s / %s
%s reserved · %s free

## godot/scripts/command_ledger.gd:272

Inspect party

Also: godot/scripts/command_trial.gd:485

## godot/scripts/command_ledger.gd:285

Waiting for this character's progression.

## godot/scripts/command_ledger.gd:287

Character development

## godot/scripts/command_ledger.gd:292

%s XP · Level %s · %s pending levels

## godot/scripts/command_ledger.gd:294

Defense %s  ·  Attack %s  ·  Power DC %s

## godot/scripts/command_ledger.gd:296

Fortitude %s  ·  Reflex %s  ·  Will %s

## godot/scripts/command_ledger.gd:299

%s   %s   (base %s, equipment %s)

## godot/scripts/command_ledger.gd:302

%s   %s   ·   Rank %s / %s + ability %s + bonus %s

## godot/scripts/command_ledger.gd:303

Unspent choices

## godot/scripts/command_ledger.gd:305

Skills %s · Feats %s · Powers %s · Attributes %s

## godot/scripts/command_ledger.gd:306

Next choices

## godot/scripts/command_ledger.gd:308

%s · %s · Cost %s%s

## godot/scripts/command_ledger.gd:310

Skill opportunities

## godot/scripts/command_ledger.gd:313

Review a complete build plan

## godot/scripts/command_ledger.gd:316

Respec: %s %s%s

## godot/scripts/command_ledger.gd:319

No complete progression plan is exposed for this character. Current ranks and legal next choices are shown above.

## godot/scripts/command_ledger.gd:331

Select a plan to read every allocation before previewing it.

## godot/scripts/command_ledger.gd:336

Compare this complete plan

## godot/scripts/command_ledger.gd:350

Next level

## godot/scripts/command_ledger.gd:352

%s +%s ranks

## godot/scripts/command_ledger.gd:356

Power: %s · Rank %s

## godot/scripts/command_ledger.gd:358

Attribute: %s +%s

## godot/scripts/command_ledger.gd:359

Unbind items: 

## godot/scripts/command_ledger.gd:360

Unallocated earned choices remain banked. Final costs and legality are checked in the comparison.

## godot/scripts/command_ledger.gd:365

Waiting for this character's equipment.

## godot/scripts/command_ledger.gd:367

Equipment · 

## godot/scripts/command_ledger.gd:368

Choose a slot to compare equipment. Items used by queued orders are locked.

## godot/scripts/command_ledger.gd:384

Plans for 

## godot/scripts/command_ledger.gd:399

No equipment plans are exposed for this slot.

## godot/scripts/command_ledger.gd:400

Weapon sets

## godot/scripts/command_ledger.gd:402

 · Active

## godot/scripts/command_ledger.gd:406

Equipment upgrades

## godot/scripts/command_ledger.gd:411

Waiting for this character's powers.

## godot/scripts/command_ledger.gd:415

%s · Rank %s

## godot/scripts/command_ledger.gd:417

No purchased feats exposed.

## godot/scripts/command_ledger.gd:418

Learned powers

## godot/scripts/command_ledger.gd:420

%s · Rank %s
Source: %s

## godot/scripts/command_ledger.gd:422

No learned powers exposed.

## godot/scripts/command_ledger.gd:423

Current actions and sources

## godot/scripts/command_ledger.gd:425

Action availability belongs to the current order recipient. Inspecting this sheet does not switch orders.

## godot/scripts/command_ledger.gd:430

%s · %s · Rank %s

## godot/scripts/command_ledger.gd:434

%s
%s
Target: %s · Range: %s m · Cooldown: %s ticks

## godot/scripts/command_ledger.gd:439

Party roles

## godot/scripts/command_ledger.gd:440

Inspect or deploy a companion.

## godot/scripts/command_ledger.gd:443

%s · %s · %s queued

## godot/scripts/command_ledger.gd:446

Companion behavior · 

## godot/scripts/command_ledger.gd:449

No companion AI settings are exposed for this character.

## godot/scripts/command_ledger.gd:451

Resource policy

## godot/scripts/command_ledger.gd:452

When the queue is empty

## godot/scripts/command_ledger.gd:454

Hold after explicit orders

## godot/scripts/command_ledger.gd:458

Apply companion behavior

## godot/scripts/command_ledger.gd:462

Last decision: 

## godot/scripts/command_ledger.gd:480

Inventory · %s credits

## godot/scripts/command_ledger.gd:496

Find an item by name

## godot/scripts/command_ledger.gd:527

%s ×%s
%s free / %s reserved

## godot/scripts/command_ledger.gd:534

No items match these filters.

## godot/scripts/command_ledger.gd:539

Select an item to inspect its instance, reservations and permitted operations.

## godot/scripts/command_ledger.gd:540

Workbench and trade

## godot/scripts/command_ledger.gd:566

Instance: %s
Container: %s
Quantity %s · Free %s · Reserved %s

## godot/scripts/command_ledger.gd:568

Bound to: %s
Slots: %s

## godot/scripts/command_ledger.gd:570

Grants: 

## godot/scripts/command_ledger.gd:572

Occupies: 

## godot/scripts/command_ledger.gd:574

Quest protected

## godot/scripts/command_ledger.gd:579

Use with 

## godot/scripts/command_ledger.gd:583

Reserve characters cannot issue item orders.

## godot/scripts/command_ledger.gd:586

Choose a target next. Use joins this character's ordinary action queue.

## godot/scripts/command_ledger.gd:613

The Disputed Charter

Also: godot/scripts/command_ledger.gd:633, godot/content/garden_chapter.json#/title

## godot/scripts/command_ledger.gd:614

No active objective

## godot/scripts/command_ledger.gd:615

Status: %s · Outcome: %s

## godot/scripts/command_ledger.gd:616

Revealed skill opportunities

## godot/scripts/command_ledger.gd:619

%s · Checker: %s · DC %s

## godot/scripts/command_ledger.gd:621

Helper: 

## godot/scripts/command_ledger.gd:624

Available interactions

## godot/scripts/command_ledger.gd:626

Recent events

## godot/scripts/command_ledger.gd:630

No events recorded.

## godot/scripts/command_ledger.gd:634

This chapter has its own save slot. Your Lantern Quay journey is saved separately.

## godot/scripts/command_ledger.gd:635

Save chapter

## godot/scripts/command_ledger.gd:636

Load chapter…

## godot/scripts/command_ledger.gd:637

Loading pauses the encounter until you resume.

## godot/scripts/command_trial.gd:71

Command extension is not available. Rebuild the host extension.

## godot/scripts/command_trial.gd:88

Command returned an invalid transport response.

## godot/scripts/command_trial.gd:91

Command failed

## godot/scripts/command_trial.gd:98

Command: 

## godot/scripts/command_trial.gd:236

Stop current action?

## godot/scripts/command_trial.gd:236

Paid costs remain spent, and recovery still has to finish.

## godot/scripts/command_trial.gd:267

 · Unavailable

## godot/scripts/command_trial.gd:269

‹ Category

## godot/scripts/command_trial.gd:270

Category ›

## godot/scripts/command_trial.gd:271

‹ Previous companion

Also: godot/scripts/command_trial.gd:327

## godot/scripts/command_trial.gd:272

Next companion ›

Also: godot/scripts/command_trial.gd:328

## godot/scripts/command_trial.gd:274

More actions

## godot/scripts/command_trial.gd:276

Choose an order. Time stays paused.
L3 / R3 or [ / ] switches companions.

## godot/scripts/command_trial.gd:324

Choose on the garden floor

## godot/scripts/command_trial.gd:326

Click the garden floor to aim. Esc / Ⓑ cancels without spending.

## godot/scripts/command_trial.gd:330

Choose a target. Time stays paused while you aim.

## godot/scripts/command_trial.gd:335

Use item

## godot/scripts/command_trial.gd:438

Cannot apply this plan

## godot/scripts/command_trial.gd:454

Confirm this change?

## godot/scripts/command_trial.gd:455

Apply this change?

## godot/scripts/command_trial.gd:482

Enter the garden

## godot/scripts/command_trial.gd:486

Load chapter

## godot/scripts/command_trial.gd:493

Return to camp

## godot/scripts/command_trial.gd:498

Retry from encounter checkpoint

## godot/scripts/command_trial.gd:503

Party sheet

Also: godot/scripts/command_trial.gd:545

## godot/scripts/command_trial.gd:504

Return to menu

Also: godot/scripts/command_trial.gd:554

## godot/scripts/command_trial.gd:505

The seal recovered

## godot/scripts/command_trial.gd:505

Party defeated

## godot/scripts/command_trial.gd:505

Return to the gate and try again, or load a save.

## godot/scripts/command_trial.gd:513

Could not save this chapter.

## godot/scripts/command_trial.gd:521

Chapter saved.

## godot/scripts/command_trial.gd:521

Save failed: 

## godot/scripts/command_trial.gd:525

No save exists for this chapter.

## godot/scripts/command_trial.gd:545

Chapter loaded

## godot/scripts/command_trial.gd:545

Time is paused. Review the party before resuming.

## godot/scripts/command_trial.gd:554

Return to menu?

## godot/scripts/command_trial.gd:554

Unsaved chapter progress will be lost.

## godot/scripts/command_trial.gd:670

Clear future orders?

## godot/scripts/command_trial.gd:670

Release all waiting reservations. The current action continues.

## godot/scripts/command_weapon.gd:94

CommandWeapon requires a sibling ModelSlot with a rigged skeleton.

## godot/scripts/command_weapon.gd:101

CommandWeapon requires RHand and LHand bones.

## godot/scripts/command_weapon.gd:210

Unknown Command weapon presentation: 

## godot/scripts/demo.gd:32

Civic Clerk

## godot/scripts/demo.gd:78

Narrative extension is unavailable.

## godot/scripts/demo.gd:84

Story error: %s

## godot/scripts/demo.gd:186

RT Strike · Ⓧ Draw · Ⓑ Sheathe

## godot/scripts/demo.gd:186

LMB Strike · Q Draw · Esc Sheathe

## godot/scripts/demo.gd:187

Menu Ledger · View Map · Ⓨ Quest


## godot/scripts/demo.gd:187

Tab Ledger · M Map · J Quest · F5 Save · F9 Load


## godot/scripts/demo.gd:199

Speak with

## godot/scripts/demo.gd:202

Return to

## godot/scripts/demo.gd:208

filing cabinet

## godot/scripts/demo.gd:210

Civic Court

## godot/scripts/demo.gd:213

west archive door

## godot/scripts/demo.gd:235

CIVIC RECORDS OFFICE
Records recovered · exit south

Also: godot/scripts/map_widget.gd:174

## godot/scripts/demo.gd:235

CIVIC RECORDS OFFICE
Cabinet northwest · exit south

Also: godot/scripts/map_widget.gd:174

## godot/scripts/demo.gd:237

LANTERN GARDEN
Tower west · tide gate behind

Also: godot/scripts/map_widget.gd:177

## godot/scripts/demo.gd:239

EAST BLUFF
Ivo east · tower northwest

Also: godot/scripts/map_widget.gd:179

## godot/scripts/demo.gd:241

WEST MARKET
Quay east · old way north

Also: godot/scripts/map_widget.gd:181

## godot/scripts/demo.gd:243

CIVIC COURT
Tower ahead · quay south

Also: godot/scripts/map_widget.gd:183

## godot/scripts/demo.gd:245

CENTRAL QUAY
Tower north · market west · gate east

Also: godot/scripts/map_widget.gd:184

## godot/scripts/demo.gd:285

%s ready.

## godot/scripts/demo.gd:290

Weapon sheathed.

## godot/scripts/demo.gd:336

The archive door is locked. Ask the civic clerk about the records.

## godot/scripts/demo.gd:433

Dialogue failed.

Also: godot/scripts/demo.gd:464

## godot/scripts/demo.gd:450

Old Harbor Records added to Inventory.

## godot/scripts/demo.gd:482

Save failed.

## godot/scripts/demo.gd:486

Saved in %s.

## godot/scripts/demo.gd:486

Civic Records Office

Also: godot/scripts/demo.gd:532

## godot/scripts/demo.gd:486

Lantern Quay

Also: godot/scripts/demo.gd:532

## godot/scripts/demo.gd:486

Could not write save: %s

## godot/scripts/demo.gd:492

Load failed.

Also: godot/scripts/demo.gd:506

## godot/scripts/demo.gd:497

Combat profile is invalid.

Also: godot/scripts/save_store.gd:51

## godot/scripts/demo.gd:502

Saved position is invalid.

Also: godot/scripts/save_store.gd:39, godot/scripts/save_store.gd:42, godot/scripts/save_store.gd:44, godot/scripts/save_store.gd:46

## godot/scripts/demo.gd:532

Loaded %s.

## godot/scripts/demo.gd:599

Narrative extension returned invalid JSON.

## godot/scripts/dialogue_panel.gd:203

Ⓑ Skip response

## godot/scripts/dialogue_panel.gd:203

Esc: Skip response

## godot/scripts/dialogue_panel.gd:205

D-pad/stick: Choose · Ⓐ Confirm · Ⓑ Leave

## godot/scripts/dialogue_panel.gd:205

↑/↓: Choose · Enter: Confirm · Esc: Leave

## godot/scripts/garden_chapter.gd:8

Missing garden chapter

## godot/scripts/grounded_idle_character.gd:27

No floor below %s; keeping authored character placement.

## godot/scripts/hub_environment.gd:464

Seaside Garden GLB is missing; using blockout garden.

## godot/scripts/hub_environment.gd:468

Seaside Garden GLB did not import as a scene; using blockout garden.

## godot/scripts/hub_environment.gd:473

Seaside Garden GLB root is not Node3D; using blockout garden.

## godot/scripts/hub_environment.gd:482

Seaside Garden GLB has no visible mesh; using blockout garden.

## godot/scripts/hub_environment.gd:707

WEST ARCHIVE

## godot/scripts/hub_environment.gd:911

Lantern tower GLB did not import as a scene; using primitive tower.

## godot/scripts/hub_environment.gd:916

Lantern tower GLB root is not Node3D; using primitive tower.

## godot/scripts/hub_environment.gd:924

Lantern tower GLB has no visible mesh; using primitive tower.

## godot/scripts/journal_menu.gd:17

Combat Style

## godot/scripts/journal_menu.gd:82

Ⓑ Back   LB/RB Pages   Ⓧ/Ⓨ Actor   R-stick Scroll   D-pad Browse   Ⓐ Select

## godot/scripts/journal_menu.gd:82

Esc Back   ←/→ Pages   Q/E Actor   PgUp/PgDn Scroll   ↑/↓ Browse   Enter Select

## godot/scripts/journal_menu.gd:145

THE WAYFARER'S LEDGER

## godot/scripts/journal_menu.gd:270

CIVIC RECORDS OFFICE

## godot/scripts/journal_menu.gd:350

PARTY · 

## godot/scripts/journal_menu.gd:379

Ivo affinity 

## godot/scripts/journal_menu.gd:382

Outlook · not established

## godot/scripts/journal_menu.gd:384

Affinity 

## godot/scripts/journal_menu.gd:389

TRAINING  ·  

## godot/scripts/journal_menu.gd:391

Tradeoff: 

## godot/scripts/journal_menu.gd:392

Progression: 

## godot/scripts/journal_menu.gd:400

Equipment preview · Read only

## godot/scripts/journal_menu.gd:424

CHANGE COMBAT STYLE

## godot/scripts/journal_menu.gd:426

Controls: 

## godot/scripts/journal_menu.gd:430

CARRIED QUEST ITEMS

## godot/scripts/journal_menu.gd:436

No quest items carried. The old harbor records are kept in the civic building.

## godot/scripts/journal_menu.gd:438

INVENTORY PREVIEW · 

## godot/scripts/journal_menu.gd:440

Equipment changes are unavailable on this page.

## godot/scripts/journal_menu.gd:446

The area map is unavailable.

Also: godot/scripts/journal_menu.gd:450

## godot/scripts/journal_menu.gd:462

Return to your last saved position and story state.

## godot/scripts/journal_menu.gd:464

Loading replaces your current unsaved progress.

## godot/scripts/journal_menu.gd:468

Keep your position, choices, and the records in one local save slot.

## godot/scripts/journal_menu.gd:469

SAVE JOURNEY

## godot/scripts/journal_menu.gd:470

You can also save directly from exploration.

## godot/scripts/map_widget.gd:218

CIVIC COURT

## godot/scripts/map_widget.gd:219

EAST BLUFF

## godot/scripts/map_widget.gd:455

RECORDS FOUND

Also: godot/scripts/map_widget.gd:485

## godot/scripts/map_widget.gd:455

OLD RECORDS

Also: godot/scripts/map_widget.gd:483

## godot/scripts/map_widget.gd:469

YOU · GOAL

## godot/scripts/map_widget.gd:469

YOU · DONE

## godot/scripts/map_widget.gd:479

FIND THE CIVIC CLERK

## godot/scripts/map_widget.gd:481

RECORDS DOOR

## godot/scripts/map_widget.gd:486

EXPLORE THE QUAY

## godot/scripts/objective_tracker.gd:41

TRACKED OBJECTIVE

Also: godot/scripts/objective_tracker.gd:96

## godot/scripts/objective_tracker.gd:47

Collapse or expand quest

## godot/scripts/objective_tracker.gd:57

Dismiss objective (J / Y)

## godot/scripts/objective_tracker.gd:101

Expand quest

## godot/scripts/objective_tracker.gd:101

Collapse quest

## godot/scripts/objective_tracker.gd:130

Ask the civic clerk about the flood ledger.

## godot/scripts/objective_tracker.gd:132

Enter the west archive's records door.

## godot/scripts/objective_tracker.gd:134

Open the iron filing cabinet inside.

## godot/scripts/objective_tracker.gd:136

Records recovered. Read them in Inventory.

## godot/scripts/objective_tracker.gd:140

Explore Lantern Quay.

## godot/scripts/objective_tracker.gd:141

%d m to waypoint

## godot/scripts/objective_tracker.gd:141

Follow the map waypoint

## godot/scripts/party_catalog.gd:9

Invalid party preview catalog

## godot/scripts/records_office.gd:194

CIVIC RECORDS

## godot/scripts/save_store.gd:29

No save exists.

## godot/scripts/save_store.gd:32

Save header is invalid.

Also: godot/scripts/save_store.gd:36

## godot/scripts/save_store.gd:48

Narrative save is missing.

## godot/scripts/weapon_presentation.gd:12

Practice weapons require a rigged player with RHand.

## godot/content/lantern_quay.json#/nodes/0/text

The harbor wind keeps finding my lantern's last wick.

## godot/content/lantern_quay.json#/nodes/0/variants/0/text

That should keep the pier lamp burning until morning. Thank you.

## godot/content/lantern_quay.json#/nodes/0/variants/1/text

Mind the edge of the pier. The lamp is nearly out.

## godot/content/lantern_quay.json#/nodes/0/choices/0/text

Share a flask of lantern oil.

## godot/content/lantern_quay.json#/nodes/0/choices/1/text

Keep the oil for the road.

## godot/content/lantern_quay.json#/nodes/0/choices/2/text

Ask where Ivo stands watch.

## godot/content/lantern_quay.json#/nodes/0/choices/2/disable_when/0/reason

Already asked

## godot/content/lantern_quay.json#/nodes/0/choices/2/locked_reason

Share oil with Mara

Also: godot/content/lantern_quay.json#/nodes/4/choices/0/locked_reason, godot/content/lantern_quay.json#/nodes/7/choices/0/locked_reason

## godot/content/lantern_quay.json#/nodes/0/choices/3/text

Leave conversation.

Also: godot/content/lantern_quay.json#/nodes/4/choices/2/text, godot/content/lantern_quay.json#/nodes/7/choices/2/text, godot/content/lantern_quay.json#/nodes/13/choices/2/text

## godot/content/lantern_quay.json#/nodes/1/text

I can light the pier now. Ivo needs that marker to watch the channel.

## godot/content/lantern_quay.json#/nodes/2/text

Keep to the middle of the boards. You will need that oil farther out.

## godot/content/lantern_quay.json#/nodes/3/text

Ivo keeps watch by the east gate. Tell him you came from my pier.

## godot/content/lantern_quay.json#/nodes/4/text

The east gate has been chained since the last high water. I won't send another cart into the channel.

## godot/content/lantern_quay.json#/nodes/4/variants/0/text

The eastern road is open. Keep the tower's flame in sight when you come home.

## godot/content/lantern_quay.json#/nodes/4/variants/1/text

Mara says you gave her oil. A lit pier makes this channel safer.

## godot/content/lantern_quay.json#/nodes/4/choices/0/text

Ask Ivo to unbar the east gate.

## godot/content/lantern_quay.json#/nodes/4/choices/1/text

Ask why the gate is chained.

## godot/content/lantern_quay.json#/nodes/5/text

With the pier marker lit, I can watch your crossing. I'll raise the chain. Stay on the raised garden walk; the cart road is still flooded.

## godot/content/lantern_quay.json#/nodes/6/text

At high water you could mistake the road for the sea. We lost a wagon that way last winter.

## godot/content/lantern_quay.json#/nodes/7/text

The civic office has two doors. Only one still leads where the signs claim.

## godot/content/lantern_quay.json#/nodes/7/variants/0/text

Here: the garden walk is reserved for public passage. The seal on that gate cannot cancel this entry.

## godot/content/lantern_quay.json#/nodes/7/variants/1/text

The west archive door is marked on your map. The flood ledger is in the iron cabinet inside.

## godot/content/lantern_quay.json#/nodes/7/variants/2/text

The market side passage is unlatched for you. Mind the low lintel.

## godot/content/lantern_quay.json#/nodes/7/variants/3/text

I saw Mara's pier lamp from my desk. Perhaps I can open the market passage.

## godot/content/lantern_quay.json#/nodes/7/choices/0/text

Ask to use the market side passage.

## godot/content/lantern_quay.json#/nodes/7/choices/1/text

Ask about the old harbor records.

## godot/content/lantern_quay.json#/nodes/8/text

I'll leave the side door unlatched. It cuts from this court to the market.

## godot/content/lantern_quay.json#/nodes/9/text

The flood ledger is in the west archive, beside the tower. I have marked its records door on your map. Look in the iron cabinet inside.

## godot/content/lantern_quay.json#/nodes/10/speaker

Filing Cabinet

## godot/content/lantern_quay.json#/nodes/10/text

The bottom drawer slides open. A leather-bound flood ledger rests beneath its dividers.

## godot/content/lantern_quay.json#/nodes/10/variants/0/text

The Old Harbor Records are safe in your satchel. The cabinet holds nothing else.

## godot/content/lantern_quay.json#/nodes/10/choices/0/text

Take the Old Harbor Records.

## godot/content/lantern_quay.json#/nodes/10/choices/1/text

Close the drawer for now.

## godot/content/lantern_quay.json#/nodes/10/choices/2/text

Leave cabinet.

Also: godot/content/lantern_quay.json#/nodes/11/choices/1/text, godot/content/lantern_quay.json#/nodes/12/choices/1/text

## godot/content/lantern_quay.json#/nodes/11/text

One entry reserves the raised garden walk for the quay's workers. It bears the civic stamp. You place the ledger in your satchel.

## godot/content/lantern_quay.json#/nodes/11/choices/0/text

Close the drawer.

## godot/content/lantern_quay.json#/nodes/12/text

You close the drawer.

## godot/content/lantern_quay.json#/nodes/12/choices/0/text

Open the drawer again.

## godot/content/lantern_quay.json#/nodes/13/text

Fresh rope, dry matches, and a map that has never met the tide.

## godot/content/lantern_quay.json#/nodes/13/variants/0/text

With the east road open, people may finally buy something besides rope.

## godot/content/lantern_quay.json#/nodes/13/variants/1/text

The clerk's passage is open? That saves me the long walk around to the court.

## godot/content/lantern_quay.json#/nodes/13/choices/0/text

Ask for directions through town.

## godot/content/lantern_quay.json#/nodes/13/choices/1/text

Ask about the lantern tower.

## godot/content/lantern_quay.json#/nodes/14/text

The market runs west, the office sits by the northern tower, and Ivo watches the east gate. Find the tower when you lose your bearings.

## godot/content/lantern_quay.json#/nodes/15/text

The tower's been patched so often no one recalls its first shape. Still, every path around here finds it.

## godot/content/rpg_catalog.json#/actors/0/name

Emerald Corsair

## godot/content/rpg_catalog.json#/profiles/command/inventory

Shared categorized list · no weight penalty; proficiency and armor restrictions still apply.

## godot/content/rpg_catalog.json#/profiles/command/coverage

Weapon specialist, scout, infiltrator, melee mystic, power specialist, balanced investigator. Four builds shown.

## godot/content/rpg_catalog.json#/profiles/command/hud

Three portraits · actor action bar · current action and future queue · manual / contact pause

## godot/content/rpg_catalog.json#/profiles/command/builds/player/loop

Hold a target, bait a strike, then commit a riposte.

## godot/content/rpg_catalog.json#/profiles/command/builds/player/weakness

Limited area control; exposed while committing a lunge.

## godot/content/rpg_catalog.json#/profiles/command/builds/player/progression

Weapon feats or broader investigation skills.

## godot/content/rpg_catalog.json#/profiles/command/builds/player/gear/0/detail

One hand · melee training

## godot/content/rpg_catalog.json#/profiles/command/builds/player/gear/1/detail

Enables shield response

## godot/content/rpg_catalog.json#/profiles/command/builds/player/gear/2/detail

Light · compatible with minor powers

## godot/content/rpg_catalog.json#/profiles/command/builds/player/gear/3/detail

Grants Gust while equipped

## godot/content/rpg_catalog.json#/profiles/command/builds/player/gear/4/name

Navigator seal

## godot/content/rpg_catalog.json#/profiles/command/builds/player/gear/4/detail

Awareness bonus

## godot/content/rpg_catalog.json#/profiles/command/builds/player/gear/5/name

Field dressing ×3

Also: godot/content/rpg_catalog.json#/profiles/momentum/builds/player/gear/5/name, godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/gear/5/name, godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/gear/5/name, godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/gear/5/name

## godot/content/rpg_catalog.json#/profiles/command/builds/player/gear/5/detail

Shared consumable

## godot/content/rpg_catalog.json#/profiles/command/builds/player/abilities/0/cost

1 queued order

Also: godot/content/rpg_catalog.json#/profiles/command/builds/player/abilities/3/cost

## godot/content/rpg_catalog.json#/profiles/command/builds/player/abilities/0/source

Learned · Blades

## godot/content/rpg_catalog.json#/profiles/command/builds/player/abilities/0/effect

Close distance and attack one target.

## godot/content/rpg_catalog.json#/profiles/command/builds/player/abilities/1/cost

1 queued order · after guard

## godot/content/rpg_catalog.json#/profiles/command/builds/player/abilities/1/source

Learned · Evasion

## godot/content/rpg_catalog.json#/profiles/command/builds/player/abilities/1/effect

Exploit a blocked strike.

## godot/content/rpg_catalog.json#/profiles/command/builds/player/abilities/2/cost

1 queued order + 12 focus

## godot/content/rpg_catalog.json#/profiles/command/builds/player/abilities/2/source

Equipped · Storm lens

## godot/content/rpg_catalog.json#/profiles/command/builds/player/abilities/2/effect

Push a nearby target.

## godot/content/rpg_catalog.json#/profiles/command/builds/player/abilities/3/source

Equipped · Buckler

## godot/content/rpg_catalog.json#/profiles/command/builds/player/abilities/3/effect

Reduce the next frontal hit.

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/skills/0

Power control III

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/loop

Bind a group, create distance, then choose recovery or damage.

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/weakness

Fragile armor; healing competes with control for Focus.

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/progression

Invest in control duration or recovery efficiency.

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/gear/0/detail

Two hands · channeling

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/gear/1/name

Tideweave robe

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/gear/1/detail

Casting compatible

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/gear/2/name

Stormglass focus

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/gear/2/detail

Improves learned power reach

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/gear/5/name

Focus draught ×2

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/gear/5/detail

Limited recovery

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/abilities/0/cost

1 order + 10 focus

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/abilities/0/source

Learned · Power

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/abilities/0/effect

Ranged single-target force.

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/abilities/1/name

Binding current

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/abilities/1/cost

1 order + 18 focus

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/abilities/1/source

Learned · Control

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/abilities/1/effect

Hold a small group in place.

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/abilities/2/cost

1 order + 16 focus

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/abilities/2/source

Learned · Medicine

Also: godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/abilities/3/source

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/abilities/2/effect

Restore one ally.

Also: godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/abilities/0/effect, godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/abilities/1/effect, godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/abilities/3/effect, godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/abilities/2/effect

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/abilities/3/cost

1 order + 20 focus

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/abilities/3/source

Learned · Defense

Also: godot/content/rpg_catalog.json#/profiles/command/builds/ivo/abilities/1/source

## godot/content/rpg_catalog.json#/profiles/command/builds/mara/abilities/3/effect

Protect allies from ranged pressure.

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/loop

Hold a lane and protect the ally the enemy is pressuring.

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/weakness

Low mobility and no supernatural powers.

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/progression

Shield feats, heavy armor or ranged suppression.

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/gear/0/detail

One hand · impact

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/gear/1/detail

Interpose coverage

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/gear/2/detail

Heavy; restricts some powers

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/gear/3/detail

Physical defense

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/gear/5/name

Trauma kit ×2

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/gear/5/detail

Shared recovery

Also: godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/gear/5/detail, godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/gear/5/detail

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/abilities/0/source

Learned · Shields

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/abilities/0/effect

Push a nearby attacker.

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/abilities/1/cost

1 order + shield

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/abilities/1/effect

Guard an adjacent ally.

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/abilities/2/source

Learned · Leadership

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/abilities/2/effect

Help allies resist disruption.

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/abilities/3/name

Anchor stance

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/abilities/3/cost

1 order · stance

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/abilities/3/source

Learned · Armor

## godot/content/rpg_catalog.json#/profiles/command/builds/ivo/abilities/3/effect

Trade movement for stability.

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/skills/1

Marksmanship II

Also: godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/skills/0, godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/skills/1

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/loop

Expose a weakness and disable a device before a precision shot.

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/weakness

Poor sustained defense; utility needs valid targets.

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/progression

Device access, ranged feats or investigation.

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/gear/0/name

Light crossbow

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/gear/0/detail

Two hands · precision

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/gear/1/name

Scout leathers

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/gear/2/detail

Device detection

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/gear/3/detail

Device interaction

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/gear/5/name

Smoke vial ×2

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/gear/5/detail

Consumable escape

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/abilities/0/source

Learned · Marksmanship

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/abilities/0/effect

Slow one target.

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/abilities/1/name

Disrupt device

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/abilities/1/cost

1 order · valid device

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/abilities/1/source

Tool · Survey tool

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/abilities/1/effect

Temporarily disable a device.

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/abilities/2/name

Expose weakness

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/abilities/2/source

Learned · Lore

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/abilities/2/effect

Mark a vulnerability for allies.

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/abilities/3/name

Smoke retreat

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/abilities/3/cost

1 order + smoke vial

## godot/content/rpg_catalog.json#/profiles/command/builds/clerk/abilities/3/effect

Break sight and reposition.

## godot/content/rpg_catalog.json#/profiles/flow/inventory

Styles library + amulet and gems · learned styles are not bag items; no generic armor grid.

## godot/content/rpg_catalog.json#/profiles/flow/coverage

Martial, magic, weapon, support and transformation styles. Build emphasis never locks out cross-training.

## godot/content/rpg_catalog.json#/profiles/flow/hud

Four-slot style diamond on left · Health / Chi / Focus · block / heal · follower Attack / Support

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/role

Stone disciple · Martial

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/skills/2

Intimidation II

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/loop

Read a guard, interrupt, then use a martial finisher.

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/weakness

Must close distance; Chi enhancement competes with healing.

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/progression

Style points into speed, damage or efficiency; cross-train freely.

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/gear/0/slot

Martial style

Also: godot/content/rpg_catalog.json#/profiles/flow/builds/mara/gear/0/slot, godot/content/rpg_catalog.json#/profiles/flow/builds/mara/abilities/3/source, godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/gear/0/slot, godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/abilities/3/source, godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/gear/0/slot

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/gear/0/detail

Training · no basic resource cost

Also: godot/content/rpg_catalog.json#/profiles/flow/builds/mara/gear/0/detail, godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/gear/0/detail, godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/gear/0/detail

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/gear/1/detail

Attacks spend Focus

Also: godot/content/rpg_catalog.json#/profiles/flow/builds/mara/gear/1/detail, godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/gear/1/detail, godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/gear/1/detail

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/gear/2/detail

Attacks spend Chi

Also: godot/content/rpg_catalog.json#/profiles/flow/builds/mara/gear/2/detail, godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/gear/2/detail, godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/gear/2/detail

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/gear/3/slot

Support style

Also: godot/content/rpg_catalog.json#/profiles/flow/builds/player/abilities/2/source, godot/content/rpg_catalog.json#/profiles/flow/builds/mara/gear/3/slot, godot/content/rpg_catalog.json#/profiles/flow/builds/mara/abilities/2/source, godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/gear/3/slot, godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/abilities/2/source, godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/gear/3/slot, godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/abilities/0/source

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/gear/3/detail

Setup and control

Also: godot/content/rpg_catalog.json#/profiles/flow/builds/mara/gear/3/detail, godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/gear/3/detail, godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/gear/3/detail

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/gear/4/name

Tideglass amulet

Also: godot/content/rpg_catalog.json#/profiles/flow/builds/mara/gear/4/name, godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/gear/4/name, godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/gear/4/name

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/gear/4/detail

Two gem sockets

Also: godot/content/rpg_catalog.json#/profiles/flow/builds/mara/gear/4/detail, godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/gear/4/detail, godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/gear/4/detail

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/gear/5/detail

Passive attribute effect

Also: godot/content/rpg_catalog.json#/profiles/flow/builds/mara/gear/5/detail, godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/gear/5/detail, godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/gear/5/detail

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/abilities/0/source

Martial · Stone palm

Also: godot/content/rpg_catalog.json#/profiles/flow/builds/player/abilities/1/source

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/abilities/0/effect

Fast close strikes.

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/abilities/1/name

Guard breaker

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/abilities/1/cost

Power attack · wind-up

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/abilities/1/effect

Break a block; vulnerable to interruption.

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/abilities/2/cost

Support setup

Also: godot/content/rpg_catalog.json#/profiles/flow/builds/mara/abilities/2/cost, godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/abilities/2/cost, godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/abilities/0/cost

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/abilities/2/effect

Create a brief finisher opening.

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/abilities/3/cost

Valid setup window

Also: godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/abilities/1/cost

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/abilities/3/source

Martial finisher

Also: godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/abilities/1/source

## godot/content/rpg_catalog.json#/profiles/flow/builds/player/abilities/3/effect

Exploit the support opening.

## godot/content/rpg_catalog.json#/profiles/flow/builds/mara/role

Gale sage · Magic

## godot/content/rpg_catalog.json#/profiles/flow/builds/mara/loop

Control space with Chi, then return to martial attacks to conserve it.

## godot/content/rpg_catalog.json#/profiles/flow/builds/mara/weakness

Chi exhaustion removes both casting and healing options.

## godot/content/rpg_catalog.json#/profiles/flow/builds/mara/progression

Develop elemental styles, control duration or Chi economy.

## godot/content/rpg_catalog.json#/profiles/flow/builds/mara/gear/3/name

River stillness

Also: godot/content/rpg_catalog.json#/profiles/flow/builds/mara/abilities/2/name

## godot/content/rpg_catalog.json#/profiles/flow/builds/mara/abilities/0/effect

Area displacement.

## godot/content/rpg_catalog.json#/profiles/flow/builds/mara/abilities/1/effect

Focused ranged attack.

## godot/content/rpg_catalog.json#/profiles/flow/builds/mara/abilities/2/effect

Slow a target for a finisher.

## godot/content/rpg_catalog.json#/profiles/flow/builds/mara/abilities/3/effect

Resource-free close fallback.

## godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/role

Blade dancer · Focus

## godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/skills/0

Weapon styles III

## godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/skills/1

Acrobatics II

## godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/loop

Use weapon reach, then switch back before Focus runs dry.

## godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/weakness

Weapon attacks and time-slowing Focus mode share a reserve.

## godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/progression

Weapon efficiency, reach or martial backup.

## godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/gear/1/name

Whirling staff

## godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/abilities/0/effect

Reach across a nearby group.

## godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/abilities/1/effect

Commit to a strong overhead attack.

## godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/abilities/2/effect

Create space for a weapon follow-up.

## godot/content/rpg_catalog.json#/profiles/flow/builds/ivo/abilities/3/effect

Keep fighting without Focus.

## godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/role

Storm adept · Hybrid

## godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/loop

Apply a support setup, finish in melee, then cast only when needed.

## godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/weakness

Less early specialization; more style switching to manage.

## godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/progression

Broaden combinations or specialize one trained style.

## godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/gear/3/name

Quiet current

Also: godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/abilities/0/name

## godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/gear/5/name

Duality charm

## godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/abilities/0/effect

Open a controlled finisher window.

## godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/abilities/1/effect

Convert control into damage.

## godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/abilities/2/effect

Reach a distant target.

## godot/content/rpg_catalog.json#/profiles/flow/builds/clerk/abilities/3/effect

Deflect while closing distance.

## godot/content/rpg_catalog.json#/profiles/flow/common_actions/0/name

Block / evade

## godot/content/rpg_catalog.json#/profiles/flow/common_actions/0/effect

Respond to attacks.

## godot/content/rpg_catalog.json#/profiles/flow/common_actions/1/cost

Chi over time

## godot/content/rpg_catalog.json#/profiles/flow/common_actions/1/effect

Trade casting resource for health.

## godot/content/rpg_catalog.json#/profiles/flow/common_actions/2/effect

Slow opponents; competes with weapon use.

## godot/content/rpg_catalog.json#/profiles/flow/common_actions/3/name

Chi enhancement

## godot/content/rpg_catalog.json#/profiles/flow/common_actions/3/cost

Chi per enhanced strike

## godot/content/rpg_catalog.json#/profiles/flow/common_actions/3/effect

Toggle additional martial power.

## godot/content/rpg_catalog.json#/profiles/vanguard/inventory

Squad equipment lists · weapon / armor / tool / amplifier eligibility; heat preset, no weight penalty.

## godot/content/rpg_catalog.json#/profiles/vanguard/coverage

Combat, Tech, Biotic; Combat+Tech Saboteur and Combat+Biotic Stormbreaker still need builds; Tech+Biotic shown.

## godot/content/rpg_catalog.json#/profiles/vanguard/hud

Aim and cover · health / shields · heat · squad power wheel · cooldowns

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/role

Breacher · Combat

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/skills/1

Close quarters III

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/loop

Use the right firearm, close safely, then apply a melee response.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/weakness

Limited battlefield control; depends on squad powers.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/progression

Firearm training, resilience and close-range talents.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/gear/0/detail

Heat-based close-range firearm

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/gear/1/name

Service carbine

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/gear/1/detail

Heat-based ranged alternative

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/gear/2/name

Assault harness

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/gear/2/detail

Heavy combat training

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/gear/3/detail

Shield capacity

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/gear/4/detail

Cooling versus burst tradeoff

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/gear/5/name

Trauma gel ×3

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/gear/5/detail

Shared healing

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/abilities/0/name

Breach strike

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/abilities/0/cost

Melee · recovery

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/abilities/0/source

Combat training

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/abilities/0/effect

Close-range impact response.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/abilities/1/name

Concussive shot

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/abilities/1/source

Combat talent

Also: godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/abilities/2/source

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/abilities/1/effect

Disrupt a vulnerable target.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/abilities/2/cost

16 s cooldown

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/abilities/2/effect

Temporary damage resistance.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/player/abilities/3/effect

Keep pressure on a lane.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/role

Field engineer · Tech

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/skills/0

Engineering III

Also: godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/skills/0

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/skills/1

Electronics III

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/loop

Strip a shield or disable a weapon, then support a squadmate.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/weakness

Light protection and limited weapon training.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/progression

Tech disruption, medical recovery or tool efficiency.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/gear/0/name

Signal pistol

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/gear/0/detail

Heat-based sidearm

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/gear/1/name

Engineer harness

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/gear/1/detail

Light tech armor

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/gear/2/detail

Tech power eligibility

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/gear/3/name

Recovery cell

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/gear/3/detail

Faster shield recovery

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/gear/4/detail

Disruption potency

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/gear/5/name

Repair gel ×3

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/gear/5/detail

Finite support supply

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/abilities/0/cost

10 s cooldown

Also: godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/abilities/0/cost, godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/abilities/0/cost

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/abilities/0/source

Learned · Tech

Also: godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/abilities/1/source, godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/abilities/0/source

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/abilities/0/effect

Disable enemy weapon operation.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/abilities/1/effect

Damage a shield layer.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/abilities/2/name

Shield repair

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/abilities/2/cost

14 s cooldown

Also: godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/abilities/2/cost, godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/abilities/1/cost

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/abilities/2/source

Learned · Engineering

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/abilities/2/effect

Restore an ally's shielding.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/abilities/3/name

Device bypass

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/abilities/3/cost

Valid device · utility

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/abilities/3/source

Tool · Pulse tool

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/mara/abilities/3/effect

Open a technical interaction.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/role

Gravitic adept · Biotic

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/skills/0

Biotic control III

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/skills/1

Amplification III

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/loop

Suspend or displace enemies so the squad can exploit the opening.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/weakness

Low durability; some defended targets resist control.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/progression

Control duration, area coverage or protective barriers.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/gear/0/detail

Basic firearm

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/gear/1/name

Adept harness

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/gear/1/detail

Light amplifier-compatible armor

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/gear/2/detail

Biotic power scaling

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/gear/3/detail

Barrier support

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/gear/4/name

Focusing ring

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/gear/4/detail

Control precision

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/gear/5/name

Trauma gel ×2

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/abilities/0/source

Learned · Biotic

Also: godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/abilities/1/source, godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/abilities/2/source, godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/abilities/3/source, godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/abilities/1/source, godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/abilities/2/source

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/abilities/0/effect

Suspend a valid target.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/abilities/1/cost

18 s cooldown

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/abilities/1/effect

Pull a small group together.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/abilities/2/name

Kinetic barrier

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/abilities/2/effect

Protect against incoming fire.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/abilities/3/cost

12 s cooldown

Also: godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/abilities/2/cost

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/ivo/abilities/3/effect

Apply persistent disruptive damage.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/role

Storm sentinel · Tech + Biotic

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/skills/0

Engineering II

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/loop

Alternate shield disruption and barrier support around ally cooldowns.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/weakness

Narrow weapon training and less specialist power depth.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/progression

Choose a tech or biotic branch without gaining every specialist talent.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/gear/0/detail

Limited firearm training

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/gear/1/name

Sentinel harness

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/gear/1/detail

Hybrid compatibility

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/gear/2/name

Concord processor

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/gear/2/detail

Tech eligibility

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/gear/3/detail

Biotic eligibility

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/gear/4/name

Reactive capacitor

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/gear/4/detail

Defensive recovery

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/gear/5/name

Recovery gel ×2

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/abilities/0/effect

Weaken a defense layer.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/abilities/1/name

Barrier pulse

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/abilities/1/effect

Shield an ally.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/abilities/2/name

Kinetic throw

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/abilities/2/effect

Displace a valid target.

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/abilities/3/cost

18 s cooldown + gel

## godot/content/rpg_catalog.json#/profiles/vanguard/builds/clerk/abilities/3/effect

Recover a threatened ally.

## godot/content/rpg_catalog.json#/profiles/tactics/inventory

Actor grid/list view · PF2-inspired Bulk, held / worn / stowed access; no kilogram substitution.

## godot/content/rpg_catalog.json#/profiles/tactics/coverage

Fighter, prepared caster, skill specialist and divine warden shown; additional class families and SF2 pack pending.

## godot/content/rpg_catalog.json#/profiles/tactics/hud

Initiative · inspectable party · three actions / reaction · path cost · End Turn

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/role

Shield fighter

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/skills/0

Weapons: expert

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/skills/1

Athletics: trained

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/skills/2

Armor: trained

Also: godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/skills/2

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/loop

Stride into a lane, strike, and decide whether to raise the shield.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/weakness

Action costs prevent attacking, moving and defending without tradeoffs.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/progression

Class feats, weapon proficiency and defensive reactions.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/gear/0/detail

One-handed Strike

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/gear/1/name

Training shield

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/gear/1/detail

Raise Shield and block eligibility

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/gear/2/detail

Armor proficiency required

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/gear/3/name

Strength belt

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/gear/3/detail

Attribute effect

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/gear/4/detail

Retrieval cost

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/gear/5/name

Field dressing

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/gear/5/detail

Draw/use follow adapter rules

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/abilities/0/effect

Move up to allowed distance.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/abilities/1/cost

1 action · attack penalty applies

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/abilities/1/effect

Attack one target.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/abilities/2/effect

Gain shield defense.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/abilities/3/cost

Reaction · shield raised

## godot/content/rpg_catalog.json#/profiles/tactics/builds/player/abilities/3/effect

Reduce a qualifying hit.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/role

Prepared elementalist

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/skills/0

Arcana: trained

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/skills/1

Spellcasting: trained

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/skills/2

Lore: trained

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/loop

Prepare a limited spell selection; use cantrips when conserving slots.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/weakness

Low armor; preparation limits today's options.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/progression

Spell ranks, prepared choices and school feats.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/gear/1/detail

Unarmored defense

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/gear/2/detail

Preparation record; not a held shield

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/gear/5/name

Component pouch

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/gear/5/detail

Casting requirements

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/abilities/0/name

Cinder cantrip

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/abilities/0/source

Prepared cantrip

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/abilities/0/effect

Repeatable ranged magic.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/abilities/1/cost

2 actions + rank 1 slot

Also: godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/abilities/2/cost, godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/abilities/0/cost

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/abilities/1/source

Prepared spell

Also: godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/abilities/2/source

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/abilities/1/effect

Affect targets in a line.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/abilities/2/effect

Protect one ally.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/abilities/3/name

Recall knowledge

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/abilities/3/source

Arcana / Lore

## godot/content/rpg_catalog.json#/profiles/tactics/builds/mara/abilities/3/effect

Inspect an unfamiliar threat.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/skills/0

Stealth: expert

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/skills/1

Thievery: trained

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/skills/2

Finesse weapons: trained

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/loop

Create an opening, strike precisely, then reposition.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/weakness

Precision needs a valid opening; cannot absorb sustained hits.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/progression

Skill feats, evasive reactions and precision progression.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/gear/0/name

Dueling knife

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/gear/1/name

Throwing knife

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/gear/1/detail

Thrown alternative

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/gear/2/name

Soft leathers

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/gear/3/name

Thieves' tools

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/gear/3/detail

Device access

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/gear/4/detail

Situational bonus

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/abilities/0/source

Skill · Deception

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/abilities/0/effect

Create a precision opening.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/abilities/1/name

Precise strike

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/abilities/1/cost

1 action · qualifying target

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/abilities/1/source

Weapon + class feature

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/abilities/1/effect

Apply precision when eligible.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/abilities/2/effect

Careful short reposition.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/abilities/3/name

Disable device

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/abilities/3/cost

Actions depend on device

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/abilities/3/source

Skill + tools

## godot/content/rpg_catalog.json#/profiles/tactics/builds/ivo/abilities/3/effect

Attempt a technical obstacle.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/role

Divine warden

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/skills/0

Religion: trained

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/skills/1

Medicine: expert

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/loop

Choose between recovery, a ward and direct contribution.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/weakness

Limited slots and action economy; cannot heal everyone every turn.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/progression

Divine preparation, medicine feats and protective reactions.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/gear/2/detail

Training required

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/gear/3/detail

Divine casting

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/gear/4/name

Healer's tools

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/gear/5/detail

Limited spell slots

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/abilities/0/source

Prepared divine spell

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/abilities/1/cost

1 action + focus use

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/abilities/1/source

Learned focus power

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/abilities/1/effect

Brief protective ward.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/abilities/2/name

Battle medicine

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/abilities/2/cost

1 action · target immunity applies

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/abilities/2/source

Medicine feat

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/abilities/2/effect

Emergency recovery with a per-target limit.

## godot/content/rpg_catalog.json#/profiles/tactics/builds/clerk/abilities/3/effect

Improve personal defense.

## godot/content/rpg_catalog.json#/profiles/oathbound/inventory

Shared filtered list · expandable stack capacity; armor fatigue and two weapon sets.

## godot/content/rpg_catalog.json#/profiles/oathbound/coverage

Warrior / Rogue / Mage plus specializations; Spellwarden is a mage specialization, not a fourth class.

## godot/content/rpg_catalog.json#/profiles/oathbound/hud

Four portraits · pause · quickbar / two-layer shortcuts · ordered tactics · hold / follow

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/role

Warrior · Ashguard

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/skills/0

Shield talents III

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/skills/1

Combat training III

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/loop

Hold a choke and keep attention off the caster.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/weakness

Heavy armor increases effective ability costs.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/progression

Warrior talents → protective or aggressive specialization.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/gear/0/name

Ashguard sword

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/gear/1/detail

Shield talents

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/gear/2/detail

Protection with fatigue

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/gear/3/name

Watch crossbow

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/gear/3/detail

Weapon set B · two hands

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/gear/5/name

Groundleaf salve ×3

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/abilities/0/cost

20 stamina · cooldown

Also: godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/abilities/1/cost

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/abilities/0/source

Learned talent

Also: godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/abilities/1/source, godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/abilities/1/source, godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/abilities/2/source

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/abilities/0/effect

Interrupt a nearby foe.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/abilities/1/name

Threatening call

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/abilities/1/cost

25 stamina · cooldown

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/abilities/1/effect

Draw nearby attention.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/abilities/2/cost

Reserve 20 stamina

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/abilities/2/source

Sustained talent

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/abilities/2/effect

Defense while reducing usable stamina.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/abilities/3/name

Pommel strike

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/abilities/3/cost

15 stamina · cooldown

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/abilities/3/source

Learned weapon talent

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/player/abilities/3/effect

Disorient one target.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/role

Mage · Cinder scholar

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/skills/0

Elemental III

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/loop

Place control areas carefully, then choose offense or healing.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/weakness

Low physical protection; area spells may threaten allies.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/progression

Spell chains → control, healing or risky-resource specialization.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/gear/0/detail

Two hands · basic projectile

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/gear/2/detail

Spell potency

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/gear/3/detail

Resource capacity

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/gear/4/detail

Elemental affinity

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/gear/5/name

Mana tonic ×2

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/gear/5/detail

Finite recovery

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/abilities/0/source

Equipped staff

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/abilities/0/effect

Attack without spending mana.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/abilities/1/cost

20 mana · cooldown

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/abilities/1/source

Learned spell

Also: godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/abilities/2/source, godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/abilities/1/source, godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/abilities/3/source

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/abilities/2/cost

35 mana · cooldown

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/abilities/2/effect

Area damage with preview.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/abilities/3/cost

Reserve 30 mana

Also: godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/abilities/2/cost

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/abilities/3/source

Sustained spell

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/mara/abilities/3/effect

Protect while reducing casting reserve.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/role

Rogue · Shadow scout

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/skills/0

Dual weapons III

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/loop

Reach a flank, exploit it, then escape retaliation.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/weakness

Positional requirements and weaker frontal defense.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/progression

Rogue talents → assassin, duelist, support or companion specialization.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/gear/0/name

Needle dagger

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/gear/1/name

Parrying dagger

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/gear/1/detail

Dual-weapon training

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/gear/2/name

Shadow leathers

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/gear/4/name

Lockpick roll

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/gear/5/name

Smoke flask ×2

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/gear/5/detail

Limited escape

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/abilities/0/cost

Basic attack · valid flank

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/abilities/0/source

Class feature

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/abilities/0/effect

Positional precision damage.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/abilities/1/effect

Help the party damage a target.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/abilities/2/cost

Sustained · detection rules

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/abilities/2/effect

Approach without immediate notice.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/abilities/3/cost

Trap item + setup time

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/abilities/3/source

Skill + consumable

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/ivo/abilities/3/effect

Prepare a chokepoint.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/role

Mage · Spellwarden specialization

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/skills/0

Spellcraft II

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/skills/2

Martial specialization I

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/loop

Maintain a ward, hold a position, and reserve enough mana to recover an ally.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/weakness

Sustained defense and armor fatigue reduce casting freedom.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/progression

Mage progression with martial specialization requirements.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/gear/0/detail

Specialization eligibility

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/gear/1/detail

Martial specialization

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/gear/2/name

Spellwarden mail

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/gear/2/detail

Fatigue applies

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/gear/4/detail

Ward efficiency

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/gear/5/name

Recovery salve ×2

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/abilities/0/cost

15 mana · cooldown

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/abilities/0/source

Specialization talent

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/abilities/0/effect

Magically empowered melee.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/abilities/1/name

Guardian pulse

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/abilities/1/cost

25 mana · cooldown

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/abilities/1/effect

Protect nearby allies.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/abilities/2/source

Sustained specialization

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/abilities/2/effect

Maintain personal protection.

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/abilities/3/cost

22 mana · cooldown

## godot/content/rpg_catalog.json#/profiles/oathbound/builds/clerk/abilities/3/effect

Recover a single ally.

## godot/content/rpg_catalog.json#/profiles/momentum/inventory

Item list + linked socket editor · transferable grants and persistent weapon mastery; no weight penalty.

## godot/content/rpg_catalog.json#/profiles/momentum/coverage

Unique stance, casting zone, pressure combo and charged-shot identities; flexible socket builds across them.

## godot/content/rpg_catalog.json#/profiles/momentum/hud

Direct action · three party strips · two ATB segments · tactical slowdown · pressure / stagger

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/role

Stance striker

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/skills/0

Blade mastery II

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/skills/1

Guard timing II

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/skills/2

Gale socket I

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/loop

Build ATB in mobile stance, commit to a heavy art during stagger.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/weakness

Committed stance reduces mobility.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/progression

Master weapon arts; improve or replace linked sockets.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/gear/0/name

Resonant sabre

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/gear/0/detail

Weapon art has mastery progress

Also: godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/gear/0/detail, godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/gear/0/detail, godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/gear/0/detail

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/gear/1/detail

Socket-bearing armor

Also: godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/gear/1/detail, godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/gear/1/detail, godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/gear/1/detail

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/gear/2/detail

Grants its spell while equipped

Also: godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/gear/2/detail, godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/gear/2/detail, godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/gear/2/detail

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/gear/3/slot

Linked socket

Also: godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/gear/3/slot, godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/gear/3/slot, godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/gear/3/slot

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/gear/3/detail

Support modifier; compatibility required

Also: godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/gear/3/detail, godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/gear/3/detail, godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/gear/3/detail

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/gear/4/detail

Passive build effect

Also: godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/gear/4/detail, godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/gear/4/detail, godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/gear/4/detail

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/gear/5/detail

1 ATB segment + one item

Also: godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/gear/5/detail, godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/gear/5/detail, godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/gear/5/detail

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/abilities/0/cost

Unique action

Also: godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/abilities/0/cost

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/abilities/0/source

Actor identity

Also: godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/abilities/0/source, godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/abilities/0/source, godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/abilities/0/source

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/abilities/0/effect

Switch mobility and committed blade behavior.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/abilities/1/source

Weapon art · mastery 60%

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/abilities/1/effect

Strong focused strike.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/abilities/2/source

Socket · Gale shard

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/abilities/2/effect

Ranged elemental control.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/abilities/3/source

Mastered weapon art

Also: godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/abilities/3/source

## godot/content/rpg_catalog.json#/profiles/momentum/builds/player/abilities/3/effect

Heavy finisher; remains learned after weapon swap.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/skills/0

Magic mastery III

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/skills/1

Zone craft II

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/skills/2

Cinder socket II

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/loop

Place a casting zone, build ATB, then exploit elemental weakness.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/weakness

Fragile and vulnerable when pressured out of the zone.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/progression

Master staff arts and improve magic sockets.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/gear/0/name

Resonant staff

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/gear/1/name

Channeler coat

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/gear/6/name

Renewal shard

Also: godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/gear/2/name

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/gear/6/detail

Grants Mend while equipped

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/abilities/0/effect

Establish a favored casting position.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/abilities/1/source

Weapon art · mastery 40%

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/abilities/1/effect

Focused magical attack.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/abilities/2/cost

1 ATB + 12 MP

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/abilities/2/source

Socket · Cinder shard

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/abilities/2/effect

Exploit a fire weakness.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/abilities/3/cost

1 ATB + 10 MP

Also: godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/abilities/2/cost

## godot/content/rpg_catalog.json#/profiles/momentum/builds/mara/abilities/3/source

Socket · Renewal shard

Also: godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/abilities/2/source

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/role

Pressure specialist

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/skills/1

Combo discipline II

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/skills/2

Fracture socket I

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/loop

Build a combo tier, pressure a target, then cash out during stagger.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/weakness

Short reach and a fragile combo state.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/progression

Improve unique combo tiers and master gauntlet arts.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/gear/0/name

Impact gauntlets

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/gear/1/name

Breaker harness

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/gear/2/name

Fracture shard

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/abilities/0/cost

Unique action · combo state

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/abilities/0/effect

Change the next unique finisher.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/abilities/1/source

Weapon art · mastery 70%

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/abilities/1/effect

Build pressure.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/abilities/2/source

Socket · Fracture shard

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/abilities/2/effect

Increase vulnerability.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/abilities/3/name

Pressure wave

## godot/content/rpg_catalog.json#/profiles/momentum/builds/ivo/abilities/3/effect

Cash out on a staggered enemy.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/role

Ranged support

## godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/skills/2

Renewal socket II

## godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/loop

Build charge at range and support the ally spending ATB.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/weakness

Slower movement and weak close-range response.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/progression

Master ranged arts and supportive socket combinations.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/gear/0/name

Light repeater

## godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/gear/1/name

Support harness

## godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/gear/6/detail

Grants Haste field while equipped

## godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/abilities/0/cost

Unique action · charge state

## godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/abilities/0/effect

Release a ranged burst.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/abilities/1/source

Weapon art · mastery 30%

## godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/abilities/1/effect

Attack and help an ally build momentum.

## godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/abilities/3/cost

2 ATB + 14 MP

## godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/abilities/3/source

Socket · Tempo shard

## godot/content/rpg_catalog.json#/profiles/momentum/builds/clerk/abilities/3/effect

Temporarily improve party readiness gain.

## godot/content/rpg_catalog.json#/profiles/confluence/inventory

Item list + personal-technique and link library · links belong to participants, not equipment.

## godot/content/rpg_catalog.json#/profiles/confluence/coverage

Personal blade, elemental, physical-support and precision techniques; dual/triple links have explicit prerequisites.

## godot/content/rpg_catalog.json#/profiles/confluence/hud

Three readiness gauges · Attack / Tech / Item · moving-target geometry · participant link browser

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/skills/0

Blade techniques III

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/skills/1

Line targeting II

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/loop

Hold readiness for Mara, then line up a two-person sweep.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/weakness

Waiting for a partner delays solo pressure.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/progression

Learn personal techniques; links unlock from participant prerequisites.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/gear/0/name

Tidecut sabre

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/gear/0/detail

Character weapon eligibility

Also: godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/gear/0/detail, godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/gear/0/detail, godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/gear/0/detail

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/gear/1/name

Wayfarer vest

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/gear/1/detail

Physical / magical defense

Also: godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/gear/1/detail, godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/gear/1/detail, godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/gear/1/detail

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/gear/2/name

Harbor circlet

Also: godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/gear/2/name, godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/gear/2/name, godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/gear/2/name

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/gear/2/detail

Status resistance

Also: godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/gear/2/detail, godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/gear/2/detail, godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/gear/2/detail

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/gear/3/name

Confluence knot

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/gear/3/detail

Passive technique modifier

Also: godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/gear/3/detail, godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/gear/3/detail, godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/gear/3/detail

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/abilities/0/cost

Full readiness

Also: godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/abilities/0/cost, godot/content/rpg_catalog.json#/profiles/cadence/builds/player/abilities/0/cost, godot/content/rpg_catalog.json#/profiles/cadence/builds/player/abilities/3/cost, godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/abilities/0/cost, godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/abilities/0/cost, godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/abilities/0/cost

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/abilities/0/source

Personal technique

Also: godot/content/rpg_catalog.json#/profiles/confluence/builds/player/abilities/1/source, godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/abilities/0/source, godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/abilities/1/source, godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/abilities/0/source, godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/abilities/1/source, godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/abilities/0/source, godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/abilities/1/source

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/abilities/0/effect

A nearby arc.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/abilities/1/cost

Full readiness + 6 MP

Also: godot/content/rpg_catalog.json#/profiles/cadence/builds/player/abilities/2/cost, godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/abilities/3/cost

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/abilities/1/effect

Attack a line.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/abilities/2/cost

Corsair + Mara ready · 6 MP each

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/abilities/2/source

Linked technique

Also: godot/content/rpg_catalog.json#/profiles/confluence/builds/player/abilities/3/source, godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/abilities/2/source, godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/abilities/3/source, godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/abilities/2/source, godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/abilities/3/source, godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/abilities/2/source, godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/abilities/3/source

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/abilities/2/effect

Combine a sweep and a gale.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/abilities/3/name

Harbor concord

Also: godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/abilities/3/name, godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/abilities/3/name

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/abilities/3/cost

Corsair + Mara + Ivo ready · 10 MP each

## godot/content/rpg_catalog.json#/profiles/confluence/builds/player/abilities/3/effect

A three-person field attack.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/skills/0

Elemental techniques III

## godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/loop

Choose a solo heal now or reserve readiness for a link.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/weakness

Low durability; links tie up the party's recovery actor.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/progression

Personal recovery and elemental techniques unlock different links.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/abilities/0/cost

Full readiness + 5 MP

## godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/abilities/0/effect

Ranged elemental attack.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/abilities/1/cost

Full readiness + 8 MP

Also: godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/abilities/2/cost, godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/abilities/3/cost

## godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/abilities/1/effect

Recover one ally.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/abilities/2/cost

Mara + Corsair ready · 6 MP each

## godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/abilities/2/effect

Sweep and gale combination.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/abilities/3/cost

Mara + Corsair + Ivo ready · 10 MP each

## godot/content/rpg_catalog.json#/profiles/confluence/builds/mara/abilities/3/effect

Three-person field attack.

Also: godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/abilities/3/effect

## godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/skills/0

Impact techniques III

## godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/skills/1

Protection II

## godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/loop

Hold a lane and choose between a solo guard or coordinated impact.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/weakness

Slow recovery; missed timing delays links.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/progression

Physical support techniques and impact combinations.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/abilities/0/effect

Heavy close impact.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/abilities/1/cost

Full readiness + 4 MP

Also: godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/abilities/0/cost

## godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/abilities/1/effect

Protect an ally.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/abilities/2/cost

Ivo + clerk ready · 7 MP each

## godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/abilities/2/effect

Precision mark plus impact.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/ivo/abilities/3/cost

Ivo + Corsair + Mara ready · 10 MP each

## godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/role

Lumen tactician

## godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/skills/0

Precision techniques III

## godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/loop

Mark a target for Ivo or protect an exposed ally.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/weakness

Requires deployment; reserve actors cannot contribute to links.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/progression

Precision and ward progression; alternate party combinations.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/abilities/0/effect

Precise ranged beam.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/abilities/1/cost

Full readiness + 7 MP

## godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/abilities/1/effect

Recover and protect an ally.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/abilities/2/cost

Clerk + Ivo ready · 7 MP each

## godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/abilities/2/effect

Mark plus heavy impact.

## godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/abilities/3/name

Prism shelter

## godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/abilities/3/cost

Clerk + Mara ready · 8 MP each

## godot/content/rpg_catalog.json#/profiles/confluence/builds/clerk/abilities/3/effect

Combined protective technique.

## godot/content/rpg_catalog.json#/profiles/cadence/inventory

Categorized item list · equipment eligibility, two relic slots and teaching focus; learned spells persist.

## godot/content/rpg_catalog.json#/profiles/cadence/coverage

Blade arts, magic amplification, tools and martial sequences shown; theft, enemy skills, mimicry and chance commands pending.

## godot/content/rpg_catalog.json#/profiles/cadence/hud

Four stable HP / MP / ATB rows · signature command · Active / Wait · formation rows

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/skills/0

Blade arts III

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/skills/1

Magic learning I

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/loop

Wait for readiness, choose a committed blade art, and time a guard.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/weakness

Front-row risk; a long art delays the next decision.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/progression

Personal blade arts plus learned magic from teaching focuses.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/gear/0/name

Runed cutlass

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/gear/0/detail

Actor eligibility

Also: godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/gear/0/detail, godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/gear/0/detail, godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/gear/0/detail

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/gear/1/detail

Defense and row tradeoffs

Also: godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/gear/1/detail, godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/gear/1/detail, godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/gear/1/detail

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/gear/2/detail

Command / passive modifier

Also: godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/gear/2/detail, godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/gear/2/detail, godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/gear/2/detail

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/gear/3/detail

Independent relic slot

Also: godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/gear/3/detail, godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/gear/3/detail, godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/gear/3/detail

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/gear/4/slot

Teaching focus

Also: godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/gear/4/slot, godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/gear/4/slot, godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/gear/4/slot

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/gear/4/detail

Spell learning persists after removal

Also: godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/gear/4/detail, godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/gear/4/detail, godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/gear/4/detail

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/abilities/0/effect

Row-sensitive physical attack.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/abilities/1/name

Art: Tide cleave

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/abilities/1/cost

Full readiness · art selector

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/abilities/1/source

Personal command

Also: godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/abilities/1/source, godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/abilities/1/source, godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/abilities/2/source

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/abilities/1/effect

Choose strength and commitment.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/abilities/2/source

Learned magic

Also: godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/abilities/2/source, godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/abilities/3/source, godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/abilities/3/source, godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/abilities/3/source

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/abilities/2/effect

Remains learned without Ember rune.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/abilities/3/source

Relic · Guard seal

## godot/content/rpg_catalog.json#/profiles/cadence/builds/player/abilities/3/effect

Prepare a magical defense.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/skills/1

Amplification II

## godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/loop

Amplify at the right moment and spend MP on a weakness or recovery.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/weakness

Low health and a limited amplification state.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/progression

Personal amplification and learned spell progress.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/gear/1/name

Arcanist robe

## godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/abilities/0/effect

Basic rod attack.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/abilities/1/name

Art: Spell echo

## godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/abilities/1/cost

Full readiness · amplification state

## godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/abilities/1/effect

Enhance a future spell.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/abilities/2/effect

Elemental attack.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/abilities/3/name

Mending light

## godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/abilities/3/cost

Full readiness + 10 MP

## godot/content/rpg_catalog.json#/profiles/cadence/builds/mara/abilities/3/effect

Recover an ally.

Also: godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/abilities/3/effect

## godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/loop

Choose the acquired tool suited to the target formation.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/weakness

Tool access depends on collection; limited early magic.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/progression

Acquire tools; learn compatible magic separately.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/gear/0/name

Bolt repeater

## godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/gear/1/name

Mechanic coat

## godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/gear/5/slot

Tool collection

## godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/gear/5/name

Tide drill / Flash charge

## godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/gear/5/detail

Owned tools available to the Tools command

## godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/abilities/0/effect

Basic ranged shot.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/abilities/1/name

Tools: Tide drill

## godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/abilities/1/cost

Full readiness · tool owned

Also: godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/abilities/2/cost

## godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/abilities/1/source

Personal command + tool collection

Also: godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/abilities/2/source

## godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/abilities/1/effect

Pierce a tough target.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/abilities/2/name

Tools: Flash charge

## godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/abilities/2/effect

Disrupt a group.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/ivo/abilities/3/effect

Independent of tool ownership.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/skills/0

Martial sequences III

## godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/loop

Choose a martial sequence, then confirm its inputs or accessible list option.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/weakness

Short reach; sequence execution needs clear feedback.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/progression

Learn new sequences and improve recovery magic.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/gear/0/name

Iron knuckles

## godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/gear/2/name

Resolve sigil

## godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/abilities/0/effect

Basic close strike.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/abilities/1/name

Art: Palm sequence

## godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/abilities/1/cost

Full readiness · sequence input

Also: godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/abilities/2/cost

## godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/abilities/1/effect

Execute a martial combination.

## godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/abilities/2/name

Art: Rising wave

## godot/content/rpg_catalog.json#/profiles/cadence/builds/clerk/abilities/2/effect

A different sequence and area.

## godot/content/rpg_catalog.json#/profiles/orders/inventory

Kit list or optional packing grid · load / space are separate policies; ammo and charges persist.

## godot/content/rpg_catalog.json#/profiles/orders/coverage

Assault, recon, engineering and medical roles.

## godot/content/rpg_catalog.json#/profiles/orders/hud

Per-actor timelines · paths and facing · forecast uncertainty · team Commit / replay

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/skills/0

Ballistics III

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/loop

Synchronize a crossing with suppression or breach a position.

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/weakness

Exposed while moving; ammo limits repeated suppression.

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/progression

Weapon proficiency and plan efficiency.

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/gear/0/name

Harbor repeater

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/gear/0/detail

Ammo and aim time

Also: godot/content/rpg_catalog.json#/profiles/orders/builds/mara/gear/0/detail, godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/gear/0/detail, godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/gear/0/detail

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/gear/1/detail

Load affects authored movement

Also: godot/content/rpg_catalog.json#/profiles/orders/builds/mara/gear/1/detail, godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/gear/1/detail, godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/gear/1/detail

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/gear/2/name

Breach charge ×2

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/gear/2/detail

Limited charges

Also: godot/content/rpg_catalog.json#/profiles/orders/builds/mara/gear/2/detail, godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/gear/2/detail, godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/gear/2/detail

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/gear/3/name

Field dressing ×2

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/gear/3/detail

Persists across plans

Also: godot/content/rpg_catalog.json#/profiles/orders/builds/mara/gear/3/detail, godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/gear/3/detail, godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/gear/3/detail

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/abilities/0/cost

1.0 s + 3 ammo

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/abilities/0/effect

Cover a known lane.

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/abilities/1/effect

Move to the planned position.

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/abilities/2/cost

0.8 s + 1 charge

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/abilities/2/effect

Break an authored obstacle.

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/abilities/3/cost

1.2 s + 6 ammo

## godot/content/rpg_catalog.json#/profiles/orders/builds/player/abilities/3/effect

Pressure a firing lane.

## godot/content/rpg_catalog.json#/profiles/orders/builds/mara/role

Recon specialist

## godot/content/rpg_catalog.json#/profiles/orders/builds/mara/skills/0

Observation III

## godot/content/rpg_catalog.json#/profiles/orders/builds/mara/loop

Observe a lane before committing the team's crossing.

## godot/content/rpg_catalog.json#/profiles/orders/builds/mara/weakness

Fragile; stale information cannot guarantee a forecast.

## godot/content/rpg_catalog.json#/profiles/orders/builds/mara/progression

Observation range, concealment and precision.

## godot/content/rpg_catalog.json#/profiles/orders/builds/mara/gear/1/name

Scout harness

## godot/content/rpg_catalog.json#/profiles/orders/builds/mara/gear/2/name

Sensor dart ×2

## godot/content/rpg_catalog.json#/profiles/orders/builds/mara/gear/3/name

Smoke canister ×2

## godot/content/rpg_catalog.json#/profiles/orders/builds/mara/abilities/0/effect

Gather visible information.

## godot/content/rpg_catalog.json#/profiles/orders/builds/mara/abilities/1/cost

0.4 s · sight required

## godot/content/rpg_catalog.json#/profiles/orders/builds/mara/abilities/1/effect

Share a known target.

## godot/content/rpg_catalog.json#/profiles/orders/builds/mara/abilities/2/cost

0.8 s + smoke charge

## godot/content/rpg_catalog.json#/profiles/orders/builds/mara/abilities/2/effect

Break sight in an area.

## godot/content/rpg_catalog.json#/profiles/orders/builds/mara/abilities/3/name

Precision shot

## godot/content/rpg_catalog.json#/profiles/orders/builds/mara/abilities/3/cost

1.4 s + 1 ammo

## godot/content/rpg_catalog.json#/profiles/orders/builds/mara/abilities/3/effect

Slow aimed shot.

## godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/role

Combat engineer

## godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/loop

Create cover and smoke before allies cross.

## godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/weakness

Setup takes time; tools have finite charges.

## godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/progression

Construction, disruption or repair efficiency.

## godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/gear/0/name

Utility carbine

## godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/gear/2/name

Smoke projector

## godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/gear/3/name

Repair pack ×3

## godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/abilities/0/cost

1.2 s + kit charge

## godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/abilities/0/effect

Place temporary cover.

## godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/abilities/1/cost

1.0 s + repair charge

## godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/abilities/1/effect

Restore an eligible object.

## godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/abilities/2/cost

0.8 s + projector charge

## godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/abilities/2/effect

Obscure a lane.

## godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/abilities/3/cost

1.0 s · valid device

## godot/content/rpg_catalog.json#/profiles/orders/builds/ivo/abilities/3/effect

Disable a technical obstacle.

## godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/loop

Reach an ally at the planned time, stabilize, then extract.

## godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/weakness

A moving target can invalidate treatment; finite supplies.

## godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/progression

Triage, evacuation and medical efficiency.

## godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/gear/0/name

Medic carbine

## godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/gear/1/name

Rescue harness

## godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/gear/2/name

Healing injector ×4

## godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/abilities/0/cost

1.0 s + medical charge

## godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/abilities/0/effect

Treat an adjacent downed ally.

## godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/abilities/1/cost

Path time · eligible ally

## godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/abilities/1/effect

Move an incapacitated ally.

## godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/abilities/2/name

Field treatment

## godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/abilities/2/cost

1.2 s + medical charge

## godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/abilities/2/effect

Recover an adjacent ally.

## godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/abilities/3/name

Cover retreat

## godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/abilities/3/cost

0.8 s + 2 ammo

## godot/content/rpg_catalog.json#/profiles/orders/builds/clerk/abilities/3/effect

Support an extraction.

## godot/content/garden_chapter.json#/premise

The flood ledger names Lantern Garden as a public right of passage. A new seal has turned its sentries against the quay's workers. Mara and the civic clerk accompany you to recover it.

## godot/content/garden_chapter.json#/briefing

Clerk: "The ledger grants passage to every worker on the quay. That seal is not the one we issued."

Mara: "My crew is waiting outside. Keep the sentries off us while we reach the gate."

## godot/content/garden_chapter.json#/objective

Recover the seal from the garden sentries.

## godot/content/garden_chapter.json#/discovery

The seal carries a private owner's mark where the civic stamp should be.

## godot/content/garden_chapter.json#/resolution

Clerk: "Someone replaced this by hand. I'll lodge the seal with the ledger. They cannot close a public passage on a forged claim."

Mara: "I'll bring the crew through. We've lost half a day's work already."

## godot/content/garden_chapter.json#/records

The flood ledger reserves the garden walk as a public right of passage, even when the lower road floods. Its civic stamp differs from the seal now fitted to the garden gate. The entry gives the clerk grounds to contest the closure.

## godot/content/garden_chapter.json#/map_note

The raised garden walk lies beyond the east gate. The lower road floods at high tide.
