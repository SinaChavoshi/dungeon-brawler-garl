class_name ArenaLevel
extends Level
## Floors 2+: one of the generated caverns, with skeletons, chests and the
## way down placed on open floor.

const CAVES := ["arena_0", "arena_1", "arena_2"]

var _spots: Array = []


func build() -> void:
	time_limit = 120.0 + 10.0 * floor_number
	intro_title = "FLOOR %d" % floor_number
	intro_text = "The stairwell is somewhere. Probably. The collapse timer is definitely somewhere."
	load_cave(CAVES[(floor_number - 2) % CAVES.size()])
	_spots = cave_data.get("open_spots", []).duplicate()
	_spots.shuffle()

	# The way down goes as far from the start as possible.
	var far_index := 0
	for i in _spots.size():
		if _spot(i).distance_to(player_spawn) > _spot(far_index).distance_to(player_spawn):
			far_index = i
	spawn_stairs(_take(far_index))

	for _i in 2 + floor_number:
		spawn_enemy(_random_spot(7.0), 2 + floor_number, 2.5 + 0.25 * floor_number)
	for _i in randi_range(1, 2):
		var tier := "Gold" if randf() < 0.15 + 0.05 * floor_number else "Bronze"
		spawn_chest(_random_spot(4.0), tier)
	for _i in 3:
		prop(_random_spot(4.0))


func _spot(i: int) -> Vector3:
	var s: Array = _spots[i]
	return Vector3(s[0], 0.0, s[1])


func _take(i: int) -> Vector3:
	var at := _spot(i)
	_spots.remove_at(i)
	# Keep things from piling on top of each other.
	_spots = _spots.filter(func(s: Array) -> bool: return Vector2(s[0], s[1]).distance_to(Vector2(at.x, at.z)) > 2.5)
	return at


func _random_spot(min_distance: float) -> Vector3:
	for i in _spots.size():
		if _spot(i).distance_to(player_spawn) >= min_distance:
			return _take(i)
	return player_spawn + Vector3(randf_range(-3.0, 3.0), 0.0, -6.0)
