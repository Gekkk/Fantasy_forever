class_name PauseMenu
extends Control
## Pause menu: quest log, skills & perks, Friendbook, settings.

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
	for pair in [["Quests", _quests], ["Skills", _magic], ["Friendbook", _friendbook], ["Settings", _settings]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(160, 54)
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
	_quests()
	first.grab_focus.call_deferred()


func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()


func _friendbook() -> void:
	_clear()
	var found := 0
	var ids: Array = Game.FRIENDBOOK
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


func _quests() -> void:
	_clear()
	var q := int(Game.state["quest"])
	_content.add_child(UI.label("Main Story", 28, Color("e0609f")))
	for i in Game.QUESTS.size():
		var ch: Dictionary = Game.QUESTS[i]
		if i > 0 and ch["title"] == Game.QUESTS[i - 1]["title"]:
			continue
		if i > q:
			break
		var current: bool = ch["title"] == Game.chapter_title()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UI.icon("star_gold" if current else "hp", 28))
		var text: String = "Chapter %d: %s" % [_chapter_number(i), ch["title"]]
		if current:
			text += "  -  " + Game.objective()
		var l := UI.label(text, 22, UI.INK if current else Color("a898b8"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		_content.add_child(row)
	_content.add_child(UI.label("Side Quests", 28, Color("e0609f")))
	var any := false
	for sid in Game.SIDE_QUESTS:
		var st := Game.side_state(sid)
		if st == "none":
			continue
		any = true
		var sq: Dictionary = Game.SIDE_QUESTS[sid]
		var status: String = {"active": Game.side_goal(sid), "ready": "Done! Return to " + sq["giver"],
			"done": "Complete"}.get(st, "")
		var l := UI.label("%s  (%s)  -  %s\n      Reward: %s" % [sq["title"], sq["giver"], status, sq["reward"]], 20,
			Color("a898b8") if st == "done" else UI.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		_content.add_child(l)
	if not any:
		_content.add_child(UI.label("Talk to people around town with a ! over their head.", 20, Color("8a6aa8")))


func _chapter_number(idx: int) -> int:
	var n := 0
	for i in idx + 1:
		if i == 0 or Game.QUESTS[i]["title"] != Game.QUESTS[i - 1]["title"]:
			n += 1
	return n


func _magic() -> void:
	_clear()
	var s := Game.state
	_content.add_child(UI.label("Level %d   Power %d   HP %d / %d   MP %d / %d   XP %d / %d" % [s["level"], s["atk"],
		s["hp"], s["max_hp"], s["mp"], s["max_mp"], s["xp"], Game.xp_to_next()], 22, Color("8a6aa8")))
	_content.add_child(UI.label("Skills", 28, Color("e0609f")))
	var keys := ["1 / U", "2 / I", "3 / O", "4 / L"]
	for i in Game.SKILL_ORDER.size():
		var sid: String = Game.SKILL_ORDER[i]
		var sk: Dictionary = Game.SKILLS[sid]
		var learned: bool = s["spells"].has(sid)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UI.icon(sk["icon"], 34))
		var text: String = "[%s] %s  (%d MP, %.0fs)  -  %s" % [keys[i], sk["name"], sk["mp"], sk["cd"], sk["desc"]] if learned else "[%s] ???  -  not learned yet" % keys[i]
		var l := UI.label(text, 20, UI.INK if learned else Color("a898b8"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		_content.add_child(row)
	_content.add_child(UI.label("Wand combo: J / Z / click (3 hits)    Dash: K / Shift / right-click (dodges through attacks)", 18, Color("8a6aa8")))
	_content.add_child(UI.label("Perks", 28, Color("e0609f")))
	if s["perks"].is_empty():
		_content.add_child(UI.label("Level up to pick your first perk!", 20, Color("8a6aa8")))
	for pid in s["perks"]:
		var pk: Dictionary = Game.PERKS[pid]
		var l := UI.label("%s  %s  -  %s" % [pk["name"], "*".repeat(Game.perk(pid)), pk["desc"]], 20)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		_content.add_child(l)
	_content.add_child(UI.label("Items", 28, Color("e0609f")))
	for iid in Game.ITEMS:
		var it: Dictionary = Game.ITEMS[iid]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UI.icon(it["icon"], 34))
		row.add_child(UI.label("%s  x%d  -  %s" % [it["name"], Game.item_count(iid), it["desc"]], 20))
		_content.add_child(row)


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
