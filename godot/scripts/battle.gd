class_name Battle
extends Node3D
## Turn-based battle with timed hits, timed guards, elemental weaknesses,
## visible enemy intents and Mochi the cat as a helper.
##
## The whole fight is one coroutine (_run). Every exit path emits `finished`
## exactly once, so the overworld always gets control back.

signal finished(result: String) # "win" | "lose" | "flee"
signal _command_chosen(cmd: Dictionary)
signal _results_closed

const HERO_HOME := Vector3(-2.9, 0, 1.1)
const MOCHI_HOME := Vector3(-3.7, 0, -0.5)
const HERO_ROT := 62.0
const ENEMY_ROT := -58.0

var enemy_ids: Array = []
var area := "park"
var first_strike := false
var is_boss := false

var cam: Camera3D
var hero: ModelAnim
var mochi: ModelAnim
var enemies: Array = []
var target_ring: MeshInstance3D
var shield: MeshInstance3D

var ui: CanvasLayer
var theme: Theme
var _msg: Label
var _msg_panel: PanelContainer
var _cmd_panel: PanelContainer
var _cmd_box: VBoxContainer
var _cmd_title: Label
var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _hp_text: Label
var _mp_text: Label
var _mochi_label: Label
var _results: PanelContainer
var _big: Label

var _round := 0
var _guarding := false
var _mochi_buff := 1.0
var _over := false
var _cam_base := Vector3(0.7, 3.4, 8.8)
var _cam_look := Vector3(0.3, 0.9, 0)
var _t := 0.0
var _phase2 := false
var _selecting_target := false


func setup(ids: Array, arena: String, strike := false) -> void:
	enemy_ids = ids
	area = arena
	first_strike = strike
	is_boss = ids.has("monday")


func _ready() -> void:
	theme = UI.make_theme()
	_build_arena()
	_build_actors()
	_build_ui()
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if cam:
		cam.position = _cam_base + Vector3(sin(_t * 0.35) * 0.35, sin(_t * 0.5) * 0.08, 0)
		cam.look_at(_cam_look)
	for e in enemies:
		_place_overlay(e)
	if target_ring and target_ring.visible:
		target_ring.rotation.y += delta * 1.5


