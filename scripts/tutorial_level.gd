class_name TutorialLevel
extends Level
## Floor 1: Garl and Duchess arrive at the bottom of a long, narrow tunnel.
## It opens into the Training Room: punch the dummies, survive the
## "live-fire portion", and the way down unlocks.
##
## Layout (top-down, -Z is north), from tools/cave_gen.py level1():
##   Training Room  a big cavern centred on (0, -10.5), about 28 x 21
##   Tunnel         winds north from z 24 (Garl's start) to the cavern at z 0

enum Stage { TUNNEL, DUMMIES, LIVE_FIRE, DONE }

var _stage: Stage = Stage.TUNNEL
var _said: Dictionary = {}
var _dummies_trained: int = 0
var _dummy_count: int = 0
var _live_enemies: int = 0


func build() -> void:
	time_limit = 300.0
	intro_title = "FLOOR 1: THE TUNNEL"
	intro_text = "Welcome, Crawler! You are live on Delve Live! This is the tutorial floor. It is mandatory. It is also televised."
	load_cave("level1")

	spawn_chest(Vector3(0.2, 0.0, 11.0), "Bronze", "brass_knuckles")
	# Training Room leftovers: the crew forgot to clean up.
	prop(Vector3(-11.0, 0.0, -9.0), 0)
	prop(Vector3(-10.0, 0.0, -14.0), 2)
	prop(Vector3(10.0, 0.0, -8.0), 3)
	prop(Vector3(-12.0, 0.0, -17.0), 1)
	prop(Vector3(11.0, 0.0, -4.0), 2)
	prop(Vector3(-3.0, 0.0, -19.0), 4)

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
			_say_once("move", "H.O.S.T.", "Tip: W to run, A and D to turn, Q and E to sidestep. Hold the right mouse button and drag to steer with the mouse, or the left button to look around. The audience prefers your good side. You have one, probably.")
		if z < 13.0:
			_say_once("chest", "H.O.S.T.", "Ooh, a loot box! Walk into it. Everything you find goes in your inventory. Press I to look inside and equip things.")
		if z < 6.0:
			_say_once("map", "H.O.S.T.", "Tip: Press M for the map. It only shows what you've seen. Like a diary, but for hallways.")
		if z < -1.0:
			_stage = Stage.DUMMIES
			announce.emit("NOW ENTERING: THE TRAINING ROOM",
				"Press Tab to target a training dummy, then right-click it or press 1 for a Haymaker. They have signed waivers. Some of them even read them.")


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
