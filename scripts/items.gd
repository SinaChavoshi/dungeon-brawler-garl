class_name Items
extends RefCounted
## Every item in the dungeon, as catalogued by H.O.S.T., the dungeon AI.
## H.O.S.T. writes the descriptions. H.O.S.T. is not a fan of yours.
##
## kind: "consumable" (used up), "equipment" (goes in a slot), "junk"
## Effects: heal, max_health, punch_damage, speed_mult, time, spray_boost

const DATA := {
	"bandage": {
		"name": "Slightly Used Bandage",
		"kind": "consumable",
		"heal": 3,
		"desc": "Heals 3 HP. Previous owner unknown. Previous owner's fate also unknown. Don't think about it.",
	},
	"red_juice": {
		"name": "Suspicious Red Juice",
		"kind": "consumable",
		"heal": 6,
		"desc": "Heals 6 HP. Tastes like cherries and regret. Do not read the ingredients.",
	},
	"time_coupon": {
		"name": "Coupon: 20 More Seconds",
		"kind": "consumable",
		"time": 20.0,
		"desc": "Adds 20 seconds to the collapse timer. Not valid with other offers. Not valid in most places.",
	},
	"skunk_treat": {
		"name": "Gourmet Skunk Treat",
		"kind": "consumable",
		"spray_boost": 30.0,
		"desc": "Duchess sprays twice as fast for 30 seconds. She will pretend she didn't want it.",
	},
	"brass_knuckles": {
		"name": "Brass Knuckles of Questionable Origin",
		"kind": "equipment",
		"slot": "hands",
		"punch_damage": 1,
		"desc": "+1 punch damage. Engraved 'PROPERTY OF' and then nothing. Spooky.",
	},
	"spiked_mitts": {
		"name": "Spiked Oven Mitts",
		"kind": "equipment",
		"slot": "hands",
		"punch_damage": 2,
		"desc": "+2 punch damage. Oven safe. Skeleton unsafe.",
	},
	"lonely_sock": {
		"name": "A Single Sock",
		"kind": "equipment",
		"slot": "feet",
		"speed_mult": 1.15,
		"desc": "You now own two socks. +15% move speed from sheer confidence. They do not match.",
	},
	"utility_belt": {
		"name": "Sparkly Utility Belt",
		"kind": "equipment",
		"slot": "waist",
		"max_health": 3,
		"desc": "+3 max HP. Holds nothing. Sparkles constantly. Sponsors love it.",
	},
	"party_hat": {
		"name": "Cone of Celebration",
		"kind": "equipment",
		"slot": "head",
		"max_health": 1,
		"desc": "+1 max HP. A party hat. The party is not for you.",
	},
	"bone_fragment": {
		"name": "Bone Fragment",
		"kind": "junk",
		"desc": "Part of a skeleton. The skeleton would like it back. Worth nothing. Smells like dust.",
	},
}

const SLOTS := ["head", "hands", "waist", "feet"]


static func info(id: String) -> Dictionary:
	return DATA.get(id, {})


static func display_name(id: String) -> String:
	return info(id).get("name", id)


## Short line that sums up what an item does, for buttons and tooltips.
static func effect_text(id: String) -> String:
	var item := info(id)
	var parts: Array[String] = []
	if item.has("heal"):
		parts.append("+%d HP" % item["heal"])
	if item.has("max_health"):
		parts.append("+%d max HP" % item["max_health"])
	if item.has("punch_damage"):
		parts.append("+%d punch" % item["punch_damage"])
	if item.has("speed_mult"):
		parts.append("+%d%% speed" % int(round((item["speed_mult"] - 1.0) * 100.0)))
	if item.has("time"):
		parts.append("+%ds timer" % int(item["time"]))
	if item.has("spray_boost"):
		parts.append("Duchess frenzy")
	return ", ".join(parts)
