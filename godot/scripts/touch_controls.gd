class_name TouchControls
extends Control
## Phone controls: joystick on the left; A (attack / talk), Dash and four
## skill buttons on the right, each with a cooldown sweep.

const RADIUS := 110.0
const KNOB := 48.0

var joystick_enabled := true
var _touch_index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _a: Button
var _dash: Button
var _skills: Array = [] # [button, cooldown overlay]
var _dash_cd: ColorRect


func _ready() -> void:
	name = "TouchControls"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Centers are relative to the bottom-right corner.
	_a = _round_button("A", Color("ff7eb6"), 150, Vector2(-120, -130))
	_a.button_down.connect(_send.bind("confirm"))
	_dash = _round_button("Dash", Color("9d86e8"), 104, Vector2(-285, -70))
	_dash.button_down.connect(_send.bind("dash"))
	_dash_cd = _overlay(_dash)
	var spots := [Vector2(-120, -320), Vector2(-240, -285), Vector2(-315, -185), Vector2(-420, -80)]
	for i in 4:
		var b := _round_button("", Color("ffd36b"), 92, spots[i])
		b.icon = Art.tex("unknown")
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 52)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.button_down.connect(_send.bind("skill%d" % (i + 1)))
		_skills.append([b, _overlay(b)])


func _round_button(text: String, color: Color, size: float, center: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(size, size)
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	var st := UI.flat(Color(color, 0.8), int(size / 2), Color(1, 1, 1, 0.9), 4, 0)
	for n in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(n, st)
	b.add_theme_stylebox_override("pressed", UI.flat(color.darkened(0.2), int(size / 2), Color.WHITE, 4, 0))
	b.add_theme_font_override("font", Art.get_font())
	b.add_theme_font_size_override("font_size", int(size * (0.4 if text.length() <= 1 else 0.24)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = center.x - size / 2
	b.offset_top = center.y - size / 2
	b.offset_right = center.x + size / 2
	b.offset_bottom = center.y + size / 2
	add_child(b)
	return b


func _overlay(b: Button) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.2, 0.1, 0.3, 0.55)
	r.anchor_right = 1.0
	r.anchor_top = 1.0
	r.anchor_bottom = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(r)
	return r


func update_cooldowns(p: Player) -> void:
	if not visible or not joystick_enabled:
		return
	_dash_cd.anchor_top = 1.0 - clampf(p.dash_ready() / (0.75 * float(Rpg.d("dash"))), 0.0, 1.0)
	for i in _skills.size():
		var sid := Rpg.slot_skill(i)
		var b: Button = _skills[i][0]
		var ov: ColorRect = _skills[i][1]
		var learned := sid != ""
		b.visible = learned
		if learned:
			var want: Texture2D = Art.tex(Rpg.ACTIVES[sid]["icon"])
			if b.icon != want:
				b.icon = want
			ov.anchor_top = 1.0 - clampf(float(p.skill_cd.get(sid, 0.0)) / Rpg.skill_cd(sid), 0.0, 1.0)
			b.modulate = Color.WHITE if Game.state["mp"] >= Rpg.skill_mp(sid) else Color(0.7, 0.7, 1.0, 0.7)


func _send(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event.call_deferred(up)


func _input(event: InputEvent) -> void:
	if not visible or not joystick_enabled:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		var vp := get_viewport_rect().size
		var pos := t.position
		if t.pressed and _touch_index == -1 and pos.x < vp.x * 0.45 and pos.y > vp.y * 0.3:
			_touch_index = t.index
			_origin = pos
			_knob = pos
			queue_redraw()
		elif not t.pressed and t.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch_index:
			var off := (d.position - _origin).limit_length(RADIUS)
			_knob = _origin + off
			var v := off / RADIUS
			_set_axis("move_left", "move_right", v.x)
			_set_axis("move_up", "move_down", v.y)
			queue_redraw()


func _set_axis(neg: String, pos: String, value: float) -> void:
	if value < -0.15:
		Input.action_press(neg, clampf(-value, 0.0, 1.0))
		Input.action_release(pos)
	elif value > 0.15:
		Input.action_press(pos, clampf(value, 0.0, 1.0))
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _release() -> void:
	_touch_index = -1
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	queue_redraw()


func set_joystick(v: bool) -> void:
	joystick_enabled = v
	_dash.visible = v
	for sk in _skills:
		sk[0].visible = v and Rpg.slot_skill(_skills.find(sk)) != ""
	if not v:
		_release()
	queue_redraw()


func _draw() -> void:
	if _touch_index == -1:
		var vp := get_viewport_rect().size
		var home := Vector2(190, vp.y - 190)
		if joystick_enabled:
			draw_circle(home, RADIUS, Color(1, 1, 1, 0.12))
			draw_arc(home, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.5), 4, true)
			draw_circle(home, KNOB, Color(1, 0.6, 0.8, 0.5))
		return
	draw_circle(_origin, RADIUS, Color(1, 1, 1, 0.15))
	draw_arc(_origin, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.6), 4, true)
	draw_circle(_knob, KNOB, Color(1, 0.55, 0.78, 0.8))
