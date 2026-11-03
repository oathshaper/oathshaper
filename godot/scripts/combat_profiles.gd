class_name CombatProfiles
extends RefCounted

const DEFAULT_ID := "command"
const CATALOG := preload("res://scripts/party_catalog.gd")

const PROFILES := {
	"confluence": {
		"name": "Confluence", "tagline": "Live time, linked techniques", "reference": "Coordinated party techniques",
		"accent": Color("91d4c3"), "party": "You + 2 companions",
		"description": "Fight where you stand. Let readiness build, watch enemy positions, and unite two or three allies in a linked technique.",
		"weapon": "sabre"
	},
	"cadence": {
		"name": "Cadence", "tagline": "Ready, choose, resolve", "reference": "Timed commands · Active / Wait",
		"accent": Color("a9bde8"), "party": "You + 3 companions",
		"description": "Guide four distinct roles as their gauges fill. Choose Attack, Arts, Magic or Item, with Active or Wait menu timing.",
		"weapon": "sabre"
	},
	"oathbound": {
		"name": "Oathbound", "tagline": "Party tactics, steel & spells", "reference": "Party tactics with pause",
		"accent": Color("cc9d96"), "party": "You + 3 companions",
		"description": "Pause to direct a four-person party. Build warrior, rogue, and mage roles around companion tactics.",
		"weapon": "sabre"
	},
	"command": {
		"name": "Command", "tagline": "Pause, queue, act", "reference": "Real time with pause",
		"accent": Color("d8bd80"), "party": "You + 2 companions",
		"description": "Plan short orders, then let the party carry them out.",
		"weapon": "sabre"
	},
	"flow": {
		"name": "Flow", "tagline": "Melee, magic, styles", "reference": "Direct action",
		"accent": Color("acd1a3"), "party": "You + 1 follower",
		"description": "Read attacks, guard or evade, and change styles in motion.",
		"weapon": "unarmed"
	},
	"vanguard": {
		"name": "Vanguard", "tagline": "Aim, cover, command", "reference": "Squad shooter",
		"accent": Color("9dcfdf"), "party": "You + 2 squadmates",
		"description": "Aim from cover, direct squad powers, and strip defenses.",
		"weapon": "carbine"
	},
	"tactics": {
		"name": "Tactics", "tagline": "Initiative, actions, reactions", "reference": "Three-action tactical rules",
		"accent": Color("e2bc88"), "party": "You + 3 companions",
		"description": "Spend actions deliberately and keep a reaction ready.",
		"weapon": "sabre"
	},
	"momentum": {
		"name": "Momentum", "tagline": "Action builds commands", "reference": "Action with tactical commands",
		"accent": Color("c7b6ed"), "party": "You + 2 companions",
		"description": "Attack and guard to fill two command gauges. Slow the action to choose a command, switch allies, and exploit a staggered foe.",
		"weapon": "sabre"
	},
	"orders": {
		"name": "Orders", "tagline": "Plan together, resolve together", "reference": "Simultaneous planning",
		"accent": Color("d2cf9d"), "party": "You + 3 companions",
		"description": "Commit a short plan, then see both sides resolve it.",
		"weapon": "carbine"
	}
}

static func ids() -> Array[String]:
	return ["command", "flow", "vanguard", "tactics", "momentum", "confluence", "cadence", "orders", "oathbound"]

static func get_profile(id: String) -> Dictionary:
	var key := id if is_valid(id) else DEFAULT_ID
	var profile := (PROFILES[key] as Dictionary).duplicate(true)
	profile["family"] = "command" if key == "oathbound" else key
	profile["page"] = {
		"confluence": "Techniques & links", "cadence": "Commands & relics",
		"oathbound": "Talents & tactics",
		"command": "Powers & queues", "flow": "Styles & training",
		"vanguard": "Powers & modules", "tactics": "Actions & preparation",
		"momentum": "Commands & sockets", "orders": "Plans & reserves"
	}[key]
	# The picker shows the Tessa Ward's authored build from the same catalog as the
	# Ledger. Companions have their own builds; no separate generic sample kit.
	var build := CATALOG.build(key, "player")
	profile.gear = []
	profile.abilities = []
	for gear in build.gear:
		profile.gear.append([gear.slot, gear.name, gear.detail])
	for ability in build.abilities:
		profile.abilities.append([ability.name, ability.cost])
	if key == "vanguard":
		profile.description = "Aim from cover, manage weapon heat, and direct distinct combat, tech and biotic squad powers."
	return profile

static func is_valid(id: String) -> bool:
	return PROFILES.has(id)
