class_name UI
extends CanvasLayer
## HUD, dialog box, choices, toasts, banners and screen fades.

signal dialog_advanced
signal choice_made(index: int)

const PINK := Color("ff7eb6")
const INK := Color("4a3560")
const CREAM := Color("fffaf3")

var theme: Theme
var hud: Control
var _name_label: Label
var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _hp_text: Label
var _mp_text: Label
var _coins: Label
var _muffins: Label
var _shards: Label
var _objective: Label
var _objective_panel: PanelContainer
var menu_button: Button

var prompt: PanelContainer
var _prompt_label: Label

var dialog: Control
var _dlg_panel: PanelContainer
var _dlg_name: Label
var _dlg_name_panel: PanelContainer
var _dlg_text: RichTextLabel
var _dlg_next: Label
var _choices: VBoxContainer
var _typing := false
var _chars := 0.0
var _options: Array = []
var _dialog_open := false

var _toast_box: VBoxContainer
var _banner: Label
var _fade: ColorRect
var _hint: Label
var _rotate_hint: Label


func _ready() -> void:
	layer = 10
	theme = make_theme()
	_build_hud()
	_build_prompt()
	_build_dialog()
	var tc := top_center(self, 150)
	_toast_box = VBoxContainer.new()
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_theme_constant_override("separation", 8)
	tc.add_child(_toast_box)
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 84)
	_banner.add_theme_color_override("font_color", Color("fff3c4"))
	_banner.add_theme_color_override("font_outline_color", Color("6a3a8a"))
	_banner.add_theme_constant_override("outline_size", 22)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	_banner.theme = theme
	add_child(_banner)
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position.y -= 200
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 30)
	_hint.add_theme_color_override("font_color", Color.WHITE)
	_hint.add_theme_color_override("font_outline_color", Color("6a3a8a"))
	_hint.add_theme_constant_override("outline_size", 14)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.theme = theme
	add_child(_hint)
	_fade = ColorRect.new()
	_fade.color = Color("24183a")
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)
	_rotate_hint = Label.new()
	_rotate_hint.text = "Turn your phone sideways\nfor the best view!"
	_rotate_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotate_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotate_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotate_hint.add_theme_font_size_override("font_size", 64)
	_rotate_hint.add_theme_color_override("font_color", Color.WHITE)
	_rotate_hint.add_theme_color_override("font_outline_color", Color("6a3a8a"))
	_rotate_hint.add_theme_constant_override("outline_size", 20)
	_rotate_hint.theme = theme
	_rotate_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotate_hint.visible = false
	add_child(_rotate_hint)
	Game.stats_changed.connect(refresh)


