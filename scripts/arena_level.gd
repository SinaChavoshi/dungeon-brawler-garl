class_name ArenaLevel
extends Level
## Floors 2+: a walled room with skeletons, chests, pillars and the way down.

@export var half_size: float = 12.0


func build() -> void:
	time_limit = 120.0 + 10.0 * floor_number
	player_spawn = Vector3(0.0, 0.1, half_size - 3.0)
	intro_title = "FLOOR %d" % floor_number
	intro_text = "The stairwell is somewhere. Probably. The collapse timer is definitely somewhere."

	var h := half_size
	var count := int(round(h * 2.0 / TILE))
	floor_area(Rect2(-h, -h, h * 2.0, h * 2.0))
	for i in count:
		var along := -h + TILE * (i + 0.5)
		wall(Vector3(along, 0.0, -h - 0.5), true, WALL_PILLAR if i % 2 == 1 else WALL)
		wall(Vector3(-h - 0.5, 0.0, along), false)
		wall(Vector3(h + 0.5, 0.0, along), false)
		low_wall(Vector3(along, 0.0, h + 0.3), true)
		if i % 2 == 0:
			torch(Vector3(along, 2.2, -h), 0.0)
		else:
			banner(Vector3(along, 0.0, -h - 0.5))
	for z in [-h * 0.4, h * 0.4]:
		torch(Vector3(-h, 2.2, z), PI / 2.0)
		torch(Vector3(h, 2.2, z), -PI / 2.0)

	for _i in 7:
		var side := randi() % 3
		var along := randf_range(-h + 2.0, h - 2.0)
		var at := Vector3(along, 0.0, -h + 1.5)
		if side == 1:
			at = Vector3(-h + 1.5, 0.0, along)
		elif side == 2:
			at = Vector3(h - 1.5, 0.0, along)
		prop(at)
	for _i in 2:
		var at := _random_spot(6.0)
		at.x = clampf(at.x, -h + 4.0, h - 4.0)
		at.z = clampf(at.z, -h + 5.0, h - 5.0)
		pillar(at)

	for _i in 2 + floor_number:
		spawn_enemy(_random_spot(7.0), 2 + floor_number, 2.5 + 0.25 * floor_number)
	for _i in randi_range(1, 2):
		var tier := "Gold" if randf() < 0.15 + 0.05 * floor_number else "Bronze"
		spawn_chest(_random_spot(4.0), tier)
	spawn_stairs(Vector3(randf_range(-h + 4.0, h - 4.0), 0.0, -h + 3.5))


func _random_spot(min_distance: float) -> Vector3:
	var limit := half_size - 2.0
	var spot := Vector3.ZERO
	for _attempt in 30:
		spot = Vector3(randf_range(-limit, limit), 0.0, randf_range(-limit, limit))
		if spot.distance_to(player_spawn) >= min_distance:
			break
	return spot
