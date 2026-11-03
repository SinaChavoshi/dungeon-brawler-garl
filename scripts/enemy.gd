class_name Enemy
extends CharacterBody3D
## A placeholder dungeon goblin: chases Garl when close and bonks him.
## Builds its own mesh and collision so it can be spawned from code.

signal died

@export var max_health: int = 3
@export var move_speed: float = 3.0
@export var aggro_range: float = 9.0
@export var attack_range: float = 1.3
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.0

var target: Player
var health: int
var _attack_timer: float = 0.0
var _knockback := Vector3.ZERO
var _material := StandardMaterial3D.new()
var _base_color := Color(0.35, 0.7, 0.25)


func _ready() -> void:
	add_to_group("enemies")
	health = max_health

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.2
	shape.shape = capsule
	shape.position.y = 0.6
	add_child(shape)

	_material.albedo_color = _base_color
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 1.2, 0.8)
	mesh.mesh = box
	mesh.material_override = _material
	mesh.position.y = 0.6
	add_child(mesh)


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_knockback = _knockback.move_toward(Vector3.ZERO, 20.0 * delta)

	var chase := Vector3.ZERO
	if target != null and not target.is_dead:
		var to_target := target.global_position - global_position
		to_target.y = 0.0
		var distance := to_target.length()
		if distance <= attack_range:
			if _attack_timer == 0.0:
				_attack_timer = attack_cooldown
				target.take_damage(attack_damage)
		elif distance <= aggro_range:
			chase = to_target.normalized() * move_speed

	velocity = Vector3(chase.x + _knockback.x, 0.0, chase.z + _knockback.z)
	move_and_slide()


func take_damage(amount: int, push_direction: Vector3) -> void:
	health -= amount
	_knockback = push_direction * 8.0
	_material.albedo_color = Color.WHITE
	get_tree().create_timer(0.08).timeout.connect(_reset_color)
	if health <= 0:
		died.emit()
		queue_free()


func _reset_color() -> void:
	if is_instance_valid(self):
		_material.albedo_color = _base_color