# ----------------------------------------------------------------- theme
static func flat(bg: Color, radius := 18, border := Color.TRANSPARENT, border_w := 0, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = pad + 4
	s.content_margin_right = pad + 4
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	s.shadow_color = Color(0.25, 0.1, 0.35, 0.25)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	s.anti_aliasing = true
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Art.get_font()
	t.default_font_size = 26
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", flat(Color(1, 0.98, 0.99, 0.94), 20, Color("ffc2dd"), 3))
	t.set_stylebox("panel", "Panel", flat(Color(1, 0.98, 0.99, 0.94), 20, Color("ffc2dd"), 3))
	var btn := flat(Color("fff4fa"), 16, Color("f3cfe4"), 3, 10)
	var hov := flat(Color("ffe3f0"), 16, PINK, 3, 10)
	var prs := flat(Color("ffd0e6"), 16, Color("e0609f"), 3, 10)
	var dis := flat(Color(0.95, 0.93, 0.96, 0.7), 16, Color("e6dff0"), 3, 10)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hov)
	t.set_stylebox("pressed", "Button", prs)
	t.set_stylebox("focus", "Button", flat(Color(0, 0, 0, 0), 16, Color("b066e0"), 4, 10))
	t.set_stylebox("disabled", "Button", dis)
	t.set_stylebox("hover_pressed", "Button", prs)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.6))
	t.set_stylebox("normal", "LineEdit", flat(Color.WHITE, 14, Color("f3cfe4"), 3, 8))
	t.set_stylebox("focus", "LineEdit", flat(Color.WHITE, 14, PINK, 3, 8))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", PINK)
	t.set_stylebox("background", "ProgressBar", flat(Color("efe6f5"), 10, Color.TRANSPARENT, 0, 0))
	t.set_stylebox("fill", "ProgressBar", flat(PINK, 10, Color.TRANSPARENT, 0, 0))
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font_size("normal_font_size", "RichTextLabel", 28)
	t.set_stylebox("slider", "HSlider", flat(Color("efe6f5"), 8, Color.TRANSPARENT, 0, 4))
	t.set_stylebox("grabber_area", "HSlider", flat(PINK, 8, Color.TRANSPARENT, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(PINK, 8, Color.TRANSPARENT, 0, 4))
	return t


## A full-width strip that centers its child horizontally (anchored top or bottom).
static func top_center(parent: Node, y: float, bottom := false) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bottom:
		c.offset_top = -y
		c.offset_bottom = -y
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		c.offset_top = y
		c.offset_bottom = y
	parent.add_child(c)
	return c


static func full_center(parent: Node) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


static func bar(color: Color, w := 220.0, h := 20.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	b.add_theme_stylebox_override("fill", flat(color, 10, Color.TRANSPARENT, 0, 0))
	return b


static func icon(name: String, size := 34) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Art.tex(name)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func label(text: String, size := 26, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# ------------------------------------------------------------------- HUD
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = theme
	add_child(hud)

	var left := PanelContainer.new()
	left.position = Vector2(16, 14)
	hud.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 4)
	left.add_child(lv)
	_name_label = label("Hero", 26)
	lv.add_child(_name_label)
	for which in ["hp", "mp"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(icon(which, 28))
		var b := bar(Color("ff7eb6") if which == "hp" else Color("7cb4ff"), 190, 18)
		row.add_child(b)
		var t := label("", 20)
		t.custom_minimum_size.x = 86
		row.add_child(t)
		lv.add_child(row)
		if which == "hp":
			_hp_bar = b
			_hp_text = t
		else:
			_mp_bar = b
			_mp_text = t

	var right := PanelContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.position = Vector2(-16, 14)
	hud.add_child(right)
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 10)
	right.add_child(rh)
	for pair in [["coin", "_coins"], ["muffin", "_muffins"], ["shard", "_shards"]]:
		rh.add_child(icon(pair[0], 32))
		var l := label("0", 24)
		rh.add_child(l)
		set(pair[1], l)
	menu_button = Button.new()
	menu_button.text = "Menu"
	menu_button.focus_mode = Control.FOCUS_NONE
	menu_button.add_theme_font_size_override("font_size", 22)
	rh.add_child(menu_button)

	_objective_panel = PanelContainer.new()
	_objective_panel.add_theme_stylebox_override("panel", flat(Color(1, 0.97, 0.85, 0.92), 20, Color("ffd76b"), 3, 8))
	top_center(hud, 16).add_child(_objective_panel)
	var oh := HBoxContainer.new()
	oh.add_theme_constant_override("separation", 8)
	_objective_panel.add_child(oh)
	oh.add_child(icon("star_gold", 28))
	_objective = label("", 22)
	oh.add_child(_objective)


func refresh() -> void:
	if Game.state.is_empty():
		return
	var s := Game.state
	_name_label.text = "%s   Lv %d" % [s["name"], s["level"]]
	_hp_bar.max_value = s["max_hp"]
	_hp_bar.value = s["hp"]
	_mp_bar.max_value = s["max_mp"]
	_mp_bar.value = s["mp"]
	_hp_text.text = "%d/%d" % [s["hp"], s["max_hp"]]
	_mp_text.text = "%d/%d" % [s["mp"], s["max_mp"]]
	_coins.text = str(s["coins"])
	_muffins.text = str(Game.item_count("muffin"))
	_shards.text = "%d/%d" % [s["shards"].size(), Game.SHARD_TOTAL]
	_objective.text = Game.objective()


func show_hud(v: bool) -> void:
	hud.visible = v
	if not v:
		prompt.visible = false


# ---------------------------------------------------------------- prompt
func _build_prompt() -> void:
	prompt = PanelContainer.new()
	prompt.theme = theme
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.add_theme_stylebox_override("panel", flat(Color(1, 1, 1, 0.92), 30, PINK, 3, 8))
	_prompt_label = label("", 24)
	prompt.add_child(_prompt_label)
	prompt.visible = false
	top_center(self, 60, true).add_child(prompt)


func show_prompt(text: String) -> void:
	if text == "":
		prompt.visible = false
		return
	var key := "A" if DisplayServer.is_touchscreen_available() else "Space"
	_prompt_label.text = "%s  [%s]" % [text, key]
	prompt.visible = true


# ---------------------------------------------------------------- dialog
func _build_dialog() -> void:
	dialog = Control.new()
	dialog.theme = theme
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.visible = false
	add_child(dialog)

	# Bottom strip: choices, then the speaker's name tag, then the text box.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var touch := DisplayServer.is_touchscreen_available()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 300 if touch else 40)
	margin.add_theme_constant_override("margin_bottom", 20)
	dialog.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	_choices = VBoxContainer.new()
	_choices.size_flags_horizontal = Control.SIZE_SHRINK_END
	_choices.add_theme_constant_override("separation", 8)
	col.add_child(_choices)

	_dlg_name_panel = PanelContainer.new()
	_dlg_name_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_dlg_name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_dlg_name_panel)
	_dlg_name = label("", 28, Color.WHITE)
	_dlg_name_panel.add_child(_dlg_name)

	_dlg_panel = PanelContainer.new()
	_dlg_panel.custom_minimum_size = Vector2(0, 150)
	_dlg_panel.add_theme_stylebox_override("panel", flat(Color(1, 0.985, 0.995, 0.97), 26, PINK, 4, 20))
	_dlg_panel.gui_input.connect(_on_dialog_gui_input)
	col.add_child(_dlg_panel)
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg_panel.add_child(inner)
	_dlg_text = RichTextLabel.new()
	_dlg_text.bbcode_enabled = true
	_dlg_text.fit_content = true
	_dlg_text.scroll_active = false
	_dlg_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dlg_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg_text.add_theme_font_size_override("normal_font_size", 32)
	_dlg_text.add_theme_font_size_override("bold_font_size", 32)
	_dlg_text.add_theme_constant_override("line_separation", 6)
	inner.add_child(_dlg_text)
	_dlg_next = label("tap to continue  v", 22, PINK)
	_dlg_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inner.add_child(_dlg_next)


func is_dialog_open() -> bool:
	return _dialog_open


## Shows a line of dialog and waits until the player advances it.
func say(speaker: String, text: String, color := PINK) -> void:
	_open(speaker, text, color, [])
	await dialog_advanced


## Shows a question with choices and returns the chosen index.
func ask(speaker: String, text: String, options: Array, color := PINK, default := 0) -> int:
	_open(speaker, text, color, options)
	_choice_default = default
	var idx: int = await choice_made
	return idx


var _choice_default := 0


func _open(speaker: String, text: String, color: Color, options: Array) -> void:
	_dialog_open = true
	dialog.visible = true
	_options = options
	_dlg_name_panel.visible = speaker != ""
	_dlg_name.text = speaker
	_dlg_name_panel.add_theme_stylebox_override("panel", flat(color, 18, Color.WHITE, 3, 6))
	_dlg_text.text = text.replace("{name}", str(Game.state.get("name", "friend")))
	_dlg_text.visible_characters = 0
	_chars = 0.0
	_typing = true
	_dlg_next.visible = true
	_dlg_next.text = ""
	for c in _choices.get_children():
		c.queue_free()


func _process(delta: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	_rotate_hint.visible = DisplayServer.is_touchscreen_available() and vs.y > vs.x * 1.1
	if _typing:
		var before := int(_chars)
		_chars += delta * 55.0
		var total := _dlg_text.get_total_character_count()
		if int(_chars) / 3 != before / 3:
			Audio.sfx("blip", 0.08, -6.0)
		_dlg_text.visible_characters = int(_chars)
		if int(_chars) >= total:
			_finish_typing()
	if _dlg_next.visible:
		_dlg_next.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 180.0)


func _finish_typing() -> void:
	_typing = false
	_dlg_text.visible_characters = -1
	if _options.is_empty():
		_dlg_next.visible = true
		_dlg_next.text = "tap to continue  v" if DisplayServer.is_touchscreen_available() else "Space to continue  v"
	else:
		for i in _options.size():
			var b := Button.new()
			b.text = str(_options[i])
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 26)
			b.pressed.connect(_choose.bind(i))
			b.focus_entered.connect(func(): Audio.sfx("ui_move", 0.0, -8.0))
			_choices.add_child(b)
		var idx := clampi(_choice_default, 0, _options.size() - 1)
		(_choices.get_child(idx) as Button).grab_focus.call_deferred()


