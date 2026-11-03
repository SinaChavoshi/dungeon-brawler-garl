extends Node3D
## Runs the dungeon: builds each floor, spawns enemies, loot and stairs,
## counts down the collapse timer, and hands out sarcastic achievements.

const FLOOR := preload("res://assets/kaykit/dungeon/floor_tile_large.glb")
const FLOOR_ROCKS := preload("res://assets/kaykit/dungeon/floor_tile_large_rocks.glb")
const WALL := preload("res://assets/kaykit/dungeon/wall.glb")
const WALL_PILLAR := preload("res://assets/kaykit/dungeon/wall_pillar.glb")
const BARRIER := preload("res://assets/kaykit/dungeon/barrier.glb")
const PILLAR := preload("res://assets/kaykit/dungeon/pillar.glb")
const TORCH := preload("res://assets/kaykit/dungeon/torch_mounted.glb")
const BANNERS := [
	preload("res://assets/kaykit/dungeon/banner_patternA_red.glb"),
	preload("res://assets/kaykit/dungeon/banner_patternB_blue.glb"),
]
## [model, collider size]
const PROPS := [
	[preload("res://assets/kaykit/dungeon/barrel_large.glb"), Vector3(1.6, 2.0, 1.6)],
	[preload("res://assets/kaykit/dungeon/barrel_small_stack.glb"), Vector3(1.8, 1.8, 1.0)],
	[preload("res://assets/kaykit/dungeon/crates_stacked.glb"), Vector3(2.0, 2.1, 2.0)],
	[preload("res://assets/kaykit/dungeon/box_large.glb"), Vector3(1.5, 1.5, 1.5)],
	[preload("res://assets/kaykit/dungeon/column.glb"), Vector3(0.8, 1.4, 0.8)],
]

@export var floor_time_seconds: float = 120.0
@export var room_half_size: float = 12.0

var floor_number: int = 1
var time_left: float = 0.0
var game_over: bool = false
var kills: int = 0
var _achievements: Dictionary = {}
var _changing_floor: bool = false
var _level: Node3D
var _torches: Array[OmniLight3D] = []

@onready var player: Player = $Player
@onready var hud: Hud = $HUD


func _ready() -> void:
	randomize()
	player.died.connect(_on_player_died)
	player.damaged.connect(_on_player_damaged)
	player.health_changed.connect(hud.set_health)
	hud.set_health(player.health, player.max_health)
	_start_floor()
	print("Game ready: floor %d, %d enemies" % [floor_number, get_tree().get_nodes_in_group("enemies").size()])


func _process(delta: float) -> void:
	if game_over:
		if Input.is_physical_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return

	for torch in _torches:
		torch.light_energy = 1.5 + sin(Time.get_ticks_msec() / 90.0 + torch.position.x) * 0.15 + randf() * 0.1
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
	var spawn := Vector3(0.0, 0.1, room_half_size - 3.0)
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
		if randf() < 0.15 + 0.05 * floor_number:
			box.tier = "Gold"
		box.position = _random_spot(spawn, 4.0)
		box.opened.connect(_on_loot_opened)
		_level.add_child(box)

	var stairs := Stairs.new()
	stairs.position = Vector3(randf_range(-room_half_size + 4.0, room_half_size - 4.0), 0.0, -room_half_size + 3.5)
	stairs.reached.connect(_on_stairs_reached)
	_level.add_child(stairs)

	time_left = floor_time_seconds
	hud.set_floor(floor_number)
	hud.set_time(time_left)
	hud.announce("H.O.S.T.: Welcome to Floor %d! The stairs are somewhere. Probably." % floor_number)


