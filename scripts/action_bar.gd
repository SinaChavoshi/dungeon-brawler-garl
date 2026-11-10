class_name ActionBar
extends Control
## The row of ability buttons along the bottom of the screen (keys 1-9).
## Shows each ability's icon and keybind, darkens with a clock sweep while it
## cools down, and flashes when used. Click a button to use it, hover for
## a tooltip.

const SLOT := 52.0
const GAP := 6.0

var player: Player
var _slots: Array[Control] = []
var _flash: Dictionary = {}
var _tooltip := PanelContainer.new()
var _tooltip_text := RichTextLabel.new()
var _hover: int = -1
## Icons are loaded up front: textures first loaded inside _draw() come out blank.
var _icons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id in Abilities.DATA:
		_icons[id] = load(Abilities.info(id)["icon"])
	var count := 9
	var width := count * SLOT + (count - 1) * GAP
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -width / 2.0
	offset_right = width / 2.0
	offset_top = -SLOT - 18.0
	offset_bottom = -18.0
	for i in count:
		var slot := Control.new()
		slot.position = Vector2(i * (SLOT + GAP), 0.0)
		slot.size = Vector2(SLOT, SLOT)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_slot_input.bind(i))
		slot.mouse_entered.connect(_on_hover.bind(i))
		slot.mouse_exited.connect(_on_hover.bind(-1))
		add_child(slot)
		_slots.append(slot)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.08, 0.94)
	style.border_color = Color(0.6, 0.5, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	_tooltip.add_theme_stylebox_override("panel", style)
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_text.bbcode_enabled = true
	_tooltip_text.fit_content = true
	_tooltip_text.custom_minimum_size = Vector2(280, 0)
	_tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(_tooltip_text)
	add_child(_tooltip)


func _process(delta: float) -> void:
	for id in _flash.keys():
		_flash[id] = maxf(_flash[id] - delta * 3.0, 0.0)
	queue_redraw()


func flash(id: String) -> void:
	_flash[id] = 1.0


func _draw() -> void:
	if player == null:
		return
	var font := get_theme_default_font()
	for i in _slots.size():
		var rect := Rect2(_slots[i].position, _slots[i].size)
		draw_rect(rect.grow(3.0), Color(0.02, 0.02, 0.03, 0.85))
		draw_rect(rect.grow(2.0), Color(0.45, 0.38, 0.25), false, 2.0)
		var id: String = player.action_bar[i] if i < player.action_bar.size() else ""
		if id != "":
			var info := Abilities.info(id)
			var icon := _icons.get(id) as Texture2D
			if icon != null:
				draw_texture_rect(icon, rect, false)
			var left: float = player.cooldowns.get(id, 0.0)
			var total: float = info["cooldown"]
			var gcd := player.global_cooldown if info["gcd"] else 0.0
			var fraction := 0.0
			if left > gcd and total > 0.0:
				fraction = left / total
			elif gcd > 0.0:
				fraction = gcd / Abilities.GLOBAL_COOLDOWN
			if fraction > 0.0:
				_draw_sweep(rect, fraction)
				if left > 1.0:
					var text := str(ceili(left))
					draw_string_outline(font, rect.position + Vector2(0, 34), text, HORIZONTAL_ALIGNMENT_CENTER, SLOT, 20, 5, Color.BLACK)
					draw_string(font, rect.position + Vector2(0, 34), text, HORIZONTAL_ALIGNMENT_CENTER, SLOT, 20, Color(1, 0.95, 0.7))
			if _flash.get(id, 0.0) > 0.0:
				draw_rect(rect, Color(1, 1, 0.8, 0.5 * _flash[id]))
			if i == _hover:
				draw_rect(rect, Color(1, 1, 1, 0.15))
		var key := str(i + 1)
		draw_string_outline(font, rect.position + Vector2(4, 15), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
		draw_string(font, rect.position + Vector2(4, 15), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.95, 0.95))


## Dark "clock" wedge showing how much cooldown is left.
func _draw_sweep(rect: Rect2, fraction: float) -> void:
	var center := rect.get_center()
	var points := PackedVector2Array([center])
	var steps := 24
	var start := -PI / 2.0
	var sweep := TAU * fraction
	for s in steps + 1:
		var a := start + sweep * float(s) / float(steps)
		var dir := Vector2(cos(a), sin(a))
		# Push the point out to the square's edge.
		var scale_to_edge := (rect.size.x / 2.0) / maxf(absf(dir.x), absf(dir.y))
		points.append(center + dir * scale_to_edge)
	draw_colored_polygon(points, Color(0, 0, 0, 0.62))


func _on_slot_input(event: InputEvent, index: int) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		var id: String = player.action_bar[index]
		if id != "":
			player.use_ability(id)
		accept_event()


func _on_hover(index: int) -> void:
	_hover = index
	if index < 0 or player == null or player.action_bar[index] == "":
		_tooltip.visible = false
		return
	var info := Abilities.info(player.action_bar[index])
	var lines := "[b][color=#ffffff]%s[/color][/b]" % info["name"]
	var meta := PackedStringArray()
	if info["range"] > 0.0:
		meta.append("%d m range" % int(info["range"]))
	if info["cooldown"] > 0.0:
		meta.append("%d sec cooldown" % int(info["cooldown"]))
	if not meta.is_empty():
		lines += "\n[color=#cccccc]%s[/color]" % "   ".join(meta)
	lines += "\n[color=#ffd75a]%s[/color]" % info["desc"]
	_tooltip_text.text = lines
	_tooltip.visible = true
	_tooltip.reset_size()
	var slot := _slots[index]
	_tooltip.position = Vector2(slot.position.x, -_tooltip.size.y - 12.0)