func _choose(i: int) -> void:
	if not _dialog_open or _typing or _options.is_empty():
		return
	Audio.sfx("ui_confirm")
	_close()
	choice_made.emit(i)


func _advance() -> void:
	if _typing:
		_finish_typing()
		return
	if not _options.is_empty():
		var f := get_viewport().gui_get_focus_owner()
		if f is Button and f.get_parent() == _choices:
			(f as Button).pressed.emit()
		return
	_close()
	dialog_advanced.emit()


func _close() -> void:
	_dialog_open = false
	_options = []
	for c in _choices.get_children():
		c.queue_free()
	_hide_later.call_deferred()


func _hide_later() -> void:
	if not _dialog_open:
		dialog.visible = false


func _on_dialog_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _options.is_empty() or _typing:
			_advance()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _dialog_open and event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		_advance()


# --------------------------------------------------------- toasts & fades
func toast(text: String, icon_name := "") -> void:
	var p := PanelContainer.new()
	p.theme = theme
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", flat(Color(1, 1, 1, 0.95), 24, Color("c9a6ff"), 3, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	if icon_name != "":
		h.add_child(icon(icon_name, 34))
	h.add_child(label(text, 26))
	p.add_child(h)
	_toast_box.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


func banner(text: String, dur := 1.4) -> void:
	_banner.text = text
	_banner.visible = true
	_banner.pivot_offset = _banner.size / 2
	_banner.scale = Vector2(0.6, 0.6)
	_banner.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tw.chain().tween_interval(dur)
	tw.chain().tween_property(_banner, "modulate:a", 0.0, 0.3)
	await tw.finished
	_banner.visible = false