# ================================================================ scene
func _build_arena() -> void:
	cam = Camera3D.new()
	cam.fov = 42
	cam.position = _cam_base
	add_child(cam)
	cam.current = true
	var floor_mat: Material
	match area:
		"office":
			floor_mat = Art.ground_mat(Color("d29a6c"), Color("c0875c"), 2, 0.9, Color("94603e"))
		"boss":
			floor_mat = Art.ground_mat(Color("c3b8dc"), Color("afa3cc"), 1, 1.0, Color("8f84b0"))
		_:
			floor_mat = Art.ground_mat(Color("86cf78"), Color("68b86a"))
	var disc := MeshInstance3D.new()
	disc.mesh = Art.cyl(9.5, 9.5, 0.4, 48)
	disc.material_override = floor_mat
	disc.position.y = -0.2
	add_child(disc)
	Art.part(self, Art.cyl(9.6, 8.6, 2.0, 48), Color("8f78d0") if area != "park" else Color("7cc97a"), Vector3(0, -1.4, 0))
	var deco := World.Batch.new()
	match area:
		"park":
			for i in 14:
				var a := PI + 0.2 + i * (PI - 0.4) / 13.0
				var p := Vector3(cos(a) * 8.5, 0, sin(a) * 6.5 - 1.5)
				var cols := [Color("6fcf7d"), Color("ffb3d1")] if i % 3 != 0 else [Color("ffb3d1"), Color("ffc9df")]
				deco.add(Art.cyl(0.2, 0.28, 1.6), Color("a87a5c"), p + Vector3(0, 0.8, 0))
				deco.add(Art.sphere(1.1), cols[0], p + Vector3(0, 2.2, 0))
				deco.add(Art.sphere(0.75), cols[1], p + Vector3(0.5, 2.7, 0.3))
			var fc := [Color("ff8fb8"), Color("ffe27a"), Color("ffffff"), Color("c3a6ff")]
			for i in 120:
				var p := Vector3(randf_range(-8, 8), 0, randf_range(-5, 5))
				if absf(p.z - 0.5) < 2.6 and absf(p.x) < 5.5:
					continue
				deco.add(Art.sphere(0.09), fc[i % 4], p + Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
			Art.ambient(self, Vector3(0, 1.5, -1), Vector3(7, 1.5, 4), Color("fff3a0"), 40, "soft", 0.22, 4.0)
		"office":
			Art.part(self, Art.box(Vector3(20, 6, 0.5)), Color("d9c9f2"), Vector3(0, 3, -6.5))
			for x in [-6.0, -2.0, 2.0, 6.0]:
				Art.part(self, Art.box(Vector3(2.2, 2.6, 0.1)), Color("3a3f8a"), Vector3(x, 3.4, -6.2), Vector3.ZERO, Vector3.ONE, 0.8)
			for x in [-5.5, 0.0, 5.5]:
				deco.add(Art.box(Vector3(2.2, 0.12, 1.1)), Color("d4a275"), Vector3(x, 0.8, -4.5))
				deco.add(Art.box(Vector3(0.8, 0.5, 0.09)), Color("8ff0ff"), Vector3(x, 1.25, -4.8), Vector3.ZERO, Vector3.ONE, 1.4)
				deco.add(Art.box(Vector3(2.0, 0.8, 1.0)), Color("b8875c"), Vector3(x, 0.4, -4.5))
			Art.ambient(self, Vector3(0, 3, -2), Vector3(7, 1.5, 3), Color(1, 1, 1, 0.9), 14, "soft", 0.3, 5.0, Vector3(0, -0.2, 0))
			Art.light(self, Vector3(0, 4, 2), Color("ffd9a8"), 1.5, 12)
		"boss":
			var clock := Art.node(self, "BigClock", Vector3(0, 6.5, -9))
			Art.part(clock, Art.cyl(5.2, 5.2, 0.6, 48), Color("8f78d0"), Vector3.ZERO, Vector3(90, 0, 0))
			Art.part(clock, Art.cyl(4.7, 4.7, 0.62, 48), Color("fff4e0"), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, 0.5)
			Art.part(clock, Art.torus(4.6, 5.0), Color("ffd36b"), Vector3(0, 0, 0.3), Vector3(90, 0, 0), Vector3.ONE, 0.8)
			for i in 12:
				var a := i * TAU / 12
				Art.part(clock, Art.box(Vector3(0.25, 0.7, 0.1)), Color("5a4a8a"), Vector3(sin(a) * 4.0, cos(a) * 4.0, 0.35), Vector3(0, 0, -rad_to_deg(a)))
			for i in 10:
				var a := PI + 0.15 + i * (PI - 0.3) / 9.0
				deco.add(Art.sphere(0.4), [Color("8fe8ff"), Color("ff9fd8")][i % 2], Vector3(cos(a) * 9, 2 + (i % 3) * 1.2, sin(a) * 6 - 1), Vector3.ZERO, Vector3(0.6, 1.4, 0.6), 2.5)
			Art.ambient(self, Vector3(0, 3, -1), Vector3(8, 2, 4), Color("ffb3d1"), 40, "sparkle", 0.22, 3.0)
			Art.light(self, Vector3(3, 3, 1), Color("ff6b8a"), 2.5, 9)
	deco.flush(self)
	Art.light(self, Vector3(-3, 3, 3), Color("ffe6f0"), 1.2, 9)

	target_ring = MeshInstance3D.new()
	target_ring.mesh = Art.torus(0.75, 0.9)
	target_ring.material_override = Art.mat(Color("ff7eb6"), 2.0)
	target_ring.scale = Vector3(1, 0.3, 1)
	target_ring.visible = false
	add_child(target_ring)


func _build_actors() -> void:
	hero = Models.hero(Game.state["style"], Game.robe_color(), Game.hair_color())
	hero.position = HERO_HOME
	hero.rotation_degrees.y = HERO_ROT
	add_child(hero)
	mochi = Models.cat()
	mochi.position = MOCHI_HOME
	mochi.rotation_degrees.y = HERO_ROT
	mochi.scale = Vector3.ONE * 1.1
	add_child(mochi)
	shield = MeshInstance3D.new()
	shield.mesh = Art.sphere(1.0)
	shield.material_override = Art.mat(Color(0.6, 0.85, 1.0, 0.3), 0.8)
	shield.position = Vector3(0, 0.8, 0)
	shield.visible = false
	hero.add_child(shield)

	var n := enemy_ids.size()
	var slots := [[Vector3(2.4, 0, 0.4)], [Vector3(1.9, 0, 1.3), Vector3(3.2, 0, -0.7)],
		[Vector3(1.6, 0, 1.8), Vector3(2.9, 0, 0.1), Vector3(4.0, 0, -1.6)]]
	for i in n:
		var id: String = enemy_ids[i]
		var data: Dictionary = Game.ENEMIES[id]
		var m := Models.critter(id)
		var pos: Vector3 = slots[n - 1][i]
		if id == "monday":
			pos = Vector3(2.6, 0, -0.6)
			m.scale = Vector3.ONE * 0.95
		else:
			m.scale = Vector3.ONE * 1.25
		m.position = pos
		m.rotation_degrees.y = ENEMY_ROT
		add_child(m)
		var e := {"id": id, "data": data, "hp": int(data["hp"]), "max_hp": int(data["hp"]), "model": m,
			"home": pos, "alive": true, "stunned": first_strike, "charging": false, "move": {},
			"intent": "", "weak": String(data["weak"])}
		enemies.append(e)


# =================================================================== UI
func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var root := Control.new()
	root.theme = theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	_msg_panel = PanelContainer.new()
	_msg_panel.add_theme_stylebox_override("panel", UI.flat(Color(1, 0.98, 1, 0.95), 24, Color("c9a6ff"), 3, 10))
	UI.top_center(root, 18).add_child(_msg_panel)
	_msg = UI.label("", 28)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_panel.add_child(_msg)

	var party := PanelContainer.new()
	party.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	party.grow_vertical = Control.GROW_DIRECTION_BEGIN
	party.position = Vector2(20, -20)
	root.add_child(party)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	party.add_child(pv)
	pv.add_child(UI.label("%s   Lv %d" % [Game.state["name"], Game.state["level"]], 28))
	for which in ["hp", "mp"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UI.icon(which, 32))
		var b := UI.bar(Color("ff7eb6") if which == "hp" else Color("7cb4ff"), 240, 22)
		row.add_child(b)
		var t := UI.label("", 24)
		row.add_child(t)
		pv.add_child(row)
		if which == "hp":
			_hp_bar = b
			_hp_text = t
		else:
			_mp_bar = b
			_mp_text = t
	_mochi_label = UI.label("Mochi is ready to help!", 22, Color("8a6aa8"))
	pv.add_child(_mochi_label)

	_cmd_panel = PanelContainer.new()
	_cmd_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_cmd_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_cmd_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cmd_panel.position = Vector2(-20, -20)
	root.add_child(_cmd_panel)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	_cmd_panel.add_child(cv)
	_cmd_title = UI.label("", 22, Color("8a6aa8"))
	cv.add_child(_cmd_title)
	_cmd_box = VBoxContainer.new()
	_cmd_box.add_theme_constant_override("separation", 8)
	cv.add_child(_cmd_box)
	_cmd_panel.visible = false

	for e in enemies:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.flat(Color(1, 1, 1, 0.9), 16, Color("ffc2dd"), 2, 6))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		p.add_child(v)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var nm := UI.label(e["data"]["name"], 20)
		h.add_child(nm)
		var weak_icon := UI.icon("unknown", 26)
		h.add_child(weak_icon)
		v.add_child(h)
		var hb := UI.bar(Color("ffb35c"), 170, 14)
		hb.max_value = e["max_hp"]
		hb.value = e["hp"]
		v.add_child(hb)
		var intent := UI.label("", 19, Color("c0407a"))
		v.add_child(intent)
		root.add_child(p)
		e["panel"] = p
		e["hp_bar"] = hb
		e["intent_label"] = intent
		e["weak_icon"] = weak_icon
		_update_weak_icon(e)

	_big = Label.new()
	_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.add_theme_font_size_override("font_size", 96)
	_big.add_theme_color_override("font_color", Color("fff3c4"))
	_big.add_theme_color_override("font_outline_color", Color("6a3a8a"))
	_big.add_theme_constant_override("outline_size", 24)
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.visible = false
	root.add_child(_big)
	_refresh_party()


