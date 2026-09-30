class_name Enemy
extends Node3D
## A grumpy critter with real-time behavior. Every attack is telegraphed on
## the ground first so it can be dodged. Knock them to 0 HP to cheer them up.

const BEHAVIOR := {
	# preferred distance, attack range, windup seconds, recover seconds
	"melee": [1.2, 1.9, 0.48, 0.5],
	"charger": [4.5, 6.5, 0.65, 0.6],
	"shooter": [6.0, 9.5, 0.5, 0.6],
	"bomber": [5.0, 8.5, 0.2, 0.8],
	"spinner": [1.4, 2.3, 0.7, 0.6],
	"boss": [3.0, 8.0, 0.6, 0.8],
}

var id := "cloud"
var uid := ""
var area := Rect2(-10, -10, 20, 20)
var elite := false
var data: Dictionary
var hp := 10
var max_hp := 10
var weak := ""
var dmg := 8
var speed := 2.0
var behavior := "melee"
var model: ModelAnim
var hit_radius := 0.6
var dead := false
var aggro := false
var state := "wander"

var _st := 0.0
var _atk_cd := 1.5
var _target := Vector3.ZERO
var _wait := 0.0
var _knock := Vector3.ZERO
var _burn := 0.0
var _burn_dps := 0.0
var _burn_tick := 0.0
var _frozen := 0.0
var _stun := 0.0
var _poise := 0
var _tele: Hazard
var _aim := Vector3.FORWARD
var _bar: Node3D
var _bar_fill: MeshInstance3D
var _bar_show := 0.0
var _ice: MeshInstance3D
var _alert: Label3D
var _weak_shown := 0.0
var affix := "" # elites: swift | armored | blazing
var _alt := false
var _dashes_left := 0
var _trail_cd := 0.0


func _ready() -> void:
	data = Game.ENEMIES[id]
	behavior = String(data["behavior"])
	var lvl := int(Game.state.get("level", 1))
	# Critters grow with you, so gear and attributes matter.
	var scale_hp := 2.2 * (1.0 + 0.2 * (lvl - 1))
	var scale_dmg := 1.5 * (1.0 + 0.22 * (lvl - 1))
	if behavior == "boss":
		# Bosses keep pace with a geared-up hero.
		scale_hp = 1.0 + 0.16 * (lvl - 1)
		scale_dmg = 1.0 + 0.2 * (lvl - 1)
	max_hp = int(float(data["hp"]) * scale_hp * (2.2 if elite else 1.0))
	hp = max_hp
	dmg = int(float(data["dmg"]) * scale_dmg * (1.3 if elite else 1.0))
	speed = float(data["speed"])
	if elite and affix == "":
		affix = ["swift", "armored", "blazing"].pick_random()
	if affix == "swift":
		speed *= 1.45
	weak = String(data["weak"])
	model = Models.tiny_clock() if id == "tick" else Models.critter(id)
	add_child(model)
	Art.outline(model, 0.022)
	model.scale = Vector3.ONE * (1.15 if elite else 0.95)
	hit_radius = 0.55 * model.scale.x
	_make_bar()
	_alert = Art.label3d(self, "!", Vector3(0, model.height * model.scale.y + 0.9, 0), 96, Color("ffd36b"))
	_alert.visible = false
	if elite:
		var aura: Color = {"swift": Color("9fffd0"), "armored": Color("9fc8ff"), "blazing": Color("ff9f5a")}.get(affix, Color("ffd36b"))
		Art.ambient(self, Vector3(0, 0.7, 0), Vector3(0.5, 0.6, 0.5), aura, 16, "sparkle", 0.25, 1.4)
	_pick_target()


func _make_bar() -> void:
	_bar = Node3D.new()
	_bar.position.y = model.height * model.scale.y + 0.45
	add_child(_bar)
	var back := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 0.14)
	back.mesh = q
	back.material_override = _bar_mat(Color(0.2, 0.1, 0.3, 0.75))
	_bar.add_child(back)
	_bar_fill = MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(1.04, 0.09)
	_bar_fill.mesh = q2
	_bar_fill.material_override = _bar_mat(Color("ffd36b") if elite else Color("ff7eb6"))
	_bar_fill.position.z = 0.01
	_bar.add_child(_bar_fill)
	_bar.visible = false