func _build_room() -> void:
	_torches.clear()
	var h := room_half_size
	var tile := 4.0
	var count := int(round(h * 2.0 / tile))

	# Floor: one big collider, KayKit tiles on top.
	_add_collider(Vector3(h * 2.0, 1.0, h * 2.0), Vector3(0.0, -0.5, 0.0))
	for ix in count:
		for iz in count:
			var at := Vector3(-h + tile * (ix + 0.5), 0.0, -h + tile * (iz + 0.5))
			var model := FLOOR_ROCKS if randf() < 0.12 else FLOOR
			_add_model(model, at, randi_range(0, 3) * PI / 2.0)

	# Walls: tall on the far side and the flanks, a low barrier on the near side
	# so the camera can see over it.
	for i in count:
		var along := -h + tile * (i + 0.5)
		_add_model(WALL_PILLAR if i % 2 == 1 else WALL, Vector3(along, 0.0, -h - 0.5), 0.0)
		_add_model(WALL, Vector3(-h - 0.5, 0.0, along), PI / 2.0)
		_add_model(WALL, Vector3(h + 0.5, 0.0, along), PI / 2.0)
		_add_model(BARRIER, Vector3(along, 0.0, h + 0.3), 0.0)
	for corner in [Vector3(-h - 0.5, 0, -h - 0.5), Vector3(h + 0.5, 0, -h - 0.5)]:
		_add_model(PILLAR, corner, 0.0)
	_add_collider(Vector3(h * 2.0 + 2.0, 4.0, 1.0), Vector3(0.0, 2.0, -h - 0.5))
	_add_collider(Vector3(h * 2.0 + 2.0, 4.0, 1.0), Vector3(0.0, 2.0, h + 0.5))
	_add_collider(Vector3(1.0, 4.0, h * 2.0), Vector3(-h - 0.5, 2.0, 0.0))
	_add_collider(Vector3(1.0, 4.0, h * 2.0), Vector3(h + 0.5, 2.0, 0.0))

	# Torches and banners on the back wall, torches on the side walls.
	for i in count:
		var along := -h + tile * (i + 0.5)
		if i % 2 == 0:
			_add_torch(Vector3(along, 2.2, -h), 0.0)
		else:
			_add_model(BANNERS[randi() % BANNERS.size()], Vector3(along, 0.0, -h - 0.5), 0.0)
	for z in [-h * 0.4, h * 0.4]:
		_add_torch(Vector3(-h, 2.2, z), PI / 2.0)
		_add_torch(Vector3(h, 2.2, z), -PI / 2.0)

	# Clutter along the walls (with simple colliders so you bump into it).
	for _i in 7:
		var prop: Array = PROPS[randi() % PROPS.size()]
		var side := randi() % 3
		var along := randf_range(-h + 2.0, h - 2.0)
		var at := Vector3(along, 0.0, -h + 1.5)
		if side == 1:
			at = Vector3(-h + 1.5, 0.0, along)
		elif side == 2:
			at = Vector3(h - 1.5, 0.0, along)
		_add_model(prop[0], at, randf() * TAU)
		_add_collider(prop[1], at + Vector3(0.0, prop[1].y / 2.0, 0.0))

	# A couple of pillars in the middle to dodge around.
	for _i in 2:
		var at := _random_spot(Vector3(0.0, 0.0, h - 3.0), 6.0)
		at.x = clampf(at.x, -h + 4.0, h - 4.0)
		at.z = clampf(at.z, -h + 5.0, h - 5.0)
		_add_model(PILLAR, at, 0.0)
		_add_collider(Vector3(1.5, 4.0, 1.5), at + Vector3(0.0, 2.0, 0.0))


func _add_model(scene: PackedScene, at: Vector3, yaw: float) -> Node3D:
	var model := scene.instantiate() as Node3D
	model.position = at
	model.rotation.y = yaw
	_level.add_child(model)
	return model


func _add_collider(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	_level.add_child(body)


func _add_torch(at: Vector3, yaw: float) -> void:
	_add_model(TORCH, at, yaw)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 1.6
	light.omni_range = 8.0
	light.position = at + Vector3(sin(yaw), 0.0, cos(yaw)) * 0.9 + Vector3(0.0, 0.5, 0.0)
	_level.add_child(light)
	_torches.append(light)


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
	if box.tier == "Gold":
		player.max_health += 2
		player.heal(player.max_health)
		hud.announce("Gold Box: a sparkly utility belt. +2 max HP and a full heal. Sponsors are watching.")
		return
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
