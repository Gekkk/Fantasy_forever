class_name TimingRing
extends Control
## The "press when the ring hits the circle" timing prompt used for
## attacks (bonus damage) and guarding (blocking enemy hits).

signal resolved(result: String) # "perfect" | "good" | "miss"

var center := Vector2.ZERO
var duration := 0.9
var start_r := 150.0
var target_r := 40.0
var color := Color("ff7eb6")
var caption := ""
var perfect_px := 11.0
var good_px := 26.0

var _t := 0.0
var _r := 150.0
var _done := false
var _result := ""
var _flash := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_r = start_r


func _process(delta: float) -> void:
	if _done:
		_flash += delta
		queue_redraw()
		return
	_t += delta
	_r = lerpf(start_r, 0.0, _t / duration)
	queue_redraw()
	if _r < target_r - good_px:
		_finish("miss")


func _input(event: InputEvent) -> void:
	if _done:
		return
	var hit := event.is_action_pressed("confirm")
	if event is InputEventScreenTouch and event.pressed:
		hit = true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hit = true
	if not hit:
		return
	get_viewport().set_input_as_handled()
	var d := absf(_r - target_r)
	if d <= perfect_px:
		_finish("perfect")
	elif d <= good_px:
		_finish("good")
	else:
		_finish("miss")


func _finish(result: String) -> void:
	_done = true
	_result = result
	resolved.emit(result)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35).set_delay(0.15)
	tw.tween_callback(queue_free)


func _draw() -> void:
	var glow := color
	if _done:
		glow = Color("ffe27a") if _result == "perfect" else (Color("9fffb8") if _result == "good" else Color(0.8, 0.8, 0.9))
		var pulse := target_r + _flash * 120.0
		draw_arc(center, pulse, 0, TAU, 48, Color(glow, maxf(0.0, 0.8 - _flash * 2.0)), 6, true)
	draw_circle(center, target_r, Color(glow, 0.18))
	draw_arc(center, target_r, 0, TAU, 48, Color(1, 1, 1, 0.95), 7, true)
	draw_arc(center, target_r, 0, TAU, 48, glow, 3, true)
	if not _done:
		var near := absf(_r - target_r) <= good_px
		draw_arc(center, _r, 0, TAU, 64, Color("fff3b0") if near else color, 6, true)
	if caption != "":
		var f := Art.get_font()
		var w := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, 30).x
		var pos := center + Vector2(-w / 2, target_r + 52)
		draw_string_outline(f, pos, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 10, Color("4a2a60"))
		draw_string(f, pos, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