static func _bar_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	m.render_priority = 5
	return m


func _pick_target() -> void:
	_target = Vector3(randf_range(area.position.x, area.end.x), 0, randf_range(area.position.y, area.end.y))
	_wait = randf_range(0.6, 2.5)


func _can_act() -> bool:
	var m = Game.combat.main
	return m.mode == m.Mode.EXPLORE


func display_name() -> String:
	if not elite:
		return String(data["name"])
	return "%s %s" % [affix.capitalize() if affix != "" else "Elite", data["name"]]


# ================================================================= update
func _process(delta: float) -> void:
	if dead:
		return
	var p: Player = Game.combat.player()
	_tick_status(delta)
	position += _knock * delta
	_knock = _knock.move_toward(Vector3.ZERO, 22.0 * delta)
	_update_bar(delta)
	if p == null or not _can_act():
		model.moving = false
		_cancel_windup()
		if state == "windup" or state == "dash":
			state = "chase"
		return
	if _stun > 0.0 or _frozen > 0.0:
		_cancel_windup()
		if state == "windup" or state == "dash":
			state = "recover"
			_st = 0.0
		model.moving = false
		return
	var to_p := p.global_position - global_position
	to_p.y = 0
	var dist := to_p.length()
	if not aggro and dist < 7.5:
		_set_aggro()
	elif aggro and dist > 20.0 and not Game.combat.arena_active:
		aggro = false
		state = "wander"
	_st += delta
	_atk_cd -= delta
	if affix == "blazing" and aggro:
		_trail_cd -= delta
		if _trail_cd <= 0.0:
			_trail_cd = 1.1
			Game.combat.hazard("circle", global_position, {"radius": 0.9, "delay": 0.3, "active": 2.2, "damage": int(dmg * 0.5),
				"color": Color(1.0, 0.55, 0.25)})
	_think(delta, p, to_p, dist)
	_clamp_position()


func _set_aggro() -> void:
	aggro = true
	if state == "wander":
		state = "chase"
	_alert.visible = true
	Audio.sfx("ui_move", 0.0, -6.0)
	get_tree().create_timer(0.7).timeout.connect(_hide_alert)


func _hide_alert() -> void:
	if is_instance_valid(_alert):
		_alert.visible = false


func _clamp_position() -> void:
	var a := area.grow(3.0)
	position.x = clampf(position.x, a.position.x, a.end.x)
	position.z = clampf(position.z, a.position.y, a.end.y)
	position.y = 0.0
	position = Game.combat.clamp_to_arena(position)


func _move(dir: Vector3, spd: float, delta: float) -> void:
	if dir.length() < 0.01:
		model.moving = false
		return
	position += dir.normalized() * spd * delta
	model.moving = true
	_face(dir, delta)


func _face(dir: Vector3, delta: float) -> void:
	if dir.length() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), minf(1.0, 10.0 * delta))


