class_name TouchControls
extends Control
## On-screen joystick plus A (talk/confirm) and B (menu/back) buttons for phones.

const RADIUS := 110.0
const KNOB := 48.0

var joystick_enabled := true
var _touch_index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _a: Button
var _b: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_a = _round_button("A", Color("ff7eb6"), 132)
	_a.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_a.position = Vector2(-170, -180)
	_a.button_down.connect(_send.bind("confirm"))
	_b = _round_button("B", Color("9d86e8"), 96)
	_b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_b.position = Vector2(-290, -120)
	_b.button_down.connect(_send.bind("cancel"))


func _round_button(text: String, color: Color, size: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(size, size)
	b.size = Vector2(size, size)
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	var st := UI.flat(Color(color, 0.8), int(size / 2), Color(1, 1, 1, 0.9), 4, 0)
	for n in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(n, st)
	b.add_theme_stylebox_override("pressed", UI.flat(color.darkened(0.2), int(size / 2), Color.WHITE, 4, 0))
	b.add_theme_font_override("font", Art.get_font())
	b.add_theme_font_size_override("font_size", int(size * 0.4))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	add_child(b)
	return b


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
	if not v:
		_release()


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
