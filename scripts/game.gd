extends Node3D
## Runs the crawl: builds each floor, wires up Garl, Duchess, the inventory,
## the HUD and the map, counts down the collapse timer, and hands out loot
## and sarcastic achievements.

const ACHIEVEMENT_COLOR := Color(0.75, 0.5, 1.0)
const LOOT_COLOR := Color(0.4, 0.9, 1.0)
const DUCHESS_COLOR := Color(1.0, 0.45, 0.8)
const WARNING_COLOR := Color(1.0, 0.35, 0.3)

const BRONZE_LOOT := ["bandage", "bandage", "red_juice", "time_coupon", "lonely_sock", "brass_knuckles", "skunk_treat", "party_hat"]
const GOLD_LOOT := ["utility_belt", "spiked_mitts", "red_juice", "skunk_treat"]

var floor_number: int = 1
var time_left: float = 0.0
var game_over: bool = false
var kills: int = 0
var inventory := Inventory.new()
var level: Level
var _achievements: Dictionary = {}
var _changing_floor: bool = false
var _warned_time: bool = false

@onready var player: Player = $Player
@onready var duchess: Duchess = $Duchess
@onready var hud: Hud = $HUD
@onready var inventory_ui: InventoryUI = $InventoryUI


func _ready() -> void:
	randomize()
	player.died.connect(_on_player_died)
	player.damaged.connect(_on_player_damaged)
	player.health_changed.connect(hud.set_health)
	hud.set_health(player.health, player.max_health)

	duchess.leader = player
	player.duchess = duchess
	player.inventory_heal = _quick_heal
	player.error.connect(hud.show_error)
	player.ability_used.connect(hud.action_bar.flash)
	_build_target_ring()
	duchess.quip.connect(_on_duchess_quip)
	duchess.sprayed_first_time.connect(_on_duchess_first_spray)

	inventory.changed.connect(_on_inventory_changed)
	inventory_ui.setup(inventory)
	inventory_ui.use_requested.connect(_use_item)
	inventory_ui.equip_requested.connect(inventory.equip)
	inventory_ui.unequip_requested.connect(inventory.unequip)

	if not Level.high_quality():
		# The web preview has no ambient occlusion or volumetric light, so
		# lift the shadows a little to keep the cave readable.
		var env := ($WorldEnvironment as WorldEnvironment).environment
		env.ambient_light_energy = 0.4

	_start_floor()
	hud.notify("DUCHESS", "Garl, darling, the cameras are rolling. Do try to look heroic. And for heaven's sake, put on some pants.", DUCHESS_COLOR)
	print("Game ready: floor %d, %d enemies" % [floor_number, get_tree().get_nodes_in_group("enemies").size()])
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_take_screenshots(arg.trim_prefix("--screenshot="))


## For CI: walk the camera through the first floor and save a few pictures
## (godot -- --screenshot=/some/dir), then quit.
func _take_screenshots(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	time_left = 9999.0
	# [name, Garl's position, camera yaw, distance, pitch]
	var shots := [
		["spawn", Vector3(0.0, 0.3, 22.0), 0.0, 7.0, -20.0],
		["garl_closeup", Vector3(0.3, 0.3, 17.0), PI + 0.4, 3.2, -6.0],
		["tunnel", Vector3(-0.8, 0.3, 11.5), 0.0, 6.0, -16.0],
		["cavern", Vector3(0.0, 0.3, -2.0), 0.0, 9.0, -24.0],
		["overview", Vector3(0.0, 0.3, -4.0), 0.0, 17.0, -62.0],
	]
	for shot in shots:
		player.global_position = shot[1]
		duchess.global_position = shot[1] + Vector3(1.2, 0.0, 1.0)
		player.camera_rig.snap(shot[2], shot[3], shot[4])
		if shot[0] == "cavern":
			player.target_nearest()  # show the target ring
		for _frame in 45:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := folder.path_join("%s.jpg" % shot[0])
		get_viewport().get_texture().get_image().save_jpg(path, 0.85)
		print("Saved screenshot ", path)
	get_tree().quit()


func _process(delta: float) -> void:
	if game_over:
		if Input.is_physical_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return

	time_left -= delta
	hud.set_time(time_left)
	if time_left <= 30.0 and not _warned_time:
		_warned_time = true
		hud.notify("WARNING", "Floor collapse in 30 seconds. H.O.S.T. recommends finding the stairs, or at least looking busy.", WARNING_COLOR)
	if time_left <= 0.0:
		player.die("collapse")
	if level != null:
		level.reveal_around(player.global_position, 7.0)
	_update_target_ring()


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo or game_over:
		return
	if key_event.physical_keycode == KEY_M:
		hud.toggle_full_map()


func _start_floor() -> void:
	_changing_floor = false
	_warned_time = false
	if level != null:
		level.queue_free()
	level = TutorialLevel.new() if floor_number == 1 else ArenaLevel.new()
	level.name = "Level%d" % floor_number
	level.floor_number = floor_number
	level.player = player
	add_child(level)
	level.build()
	level.stairs_reached.connect(_on_stairs_reached)
	level.enemy_died.connect(_on_enemy_died)
	level.chest_opened.connect(_on_chest_opened)
	level.announce.connect(_on_level_announce)

	player.reset_for_new_floor(level.player_spawn)
	duchess.global_position = level.player_spawn + Vector3(1.2, 0.0, 1.0)
	time_left = level.time_limit
	hud.set_floor(floor_number)
	hud.set_time(time_left)
	hud.set_level(level, player)
	hud.notify(level.intro_title, level.intro_text, Color(1.0, 0.6, 0.2), 7.0)


var _target_ring: MeshInstance3D


## A red ring on the floor under whatever Garl has targeted.
func _build_target_ring() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.75
	torus.outer_radius = 0.9
	torus.rings = 32
	torus.ring_segments = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.2, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.15, 0.1)
	torus.material = mat
	_target_ring = MeshInstance3D.new()
	_target_ring.mesh = torus
	_target_ring.scale = Vector3(1.0, 0.1, 1.0)
	_target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_target_ring.visible = false
	add_child(_target_ring)