func _update_weak_icon(e: Dictionary) -> void:
	var known: bool = Game.state["known_weak"].get(e["id"] + ("_2" if e["id"] == "monday" and _phase2 else ""), false)
	var icon_node: TextureRect = e["weak_icon"]
	icon_node.texture = Art.tex(e["weak"] if known else "unknown")
	icon_node.tooltip_text = "Weak to " + Game.ELEMENT_NAMES.get(e["weak"], "?") if known else "Weakness unknown"


func _place_overlay(e: Dictionary) -> void:
	var p: PanelContainer = e.get("panel")
	if p == null:
		return
	if not e["alive"]:
		p.visible = false
		return
	var m: ModelAnim = e["model"]
	var world_pos := m.global_position + Vector3(0, m.height * m.scale.y + 0.25, 0)
	if cam.is_position_behind(world_pos):
		p.visible = false
		return
	p.visible = true
	var sp := cam.unproject_position(world_pos)
	p.reset_size()
	p.position = sp - Vector2(p.size.x / 2, p.size.y)


func _refresh_party() -> void:
	var s := Game.state
	_hp_bar.max_value = s["max_hp"]
	_hp_bar.value = s["hp"]
	_mp_bar.max_value = s["max_mp"]
	_mp_bar.value = s["mp"]
	_hp_text.text = "%d/%d" % [s["hp"], s["max_hp"]]
	_mp_text.text = "%d/%d" % [s["mp"], s["max_mp"]]


func _say(text: String) -> void:
	_msg.text = text
	_msg_panel.visible = text != ""


func _big_text(text: String, dur := 1.0) -> void:
	_big.text = text
	_big.visible = true
	_big.pivot_offset = _big.size / 2
	_big.scale = Vector2(0.5, 0.5)
	_big.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_big, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur)
	tw.tween_property(_big, "modulate:a", 0.0, 0.3)
	await tw.finished
	_big.visible = false


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


# ============================================================== flow
func _run() -> void:
	# Intro: camera swoop, critters pop in.
	cam.position = _cam_base + Vector3(0, 3, 6)
	var tw := create_tween()
	tw.tween_property(self, "_cam_base", _cam_base, 0.9).from(_cam_base + Vector3(2, 3, 6)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for e in enemies:
		var m: Node3D = e["model"]
		var target_scale: Vector3 = m.scale
		m.scale = Vector3.ONE * 0.01
		var t2 := create_tween()
		t2.tween_property(m, "scale", target_scale, 0.45).set_delay(0.3 + randf() * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_boss:
		Audio.sfx("alarm")
		_say("The Monday Monster rings furiously!")
		await _big_text("BOSS BATTLE!", 1.0)
	else:
		var names := {}
		for e in enemies:
			names[e["data"]["name"]] = names.get(e["data"]["name"], 0) + 1
		var parts: Array = []
		for k in names:
			parts.append(("%d x %s" % [names[k], k]) if names[k] > 1 else k)
		_say("Grumpy critters appear: " + ", ".join(parts) + "!")
		await _wait(1.1)
	if first_strike:
		Audio.sfx("perfect")
		_say("First strike! The critters are dizzy!")
		for e in enemies:
			Art.burst(self, e["model"].position + Vector3(0, 1.5, 0), Color("ffe27a"), 10, "star", 1.5, 0.9, 0.25, Vector3.ZERO)
		await _big_text("First Strike!", 0.6)

	while not _over:
		_round += 1
		_guarding = false
		shield.visible = false
		for e in enemies:
			if e["alive"]:
				_choose_intent(e)
		var cmd: Dictionary = await _player_command()
		if _over:
			return
		match String(cmd["type"]):
			"flee":
				await _flee()
				return
			"attack":
				await _do_attack(cmd["target"])
			"spell":
				await _do_spell(cmd["spell"], cmd.get("target"))
			"item":
				await _do_item(cmd["item"])
			"guard":
				await _do_guard()
		if cmd["type"] != "guard" and cmd["type"] != "item":
			_mochi_buff = 1.0
		if _all_calm():
			await _victory()
			return
		await _mochi_turn()
		if _all_calm():
			await _victory()
			return
		for e in enemies:
			if not e["alive"]:
				continue
			await _enemy_turn(e)
			if Game.state["hp"] <= 0:
				await _defeat()
				return


func _all_calm() -> bool:
	for e in enemies:
		if e["alive"]:
			return false
	return true


func _alive() -> Array:
	return enemies.filter(func(e): return e["alive"])


func _choose_intent(e: Dictionary) -> void:
	var moves: Array = e["data"]["moves"]
	var lbl: Label = e["intent_label"]
	if e["stunned"]:
		e["intent"] = "dizzy"
		lbl.text = "Dizzy"
		return
	if e["charging"]:
		e["intent"] = "big"
		lbl.text = "BIG: %s ~%d" % [e["move"]["n"], _estimate(e, e["move"])]
		return
	var mv: Dictionary
	if e["id"] == "monday":
		if _round % 3 == 0 or (_phase2 and _round % 2 == 0):
			mv = moves[2]
		else:
			mv = moves[randi() % 2]
	else:
		mv = moves[1] if randf() < 0.35 else moves[0]
	e["move"] = mv
	if mv.get("charge", false):
		e["intent"] = "charge"
		lbl.text = "Charging up!"
	else:
		e["intent"] = "attack"
		lbl.text = "%s ~%d" % [mv["n"], _estimate(e, mv)]


func _enemy_atk(e: Dictionary) -> int:
	return int(e["data"]["atk"]) + (3 if _phase2 else 0)


func _estimate(e: Dictionary, mv: Dictionary) -> int:
	return maxi(1, int(round(_enemy_atk(e) * float(mv["p"]) - Game.state["def"] * 0.5)))


# ------------------------------------------------------------ commands
func _player_command() -> Dictionary:
	_say("What will %s do?" % Game.state["name"])
	_show_main_menu()
	var cmd: Dictionary = await _command_chosen
	_cmd_panel.visible = false
	target_ring.visible = false
	return cmd


func _clear_menu(title: String) -> void:
	_cmd_title.text = title
	for c in _cmd_box.get_children():
		c.queue_free()
	_cmd_panel.visible = true


func _menu_button(text: String, cb: Callable, enabled := true, icon_name := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 58)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 27)
	b.disabled = not enabled
	if icon_name != "":
		b.icon = Art.tex(icon_name)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 34)
	b.pressed.connect(func():
		Audio.sfx("ui_confirm")
		cb.call())
	b.focus_entered.connect(func(): Audio.sfx("ui_move", 0.0, -8.0))
	_cmd_box.add_child(b)
	return b


