class_name InventoryUI
extends CanvasLayer
## The inventory screen, "managed" by H.O.S.T. Press I or Tab to open.
## Opening it pauses the game. Click an item to read H.O.S.T.'s notes on it,
## then use or equip it.

signal use_requested(id: String)
signal equip_requested(id: String)
signal unequip_requested(slot: String)

const ACCENT := Color(1.0, 0.85, 0.3)

var inventory: Inventory
var _panel := PanelContainer.new()
var _gold := Label.new()
var _grid := GridContainer.new()
var _equipped := VBoxContainer.new()
var _detail_name := Label.new()
var _detail_effect := Label.new()
var _detail_desc := Label.new()
var _action := Button.new()
var _selected: String = ""


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func setup(bag: Inventory) -> void:
	inventory = bag
	inventory.changed.connect(_refresh)
	_refresh()


func is_open() -> bool:
	return _panel.visible


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var key := key_event.physical_keycode
	if key == KEY_I or key == KEY_TAB:
		_toggle()
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE and _panel.visible:
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	_panel.visible = not _panel.visible
	get_tree().paused = _panel.visible
	if _panel.visible:
		_refresh()


func _build() -> void:
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(760, 460)
	_panel.offset_left = -380
	_panel.offset_right = 380
	_panel.offset_top = -230
	_panel.offset_bottom = 230
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.1, 1.0)
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "INVENTORY  ·  catalogued by H.O.S.T."
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_gold.add_theme_font_size_override("font_size", 18)
	header.add_child(_gold)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var left := VBoxContainer.new()
	body.add_child(left)
	left.add_child(_section("BAG (%d slots)" % Inventory.MAX_SLOTS))
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(_grid)
	left.add_child(_section("EQUIPPED"))
	left.add_child(_equipped)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(250, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	right.add_child(_section("H.O.S.T.'S NOTES"))
	_detail_name.add_theme_font_size_override("font_size", 18)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_detail_name)
	_detail_effect.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	right.add_child(_detail_effect)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.custom_minimum_size = Vector2(250, 0)
	_detail_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	right.add_child(_detail_desc)
	_action.custom_minimum_size = Vector2(0, 36)
	_action.pressed.connect(_on_action)
	right.add_child(_action)

	var footer := Label.new()
	footer.text = "I / Tab / Esc to close  ·  The game is paused while you browse. H.O.S.T. is billing you for the time anyway."
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	root.add_child(footer)


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	return label


func _refresh() -> void:
	if inventory == null:
		return
	_gold.text = "Gold: %d" % inventory.gold
	for child in _grid.get_children():
		child.queue_free()
	for i in Inventory.MAX_SLOTS:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(225, 30)
		slot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		slot.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot.add_theme_font_size_override("font_size", 13)
		if i < inventory.items.size():
			var entry: Dictionary = inventory.items[i]
			var id: String = entry["id"]
			slot.text = Items.display_name(id) + ("  x%d" % entry["count"] if entry["count"] > 1 else "")
			slot.tooltip_text = Items.display_name(id)
			slot.pressed.connect(_select.bind(id))
		else:
			slot.text = ""
			slot.disabled = true
		_grid.add_child(slot)

	for child in _equipped.get_children():
		child.queue_free()
	for slot_name in Items.SLOTS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.custom_minimum_size = Vector2(70, 0)
		label.text = slot_name.capitalize() + ":"
		row.add_child(label)
		if inventory.equipped.has(slot_name):
			var item_id: String = inventory.equipped[slot_name]
			var name_button := Button.new()
			name_button.text = Items.display_name(item_id)
			name_button.flat = true
			name_button.pressed.connect(_select.bind(item_id))
			row.add_child(name_button)
			var off := Button.new()
			off.text = "Unequip"
			off.pressed.connect(func() -> void: unequip_requested.emit(slot_name))
			row.add_child(off)
		else:
			var empty := Label.new()
			empty.text = "(nothing)"
			empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
			row.add_child(empty)
		_equipped.add_child(row)

	if _selected != "" and inventory.count_of(_selected) == 0 and not inventory.equipped.values().has(_selected):
		_selected = ""
	_show_detail()


func _select(id: String) -> void:
	_selected = id
	_show_detail()


func _show_detail() -> void:
	if _selected == "":
		_detail_name.text = "Pick an item."
		_detail_effect.text = ""
		_detail_desc.text = "H.O.S.T. has written a review of every single thing you own. You're welcome."
		_action.visible = false
		return
	var item := Items.info(_selected)
	_detail_name.text = Items.display_name(_selected)
	_detail_effect.text = Items.effect_text(_selected)
	_detail_desc.text = item.get("desc", "")
	var kind: String = item.get("kind", "junk")
	var in_bag := inventory.count_of(_selected) > 0
	_action.visible = in_bag and kind != "junk"
	_action.text = "Use" if kind == "consumable" else "Equip"


func _on_action() -> void:
	if _selected == "":
		return
	if Items.info(_selected).get("kind", "") == "consumable":
		use_requested.emit(_selected)
	else:
		equip_requested.emit(_selected)
