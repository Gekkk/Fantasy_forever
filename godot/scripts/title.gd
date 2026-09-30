class_name TitleScreen
extends Control
## Title logo plus a little character creator. The hero preview is the
## live 3D model standing in front of the house behind this panel.

signal start_new(hero_name: String, style: String, robe: int, hair: int)
signal continue_game
signal preview_changed(style: String, robe: int, hair: int)

var _style := "witch"
var _robe := 0
var _hair := 0
var _name: LineEdit
var _continue: Button
var _start: Button
var _style_buttons := {}
var _robe_buttons: Array = []
var _hair_buttons: Array = []
var _logo: Label
var _t := 0.0
var _confirm_new := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.make_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_logo = Label.new()
	_logo.text = "Fantasy Forever"
	_logo.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_logo.position = Vector2(40, 36)
	_logo.add_theme_font_size_override("font_size", 92)
	_logo.add_theme_color_override("font_color", Color("fff3f8"))
	_logo.add_theme_color_override("font_outline_color", Color("b0509a"))
	_logo.add_theme_constant_override("outline_size", 26)
	_logo.add_theme_color_override("font_shadow_color", Color(0.3, 0.1, 0.4, 0.5))
	_logo.add_theme_constant_override("shadow_offset_y", 8)
	add_child(_logo)
	var sub := UI.label("A cozy adventure in Moonbrook City", 30, Color("fff3c4"))
	sub.add_theme_color_override("font_outline_color", Color("6a3a8a"))
	sub.add_theme_constant_override("outline_size", 12)
	sub.position = Vector2(52, 150)
	add_child(sub)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.position.x = -40
	panel.add_theme_stylebox_override("panel", UI.flat(Color(1, 0.98, 1, 0.94), 30, Color("ffc2dd"), 4, 22))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var h := UI.label("Create your hero", 34, Color("e0609f"))
	v.add_child(h)

	v.add_child(UI.label("Style", 24, Color("8a6aa8")))
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 8)
	v.add_child(sr)
	for st in Game.STYLES:
		var b := Button.new()
		b.text = Game.STYLE_NAMES[st]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(130, 54)
		b.pressed.connect(_set_style.bind(st))
		sr.add_child(b)
		_style_buttons[st] = b

	v.add_child(UI.label("Robe color", 24, Color("8a6aa8")))
	var rr := HBoxContainer.new()
	rr.add_theme_constant_override("separation", 8)
	v.add_child(rr)
	for i in Game.ROBE_COLORS.size():
		var b := _swatch(Game.ROBE_COLORS[i])
		b.pressed.connect(_set_robe.bind(i))
		rr.add_child(b)
		_robe_buttons.append(b)

	v.add_child(UI.label("Hair color", 24, Color("8a6aa8")))
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	v.add_child(hr)
	for i in Game.HAIR_COLORS.size():
		var b := _swatch(Game.HAIR_COLORS[i])
		b.pressed.connect(_set_hair.bind(i))
		hr.add_child(b)
		_hair_buttons.append(b)

	v.add_child(UI.label("Name", 24, Color("8a6aa8")))
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 8)
	v.add_child(nr)
	_name = LineEdit.new()
	_name.max_length = 12
	_name.custom_minimum_size = Vector2(0, 54)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.add_theme_font_size_override("font_size", 28)
	_name.placeholder_text = "Your name"
	_name.select_all_on_focus = true
	_name.text_submitted.connect(func(_t): _on_start())
	nr.add_child(_name)
	var clear := Button.new()
	clear.text = "✕"
	clear.custom_minimum_size = Vector2(54, 54)
	clear.focus_mode = Control.FOCUS_NONE
	clear.pressed.connect(func():
		_name.text = ""
		if _use_native_prompt():
			_ask_name())
	nr.add_child(clear)
	if _use_native_prompt():
		# Phone browsers' keyboards can't delete text in the game's own box
		# (Backspace gets lost), so ask with the browser's native text prompt.
		_name.editable = false
		_name.gui_input.connect(func(e: InputEvent):
			if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
				_ask_name())

	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 10)
	v.add_child(br)
	_start = Button.new()
	_start.text = "New Adventure"
	_start.custom_minimum_size = Vector2(230, 64)
	_start.add_theme_font_size_override("font_size", 28)
	_start.add_theme_stylebox_override("normal", UI.flat(Color("ff8fc0"), 18, Color("e0609f"), 3, 10))
	_start.add_theme_stylebox_override("hover", UI.flat(Color("ff7eb6"), 18, Color("c0407a"), 3, 10))
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		_start.add_theme_color_override(c, Color.WHITE)
	_start.pressed.connect(_on_start)
	br.add_child(_start)
	_continue = Button.new()
	_continue.text = "Continue"
	_continue.custom_minimum_size = Vector2(180, 64)
	_continue.add_theme_font_size_override("font_size", 28)
	_continue.pressed.connect(func():
		Audio.sfx("ui_confirm")
		continue_game.emit())
	br.add_child(_continue)