func _update_target_ring() -> void:
	var t := player.target
	_target_ring.visible = t != null and is_instance_valid(t)
	if _target_ring.visible:
		_target_ring.global_position = t.global_position + Vector3(0.0, 0.06, 0.0)
		_target_ring.rotation.y += get_process_delta_time() * 1.5


func _award(id: String, text: String) -> void:
	if _achievements.has(id):
		return
	_achievements[id] = true
	hud.notify("NEW ACHIEVEMENT!", text, ACHIEVEMENT_COLOR)


# --- Inventory -------------------------------------------------------------

func _on_inventory_changed() -> void:
	player.apply_bonuses(inventory.bonuses())
	hud.set_gold(inventory.gold)


func _use_item(id: String) -> void:
	var item := Items.info(id)
	if item.get("kind", "") != "consumable" or inventory.count_of(id) == 0:
		return
	if item.has("heal"):
		if player.health >= player.max_health:
			hud.notify("H.O.S.T.", "You're already at full health. H.O.S.T. admires your commitment to waste, but no.")
			return
		player.heal(item["heal"])
	if item.has("time"):
		time_left += item["time"]
	if item.has("spray_boost"):
		duchess.boost_time = item["spray_boost"]
		hud.notify("DUCHESS", "Is that... gourmet? Fine. FINE. Stand back, everyone.", DUCHESS_COLOR)
	inventory.remove(id)
	hud.notify("ITEM USED", "%s. %s" % [Items.display_name(id), Items.effect_text(id)], LOOT_COLOR, 3.0)


## Quick Heal ability: returns false if there was nothing to use.
func _quick_heal() -> bool:
	var id := inventory.best_heal()
	if id == "":
		player.error.emit("No healing items")
		hud.notify("H.O.S.T.", "No healing items. H.O.S.T. suggests the classic strategy of 'not getting hit'.")
		return false
	if player.health >= player.max_health:
		player.error.emit("Already at full health")
		return false
	_use_item(id)
	return true


func _on_chest_opened(box: LootBox) -> void:
	_award("first_box", "Unboxing Influencer. You opened a loot box on live television. The algorithm is pleased.")
	var id := box.contents
	if id == "":
		var table: Array = GOLD_LOOT if box.tier == "Gold" else BRONZE_LOOT
		id = table[randi() % table.size()]
	var gold := randi_range(20, 40) if box.tier == "Gold" else randi_range(3, 10)
	inventory.add_gold(gold)
	if not inventory.add(id):
		hud.notify("INVENTORY FULL", "You found %s, but your bag is full. H.O.S.T. has disposed of it for you. You're welcome." % Items.display_name(id), WARNING_COLOR)
		return
	hud.notify("%s BOX OPENED" % box.tier.to_upper(),
		"You received: %s (+%d gold).\n%s" % [Items.display_name(id), gold, Items.info(id).get("desc", "")], LOOT_COLOR, 7.0)
	if Items.info(id).get("kind", "") == "equipment" and not inventory.equipped.has(Items.info(id)["slot"]):
		hud.notify("H.O.S.T.", "Tip: press I to open your inventory and equip that. Or don't. It's your funeral, and it's televised.")


# --- Events ----------------------------------------------------------------

func _on_enemy_died(_enemy: Enemy) -> void:
	kills += 1
	inventory.add_gold(randi_range(1, 4))
	if randf() < 0.15:
		inventory.add("bone_fragment")
	duchess.on_enemy_killed()
	_award("first_kill", "First Blood (Not Yours). You destroyed a skeleton. It was already dead, so legally this is fine.")
	if kills == 10:
		_award("ten_kills", "Knuckle Sandwich Franchise. Ten skeletons served.")


func _on_level_announce(title: String, body: String) -> void:
	hud.notify(title, body)


func _on_duchess_quip(text: String) -> void:
	hud.notify("DUCHESS", text.trim_prefix("Duchess: "), DUCHESS_COLOR)


func _on_duchess_first_spray() -> void:
	_award("royal_spray", "Smells Like Royalty. Duchess used Royal Spray. Everyone within ten meters now regrets it.")


func _on_player_damaged() -> void:
	_award("first_hurt", "Ow. You have discovered pain. The viewers love it.")


func _on_stairs_reached() -> void:
	if _changing_floor or game_over:
		return
	_changing_floor = true
	if get_tree().get_nodes_in_group("enemies").is_empty():
		_award("floor_%d_clear" % floor_number, "Exterminator. You cleared Floor %d. Show-off." % floor_number)
	if floor_number == 1:
		_award("tutorial", "Graduate. You survived the tutorial. Most do. Some don't. We don't talk about those.")
	floor_number += 1
	call_deferred("_start_floor")


func _on_player_died(cause: String) -> void:
	game_over = true
	if cause == "collapse":
		hud.show_center("The floor collapsed with you on it.\nH.O.S.T. reminds you that punctuality is a virtue.\n\nPress R to try again")
	else:
		hud.show_center("You died on Floor %d.\nGlorbcorp thanks you for your content.\n\nPress R to try again" % floor_number)