func hint(text: String) -> void:
	_hint.text = text


func fade_out(dur := 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, dur)
	await tw.finished


func fade_in(dur := 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, dur)
	await tw.finished


# ---------------------------------------------------------------- ending
signal _ending_closed


## The "You saved Monday!" screen with stats and the love note.
func show_ending() -> void:
	var root := Control.new()
	root.theme = theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.1, 0.3, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var conf := CPUParticles2D.new()
	conf.texture = Art.tex("heart")
	conf.amount = 60
	conf.lifetime = 6.0
	conf.preprocess = 3.0
	conf.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	conf.emission_rect_extents = Vector2(900, 10)
	conf.position = Vector2(640, -40)
	conf.direction = Vector2(0, 1)
	conf.spread = 20
	conf.gravity = Vector2(0, 40)
	conf.initial_velocity_min = 60
	conf.initial_velocity_max = 140
	conf.angular_velocity_min = -90
	conf.angular_velocity_max = 90
	conf.scale_amount_min = 0.3
	conf.scale_amount_max = 0.7
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	grad.colors = PackedColorArray([Color("ff8fc8"), Color("ffe27a"), Color("8fe8ff"), Color("c3a6ff")])
	conf.color_initial_ramp = grad
	root.add_child(conf)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	panel.add_theme_stylebox_override("panel", flat(Color(1, 0.98, 1, 0.97), 34, PINK, 5, 30))
	full_center(root).add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var t := label("You saved Monday!", 64, Color("e0609f"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := Game.state
	var friends := 0
	for k in s["friends"]:
		friends += int(s["friends"][k])
	var body := label("%s cheered up %d grumpy critters, reached level %d, found %d of 5 Star Shards, and turned the Monday Monster back into a sleepy little clock. Spellwork Tower has declared a four-day weekend in your honor!" % [s["name"], friends, s["level"], s["shards"].size()], 26)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 760
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)
	var note := PanelContainer.new()
	note.add_theme_stylebox_override("panel", flat(Color("fff0f7"), 22, Color("ff9fc4"), 3, 18))
	var nl := label(Game.LOVE_NOTE, 30, Color("c0407a"))
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size.x = 700
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_child(nl)
	v.add_child(note)
	var b := Button.new()
	b.text = "Keep exploring"
	b.custom_minimum_size = Vector2(300, 64)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(func():
		Audio.sfx("ui_confirm")
		_ending_closed.emit())
	var c := CenterContainer.new()
	c.add_child(b)
	v.add_child(c)
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.6)
	Audio.sfx("level_up")
	b.grab_focus.call_deferred()
	await _ending_closed
	root.queue_free()
