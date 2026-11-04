class_name Enemy
extends CharacterBody3D
## A dungeon skeleton (KayKit CC0 model): wakes up, chases Garl when close,
## and whacks him. Builds its own collision and model so it can be spawned from code.

signal died

const MODELS := [
	preload("res://assets/kaykit/skeletons/Skeleton_Minion.glb"),
	preload("res://assets/kaykit/skeletons/Skeleton_Warrior.glb"),
]
const LOOPING := ["Idle", "Running_A", "Walking_D_Skeletons", "Unarmed_Idle"]

@export var max_health: int = 3
@export var move_speed: float = 3.0
@export var aggro_range: float = 8.0
@export var attack_range: float = 1.5
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.2
@export var attack_windup: float = 0.35

var target: Player
var health: int
var is_dead: bool = false
var _attack_timer: float = 0.0
var _windup_timer: float = -1.0
var _stun_timer: float = 0.0
var _knockback := Vector3.ZERO
var _model: Node3D
var _anim: AnimationPlayer
var _attack_anim: String = "Unarmed_Melee_Attack_Punch_A"


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("hittable")
	health = max_health

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 0.95
	add_child(shape)

	var which := randi() % MODELS.size()
	if which == 1:
		_attack_anim = "1H_Melee_Attack_Chop"
	_model = (MODELS[which] as PackedScene).instantiate()
	_model.scale = Vector3.ONE * 0.9
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		for anim_name in LOOPING:
			if _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		_play("Skeletons_Awaken_Standing")
	_stun_timer = 1.2  # let the wake-up animation finish before chasing


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_stun_timer = maxf(_stun_timer - delta, 0.0)
	_knockback = _knockback.move_toward(Vector3.ZERO, 20.0 * delta)

	var chase := Vector3.ZERO
	if target != null and not target.is_dead and _stun_timer == 0.0:
		var to_target := target.global_position - global_position
		to_target.y = 0.0
		var distance := to_target.length()
		if distance > 0.01:
			_face(to_target)

		if _windup_timer >= 0.0:
			# Mid-swing: land the hit when the windup ends, if Garl is still close.
			_windup_timer -= delta
			if _windup_timer < 0.0 and distance <= attack_range + 0.4:
				target.take_damage(attack_damage)
		elif distance <= attack_range:
			if _attack_timer == 0.0:
				_attack_timer = attack_cooldown
				_windup_timer = attack_windup
				_play(_attack_anim, true)
			elif not _is_playing(_attack_anim):
				_play("Idle")
		elif distance <= aggro_range:
			chase = to_target.normalized() * move_speed
			_play("Running_A")
		else:
			_play("Idle")
	elif target != null and target.is_dead:
		_play("Cheer")

	velocity = Vector3(chase.x + _knockback.x, 0.0, chase.z + _knockback.z)
	move_and_slide()


func take_damage(amount: int, push_direction: Vector3) -> void:
	if is_dead:
		return
	health -= amount
	_knockback = push_direction * 7.0
	_stun_timer = 0.3
	_windup_timer = -1.0
	_spawn_bone_bits()
	if health <= 0:
		_die()
	else:
		_play("Hit_A", true)


func _die() -> void:
	is_dead = true
	remove_from_group("enemies")
	remove_from_group("hittable")
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	_play("Death_A", true)
	died.emit()
	get_tree().create_timer(2.5).timeout.connect(queue_free)


func _face(direction: Vector3) -> void:
	# KayKit characters face +Z.
	var yaw := atan2(direction.x, direction.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, yaw, 0.25)


func _play(anim_name: String, restart: bool = false) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _anim.current_animation == anim_name and not restart:
		return
	_anim.play(anim_name, 0.15)
	if restart:
		_anim.seek(0.0, true)


func _is_playing(anim_name: String) -> bool:
	return _anim != null and _anim.is_playing() and _anim.current_animation == anim_name


func _spawn_bone_bits() -> void:
	var bits := CPUParticles3D.new()
	bits.one_shot = true
	bits.emitting = true
	bits.amount = 14
	bits.lifetime = 0.6
	bits.explosiveness = 1.0
	bits.direction = Vector3.UP
	bits.spread = 70.0
	bits.initial_velocity_min = 3.0
	bits.initial_velocity_max = 6.0
	bits.gravity = Vector3(0, -14, 0)
	bits.scale_amount_min = 0.6
	bits.scale_amount_max = 1.2
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 0.08)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.93, 0.85)
	mesh.material = material
	bits.mesh = mesh
	bits.position = Vector3(0, 1.2, 0)
	add_child(bits)
	get_tree().create_timer(1.0).timeout.connect(bits.queue_free)
