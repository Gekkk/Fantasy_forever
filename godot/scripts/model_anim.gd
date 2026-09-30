class_name ModelAnim
extends Node3D
## Procedural idle/walk animation for the primitive-built models:
## bobbing, arm swing, blinking, wing flaps and tail sways.

var kind := "biped" # biped | quad | float | hop
var moving := false
var height := 1.4 # used by UI to place labels above the model
var speed_scale := 1.0

var _t := 0.0
var _blink := 2.0
var _pivot: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _tail: Node3D
var _eyes: Array[Node3D] = []
var _brows: Node3D
var _base_y := 0.0


func _ready() -> void:
	_t = randf() * 10.0
	_blink = randf_range(1.0, 4.0)
	_pivot = find_child("Pivot", true, false)
	_head = find_child("Head", true, false)
	_arm_l = find_child("ArmL", true, false)
	_arm_r = find_child("ArmR", true, false)
	_wing_l = find_child("WingL", true, false)
	_wing_r = find_child("WingR", true, false)
	_tail = find_child("Tail", true, false)
	_brows = find_child("Brows", true, false)
	for n in ["EyeL", "EyeR"]:
		var e: Node3D = find_child(n, true, false)
		if e:
			_eyes.append(e)
	if _pivot:
		_base_y = _pivot.position.y


## One-shot animations only exist on rigged models (see KayChar).
func action(_name: String, _speed := 1.0, _hold := false) -> void:
	pass


func clear_action() -> void:
	pass


func set_calm(v: bool) -> void:
	if _brows:
		_brows.visible = not v


func _process(delta: float) -> void:
	_t += delta * speed_scale * (1.8 if moving else 1.0)
	if _pivot:
		match kind:
			"biped", "quad":
				if moving:
					_pivot.position.y = _base_y + absf(sin(_t * 6.0)) * 0.07
					_pivot.rotation.z = sin(_t * 6.0) * 0.06
				else:
					_pivot.position.y = _base_y + sin(_t * 2.0) * 0.012
					_pivot.rotation.z = lerpf(_pivot.rotation.z, 0.0, delta * 8.0)
				_pivot.scale = Vector3(1.0, 1.0 + sin(_t * 2.0) * 0.015, 1.0)
			"float":
				_pivot.position.y = _base_y + sin(_t * 2.2) * 0.09
				_pivot.rotation.z = sin(_t * 1.3) * 0.08
			"hop":
				var h := absf(sin(_t * (5.0 if moving else 2.5)))
				_pivot.position.y = _base_y + h * (0.22 if moving else 0.06)
				var sq := 1.0 - (1.0 - h) * 0.12
				_pivot.scale = Vector3(2.0 - sq, sq, 2.0 - sq)
	if _arm_l and _arm_r:
		var swing := sin(_t * 6.0) * 0.7 if moving else sin(_t * 2.0) * 0.05
		_arm_l.rotation.x = swing
		_arm_r.rotation.x = -swing
	if _head:
		_head.rotation.z = sin(_t * 1.1) * 0.05
	if _wing_l and _wing_r:
		var f := sin(_t * 16.0) * 0.45
		_wing_l.rotation.y = f
		_wing_r.rotation.y = -f
	if _tail:
		_tail.rotation.z = sin(_t * 3.0) * 0.25
	_blink -= delta
	var eye_y := 1.0
	if _blink < 0.0:
		eye_y = 0.1
		if _blink < -0.12:
			_blink = randf_range(2.0, 5.0)
	for e in _eyes:
		e.scale.y = eye_y
