class_name Pickup
extends Node3D
## XP orbs, coins and snacks that pop out of cheered-up critters and fly to you.

var kind := "xp" # xp | coin | muffin | tea | heart
var value := 1

var _vel := Vector3.ZERO
var _t := 0.0


func _ready() -> void:
	_vel = Vector3(randf_range(-2.5, 2.5), randf_range(4, 6), randf_range(-2.5, 2.5))
	position.y = 0.8
	match kind:
		"xp": Art.part(self, Art.sphere(0.13), Color("9fd0ff"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 2.5, false)
		"coin": Art.part(self, Art.cyl(0.16, 0.16, 0.05), Color("ffd36b"), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, 1.2, false)
		"muffin":
			Art.part(self, Art.cyl(0.14, 0.1, 0.16), Color("ff9fc4"), Vector3.ZERO)
			Art.part(self, Art.sphere(0.16), Color("f0a050"), Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
		"tea": Art.part(self, Art.cyl(0.12, 0.12, 0.22), Color("9fd0ff"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 0.6)
		"heart": Art.part(self, Art.sphere(0.18), Color("ff7eb6"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.5, false)


func _process(delta: float) -> void:
	_t += delta
	rotation.y += delta * 4.0
	var p: Player = Game.combat.player() if Game.combat else null
	if _t < 0.45 or p == null:
		_vel.y -= 14.0 * delta
		position += _vel * delta
		if position.y < 0.3:
			position.y = 0.3
			_vel = Vector3(_vel.x * 0.5, absf(_vel.y) * 0.35, _vel.z * 0.5)
		return
	var target := p.global_position + Vector3(0, 0.8, 0)
	var to := target - global_position
	if to.length() < 0.5:
		_collect()
		return
	if to.length() < 5.0 or _t > 1.2:
		position += to.normalized() * minf(to.length(), (6.0 + _t * 10.0) * delta)


func _collect() -> void:
	match kind:
		"xp":
			Audio.sfx("coin", 0.3, -12.0)
			Game.combat.gain_xp(value)
		"coin":
			Audio.sfx("coin", 0.1, -6.0)
			Game.add_coins(value)
		"muffin":
			Audio.sfx("heal")
			Game.add_item("muffin")
			Game.combat.main.ui.toast("Found a Pumpkin Muffin!", "muffin")
		"tea":
			Audio.sfx("buff")
			Game.add_item("tea")
			Game.combat.main.ui.toast("Found a Moon Tea!", "tea")
		"heart":
			Audio.sfx("heal", 0.1, -4.0)
			Game.heal(value)
	queue_free()