func _think(delta: float, p: Player, to_p: Vector3, dist: float) -> void:
	var cfg: Array = BEHAVIOR[behavior]
	match state:
		"wander":
			# Spawned already angry (boss minions, arena waves): go straight for you.
			if aggro:
				state = "chase"
				_st = 0.0
				return
			if _wait > 0.0:
				_wait -= delta
				model.moving = false
			else:
				var to_t := _target - global_position
				to_t.y = 0
				if to_t.length() < 0.4:
					_pick_target()
				else:
					_move(to_t, speed * 0.45, delta)
		"chase":
			var pref: float = cfg[0]
			var dir := Vector3.ZERO
			if dist > pref + 0.4:
				dir = to_p
			elif dist < pref - 1.2 and behavior in ["shooter", "bomber", "charger"]:
				dir = -to_p
			else:
				# Circle around a little so they don't just stand still.
				dir = to_p.cross(Vector3.UP) * (0.5 if int(_st) % 4 < 2 else -0.5)
			_move(dir, speed, delta)
			_face(to_p, delta)
			if dist <= float(cfg[1]) and _atk_cd <= 0.0:
				_begin_windup(p, to_p)
		"windup":
			model.moving = false
			_face(to_p if behavior != "charger" else _aim, delta)
			model.position.x = sin(_st * 60.0) * 0.04
			if _st >= float(cfg[2]) * (0.7 if affix == "swift" else 1.0):
				model.position.x = 0.0
				_execute(p, to_p)
		"dash":
			position += _aim * 13.0 * delta
			model.moving = true
			var rel := p.global_position - global_position
			rel.y = 0
			if rel.length() < 1.0 + hit_radius:
				p.hurt(dmg, global_position)
			if _st >= (0.25 if _alt and behavior == "melee" else 0.42):
				if _dashes_left > 0:
					_dashes_left -= 1
					var again := p.global_position - global_position
					again.y = 0
					_aim = again.normalized()
					_tele = Game.combat.hazard("line", global_position, {"dir": _aim, "length": 7.0, "width": 1.3, "delay": 0.35, "damage": 0})
					state = "windup"
					_st = float(BEHAVIOR[behavior][2]) - 0.35
				else:
					state = "recover"
				_st = 0.0 if state == "recover" else _st
		"recover":
			model.moving = false
			if _st >= float(cfg[3]) * (0.6 if affix == "swift" else 1.0):
				state = "chase"
				_st = 0.0


func _begin_windup(p: Player, to_p: Vector3) -> void:
	state = "windup"
	_st = 0.0
	_aim = to_p.normalized()
	var c: Combat = Game.combat
	var base := global_position
	_alt = randf() < 0.35
	if _alt:
		match behavior:
			"melee":
				_tele = c.hazard("line", base, {"dir": _aim, "length": 4.5, "width": 1.2, "delay": 0.6, "damage": 0})
				return
			"shooter":
				_tele = c.hazard("circle", base, {"radius": 1.2, "delay": 0.7, "damage": 0, "color": Color(1.0, 0.6, 0.3)})
				return
			"bomber":
				for i in 3:
					var off := Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)) if i > 0 else Vector3.ZERO
					var h := c.hazard("circle", p.global_position + off, {"radius": 1.4, "delay": 1.0 + i * 0.15, "damage": dmg,
						"color": Color(0.5, 0.6, 1.0) if id == "cloud" else Color(0.7, 0.45, 0.3)})
					h.fired.connect(_bomb_fx.bind(p.global_position + off))
				return
			"spinner":
				_tele = c.hazard("circle", base, {"radius": 1.0, "delay": 0.8, "damage": 0})
				return
			"charger":
				_dashes_left = 1
	match behavior:
		"melee":
			_tele = c.hazard("circle", base + _aim * 1.0, {"radius": 1.25, "delay": 0.55, "damage": dmg})
		"charger":
			_tele = c.hazard("line", base, {"dir": _aim, "length": 7.0, "width": 1.3, "delay": 0.75, "damage": 0})
		"shooter":
			_tele = c.hazard("line", base, {"dir": _aim, "length": 8.0, "width": 0.35, "delay": 0.6, "damage": 0,
				"color": Color(1.0, 0.6, 0.3)})
		"bomber":
			_tele = c.hazard("circle", p.global_position, {"radius": 1.7, "delay": 1.1, "damage": dmg,
				"color": Color(0.5, 0.6, 1.0) if id == "cloud" else Color(0.7, 0.45, 0.3)})
			_tele.fired.connect(_bomb_fx.bind(p.global_position))
		"spinner":
			_tele = c.hazard("circle", base, {"radius": 2.3, "delay": 0.8, "damage": dmg})


func _bomb_fx(at: Vector3) -> void:
	if id == "cloud":
		Audio.sfx("ice", 0.1, -6.0)
		Art.burst(Game.combat.world(), at + Vector3(0, 3, 0), Color("8fc8ff"), 24, "soft", 2.0, 0.6, 0.2, Vector3(0, -20, 0), 20)
	else:
		Audio.sfx("hit", 0.1, -4.0)
		Art.burst(Game.combat.world(), at + Vector3(0, 0.3, 0), Color("8a5a3c"), 24, "soft", 3.0, 0.6, 0.35)