func _swatch(c: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(52, 52)
	b.toggle_mode = true
	b.add_theme_stylebox_override("normal", UI.flat(c, 26, Color.WHITE, 4, 0))
	b.add_theme_stylebox_override("hover", UI.flat(c, 26, Color("ffc2dd"), 4, 0))
	b.add_theme_stylebox_override("pressed", UI.flat(c, 26, Color("b066e0"), 6, 0))
	b.add_theme_stylebox_override("focus", UI.flat(Color(0, 0, 0, 0), 26, Color("b066e0"), 3, 0))
	return b


func refresh(has_save: bool) -> void:
	_style = Game.state.get("style", "witch")
	_robe = int(Game.state.get("robe", 0))
	_hair = int(Game.state.get("hair", 0))
	_name.text = Game.state.get("name", Game.DEFAULT_NAME)
	_continue.visible = has_save
	_confirm_new = false
	_start.text = "New Adventure"
	_sync()
	(_continue if has_save else _start).grab_focus.call_deferred()


func _sync() -> void:
	for st in _style_buttons:
		_style_buttons[st].button_pressed = st == _style
	for i in _robe_buttons.size():
		_robe_buttons[i].button_pressed = i == _robe
	for i in _hair_buttons.size():
		_hair_buttons[i].button_pressed = i == _hair
	preview_changed.emit(_style, _robe, _hair)


func _set_style(s: String) -> void:
	_style = s
	Audio.sfx("sparkle", 0.1, -6.0)
	_sync()


func _set_robe(i: int) -> void:
	_robe = i
	Audio.sfx("ui_move")
	_sync()


func _set_hair(i: int) -> void:
	_hair = i
	Audio.sfx("ui_move")
	_sync()


func _use_native_prompt() -> bool:
	return OS.has_feature("web") and DisplayServer.is_touchscreen_available()


func _ask_name() -> void:
	var cur := _name.text.replace("\\", "").replace("'", "\\'")
	var r = JavaScriptBridge.eval("(function(){var n = window.prompt('What is your name?', '%s'); return n === null ? '' : n;})()" % cur)
	var n := String(r if r != null else "").strip_edges().left(12)
	if n != "":
		_name.text = n
	elif _name.text == "":
		_name.text = Game.DEFAULT_NAME


func _on_start() -> void:
	if _continue.visible and not _confirm_new:
		# Two-step confirm so an existing save isn't replaced by accident.
		_confirm_new = true
		_start.text = "Tap again: start over"
		Audio.sfx("ui_cancel")
		return
	Audio.sfx("ui_confirm")
	var n := _name.text.strip_edges()
	if n == "":
		n = Game.DEFAULT_NAME
	start_new.emit(n, _style, _robe, _hair)


func _process(delta: float) -> void:
	_t += delta
	_logo.rotation = sin(_t * 1.2) * 0.012
	_logo.position.y = 36 + sin(_t * 1.6) * 5.0