func _focus_first() -> void:
	await get_tree().process_frame
	for c in _cmd_box.get_children():
		if c is Button and not c.disabled:
			c.grab_focus()
			return


func _show_main_menu() -> void:
	_selecting_target = false
	target_ring.visible = false
	_clear_menu("Your turn")
	_menu_button("Attack", func(): _pick_target(func(t): _command_chosen.emit({"type": "attack", "target": t})), true, "star_gold")
	_menu_button("Magic", _show_magic, true, "arcane")
	var has_items := Game.item_count("muffin") + Game.item_count("tea") > 0
	_menu_button("Items", _show_items, has_items, "muffin")
	_menu_button("Guard  (+3 MP)", func(): _command_chosen.emit({"type": "guard"}), true, "mp")
	_menu_button("Run away" if not is_boss else "Can't run!", func(): _command_chosen.emit({"type": "flee"}), not is_boss)
	_focus_first()


func _show_magic() -> void:
	_clear_menu("Magic  (MP %d)" % Game.state["mp"])
	for sid in Game.state["spells"]:
		var sp: Dictionary = Game.SPELLS[sid]
		var ok: bool = Game.state["mp"] >= int(sp["mp"])
		var icon_name: String = sp["element"] if sp["element"] != "none" else "hp"
		var label := "%s   %d MP" % [sp["name"], sp["mp"]]
		_menu_button(label, _choose_spell.bind(String(sid)), ok, icon_name)
	_menu_button("Back", _show_main_menu)
	_focus_first()


func _choose_spell(spell_id: String) -> void:
	if String(Game.SPELLS[spell_id]["target"]) == "one":
		_pick_target(func(t): _command_chosen.emit({"type": "spell", "spell": spell_id, "target": t}))
	else:
		_command_chosen.emit({"type": "spell", "spell": spell_id, "target": null})


func _show_items() -> void:
	_clear_menu("Items")
	for iid in ["muffin", "tea"]:
		var it: Dictionary = Game.ITEMS[iid]
		var n := Game.item_count(iid)
		var item_id: String = iid
		_menu_button("%s  x%d" % [it["name"], n], func(): _command_chosen.emit({"type": "item", "item": item_id}), n > 0, it["icon"])
	_menu_button("Back", _show_main_menu)
	_focus_first()


func _pick_target(cb: Callable) -> void:
	var alive := _alive()
	if alive.size() == 1:
		cb.call(alive[0])
		return
	_clear_menu("Choose a target")
	_selecting_target = true
	for e in alive:
		var enemy: Dictionary = e
		var b := _menu_button(enemy["data"]["name"], func(): cb.call(enemy))
		b.focus_entered.connect(func(): _show_target(enemy))
		b.mouse_entered.connect(func(): _show_target(enemy))
	_menu_button("Back", _show_main_menu)
	_show_target(alive[0])
	_focus_first()


func _show_target(e: Dictionary) -> void:
	target_ring.visible = true
	target_ring.position = e["model"].position + Vector3(0, 0.05, 0)
	var s := 1.6 if e["id"] == "monday" else 1.0
	target_ring.scale = Vector3(s, 0.3, s)


func _unhandled_input(event: InputEvent) -> void:
	if not _cmd_panel.visible:
		return
	if event.is_action_pressed("confirm"):
		var f := get_viewport().gui_get_focus_owner()
		if f is Button and _cmd_box.is_ancestor_of(f) and not f.disabled:
			get_viewport().set_input_as_handled()
			(f as Button).pressed.emit()
	elif event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		Audio.sfx("ui_cancel")
		_show_main_menu()