func _execute(p: Player, to_p: Vector3) -> void:
	_tele = null
	var cfg: Array = BEHAVIOR[behavior]
	state = "recover"
	_st = 0.0
	_atk_cd = randf_range(0.8, 1.5) * (0.7 if affix == "swift" else 1.0)
	if _alt:
		match behavior:
			"melee":
				state = "dash"
				Audio.sfx("swing", 0.1)
				return
			"shooter":
				for i in 8:
					var d := Vector3(sin(i * TAU / 8), 0, cos(i * TAU / 8))
					Game.combat.projectile(global_position + d * 0.6, d * 7.0, dmg, false, Color("fff4e0") if id != "email" else Color("c9b6ff"))
				Audio.sfx("swing", 0.2, -2.0)
				return
			"bomber":
				return
			"spinner":
				Game.combat.hazard("ring", global_position, {"delay": 0.02, "active": 1.2, "damage": dmg, "ring_speed": 5.0, "ring_max": 6.0,
					"color": Color(0.7, 1.0, 0.8)})
				Audio.sfx("swing", 0.1, -2.0)
				return
	match behavior:
		"melee":
			var tw := create_tween()
			tw.tween_property(self, "position", position + _aim * 0.8, 0.1)
			Audio.sfx("swing", 0.15, -4.0)
		"charger":
			state = "dash"
			Audio.sfx("swing", 0.1)
		"shooter":
			var n := 3 if id == "printer" else 1
			for i in n:
				var ang := (i - (n - 1) / 2.0) * 0.28
				var d := _aim.rotated(Vector3.UP, ang)
				Game.combat.projectile(global_position + d * 0.6, d * 8.0, dmg, false, Color("fff4e0") if id != "email" else Color("c9b6ff"))
			Audio.sfx("swing", 0.2, -4.0)
		"spinner":
			var tw := create_tween()
			tw.tween_property(model, "rotation:y", model.rotation.y + TAU, 0.3)
			Art.burst(Game.combat.world(), global_position + Vector3(0, 0.6, 0), Color("c8f0b0") if id == "shroom" else Color("8fe8e0"), 20, "soft", 3.5, 0.5, 0.35)
			Audio.sfx("swing", 0.1, -2.0)


func _cancel_windup() -> void:
	if _tele and is_instance_valid(_tele):
		_tele.queue_free()
	_tele = null
	model.position.x = 0.0


# ================================================================= damage
func take_damage(amount: int, element := "none", from_dir := Vector3.ZERO, status := "") -> void:
	if dead:
		return
	var mult := 1.0
	var is_weak := element != "none" and element == weak
	if is_weak:
		mult = 1.5
		Game.state["known_weak"][_weak_key()] = true
	if _stun > 0.0:
		mult *= 1.25
	if affix == "armored" and hp > max_hp / 2:
		mult *= 0.6
	var amt := maxi(1, int(round(amount * mult)))
	hp -= amt
	_bar_show = 3.0
	var top := global_position + Vector3(0, model.height * model.scale.y * 0.8, 0)
	var col := Color("ffd36b") if is_weak else (Game.ELEMENT_COLORS.get(element, Color.WHITE) as Color).lightened(0.4)
	Art.float_text(Game.combat.world(), top + Vector3(randf_range(-0.3, 0.3), 0.2, 0), str(amt), col, 80 if is_weak else 64, 1.0, 0.8)
	if is_weak and _weak_shown <= 0.0:
		_weak_shown = 2.0
		Art.float_text(Game.combat.world(), top + Vector3(0, 0.9, 0), "WEAK!", Color("ff9f4c"), 70, 0.8, 1.0)
	Audio.sfx("crit" if is_weak else "hit", 0.12, -3.0)
	var punch := create_tween()
	punch.tween_property(model, "scale", model.scale * Vector3(1.25, 0.8, 1.25), 0.05)
	punch.tween_property(model, "scale", Vector3.ONE * (1.15 if elite else 0.95) * _base_scale_mult(), 0.1)
	var d := from_dir
	d.y = 0
	if d.length() > 0.01:
		_knock = d.normalized() * _knock_force()
	match status:
		"burn":
			_burn = 3.0 + 1.5 * Game.perk("fire_heart")
			_burn_dps = amount * 0.35
		"freeze":
			freeze(2.0 + 1.0 * Game.perk("frost_touch"))
		"stun":
			_stun = maxf(_stun, 1.5)
			Art.burst(Game.combat.world(), top + Vector3(0, 0.5, 0), Color("ffe27a"), 8, "star", 1.0, 1.0, 0.25, Vector3.ZERO)
	_poise += 1
	if state == "windup" and _poise >= _poise_limit():
		_poise = 0
		_cancel_windup()
		state = "recover"
		_st = 0.0
	if not aggro:
		_set_aggro()
	if hp <= 0:
		_die()


