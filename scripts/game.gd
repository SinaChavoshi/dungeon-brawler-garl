extends Node3D
## Runs the dungeon: builds each floor, spawns enemies, loot and stairs,
## counts down the collapse timer, and hands out sarcastic achievements.

@export var floor_time_seconds: float = 120.0
@export var room_half_size: float = 12.0

var floor_number: int = 1
var time_left: float = 0.0
var game_over: bool = false
var kills: int = 0
var _achievements: Dictionary = {}
var _changing_floor: bool = false
var _level: Node3D

@onready var player: Player = $Player
@onready var hud: Hud = $HUD


func _ready() -> void:
	randomize()
	player.died.connect(_on_player_died)
	player.damaged.connect(_on_player_damaged)
	player.health_changed.connect(hud.set_health)
	hud.set_health(player.health, player.max_health)
	_start_floor()


func _process(delta: float) -> void:
	if game_over:
		if Input.is_physical_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return

	time_left -= delta
	hud.set_time(time_left)
	if time_left <= 0.0:
		player.die("collapse")


func _start_floor() -> void:
	_changing_floor = false
	if _level != null:
		_level.queue_free()
	_level = Node3D.new()
	_level.name = "Level"
	add_child(_level)

	_build_room()
	var spawn := Vector3(0.0, 0.1, room_half_size - 2.0)
	player.reset_for_new_floor(spawn)

	for _i in 2 + floor_number:
		var enemy := Enemy.new()
		enemy.target = player
		enemy.max_health = 2 + floor_number
		enemy.move_speed = 2.5 + 0.25 * floor_number
		enemy.position = _random_spot(spawn, 7.0)
		enemy.died.connect(_on_enemy_died)
		_level.add_child(enemy)

	for _i in randi_range(1, 2):
		var box := LootBox.new()
		box.position = _random_spot(spawn, 4.0)
		box.opened.connect(_on_loot_opened)
		_level.add_child(box)

	var stairs := Stairs.new()
	stairs.position = Vector3(randf_range(-room_half_size + 3.0, room_half_size - 3.0), 0.0, -room_half_size + 2.5)
	stairs.reached.connect(_on_stairs_reached)
	_level.add_child(stairs)

	time_left = floor_time_seconds
	hud.set_floor(floor_number)
	hud.set_time(time_left)
	hud.announce("H.O.S.T.: Welcome to Floor %d! The stairs are somewhere. Probably." % floor_number)


func _build_room() -> void:
	var size := room_half_size * 2.0
	_add_box(Vector3(size, 1.0, size), Vector3(0.0, -0.5, 0.0), Color(0.35, 0.3, 0.28))
	var wall_color := Color(0.25, 0.22, 0.24)
	var h := room_half_size
	_add_box(Vector3(size + 1.0, 1.2, 1.0), Vector3(0.0, 0.6, -h - 0.5), wall_color)
	_add_box(Vector3(size + 1.0, 1.2, 1.0), Vector3(0.0, 0.6, h + 0.5), wall_color)
	_add_box(Vector3(1.0, 1.2, size), Vector3(-h - 0.5, 0.6, 0.0), wall_color)
	_add_box(Vector3(1.0, 1.2, size), Vector3(h + 0.5, 0.6, 0.0), wall_color)


func _add_box(size: Vector3, at: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	body.add_child(mesh)
	_level.add_child(body)


func _random_spot(away_from: Vector3, min_distance: float) -> Vector3:
	var limit := room_half_size - 2.0
	var spot := Vector3.ZERO
	for _attempt in 30:
		spot = Vector3(randf_range(-limit, limit), 0.0, randf_range(-limit, limit))
		if spot.distance_to(away_from) >= min_distance:
			break
	return spot


func _award(id: String, text: String) -> void:
	if _achievements.has(id):
		return
	_achievements[id] = true
	hud.announce("New Achievement! " + text)


func _on_enemy_died() -> void:
	kills += 1
	_award("first_kill", "First Blood (Not Yours). Reward: the crowd's mild interest.")
	if kills == 10:
		_award("ten_kills", "Knuckle Sandwich Franchise. Ten goblins served.")


func _on_player_damaged() -> void:
	_award("first_hurt", "Ow. You have discovered pain. The viewers love it.")


func _on_loot_opened(box: LootBox) -> void:
	_award("first_box", "Unboxing Influencer. You opened a box on camera.")
	match randi_range(0, 3):
		0:
			player.heal(3)
			hud.announce("%s Box: a slightly used bandage. +3 HP." % box.tier)
		1:
			player.punch_damage += 1
			hud.announce("%s Box: brass knuckles of questionable origin. +1 punch damage." % box.tier)
		2:
			time_left += 20.0
			hud.announce("%s Box: a coupon for 20 more seconds of not dying." % box.tier)
		_:
			hud.announce("%s Box: a single sock. It does not match the one you have." % box.tier)


func _on_stairs_reached() -> void:
	if _changing_floor or game_over:
		return
	_changing_floor = true
	if get_tree().get_nodes_in_group("enemies").is_empty():
		_award("floor_%d_clear" % floor_number, "Exterminator. You cleared Floor %d. Show-off." % floor_number)
	floor_number += 1
	call_deferred("_start_floor")


func _on_player_died(cause: String) -> void:
	game_over = true
	if cause == "collapse":
		hud.show_center("The floor collapsed with you on it.\nH.O.S.T. reminds you that punctuality is a virtue.\n\nPress R to try again")
	else:
		hud.show_center("You died on Floor %d.\nGlorbcorp thanks you for your content.\n\nPress R to try again" % floor_number)
