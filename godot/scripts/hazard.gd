class_name Hazard
extends Node3D
## A telegraphed area on the ground. It shows a warning that fills up over
## `delay` seconds, then fires once (or keeps hurting for `active` seconds).
## Shapes: circle, line, ring (expanding shockwave), sweep (rotating line).

signal fired

var shape := "circle"
var radius := 1.5
var length := 6.0
var width := 1.2
var dir := Vector3.FORWARD
var delay := 0.8
var active := 0.0 # >0: keeps dealing damage while active (ring, sweep, puddle)
var damage := 10
var friendly := false # true = hurts critters, false = hurts the player
var element := "none"
var color := Color(1.0, 0.35, 0.5)
var ring_speed := 6.0
var ring_max := 14.0
var sweep_speed := 1.4 # radians per second
var status := ""

var _t := 0.0
var _fired := false
var _hit_cooldown := {}
var _warn: MeshInstance3D
var _fill: MeshInstance3D
var _ring: MeshInstance3D
var _ring_r := 0.5


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.render_priority = 2
	return m


func _ready() -> void:
	position.y = 0.06
	match shape:
		"circle":
			_warn = _disc(radius, Color(color, 0.22))
			_fill = _disc(radius, Color(color, 0.45))
			_fill.scale = Vector3(0.01, 1, 0.01)
			var edge := MeshInstance3D.new()
			edge.mesh = Art.torus(radius - 0.08, radius)
			edge.material_override = _mat(Color(color, 0.8))
			edge.scale = Vector3(1, 0.05, 1)
			add_child(edge)
		"line", "sweep":
			_warn = _bar(Color(color, 0.22))
			_fill = _bar(Color(color, 0.45))
			_fill.scale = Vector3(1, 1, 0.01)
			rotation.y = atan2(dir.x, dir.z)
		"ring":
			_ring = MeshInstance3D.new()
			_ring.mesh = Art.torus(0.85, 1.0)
			_ring.material_override = _mat(Color(color, 0.85))
			_ring.scale = Vector3(0.5, 0.25, 0.5)
			add_child(_ring)
			_warn = _disc(0.9, Color(color, 0.35))


func _disc(r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = 0.02
	m.radial_segments = 32
	mi.mesh = m
	mi.material_override = _mat(c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _bar(c: Color) -> MeshInstance3D:
	# A strip that starts at the origin and extends `length` along local +Z.
	var holder := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(width, 0.02, length)
	holder.mesh = m
	holder.position.z = length / 2.0
	holder.material_override = _mat(c)
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(holder)
	return holder


func _process(delta: float) -> void:
	_t += delta
	if not _fired:
		var k := clampf(_t / delay, 0.0, 1.0)
		match shape:
			"circle": _fill.scale = Vector3(k, 1, k)
			"line", "sweep":
				_fill.scale = Vector3(1, 1, maxf(0.01, k))
				_fill.position.z = length * k / 2.0
			"ring": _warn.scale = Vector3.ONE * (0.6 + 0.4 * sin(_t * 20.0))
		if _t >= delay:
			_fire()
		return
	if active <= 0.0:
		return
	match shape:
		"ring":
			_ring_r += ring_speed * delta
			_ring.scale = Vector3(_ring_r, 0.25, _ring_r)
			if _ring_r >= ring_max:
				queue_free()
				return
		"sweep":
			rotation.y += sweep_speed * delta
	_apply_damage()
	if _t >= delay + active:
		queue_free()


func _fire() -> void:
	_fired = true
	fired.emit()
	if active <= 0.0:
		_apply_damage()
		if _warn:
			_warn.visible = false
		_fill.material_override = _mat(Color(1, 1, 1, 0.7))
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3(1.15, 1, 1.15), 0.12)
		tw.tween_callback(queue_free)
	else:
		if _warn:
			_warn.visible = false
		if _fill:
			_fill.material_override = _mat(Color(color, 0.75))
			_fill.scale = Vector3.ONE
			if shape == "sweep":
				_fill.position.z = length / 2.0


## Is a world point inside the hurtful part of this hazard?
func contains(p: Vector3) -> bool:
	var local := p - global_position
	local.y = 0
	match shape:
		"circle":
			return local.length() <= radius
		"line", "sweep":
			var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
			var along := local.dot(fwd)
			var side := absf(local.dot(fwd.cross(Vector3.UP)))
			return along >= -0.3 and along <= length and side <= width / 2.0 + 0.25
		"ring":
			return absf(local.length() - _ring_r) <= 0.7
	return false


func _apply_damage() -> void:
	var c: Combat = Game.combat
	if c == null:
		return
	if friendly:
		for e in c.enemies.duplicate():
			if not is_instance_valid(e) or e.dead:
				continue
			var key: int = e.get_instance_id()
			if _hit_cooldown.get(key, -1.0) > _t:
				continue
			if contains(e.global_position):
				_hit_cooldown[key] = _t + 0.5
				e.take_damage(damage, element, e.global_position - global_position, status)
	else:
		var p: Player = c.player()
		if p and _hit_cooldown.get(0, -1.0) <= _t and contains(p.global_position):
			if p.hurt(damage, global_position):
				_hit_cooldown[0] = _t + 0.6
