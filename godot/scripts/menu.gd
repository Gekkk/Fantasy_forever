class_name PauseMenu
extends Control
## Pause menu: quest log, hero attributes, skill tree, gear, Friendbook, settings.

signal closed

var _content: VBoxContainer
var _main
var _scroll: ScrollContainer
var _current: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.make_theme()
	_main = get_tree().current_scene
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0.08, 0.25, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1120, 600)
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
	for pair in [["Quests", _quests], ["Hero", _hero], ["Skills", _magic], ["Gear", _gear], ["Friends", _friendbook], ["Settings", _settings]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(138, 54)
		b.pressed.connect(_open_tab.bind(pair[1]))
		b.pressed.connect(func(): Audio.sfx("ui_move"))
		tabs.add_child(b)
		if first == null:
			first = b
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(110, 54)
	close.pressed.connect(func(): closed.emit())
	tabs.add_child(close)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	_scroll.add_child(_content)
	var unspent := int(Game.state.get("attr_points", 0)) + int(Game.state.get("skill_points", 0)) > 0
	_open_tab(_hero if unspent else _quests)
	first.grab_focus.call_deferred()


func _open_tab(fn: Callable) -> void:
	_current = fn
	_scroll.scroll_vertical = 0
	fn.call()


## Redraws the open tab after a change, keeping the scroll position.
func _refresh() -> void:
	var keep := _scroll.scroll_vertical
	_current.call()
	await get_tree().process_frame
	_scroll.scroll_vertical = keep
	if _main and _main.ui:
		_main.ui.refresh()
	if _main and _main.player:
		_main.player.rebuild_model()


func _clear() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()


func _row(sep := 10) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	_content.add_child(r)
	return r


func _btn(text: String, cb: Callable, enabled := true, w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	if w > 0.0:
		b.custom_minimum_size.x = w
	b.pressed.connect(func():
		Audio.sfx("ui_confirm")
		cb.call()
		_refresh())
	return b


func _wide(text: String, size := 20, color := UI.INK) -> Label:
	var l := UI.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


# ------------------------------------------------------------------ hero
func _hero() -> void:
	_clear()
	var s := Game.state
	_content.add_child(UI.label("%s   Level %d   (XP %d / %d)" % [s["name"], s["level"], s["xp"], Game.xp_to_next()], 28, Color("e0609f")))
	var role: Dictionary = Rpg.ROLES[Rpg.role()]
	_content.add_child(_wide("%s (%s): %s  Change roles at the magic mirror in Velour's Boutique." % [role["name"], role["title"], role["desc"]], 19, Color("6a5a88")))
	var pts := int(s["attr_points"])
	var head := _row()
	head.add_child(UI.icon("gem", 30))
	head.add_child(UI.label("Attribute points: %d" % pts, 24, Color("8a4fd8") if pts > 0 else Color("8a6aa8")))
	for a in Rpg.ATTRS:
		var info: Dictionary = Rpg.ATTR_INFO[a]
		var r := _row()
		r.add_child(UI.icon(info["icon"], 40))
		var bonus := Rpg.attr_total(a) - int(s["attr"][a])
		r.add_child(UI.label("%s  %d%s" % [info["name"], Rpg.attr_total(a), ("  (+%d gear)" % bonus) if bonus > 0 else ""], 24))
		r.add_child(_wide("  -  " + info["desc"], 19, Color("8a6aa8")))
		var aa: String = a
		r.add_child(_btn("+1", func(): Rpg.spend_attr(aa), pts > 0, 70))
		r.add_child(_btn("+5", func():
			for i in 5:
				Rpg.spend_attr(aa), pts >= 5, 70))
	_row().add_child(_btn("Reset attribute points", Rpg.reset_attrs))
	_content.add_child(UI.label("Stats", 26, Color("e0609f")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 4)
	_content.add_child(grid)
	var df := float(Rpg.d("def"))
	for line in [
		"Max HP  %d" % s["max_hp"], "Max MP  %d" % s["max_mp"],
		"Wand Power  %d" % s["atk"], "Spell Power  %d" % int(Rpg.d("matk")),
		"Defense  %d  (-%d%% damage)" % [int(df), int(round(100.0 * df / (60.0 + df)))],
		"Critical Hit  %d%%" % int(round(100.0 * float(Rpg.d("crit")))),
		"Move Speed  +%d%%" % int(round(100.0 * (float(Rpg.d("move")) - 1.0))),
		"Swing Speed  +%d%%" % int(round(100.0 * (float(Rpg.d("aspd")) - 1.0))),
		"Cooldowns  -%d%%" % int(round(100.0 * float(Rpg.d("cdr")))),
		"Item Find  +%d%%" % int(round(100.0 * (float(Rpg.d("find")) - 1.0))),
		"Fire / Ice / Sparkle  +%d%% / +%d%% / +%d%%" % [int(round(100 * (float(Rpg.d("fire")) - 1))), int(round(100 * (float(Rpg.d("ice")) - 1))), int(round(100 * (float(Rpg.d("arcane")) - 1)))],
		"MP per wand hit  %d" % int(Rpg.d("mp_hit")),
	]:
		grid.add_child(UI.label(line, 20, UI.INK))


# ------------------------------------------------------------------ gear
func _item_row(it: Dictionary, actions: Array) -> void:
	var r := _row(12)
	r.add_child(UI.icon(it["slot"], 44))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	r.add_child(col)
	var rar: Dictionary = Rpg.RARITY[int(it["rarity"])]
	var title := UI.label("%s   (%s %s, item level %d)" % [it["name"], rar["name"], Rpg.SLOT_NAMES[it["slot"]], it["ilvl"]], 21, (rar["color"] as Color).darkened(0.25))
	col.add_child(title)
	var lines: Array = Rpg.item_lines(it)
	var stats := _wide(", ".join(lines), 18, Color("6a5a88"))
	col.add_child(stats)
	for a in actions:
		r.add_child(a)


func _gear() -> void:
	_clear()
	var s := Game.state
	_content.add_child(UI.label("Equipped", 26, Color("e0609f")))
	for slot in Rpg.SLOTS:
		var it: Dictionary = s["equip"][slot]
		if it.is_empty():
			var r := _row()
			r.add_child(UI.icon(slot, 44))
			r.add_child(UI.label("%s: (empty)" % Rpg.SLOT_NAMES[slot], 21, Color("a898b8")))
		else:
			_item_row(it, [])
	var bag: Array = s["bag"]
	var head := _row()
	head.add_child(UI.label("Bag  %d / %d" % [bag.size(), Rpg.BAG_SIZE], 26, Color("e0609f")))
	head.add_child(_btn("Equip best", _equip_best, not bag.is_empty()))
	head.add_child(_btn("Sell all Common", _sell_commons, not bag.is_empty()))
	if bag.is_empty():
		_content.add_child(UI.label("Cheer up critters to find gear. Elites and bosses drop the best!", 19, Color("8a6aa8")))
	for i in bag.size():
		var it: Dictionary = bag[i]
		var diff := Rpg.score(it) - Rpg.score(s["equip"][it["slot"]])
		var arrow := UI.label(("+%d" % int(diff)) if diff > 0 else ("%d" % int(diff)), 20, Color("3aa860") if diff > 0 else Color("c05a7a"))
		arrow.custom_minimum_size.x = 50
		var idx := i
		_item_row(it, [arrow, _btn("Equip", func(): Rpg.equip_from_bag(idx)), _btn("Sell %d" % int(int(it["price"]) / 4), func(): Rpg.sell_from_bag(idx))])
	_content.add_child(UI.label("Snacks", 26, Color("e0609f")))
	for iid in Game.ITEMS:
		var info: Dictionary = Game.ITEMS[iid]
		var r := _row()
		r.add_child(UI.icon(info["icon"], 34))
		r.add_child(_wide("%s  x%d  -  %s" % [info["name"], Game.item_count(iid), info["desc"]], 20))


func _equip_best() -> void:
	for slot in Rpg.SLOTS:
		var best := -1
		var best_score := Rpg.score(Game.state["equip"][slot])
		var bag: Array = Game.state["bag"]
		for i in bag.size():
			if bag[i]["slot"] == slot and Rpg.score(bag[i]) > best_score:
				best = i
				best_score = Rpg.score(bag[i])
		if best >= 0:
			Rpg.equip_from_bag(best)


func _sell_commons() -> void:
	var bag: Array = Game.state["bag"]
	for i in range(bag.size() - 1, -1, -1):
		if int(bag[i]["rarity"]) == 0:
			Rpg.sell_from_bag(i)


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
	var pts := int(s["skill_points"])
	var head := _row()
	head.add_child(UI.icon("gem", 30))
	head.add_child(UI.label("Skill points: %d" % pts, 24, Color("8a4fd8") if pts > 0 else Color("8a6aa8")))
	head.add_child(_wide("   Buttons 1-4 put a spell on your hotbar.", 18, Color("8a6aa8")))
	_content.add_child(UI.label("Spells", 26, Color("e0609f")))
	for sid in Rpg.ACTIVE_ORDER:
		var sk: Dictionary = Rpg.ACTIVES[sid]
		var r := _row()
		var rk := Rpg.rank(sid)
		var ic := UI.icon(sk["icon"], 44)
		ic.modulate = Color.WHITE if rk > 0 else Color(1, 1, 1, 0.35)
		r.add_child(ic)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		r.add_child(col)
		col.add_child(UI.label("%s   Rank %d/%d    %d MP, %.1fs" % [sk["name"], rk, sk["max"], sk["mp"], Rpg.skill_cd(sid)], 21,
			UI.INK if rk > 0 else Color("a898b8")))
		col.add_child(_wide("%s  Per rank: %s" % [sk["desc"], sk["per"]], 17, Color("6a5a88")))
		var why := Rpg.cant_raise(sid)
		var ss: String = sid
		r.add_child(_btn("+ Rank" if why == "" else why, func(): Rpg.raise(ss), why == "", 130))
		if rk > 0:
			for i in 4:
				var slot := i
				var b := _btn(str(i + 1), func(): Rpg.set_slot(slot, ss), true, 44)
				if Rpg.slot_skill(i) == sid:
					b.modulate = Color(1.0, 0.8, 0.3)
				r.add_child(b)
	_content.add_child(UI.label("Talents", 26, Color("e0609f")))
	for tid in Rpg.TALENT_ORDER:
		var t: Dictionary = Rpg.TALENTS[tid]
		var r := _row()
		var rk := Rpg.rank(tid)
		r.add_child(UI.label("%s  %d/%d" % [t["name"], rk, t["max"]], 21, UI.INK if rk > 0 else Color("8a6aa8")))
		r.add_child(_wide("  -  " + String(t["desc"]), 18, Color("6a5a88")))
		var why := Rpg.cant_raise(tid)
		var tt: String = tid
		r.add_child(_btn("+1" if why == "" else why, func(): Rpg.raise(tt), why == "", 130))


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
