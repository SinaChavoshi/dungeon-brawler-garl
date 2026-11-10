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

const TORCH := preload("res://assets/kaykit/dungeon/torch_mounted.glb")
const PILLAR := preload("res://assets/kaykit/dungeon/pillar.glb")
const ROCK_SHADER := preload("res://shaders/rock.gdshader")
const CRYSTAL_SHADER := preload("res://shaders/crystal.gdshader")
const ROCK_HEIGHT := preload("res://assets/textures/rock_height.png")
const ROCK_NORMAL := preload("res://assets/textures/rock_normal.png")
const CRYSTAL_COLORS := [Color(0.3, 0.85, 1.0), Color(0.7, 0.4, 1.0), Color(0.35, 1.0, 0.6)]
const TORCH_ENERGY := 2.4
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
## Map cells (Vector2i -> true) that have open floor.
var walkable_cells: Dictionary = {}
var bounds := Rect2()
## Extra data that came with the cave mesh (spawn, torches, open spots...).
var cave_data: Dictionary = {}
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
		torch.light_energy = TORCH_ENERGY + sin(t + torch.position.x + torch.position.z) * 0.2 + randf() * 0.15


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
	return walkable_cells.has(Vector2i(floori(point.x / MAP_CELL), floori(point.y / MAP_CELL)))


func is_revealed(pos: Vector3) -> bool:
	return explored.has(Vector2i(floori(pos.x / MAP_CELL), floori(pos.z / MAP_CELL)))


# --- Building helpers ------------------------------------------------------

## True on desktop (Forward+). The web preview runs the lighter renderer,
## so it skips the expensive extras like torch shadows.
static func high_quality() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


## Loads a generated cave (see tools/cave_gen.py): the rock mesh with its
## collision, torches, glowing crystals, rubble and the map cells.
func load_cave(cave_name: String) -> void:
	var meta := load("res://assets/cave/%s.json" % cave_name) as JSON
	cave_data = meta.data
	var cave_scene := load("res://assets/cave/%s.glb" % cave_name) as PackedScene
	var cave := cave_scene.instantiate() as Node3D
	cave.name = "Cave"
	add_child(cave)

	var rock := ShaderMaterial.new()
	rock.shader = ROCK_SHADER
	rock.set_shader_parameter("height_tex", ROCK_HEIGHT)
	rock.set_shader_parameter("normal_tex", ROCK_NORMAL)
	for mesh_instance in cave.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_instance as MeshInstance3D
		mi.material_override = rock
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = mi.mesh.create_trimesh_shape()
		body.add_child(shape)
		mi.add_child(body)

	for cell in cave_data.get("map_cells", []):
		walkable_cells[Vector2i(int(cell[0]), int(cell[1]))] = true
	var b: Array = cave_data.get("bounds", [0, 0, 0, 0])
	bounds = Rect2(b[0], b[1], b[2], b[3])
	var spawn: Array = cave_data.get("spawn", [0, 0])
	player_spawn = Vector3(spawn[0], 0.3, spawn[1])

	for spot in cave_data.get("torches", []):
		cave_torch(_vec3(spot["pos"]), _vec3(spot["normal"]))
	for spot in cave_data.get("crystals", []):
		crystal_cluster(_vec3(spot["pos"]), _vec3(spot["normal"]))
	_scatter_rubble(cave_data.get("rubble", []), rock)


## A torch mounted on the rock at `at`, sticking out along the wall normal.
func cave_torch(at: Vector3, normal: Vector3) -> void:
	var out := Vector3(normal.x, 0.0, normal.z).normalized()
	var model := add_model(TORCH, at - out * 0.2, atan2(out.x, out.z))
	var flame_at := model.position + out * 0.45 + Vector3(0.0, 0.78, 0.0)
	_add_flame(flame_at)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.58, 0.26)
	light.light_energy = TORCH_ENERGY
	light.omni_range = 11.0
	light.omni_attenuation = 1.3
	light.shadow_enabled = high_quality()
	light.shadow_blur = 1.5
	light.light_volumetric_fog_energy = 1.4
	light.position = flame_at + out * 0.35 + Vector3(0.0, 0.15, 0.0)
	add_child(light)
	torches.append(light)


func _add_flame(at: Vector3) -> void:
	var fire := CPUParticles3D.new()
	fire.position = at
	fire.amount = 16
	fire.lifetime = 0.55
	fire.local_coords = false
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.07
	fire.direction = Vector3.UP
	fire.spread = 12.0
	fire.gravity = Vector3(0.0, 1.6, 0.0)
	fire.initial_velocity_min = 0.2
	fire.initial_velocity_max = 0.5
	fire.scale_amount_min = 0.7
	fire.scale_amount_max = 1.1
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.1))
	fire.scale_amount_curve = shrink
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	ramp.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
	fire.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.3)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(2.5, 1.6, 0.8)
	mat.albedo_texture = _soft_dot()
	quad.material = mat
	fire.mesh = quad
	add_child(fire)


var _dot_texture: GradientTexture2D

func _soft_dot() -> Texture2D:
	if _dot_texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_dot_texture = GradientTexture2D.new()
		_dot_texture.gradient = g
		_dot_texture.fill = GradientTexture2D.FILL_RADIAL
		_dot_texture.fill_from = Vector2(0.5, 0.5)
		_dot_texture.fill_to = Vector2(0.5, 0.0)
		_dot_texture.width = 64
		_dot_texture.height = 64
	return _dot_texture


## A cluster of glowing crystals growing out of the wall.
func crystal_cluster(at: Vector3, normal: Vector3) -> void:
	var out := Vector3(normal.x, 0.0, normal.z).normalized()
	var color: Color = CRYSTAL_COLORS[randi() % CRYSTAL_COLORS.size()]
	var mat := ShaderMaterial.new()
	mat.shader = CRYSTAL_SHADER
	mat.set_shader_parameter("color", color)
	var root := Node3D.new()
	root.position = at - out * 0.15 + Vector3(0.0, -0.45, 0.0)
	add_child(root)
	for i in randi_range(4, 6):
		var shard := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = randf_range(0.08, 0.17)
		mesh.height = randf_range(0.45, 1.25)
		mesh.radial_segments = 5
		mesh.rings = 0
		mesh.material = mat
		shard.mesh = mesh
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tilt_axis := out.cross(Vector3.UP).normalized()
		var rot := Basis(tilt_axis, -randf_range(0.2, 0.9)).rotated(Vector3.UP, randf_range(-0.6, 0.6))
		shard.transform = Transform3D(rot, out * randf_range(0.0, 0.3) + tilt_axis * randf_range(-0.35, 0.35))
		shard.position += rot.y * mesh.height * 0.5
		root.add_child(shard)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = 4.5
	light.position = out * 0.6 + Vector3(0.0, 0.5, 0.0)
	root.add_child(light)


func _scatter_rubble(spots: Array, rock: Material) -> void:
	if spots.is_empty():
		return
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 0.8
	mesh.radial_segments = 7
	mesh.rings = 3
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = spots.size()
	for i in spots.size():
		var spot: Array = spots[i]
		var size: float = spot[2]
		var rot := Basis.from_euler(Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3)))
		rot = rot.scaled(Vector3(size * randf_range(0.8, 1.5), size * randf_range(0.5, 0.9), size * randf_range(0.8, 1.5)))
		multimesh.set_instance_transform(i, Transform3D(rot, Vector3(spot[0], size * 0.1, spot[1])))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = rock
	add_child(instance)


static func _vec3(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])


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
