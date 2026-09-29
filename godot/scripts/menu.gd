class_name PauseMenu
extends Control
## Pause menu: Friendbook, spells & items, volume settings, save.

signal closed

var _content: VBoxContainer
var _main


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.make_theme()
	_main = get_tree().current_scene
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0.08, 0.25, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 560)
	panel.add_theme_stylebox_override("panel", UI.flat(Color(1, 0.98, 1, 0.97), 30, Color("ffc2dd"), 4, 22))
	var cc := UI.full_center(self)
	cc.mouse_filter = Control.MOUSE_FILTER_STOP
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	v.add_child(tabs)
	var first: Button
	for pair in [["Friendbook", _friendbook], ["Magic & Items", _magic], ["Settings", _settings]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(200, 54)
		b.pressed.connect(pair[1])
		b.pressed.connect(func(): Audio.sfx("ui_move"))
		tabs.add_child(b)
		if first == null:
			first = b
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(130, 54)
	close.pressed.connect(func(): closed.emit())
	tabs.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)
	_friendbook()
	first.grab_focus.call_deferred()


func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()


func _friendbook() -> void:
	_clear()
	var found := 0
	var ids: Array = Game.PARK_POOL + Game.OFFICE_POOL + ["monday"]
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for id in ids:
		var n := int(Game.state["friends"].get(id, 0))
		if n > 0:
			found += 1
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(200, 96)
		cell.add_theme_stylebox_override("panel", UI.flat(Color("fff0f7") if n > 0 else Color("f1edf6"), 16, Color.TRANSPARENT, 0, 8))
		var cv := VBoxContainer.new()
		cell.add_child(cv)
		var name_row := HBoxContainer.new()
		var data: Dictionary = Game.ENEMIES[id]
		var nm := UI.label(data["name"] if n > 0 else "???", 20, UI.INK if n > 0 else Color(0.6, 0.55, 0.65))
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD
		nm.custom_minimum_size.x = 140
		name_row.add_child(nm)
		if Game.state["known_weak"].get(id, false):
			name_row.add_child(UI.icon(data["weak"], 26))
		cv.add_child(name_row)
		cv.add_child(UI.label(("Cheered up x%d" % n) if n > 0 else "Not met yet", 18, Color("8a6aa8")))
		grid.add_child(cell)
	var head := UI.label("Friendbook: %d / %d friends made" % [found, ids.size()], 28, Color("e0609f"))
	_content.add_child(head)
	_content.add_child(UI.label("Every critter you cheer up joins your Friendbook. The icon shows its weakness once you find it.", 20, Color("8a6aa8")))
	_content.add_child(grid)


func _magic() -> void:
	_clear()
	_content.add_child(UI.label("Spells", 28, Color("e0609f")))
	for sid in Game.state["spells"]:
		var sp: Dictionary = Game.SPELLS[sid]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UI.icon(sp["element"] if sp["element"] != "none" else "hp", 34))
		row.add_child(UI.label("%s  (%d MP)  -  %s" % [sp["name"], sp["mp"], sp["desc"]], 22))
		_content.add_child(row)
	if not Game.state["spells"].has("starfall"):
		_content.add_child(UI.label("Collect all 5 Star Shards to learn a secret spell... (%d / 5)" % Game.state["shards"].size(), 20, Color("8a6aa8")))
	_content.add_child(UI.label("Items", 28, Color("e0609f")))
	for iid in Game.ITEMS:
		var it: Dictionary = Game.ITEMS[iid]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UI.icon(it["icon"], 34))
		row.add_child(UI.label("%s  x%d  -  %s" % [it["name"], Game.item_count(iid), it["desc"]], 22))
		_content.add_child(row)
	var s := Game.state
	_content.add_child(UI.label("Level %d   Power %d   Defense %d   XP %d / %d" % [s["level"], s["atk"], s["def"], s["xp"], Game.xp_to_next()], 22, Color("8a6aa8")))


func _settings() -> void:
	_clear()
	_content.add_child(UI.label("Settings", 28, Color("e0609f")))
	for pair in [["Music volume", "music"], ["Sound effects volume", "sfx"]]:
		_content.add_child(UI.label(pair[0], 22))
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.custom_minimum_size = Vector2(500, 36)
		sl.value = Audio.music_volume if pair[1] == "music" else Audio.sfx_volume
		if pair[1] == "music":
			sl.value_changed.connect(func(v): Audio.set_music_volume(v))
		else:
			sl.value_changed.connect(func(v):
				Audio.sfx_volume = v
				Audio.sfx("ui_move"))
		_content.add_child(sl)
	var save := Button.new()
	save.text = "Save game"
	save.custom_minimum_size = Vector2(240, 56)
	save.pressed.connect(func():
		Game.save_game()
		Audio.sfx("coin")
		save.text = "Saved!")
	_content.add_child(save)
	var title := Button.new()
	title.text = "Back to title screen"
	title.custom_minimum_size = Vector2(300, 56)
	title.pressed.connect(func():
		Game.save_game()
		_main.back_to_title())
	_content.add_child(title)