# ------------------------------------------------------------- actions
func _timing(target: Node3D, caption: String, guard := false, duration := 0.9) -> String:
	var ring := TimingRing.new()
	ring.duration = duration * (1.25 if Game.state["tutorial_timing"] < 3 else 1.0)
	ring.color = Color("7cc8ff") if guard else Color("ff7eb6")
	var tutorial: bool = Game.state["tutorial_timing"] < 3
	ring.caption = caption
	if tutorial:
		ring.caption = ("Tap / press A as the ring meets the circle!" if not guard else "Tap / press A to guard as it hits!")
	var h: float = target.get("height") if target.get("height") != null else 1.2
	ring.center = cam.unproject_position(target.global_position + Vector3(0, h * target.scale.y * 0.5, 0))
	ui.add_child(ring)
	var result: String = await ring.resolved
	Game.state["tutorial_timing"] = int(Game.state["tutorial_timing"]) + 1
	return result


func _rating_text(res: String, at: Vector3) -> void:
	match res:
		"perfect":
			Audio.sfx("perfect")
			Art.float_text(self, at + Vector3(0, 0.6, 0), "Perfect!", Color("ffe27a"), 80, 1.0, 1.0)
		"good":
			Art.float_text(self, at + Vector3(0, 0.6, 0), "Nice!", Color("9fffb8"), 70, 1.0, 0.9)


func _dmg(power: float, elem: String, e: Dictionary, res: String) -> Array:
	var base: float = Game.state["atk"] * power * randf_range(0.9, 1.1) * _mochi_buff
	var weak: bool = elem != "none" and elem == e["weak"]
	if weak:
		base *= 1.6
	match res:
		"perfect": base *= 1.5
		"good": base *= 1.2
	return [maxi(1, int(round(base))), weak]


func _hit(e: Dictionary, amount: int, weak: bool, elem: String) -> void:
	var m: ModelAnim = e["model"]
	var top := m.position + Vector3(0, m.height * m.scale.y * 0.7, 0)
	var col: Color = Game.ELEMENT_COLORS.get(elem, Color.WHITE)
	Art.burst(self, top, col.lightened(0.3), 18, "sparkle", 4.0, 0.6, 0.35)
	Art.float_text(self, top + Vector3(0.3, 0.4, 0), str(amount), Color("fff3f8") if not weak else Color("ffd36b"), 96 if weak else 84)
	Audio.sfx("crit" if weak else "hit", 0.08)
	_shake(m, 0.18)
	if weak:
		var key: String = e["id"] + ("_2" if e["id"] == "monday" and _phase2 else "")
		var was_known: bool = Game.state["known_weak"].get(key, false)
		Game.state["known_weak"][key] = true
		_update_weak_icon(e)
		Art.float_text(self, top + Vector3(-0.4, 1.0, 0), "WEAK!", Color("ff9f4c"), 80, 0.8, 1.2)
		if not e["stunned"]:
			e["stunned"] = true
			(e["intent_label"] as Label).text = "Dizzy"
			Art.burst(self, top + Vector3(0, 0.5, 0), Color("ffe27a"), 8, "star", 1.0, 1.0, 0.25, Vector3.ZERO)
		if not was_known:
			_say("It's weak to %s! It's too dizzy to act next turn." % Game.ELEMENT_NAMES[elem])
	e["hp"] = maxi(0, e["hp"] - amount)
	var hb: ProgressBar = e["hp_bar"]
	create_tween().tween_property(hb, "value", float(e["hp"]), 0.3)
	await _wait(0.45)
	if e["id"] == "monday" and not _phase2 and e["hp"] > 0 and e["hp"] <= e["max_hp"] / 2:
		await _boss_phase2(e)
	if e["hp"] <= 0:
		await _calm(e)


func _boss_phase2(e: Dictionary) -> void:
	_phase2 = true
	e["weak"] = "fire"
	_update_weak_icon(e)
	Audio.sfx("alarm")
	_shake(e["model"], 0.5)
	Art.burst(self, e["model"].position + Vector3(0, 2, 0), Color("ff6b8a"), 30, "sparkle", 5, 1.0, 0.4)
	_say("The Monday Monster overheats! Its weakness changed!")
	await _big_text("It's getting angry!", 0.8)