func _weak_key() -> String:
	return id


func _base_scale_mult() -> float:
	return 1.0


func _poise_limit() -> int:
	return 3


func _knock_force() -> float:
	return 6.0 if not elite else 3.5


func freeze(sec: float) -> void:
	_frozen = maxf(_frozen, sec)
	if _ice == null:
		_ice = MeshInstance3D.new()
		_ice.mesh = Art.sphere(0.75)
		_ice.material_override = Art.mat(Color(0.7, 0.9, 1.0, 0.45), 0.6)
		_ice.position.y = model.height * model.scale.y * 0.45
		_ice.scale = Vector3.ONE * model.scale.x * 1.1
		add_child(_ice)


func _tick_status(delta: float) -> void:
	_weak_shown -= delta
	if _burn > 0.0:
		_burn -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			var b := maxi(1, int(_burn_dps * 0.5))
			hp -= b
			_bar_show = 2.0
			Art.float_text(Game.combat.world(), global_position + Vector3(0, model.height * 0.9, 0), str(b), Color("ff9f4c"), 48, 0.6, 0.6)
			Art.burst(Game.combat.world(), global_position + Vector3(0, 0.6, 0), Color("ff8a4c"), 5, "soft", 1.5, 0.5, 0.3, Vector3(0, 2, 0))
			if hp <= 0:
				_die()
	if _frozen > 0.0:
		_frozen -= delta
		if _frozen <= 0.0 and _ice:
			_ice.queue_free()
			_ice = null
	if _stun > 0.0:
		_stun -= delta


func _update_bar(delta: float) -> void:
	_bar_show -= delta
	_bar.visible = (_bar_show > 0.0 or aggro) and not dead
	var k := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_bar_fill.scale.x = maxf(0.001, k)
	_bar_fill.position.x = -0.52 * (1.0 - k)


func _die() -> void:
	if dead:
		return
	dead = true
	_cancel_windup()
	if _ice:
		_ice.queue_free()
	_bar.visible = false
	model.set_calm(true)
	var w: Node3D = Game.combat.world()
	Audio.sfx("calm", 0.1)
	Art.burst(w, global_position + Vector3(0, 1.0, 0), Color("ff8fc8"), 18, "heart", 3.0, 1.2, 0.4, Vector3(0, 1.0, 0))
	Art.float_text(w, global_position + Vector3(0, model.height + 0.6, 0), "Cheered up!", Color("ffc2e0"), 56, 1.0, 1.2)
	var tier := 2 if behavior == "boss" else (1 if elite else 0)
	var xp_mult := 1.0 if tier == 2 else (4.0 if elite else 1.7)
	Game.combat.drop_loot(global_position, int(float(data["xp"]) * xp_mult), int(data["coins"]) * (3 if elite else 1), tier)
	Game.combat.on_calmed(self)
	var tw := create_tween()
	tw.tween_property(model, "rotation_degrees:y", model.rotation_degrees.y + 540.0, 0.9)
	tw.parallel().tween_property(model, "position:y", 1.6, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(model, "scale", Vector3.ONE * 0.05, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
