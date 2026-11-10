class_name Duchess
extends CharacterBody3D
## Duchess Pumpernickel III, prize-winning show skunk and Garl's partner.
## Follows Garl around and fires Royal Spray at anything that looks hostile.
## She can't be hurt. She would never allow it.

signal sprayed_first_time
signal quip(text: String)

const BLACK := Color(0.08, 0.08, 0.1)
const WHITE := Color(0.95, 0.95, 0.95)
const GOLD := Color(1.0, 0.8, 0.25)

const COMMAND_QUIPS := [
	"Duchess: Fine. But I'm billing you for this.",
	"Duchess: Stand back, darling. This is art.",
	"Duchess: You could have just asked nicely. Oh, you did. Hmm.",
	"Duchess: For the cameras!",
]
const KILL_QUIPS := [
	"Duchess: Another one bites the dust. Literally. They're made of dust.",
	"Duchess: Garl, darling, you're welcome.",
	"Duchess: I'd like it noted that I did that in heels. Metaphorical heels.",
	"Duchess: Hold for applause.",
	"Duchess: That one was for my fans.",
	"Duchess: Ugh, bone dust in my fur. Again.",
]

@export var follow_distance: float = 2.0
@export var move_speed: float = 7.0
@export var spray_range: float = 9.0
@export var spray_cooldown: float = 1.6
@export var spray_damage: int = 1

var leader: Player
var boost_time: float = 0.0
var _spray_timer: float = 1.0
var _has_sprayed: bool = false
var _quip_cooldown: float = 0.0
var _model: Node3D
var _tail: Node3D
var _walk_phase: float = 0.0


func _ready() -> void:
	add_to_group("companion")
	collision_layer = 2  # don't body-block Garl or the skeletons
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	shape.shape = sphere
	shape.position.y = 0.35
	add_child(shape)
	_build_model()


func _physics_process(delta: float) -> void:
	if leader == null:
		return
	_spray_timer = maxf(_spray_timer - delta, 0.0)
	_quip_cooldown = maxf(_quip_cooldown - delta, 0.0)
	boost_time = maxf(boost_time - delta, 0.0)

	# Trot after Garl, staying a little behind and to the side.
	var to_leader := leader.global_position - global_position
	to_leader.y = 0.0
	var distance := to_leader.length()
	if distance > 18.0:
		global_position = leader.global_position + Vector3(1.0, 0.0, 1.0)
		distance = 0.0
	var move := Vector3.ZERO
	if distance > follow_distance:
		var speed := move_speed * clampf((distance - follow_distance) / 2.0, 0.3, 1.3)
		move = to_leader.normalized() * speed
	velocity = Vector3(move.x, -4.0, move.z)
	move_and_slide()

	var walk := clampf(move.length() / move_speed, 0.0, 1.0)
	_walk_phase += delta * 14.0 * walk
	_model.position.y = absf(sin(_walk_phase)) * 0.08 * walk
	_tail.rotation.x = -0.4 + sin(Time.get_ticks_msec() / 250.0) * 0.12

	var target := _nearest_enemy()
	if target != null:
		_face(target.global_position - global_position, delta)
		if _spray_timer == 0.0:
			_spray(target)
	elif move.length() > 0.1:
		_face(move, delta)


## Garl's "Command: Royal Spray": a big spray at his target, right now.
func command_spray(target: Node3D) -> void:
	var cloud := _spray(target)
	cloud.damage = spray_damage + 2
	if _quip_cooldown == 0.0:
		_quip_cooldown = 6.0
		quip.emit(COMMAND_QUIPS[randi() % COMMAND_QUIPS.size()])


func on_enemy_killed() -> void:
	if _quip_cooldown == 0.0 and randf() < 0.35:
		_quip_cooldown = 12.0
		quip.emit(KILL_QUIPS[randi() % KILL_QUIPS.size()])


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_distance := spray_range
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D
		if enemy == null:
			continue
		var d := enemy.global_position.distance_to(global_position)
		if d < best_distance:
			best = enemy
			best_distance = d
	return best