func _calm(e: Dictionary) -> void:
	e["alive"] = false
	var m: ModelAnim = e["model"]
	m.set_calm(true)
	Audio.sfx("calm")
	Art.burst(self, m.position + Vector3(0, 1.0, 0), Color("ff8fc8"), 22, "heart", 3.0, 1.2, 0.4, Vector3(0, 1.0, 0))
	_say("%s %s" % [e["data"]["name"], e["data"]["calm"]])
	var tw := create_tween()
	tw.tween_property(m, "rotation_degrees:y", m.rotation_degrees.y + 540.0, 0.9)
	tw.parallel().tween_property(m, "position:y", 1.5, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(m, "scale", Vector3.ONE * 0.05, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	m.visible = false
	await _wait(0.4)


func _shake(n: Node3D, amount: float) -> void:
	var base := n.position
	var tw := create_tween()
	for i in 4:
		tw.tween_property(n, "position", base + Vector3(randf_range(-amount, amount), 0, randf_range(-amount, amount)), 0.04)
	tw.tween_property(n, "position", base, 0.05)


func _move(n: Node3D, to: Vector3, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(n, "position", to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if n is ModelAnim:
		(n as ModelAnim).moving = true
	await tw.finished
	if n is ModelAnim:
		(n as ModelAnim).moving = false


func _swing() -> void:
	var arm: Node3D = hero.find_child("ArmR", true, false)
	if arm == null:
		return
	Audio.sfx("swing", 0.1)
	var tw := create_tween()
	tw.tween_property(arm, "rotation:x", -2.4, 0.1)
	tw.tween_property(arm, "rotation:x", 0.6, 0.12)
	tw.tween_property(arm, "rotation:x", 0.0, 0.15)


func _do_attack(e: Dictionary) -> void:
	_say("Wand Bonk!")
	var m: ModelAnim = e["model"]
	var front := m.position + (HERO_HOME - m.position).normalized() * (1.3 if e["id"] != "monday" else 2.2)
	await _move(hero, front, 0.32)
	var res := await _timing(m, "Bonk!")
	_swing()
	_rating_text(res, m.position + Vector3(0, m.height * m.scale.y, 0))
	var d := _dmg(1.0, "none", e, res)
	if res == "miss":
		Audio.sfx("miss")
	await _hit(e, d[0], d[1], "none")
	await _move(hero, HERO_HOME, 0.3)
	hero.rotation_degrees.y = HERO_ROT


func _cast_pose() -> void:
	var arm: Node3D = hero.find_child("ArmR", true, false)
	var tw := create_tween()
	tw.tween_property(hero, "position:y", 0.35, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(hero, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if arm:
		var t2 := create_tween()
		t2.tween_property(arm, "rotation:x", -2.6, 0.15)
		t2.tween_interval(0.5)
		t2.tween_property(arm, "rotation:x", 0.0, 0.2)
	Art.burst(self, hero.position + Vector3(0.4, 1.6, 0.3), Color("fff3b0"), 14, "sparkle", 2.0, 0.7, 0.25)


func _spell_fx(elem: String, at: Vector3) -> void:
	match elem:
		"fire":
			Audio.sfx("fire")
			Art.burst(self, at, Color("ff8a4c"), 40, "soft", 5.0, 0.9, 0.55, Vector3(0, 3, 0))
			Art.burst(self, at, Color("ffd36b"), 20, "sparkle", 3.0, 0.8, 0.35)
			var l := Art.light(self, at + Vector3(0, 0.5, 0), Color("ff8a4c"), 4.0, 6.0)
			create_tween().tween_property(l, "light_energy", 0.0, 0.6).finished.connect(l.queue_free)
		"ice":
			Audio.sfx("ice")
			Art.burst(self, at, Color("9fe0ff"), 30, "sparkle", 4.0, 1.0, 0.4, Vector3(0, -2, 0))
			for i in 6:
				var a := i * TAU / 6
				var shardm := Art.part(self, Art.cyl(0.0, 0.18, 0.9), Color(0.75, 0.93, 1.0, 0.8), at + Vector3(cos(a) * 0.5, -0.2, sin(a) * 0.5), Vector3(cos(a) * 25, 0, sin(a) * 25), Vector3.ONE * 0.1, 1.5, false)
				var tw := create_tween()
				tw.tween_property(shardm, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_interval(0.4)
				tw.tween_property(shardm, "scale", Vector3.ONE * 0.01, 0.2)
				tw.tween_callback(shardm.queue_free)
		"arcane":
			Audio.sfx("sparkle")
			Art.burst(self, at, Color("ff9fd8"), 36, "star", 4.5, 0.9, 0.35)
			Art.burst(self, at, Color("fff3b0"), 16, "sparkle", 2.5, 0.8, 0.3)
	await _wait(0.35)


func _do_spell(sid: String, target) -> void:
	var sp: Dictionary = Game.SPELLS[sid]
	Game.state["mp"] -= int(sp["mp"])
	_refresh_party()
	_say(sp["name"] + "!")
	_cast_pose()
	await _wait(0.35)
	match String(sp["target"]):
		"self":
			var res := await _timing(hero, "Heal!")
			var amount := int(Game.state["max_hp"] * 0.45) + 10
			if res == "perfect":
				amount = int(amount * 1.4)
			elif res == "good":
				amount = int(amount * 1.2)
			_rating_text(res, hero.position + Vector3(0, 1.6, 0))
			Game.heal(amount)
			Audio.sfx("heal")
			Art.burst(self, hero.position + Vector3(0, 0.3, 0), Color("9fffb8"), 26, "heart", 2.5, 1.2, 0.3, Vector3(0, 2, 0))
			Art.float_text(self, hero.position + Vector3(0, 1.8, 0), "+%d" % amount, Color("9fffb8"), 84)
			_refresh_party()
			await _wait(0.6)
		"one":
			var e: Dictionary = target
			var m: ModelAnim = e["model"]
			var res := await _timing(m, sp["name"])
			var at := m.position + Vector3(0, m.height * m.scale.y * 0.5, 0)
			_rating_text(res, at + Vector3(0, 0.8, 0))
			await _spell_fx(sp["element"], at)
			var d := _dmg(float(sp["power"]), sp["element"], e, res)
			await _hit(e, d[0], d[1], sp["element"])
		"all":
			var alive := _alive()
			var res := await _timing(alive[0]["model"], "Starfall!")
			Audio.sfx("starfall")
			for e in alive:
				var m: ModelAnim = e["model"]
				var star := Art.part(self, Art.sphere(0.35), Color("fff3b0"), m.position + Vector3(0, 7, 0), Vector3.ZERO, Vector3.ONE, 3.0, false)
				var tw := create_tween()
				tw.tween_property(star, "position:y", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.tween_callback(star.queue_free)
			await _wait(0.35)
			for e in alive:
				var m: ModelAnim = e["model"]
				Art.burst(self, m.position + Vector3(0, 1, 0), Color("ffe27a"), 24, "star", 4.0, 0.9, 0.35)
				var d := _dmg(float(sp["power"]), sp["element"], e, res)
				_hit(e, d[0], d[1], sp["element"])
			_rating_text(res, Vector3(2.5, 3, 0))
			await _wait(1.2)
	_refresh_party()


func _do_item(iid: String) -> void:
	Game.state["items"][iid] = Game.item_count(iid) - 1
	var it: Dictionary = Game.ITEMS[iid]
	_say("You use a %s!" % it["name"])
	if iid == "muffin":
		Game.heal(40)
		Audio.sfx("heal")
		Art.float_text(self, hero.position + Vector3(0, 1.8, 0), "+40 HP", Color("9fffb8"), 80)
		Art.burst(self, hero.position + Vector3(0, 0.5, 0), Color("ffb347"), 16, "heart", 2.0, 1.0, 0.3, Vector3(0, 2, 0))
	else:
		Game.heal(0, 12)
		Audio.sfx("buff")
		Art.float_text(self, hero.position + Vector3(0, 1.8, 0), "+12 MP", Color("9fd0ff"), 80)
		Art.burst(self, hero.position + Vector3(0, 0.5, 0), Color("9fd0ff"), 16, "star", 2.0, 1.0, 0.3, Vector3(0, 2, 0))
	_refresh_party()
	await _wait(0.9)


func _do_guard() -> void:
	_guarding = true
	Game.heal(0, 3)
	_refresh_party()
	shield.visible = true
	shield.scale = Vector3.ONE * 0.2
	create_tween().tween_property(shield, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.sfx("guard")
	_say("You raise a sparkly shield! (+3 MP)")
	await _wait(0.8)


func _flee() -> void:
	_say("You tiptoe away very, very quietly...")
	Audio.sfx("swing")
	hero.rotation_degrees.y = -120
	mochi.rotation_degrees.y = -120
	var tw := create_tween().set_parallel(true)
	tw.tween_property(hero, "position", HERO_HOME + Vector3(-6, 0, 3), 0.7)
	tw.tween_property(mochi, "position", MOCHI_HOME + Vector3(-6, 0, 3), 0.7)
	hero.moving = true
	mochi.moving = true
	await tw.finished
	_end("flee")


# --------------------------------------------------------- mochi & foes
func _mochi_turn() -> void:
	var alive := _alive()
	if alive.is_empty():
		return
	var tw := create_tween()
	tw.tween_property(mochi, "position:y", 0.5, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mochi, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	var hp_ratio: float = float(Game.state["hp"]) / float(Game.state["max_hp"])
	var r := randf()
	if hp_ratio < 0.4 and r < 0.7:
		var amount := 10 + int(Game.state["level"]) * 3
		Game.heal(amount)
		Audio.sfx("purr")
		_say("Mochi purrs soothingly. You feel better!")
		_mochi_label.text = "Mochi purred: +%d HP" % amount
		Art.burst(self, hero.position + Vector3(0, 0.6, 0), Color("ff9fc4"), 12, "heart", 1.5, 1.2, 0.3, Vector3(0, 1.5, 0))
		Art.float_text(self, hero.position + Vector3(0, 1.8, 0), "+%d" % amount, Color("9fffb8"), 72)
	elif r < 0.55:
		var e: Dictionary = alive.pick_random()
		var m: ModelAnim = e["model"]
		Audio.sfx("meow")
		_say("Mochi pounces on %s!" % e["data"]["name"])
		await _move(mochi, m.position + (MOCHI_HOME - m.position).normalized() * 1.0, 0.25)
		var dmg := 3 + int(Game.state["level"]) * 2
		_mochi_label.text = "Mochi scratched for %d" % dmg
		await _hit(e, dmg, false, "none")
		await _move(mochi, MOCHI_HOME, 0.25)
		mochi.rotation_degrees.y = HERO_ROT
	elif r < 0.85:
		_mochi_buff = 1.25
		Game.heal(0, 2)
		Audio.sfx("buff")
		_say("Mochi cheers you on! Your next attack is stronger. (+2 MP)")
		_mochi_label.text = "Mochi is cheering! Next hit +25%"
		Art.burst(self, mochi.position + Vector3(0, 0.8, 0), Color("ffe27a"), 12, "star", 1.5, 1.0, 0.25, Vector3(0, 1, 0))
	else:
		_say("Mochi is napping. Zzz...")
		_mochi_label.text = "Mochi is napping..."
		Art.float_text(self, mochi.position + Vector3(0, 1.0, 0), "Zzz", Color("c9b6ff"), 60, 0.8, 1.2)
	_refresh_party()
	await _wait(0.8)


func _enemy_turn(e: Dictionary) -> void:
	var m: ModelAnim = e["model"]
	var ename: String = e["data"]["name"]
	if e["stunned"]:
		e["stunned"] = false
		_say("%s is too dizzy to move!" % ename)
		Art.burst(self, m.position + Vector3(0, m.height * m.scale.y + 0.2, 0), Color("ffe27a"), 8, "star", 1.0, 0.8, 0.25, Vector3.ZERO)
		await _wait(0.9)
		return
	var mv: Dictionary = e["move"]
	if mv.get("charge", false) and not e["charging"]:
		e["charging"] = true
		_say("%s is charging up %s!" % [ename, mv["n"]])
		if e["id"] == "monday":
			Audio.sfx("alarm")
		else:
			Audio.sfx("buff", 0.0, -2.0)
		Art.burst(self, m.position + Vector3(0, 1, 0), Color("ff6b8a"), 20, "soft", 1.5, 1.0, 0.4, Vector3(0, 2, 0))
		_shake(m, 0.08)
		await _wait(1.0)
		return
	e["charging"] = false
	_say("%s uses %s!" % [ename, mv["n"]])
	# Lunge towards the hero while the guard ring shrinks.
	var dur := 0.95 if not mv.get("charge", false) else 1.1
	var lunge := m.position + (HERO_HOME - m.position).normalized() * (m.position.distance_to(HERO_HOME) - (1.3 if e["id"] != "monday" else 2.4))
	var tw := create_tween()
	tw.tween_property(m, "position", lunge, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	var res := await _timing(hero, "Guard!", true, dur)
	if tw.is_running():
		await tw.finished
	var dmg := int(round(_enemy_atk(e) * float(mv["p"]) * randf_range(0.9, 1.1) - Game.state["def"] * 0.5))
	dmg = maxi(1, dmg)
	if _guarding:
		dmg = int(ceil(dmg * 0.5))
	var drain := int(mv.get("drain", 0))
	match res:
		"perfect":
			dmg = 0
			drain = 0
			Audio.sfx("guard")
			Game.heal(0, 2)
			Art.float_text(self, hero.position + Vector3(0, 2.2, 0), "Perfect Guard!", Color("ffe27a"), 72)
			Art.burst(self, hero.position + Vector3(0.5, 1, 0), Color("9fe0ff"), 20, "sparkle", 3.0, 0.7, 0.3)
		"good":
			dmg = int(ceil(dmg * 0.5))
			Audio.sfx("guard", 0.05)
			Art.float_text(self, hero.position + Vector3(0, 2.2, 0), "Blocked!", Color("9fe0ff"), 70)
	if dmg > 0:
		Audio.sfx("hurt", 0.08)
		Game.heal(-dmg)
		_shake(hero, 0.15)
		Art.float_text(self, hero.position + Vector3(0.2, 1.7, 0), "-%d" % dmg, Color("ff8fa3"), 84)
		Art.burst(self, hero.position + Vector3(0, 1, 0), Color("ffffff"), 12, "sparkle", 3.0, 0.5, 0.3)
	if drain > 0:
		Game.heal(0, -drain)
		Art.float_text(self, hero.position + Vector3(-0.4, 2.3, 0), "-%d MP" % drain, Color("9fd0ff"), 64)
	if mv["n"] == "Sandwich Heist" and res != "perfect" and Game.state["coins"] > 0:
		Game.add_coins(-2)
		_say("The Pigeon of Doom stole 2 coins' worth of sandwich!")
	_refresh_party()
	var back := create_tween()
	back.tween_property(m, "position", e["home"], 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished
	await _wait(0.25)


# ------------------------------------------------------------- endings
func _victory() -> void:
	_cmd_panel.visible = false
	Audio.play_music("victory", 0.2)
	var xp := 0
	var coins := 0
	var names: Array = []
	for e in enemies:
		xp += int(e["data"]["xp"])
		coins += int(e["data"]["coins"])
		names.append(e["data"]["name"])
		var fid: String = e["id"]
		Game.state["friends"][fid] = int(Game.state["friends"].get(fid, 0)) + 1
	hero.rotation_degrees.y = 0
	var jump := create_tween().set_loops(3)
	jump.tween_property(hero, "position:y", 0.5, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jump.tween_property(hero, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Art.burst(self, hero.position + Vector3(0, 2, 0), Color("ffe27a"), 30, "star", 4, 1.2, 0.35)
	_say("")
	await _big_text("Victory!", 0.7)
	var levels := Game.add_xp(xp)
	Game.add_coins(coins)
	var drop := ""
	if randf() < 0.3 and not is_boss:
		var it: String = ["muffin", "tea"].pick_random()
		Game.add_item(it)
		drop = Game.ITEMS[it]["name"]
	_refresh_party()
	await _show_results(names, xp, coins, levels, drop)
	_end("win")


func _show_results(names: Array, xp: int, coins: int, levels: int, drop: String) -> void:
	_results = PanelContainer.new()
	_results.theme = theme
	_results.add_theme_stylebox_override("panel", UI.flat(Color(1, 0.98, 1, 0.97), 28, Color("ff7eb6"), 4, 26))
	UI.full_center(ui).add_child(_results)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_results.add_child(v)
	var t := UI.label("Everyone cheered up!", 38, Color("e0609f"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var friends := {}
	for n in names:
		friends[n] = friends.get(n, 0) + 1
	for n in friends:
		var l := UI.label(("%s  x%d" % [n, friends[n]]) if friends[n] > 1 else n, 26)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(UI.icon("star_gold", 34))
	row.add_child(UI.label("+%d XP" % xp, 30))
	row.add_child(UI.icon("coin", 34))
	row.add_child(UI.label("+%d" % coins, 30))
	v.add_child(row)
	if drop != "":
		var dl := UI.label("Found: %s!" % drop, 26, Color("8a6aa8"))
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(dl)
	if levels > 0:
		Audio.sfx("level_up")
		var lv := UI.label("LEVEL UP!  You are now Lv %d" % Game.state["level"], 32, Color("ff9f4c"))
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lv)
		var sub := UI.label("HP +10   MP +3   Power +2   Fully healed!", 22, Color("8a6aa8"))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sub)
		Art.burst(self, hero.position + Vector3(0, 1, 0), Color("ffe27a"), 40, "star", 5, 1.4, 0.4, Vector3(0, 1, 0))
	var b := Button.new()
	b.text = "Continue"
	b.custom_minimum_size = Vector2(260, 60)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(func():
		Audio.sfx("ui_confirm")
		_results_closed.emit())
	var center := CenterContainer.new()
	center.add_child(b)
	v.add_child(center)
	await get_tree().process_frame
	b.grab_focus()
	await _results_closed


func _defeat() -> void:
	_cmd_panel.visible = false
	Audio.sfx("hurt")
	_say("You feel sooo sleepy...")
	var tw := create_tween()
	tw.tween_property(hero, "rotation_degrees:z", 80.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Art.float_text(self, hero.position + Vector3(0, 1.2, 0), "Zzz", Color("c9b6ff"), 80, 1.5, 2.0)
	await _wait(2.0)
	_end("lose")


func _end(result: String) -> void:
	if _over:
		return
	_over = true
	finished.emit(result)
