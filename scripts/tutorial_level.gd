class_name TutorialLevel
extends Level
## Floor 1: Garl and Duchess arrive at the bottom of a long, narrow tunnel.
## It opens into the Training Room: punch the dummies, survive the
## "live-fire portion", and the way down unlocks.
##
## Layout (top-down, -Z is north):
##   Training Room  x -14..14, z -20..0
##   Tunnel         x  -2..2,  z   0..24  (Garl starts at the south end)

enum Stage { TUNNEL, DUMMIES, LIVE_FIRE, DONE }

var _stage: Stage = Stage.TUNNEL
var _said: Dictionary = {}
var _dummies_trained: int = 0
var _dummy_count: int = 0
var _live_enemies: int = 0


func build() -> void:
	time_limit = 300.0
	player_spawn = Vector3(0.0, 0.1, 21.0)
	intro_title = "FLOOR 1: THE TUNNEL"
	intro_text = "Welcome, Crawler! You are live on Delve Live! This is the tutorial floor. It is mandatory. It is also televised."

	# --- Tunnel ---
	floor_area(Rect2(-2.0, 0.0, 4.0, 24.0))
	for i in 6:
		var z := 2.0 + TILE * i
		wall(Vector3(-2.5, 0.0, z), false, WALL_PILLAR if i % 2 == 1 else WALL)
		wall(Vector3(2.5, 0.0, z), false, WALL_PILLAR if i % 2 == 0 else WALL)
	wall(Vector3(0.0, 0.0, 24.5), true)
	for i in [0, 2, 4]:
		torch(Vector3(2.0, 2.2, 2.0 + TILE * i), -PI / 2.0)
	for i in [1, 3, 5]:
		torch(Vector3(-2.0, 2.2, 2.0 + TILE * i), PI / 2.0)
	spawn_chest(Vector3(0.0, 0.0, 11.0), "Bronze", "brass_knuckles")

	# --- Training Room ---
	floor_area(Rect2(-14.0, -20.0, 28.0, 20.0))
	for i in 7:
		var x := -12.0 + TILE * i
		wall(Vector3(x, 0.0, -20.5), true, WALL_PILLAR if i % 2 == 1 else WALL)
		if i != 3:  # the tunnel comes in through the middle of the south wall
			low_wall(Vector3(x, 0.0, 0.3), true)
	for i in 5:
		var z := -18.0 + TILE * i
		wall(Vector3(-14.5, 0.0, z), false)
		wall(Vector3(14.5, 0.0, z), false)
	for x in [-8.0, 0.0, 8.0]:
		torch(Vector3(x, 2.2, -20.0), 0.0)
	for x in [-4.0, 4.0]:
		banner(Vector3(x, 0.0, -20.5))
	torch(Vector3(-14.0, 2.2, -10.0), PI / 2.0)
	torch(Vector3(14.0, 2.2, -10.0), -PI / 2.0)
	prop(Vector3(-12.0, 0.0, -18.0), 0)
	prop(Vector3(12.0, 0.0, -18.0), 2)
	prop(Vector3(-12.0, 0.0, -2.5), 3)
	prop(Vector3(12.0, 0.0, -2.5), 1)
	prop(Vector3(-12.5, 0.0, -10.0), 4)

	for at in [Vector3(-6.0, 0.0, -9.0), Vector3(0.0, 0.0, -11.0), Vector3(6.0, 0.0, -9.0)]:
		var dummy := TrainingDummy.new()
		dummy.position = at
		dummy.trained.connect(_on_dummy_trained)
		add_child(dummy)
		_dummy_count += 1


func _process(delta: float) -> void:
	super(delta)
	if player == null:
		return
	var z := player.global_position.z
	if _stage == Stage.TUNNEL:
		if z < 18.0:
			_say_once("move", "H.O.S.T.", "Tip: WASD to walk. Hold the right mouse button and drag to swivel the camera. The audience prefers your good side. You have one, probably.")
		if z < 13.0:
			_say_once("chest", "H.O.S.T.", "Ooh, a loot box! Walk into it. Everything you find goes in your inventory. Press I to look inside and equip things.")
		if z < 6.0:
			_say_once("map", "H.O.S.T.", "Tip: Press M for the map. It only shows what you've seen. Like a diary, but for hallways.")
		if z < -1.0:
			_stage = Stage.DUMMIES
			announce.emit("NOW ENTERING: THE TRAINING ROOM",
				"Punch the training dummies (left click, Space or J). They have signed waivers. Some of them even read them.")


func _on_dummy_trained(_dummy: TrainingDummy) -> void:
	_dummies_trained += 1
	if _dummies_trained < _dummy_count:
		announce.emit("H.O.S.T.", "Dummy %d of %d defeated. It did not fight back. Still counts." % [_dummies_trained, _dummy_count])
		return
	if _stage != Stage.DUMMIES and _stage != Stage.TUNNEL:
		return
	_stage = Stage.LIVE_FIRE
	announce.emit("TRAINING COMPLETE", "And now, the live-fire portion of the tutorial! Please welcome our volunteers. They are not volunteers.")
	for at in [Vector3(-8.0, 0.0, -17.0), Vector3(0.0, 0.0, -17.5), Vector3(8.0, 0.0, -17.0)]:
		spawn_enemy(at, 2, 2.4)
		_live_enemies += 1


func _on_enemy_killed(_enemy: Enemy) -> void:
	if _stage != Stage.LIVE_FIRE:
		return
	_live_enemies -= 1
	if _live_enemies <= 0:
		_stage = Stage.DONE
		spawn_stairs(Vector3(0.0, 0.0, -15.0))
		spawn_chest(Vector3(9.0, 0.0, -14.0), "Gold")
		announce.emit("STAIRWELL UNLOCKED", "The way down has opened at the north end of the Training Room. A Gold Box appeared too, because the sponsors are feeling generous. Glorbcorp reminds you that descending is not optional.")


func _say_once(key: String, title: String, text: String) -> void:
	if _said.has(key):
		return
	_said[key] = true
	announce.emit(title, text)
