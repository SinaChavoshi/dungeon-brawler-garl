class_name Abilities
extends RefCounted
## Garl's moves, for the action bar and spellbook. Player.use_ability()
## does the actual work; this is just the data.
##
## Fields: name, desc, cooldown (seconds), gcd (uses the 1 s global
## cooldown), range (metres, 0 = self), needs_target, icon.

const GLOBAL_COOLDOWN := 1.0

const DATA := {
	"haymaker": {
		"name": "Haymaker",
		"desc": "A wild, looping punch that hits hard. Deals double punch damage +1. Garl calls it technique.",
		"cooldown": 6.0, "gcd": true, "range": 2.4, "needs_target": false,
		"icon": "res://assets/icons/haymaker.png",
	},
	"boot": {
		"name": "Boot to the Face",
		"desc": "A kick that sends the target flying. Deals punch damage +1 and knocks it back far.",
		"cooldown": 8.0, "gcd": true, "range": 2.6, "needs_target": false,
		"icon": "res://assets/icons/boot.png",
	},
	"belly_flop": {
		"name": "Belly Flop",
		"desc": "Leap up and land belly-first. Hits everything within 3.5 m for punch damage +1. The floor files a complaint.",
		"cooldown": 12.0, "gcd": true, "range": 0.0, "needs_target": false,
		"icon": "res://assets/icons/belly_flop.png",
	},
	"dodge": {
		"name": "Dramatic Dodge",
		"desc": "Dive out of the way. You can't be hurt for half a second. Off the global cooldown.",
		"cooldown": 8.0, "gcd": false, "range": 0.0, "needs_target": false,
		"icon": "res://assets/icons/dodge.png",
	},
	"royal_spray": {
		"name": "Command: Royal Spray",
		"desc": "Ask Duchess to spray your target right now. She will do it. She will also complain about it.",
		"cooldown": 15.0, "gcd": true, "range": 12.0, "needs_target": true,
		"icon": "res://assets/icons/royal_spray.png",
	},
	"quick_heal": {
		"name": "Quick Heal",
		"desc": "Use your best healing item from your bags.",
		"cooldown": 0.0, "gcd": true, "range": 0.0, "needs_target": false,
		"icon": "res://assets/icons/quick_heal.png",
	},
}

## Default action bar, keys 1 to 9.
const DEFAULT_BAR := ["haymaker", "boot", "belly_flop", "dodge", "royal_spray", "quick_heal", "", "", ""]


static func info(id: String) -> Dictionary:
	return DATA.get(id, {})