func _spray(target: Node3D) -> RoyalSpray:
	_spray_timer = spray_cooldown * (0.5 if boost_time > 0.0 else 1.0)
	var cloud := RoyalSpray.new()
	cloud.target = target
	cloud.damage = spray_damage
	get_parent().add_child(cloud)
	cloud.global_position = global_position + Vector3(0, 0.7, 0)
	# Tail flick for the cameras.
	var tween := create_tween()
	tween.tween_property(_tail, "rotation:z", 0.5, 0.08)
	tween.tween_property(_tail, "rotation:z", 0.0, 0.15)
	if not _has_sprayed:
		_has_sprayed = true
		sprayed_first_time.emit()
	return cloud


func _face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length() < 0.01:
		return
	var yaw := atan2(-direction.x, -direction.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, yaw, 10.0 * delta)


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	# Body: a fluffy black loaf with a white racing stripe. Faces -Z.
	_add(_model, _sphere(0.32), BLACK, Vector3(0, 0.4, 0.05), Vector3(1.0, 0.85, 1.45))
	_add(_model, _sphere(0.2), WHITE, Vector3(0, 0.6, 0.05), Vector3(0.45, 0.35, 2.1))
	# Head with a white blaze, pink nose and little ears.
	_add(_model, _sphere(0.22), BLACK, Vector3(0, 0.55, -0.42), Vector3(1.0, 0.9, 1.1))
	_add(_model, _sphere(0.08), WHITE, Vector3(0, 0.66, -0.58), Vector3(0.6, 1.4, 0.6))
	_add(_model, _sphere(0.045), Color(1.0, 0.5, 0.65), Vector3(0, 0.52, -0.66))
	for side in [-1.0, 1.0]:
		_add(_model, _sphere(0.05), BLACK, Vector3(0.14 * side, 0.74, -0.38), Vector3(1, 1.3, 0.6))
		_add(_model, _sphere(0.04), Color(0.1, 0.05, 0.02), Vector3(0.09 * side, 0.6, -0.6))
		_add(_model, _sphere(0.015), WHITE, Vector3(0.08 * side, 0.62, -0.635))
	# Tiara with a pink gem.
	var tiara := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.08
	torus.outer_radius = 0.11
	tiara.mesh = torus
	tiara.material_override = _material(GOLD, true)
	tiara.position = Vector3(0, 0.78, -0.42)
	_model.add_child(tiara)
	_add(_model, _sphere(0.04), Color(1.0, 0.3, 0.7), Vector3(0, 0.84, -0.5)).material_override = _material(Color(1.0, 0.3, 0.7), true)
	# Stubby legs.
	for x in [-0.15, 0.15]:
		for z in [-0.25, 0.3]:
			_add(_model, _cylinder(0.06, 0.25), BLACK, Vector3(x, 0.13, z))
	# The magnificent tail: a curl of fluff with a white stripe.
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.45, 0.45)
	_model.add_child(_tail)
	for i in 5:
		var t := float(i) / 4.0
		var at := Vector3(0, 0.1 + t * 0.75, 0.12 + sin(t * 2.4) * 0.3)
		var radius := 0.17 + 0.07 * sin(t * PI)
		_add(_tail, _sphere(radius), BLACK, at)
		_add(_tail, _sphere(radius * 0.55), WHITE, at + Vector3(0, radius * 0.5, 0))


func _add(parent: Node3D, mesh: Mesh, color: Color, at: Vector3, scale_by: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, false)
	instance.position = at
	instance.scale = scale_by
	parent.add_child(instance)
	return instance


func _material(color: Color, shiny: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.3 if shiny else 0.8
	if shiny:
		material.metallic = 0.6
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.4
	return material


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 7
	return mesh


func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh
