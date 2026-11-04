class_name Level
extends Node3D
## Base class for a dungeon floor. Has the building helpers (KayKit tiles,
## walls, torches, props), spawns enemies, chests and stairs, and keeps the
## map data: which areas are walkable and which cells Garl has explored.

signal stairs_reached
signal enemy_died(enemy: Enemy)
signal chest_opened(box: LootBox)
signal announce(title: String, body: String)

const MAP_CELL := 2.0
const TILE := 4.0

const FLOOR := preload("res://assets/kaykit/dungeon/floor_tile_large.glb")
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

var floor_number: int = 1
var player: Player
var player_spawn := Vector3.ZERO
var time_limit: float = 120.0
var intro_title: String = ""
var intro_text: String = ""
## Walkable areas on the XZ plane (Rect2 x = world x, y = world z).
var walkable: Array[Rect2] = []
var bounds := Rect2()
## Vector2i map cell -> true, for every cell Garl has seen.
var explored: Dictionary = {}
var torches: Array[OmniLight3D] = []


## Override: build the floor's geometry and contents.
func build() -> void:
	pass


## Override: called when one of this level's enemies dies.
func _on_enemy_killed(_enemy: Enemy) -> void:
	pass


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 90.0
	for torch in torches:
		torch.light_energy = 1.5 + sin(t + torch.position.x + torch.position.z) * 0.15 + randf() * 0.1


# --- Map -------------------------------------------------------------------

func reveal_around(pos: Vector3, radius: float) -> void:
	var reach := int(ceil(radius / MAP_CELL))
	var here := Vector2(pos.x, pos.z)
	var center := Vector2i(floori(pos.x / MAP_CELL), floori(pos.z / MAP_CELL))
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var cell := center + Vector2i(dx, dz)
			if explored.has(cell):
				continue
			var cell_center := (Vector2(cell) + Vector2(0.5, 0.5)) * MAP_CELL
			if cell_center.distance_to(here) <= radius and is_walkable(cell_center):
				explored[cell] = true


func is_walkable(point: Vector2) -> bool:
	for rect in walkable:
		if rect.has_point(point):
			return true
	return false


func is_revealed(pos: Vector3) -> bool:
	return explored.has(Vector2i(floori(pos.x / MAP_CELL), floori(pos.z / MAP_CELL)))


# --- Building helpers ------------------------------------------------------

## Lays KayKit floor tiles over a rectangle (sizes in multiples of 4).
func floor_area(rect: Rect2) -> void:
	walkable.append(rect)
	bounds = rect if bounds.size == Vector2.ZERO else bounds.merge(rect)
	var nx := int(round(rect.size.x / TILE))
	var nz := int(round(rect.size.y / TILE))
	for ix in nx:
		for iz in nz:
			var at := Vector3(rect.position.x + TILE * (ix + 0.5), 0.0, rect.position.y + TILE * (iz + 0.5))
			add_model(FLOOR, at, randi_range(0, 3) * PI / 2.0)
	var center := rect.get_center()
	add_collider(Vector3(rect.size.x, 1.0, rect.size.y), Vector3(center.x, -0.5, center.y))


## One 4-unit wall segment centered at `at`. along_x = runs east-west.
func wall(at: Vector3, along_x: bool, model: PackedScene = WALL) -> void:
	add_model(model, at, 0.0 if along_x else PI / 2.0)
	var size := Vector3(4.0, 4.0, 1.0) if along_x else Vector3(1.0, 4.0, 4.0)
	add_collider(size, at + Vector3(0.0, 2.0, 0.0))


## A low barrier that the camera can see over (still blocks walking).
func low_wall(at: Vector3, along_x: bool) -> void:
	add_model(BARRIER, at, 0.0 if along_x else PI / 2.0)
	var size := Vector3(4.0, 4.0, 1.0) if along_x else Vector3(1.0, 4.0, 4.0)
	add_collider(size, at + Vector3(0.0, 2.0, 0.0))


## A wall-mounted torch. yaw: 0 faces +Z, PI/2 faces +X, -PI/2 faces -X.
func torch(at: Vector3, yaw: float) -> void:
	add_model(TORCH, at, yaw)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 1.6
	light.omni_range = 8.0
	light.position = at + Vector3(sin(yaw), 0.0, cos(yaw)) * 0.9 + Vector3(0.0, 0.5, 0.0)
	add_child(light)
	torches.append(light)


func banner(at: Vector3, yaw: float = 0.0) -> void:
	add_model(BANNERS[randi() % BANNERS.size()], at, yaw)


func prop(at: Vector3, which: int = -1) -> void:
	var entry: Array = PROPS[which if which >= 0 else randi() % PROPS.size()]
	add_model(entry[0], at, randf() * TAU)
	var size: Vector3 = entry[1]
	add_collider(size, at + Vector3(0.0, size.y / 2.0, 0.0))


func pillar(at: Vector3) -> void:
	add_model(PILLAR, at, 0.0)
	add_collider(Vector3(1.5, 4.0, 1.5), at + Vector3(0.0, 2.0, 0.0))


func add_model(scene: PackedScene, at: Vector3, yaw: float) -> Node3D:
	var model := scene.instantiate() as Node3D
	model.position = at
	model.rotation.y = yaw
	add_child(model)
	return model


func add_collider(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	add_child(body)


# --- Spawning --------------------------------------------------------------

func spawn_enemy(at: Vector3, health: int, speed: float) -> Enemy:
	var enemy := Enemy.new()
	enemy.target = player
	enemy.max_health = health
	enemy.move_speed = speed
	enemy.position = at
	enemy.died.connect(_handle_enemy_died.bind(enemy))
	add_child(enemy)
	return enemy


func spawn_chest(at: Vector3, tier: String = "Bronze", contents: String = "") -> LootBox:
	var box := LootBox.new()
	box.tier = tier
	box.contents = contents
	box.position = at
	box.opened.connect(func(b: LootBox) -> void: chest_opened.emit(b))
	add_child(box)
	return box


func spawn_stairs(at: Vector3) -> Stairs:
	var stairs := Stairs.new()
	stairs.position = at
	stairs.reached.connect(func() -> void: stairs_reached.emit())
	add_child(stairs)
	return stairs


func _handle_enemy_died(enemy: Enemy) -> void:
	enemy_died.emit(enemy)
	_on_enemy_killed(enemy)
