class_name Boss
extends Enemy
## Pattern-based boss AI for the Printer King and the Monday Monster.
## Each pattern is a short coroutine with telegraphed attacks; after slams
## the boss is dizzy for a moment and takes extra damage.

var phase := 1
var _busy := false
var _pattern_i := 0
var _between := 1.4
var _minions: Array = []


func _ready() -> void:
	super._ready()
	if id == "monday":
		model.scale = Vector3.ONE * 0.85
	else:
		model.scale = Vector3.ONE * 2.1
		# A paper crown for the Printer King.
		var crown := Art.node(model, "Crown", Vector3(0, 0.85, 0))
		Art.part(crown, Art.cyl(0.3, 0.32, 0.18, 10), Color("ffd36b"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 0.8)
		for i in 5:
			var a := i * TAU / 5
			Art.part(crown, Art.cyl(0.0, 0.07, 0.18), Color("ffd36b"), Vector3(cos(a) * 0.28, 0.16, sin(a) * 0.28), Vector3.ZERO, Vector3.ONE, 0.8)
	hit_radius = 1.3
	_bar.visible = false
	aggro = false


func _base_scale_mult() -> float:
	return 0.85 / 0.95 if id == "monday" else 2.1 / 0.95


func _poise_limit() -> int:
	return 999


func _knock_force() -> float:
	return 0.6


func _weak_key() -> String:
	return id + ("_2" if phase == 2 else "")


func _update_bar(_delta: float) -> void:
	if aggro and not dead:
		Game.combat.main.ui.boss_bar(display_name(), float(hp) / float(max_hp), weak, Game.state["known_weak"].get(_weak_key(), false))


func _process(delta: float) -> void:
	if dead:
		return
	_tick_status(delta)
	position += _knock * delta
	_knock = _knock.move_toward(Vector3.ZERO, 22.0 * delta)
	_update_bar(delta)
	var p: Player = Game.combat.player()
	if p == null or not _can_act() or not aggro:
		model.moving = false
		return
	if phase == 1 and hp <= max_hp / 2:
		_enter_phase2()
	if _busy:
		return
	var to_p := p.global_position - global_position
	to_p.y = 0
	_face(to_p, delta)
	_between -= delta * (1.4 if phase == 2 else 1.0)
	var slow := 0.4 if _frozen > 0.0 else 1.0
	if _stun > 0.0:
		model.moving = false
		return
	if to_p.length() > 3.0:
		_move(to_p, speed * slow, delta)
	else:
		model.moving = false
	_clamp_position()
	if _between <= 0.0:
		_run_pattern()


func _clamp_position() -> void:
	if Game.combat.arena_active:
		position = Game.combat.clamp_to_arena(position)
	else:
		var a := area
		position.x = clampf(position.x, a.position.x, a.end.x)
		position.z = clampf(position.z, a.position.y, a.end.y)
	position.y = 0.0


func _enter_phase2() -> void:
	phase = 2
	if id == "monday":
		weak = "fire"
	Audio.sfx("alarm")
	Art.burst(Game.combat.world(), global_position + Vector3(0, 2, 0), Color("ff6b8a"), 40, "sparkle", 6, 1.2, 0.45)
	Art.float_text(Game.combat.world(), global_position + Vector3(0, 4, 0), "It's getting angry!", Color("ff9fb0"), 80, 1.2, 1.6)
	Game.combat.main.ui.toast("%s is enraged!%s" % [display_name(), " Its weakness changed!" if id == "monday" else ""], "fire")
	Game.combat.main.shake(0.5)


func _pause(sec: float) -> bool:
	await get_tree().create_timer(sec).timeout
	return not dead and is_inside_tree() and _can_act()


func _run_pattern() -> void:
	_busy = true
	var list: Array
	if id == "monday":
		list = ["shockwave", "slam", "summon", "shockwave", "slam"] if phase == 1 else ["hands", "slam", "rain", "shockwave", "summon", "hands", "slam"]
	else:
		list = ["storm", "slam", "summon", "storm", "slam"] if phase == 1 else ["charge", "storm", "slam", "summon", "charge", "slam"]
	var pattern: String = list[_pattern_i % list.size()]
	_pattern_i += 1
	match pattern:
		"shockwave": await _shockwave()
		"slam": await _slam()
		"summon": await _summon()
		"hands": await _clock_hands()
		"rain": await _alarm_rain()
		"storm": await _paper_storm()
		"charge": await _charge()
	_between = randf_range(0.8, 1.4)
	_busy = false


func _windup_shake(sec: float) -> bool:
	var tw := create_tween()
	for i in int(sec / 0.08):
		tw.tween_property(model, "position:x", 0.08 if i % 2 == 0 else -0.08, 0.04)
	tw.tween_property(model, "position:x", 0.0, 0.04)
	return await _pause(sec)


func _shockwave() -> void:
	Audio.sfx("alarm", 0.0, -2.0)
	Art.float_text(Game.combat.world(), global_position + Vector3(0, 3.6, 0), "RIIIING!", Color("ffe27a"), 80, 0.8, 1.0)
	if not await _windup_shake(0.8):
		return
	var waves := 2 if phase == 2 else 1
	for i in waves:
		Game.combat.hazard("ring", global_position, {"delay": 0.05, "active": 3.0, "damage": dmg, "ring_speed": 6.5,
			"ring_max": 15.0, "color": Color(1.0, 0.85, 0.3)})
		Game.combat.main.shake(0.25)
		if not await _pause(0.9):
			return
	await _pause(0.6)


func _slam() -> void:
	var p: Player = Game.combat.player()
	if p == null:
		return
	var target := p.global_position
	var r := 3.0 if id == "monday" else 2.6
	var h := Game.combat.hazard("circle", target, {"radius": r, "delay": 1.1, "damage": int(dmg * 1.3)})
	var tw := create_tween()
	tw.tween_property(self, "position:y", 4.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", Vector3(target.x, 4.0, target.z), 0.3)
	tw.tween_property(self, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if not await _pause(1.12):
		return
	position.y = 0.0
	Audio.sfx("hurt", 0.0, 2.0)
	Game.combat.main.shake(0.6)
	Art.burst(Game.combat.world(), global_position + Vector3(0, 0.3, 0), Color("fff4e0"), 30, "soft", 5, 0.6, 0.5)
	if id == "monday" and phase == 2:
		Game.combat.hazard("ring", global_position, {"delay": 0.05, "active": 1.4, "damage": dmg, "ring_speed": 7.0, "ring_max": 8.0,
			"color": Color(1.0, 0.85, 0.3)})
	# Dizzy after landing: the moment to strike!
	_stun = 1.4
	Art.float_text(Game.combat.world(), global_position + Vector3(0, 3.2, 0), "Dizzy!", Color("ffe27a"), 64, 0.8, 1.0)
	Art.burst(Game.combat.world(), global_position + Vector3(0, 2.8, 0), Color("ffe27a"), 10, "star", 1.2, 1.2, 0.3, Vector3.ZERO)
	await _pause(1.4)


func _summon() -> void:
	_minions = _minions.filter(func(m): return is_instance_valid(m) and not m.dead)
	if _minions.size() >= 3:
		if id == "monday":
			await _shockwave()
		else:
			await _paper_storm()
		return
	Audio.sfx("buff")
	var kind := "tick" if id == "monday" else "paper"
	var n := 3 if id == "monday" else 2
	for i in n:
		var a := TAU * i / n + randf()
		var pos := global_position + Vector3(cos(a), 0, sin(a)) * 2.5
		var ar := area if not Game.combat.arena_active else Rect2(Game.combat.arena_center.x - 8, Game.combat.arena_center.z - 8, 16, 16)
		var m := Game.combat.spawn_enemy(kind, pos, ar, "", true)
		_minions.append(m)
		Art.burst(Game.combat.world(), pos + Vector3(0, 0.6, 0), Color("ffd36b"), 12, "sparkle", 2, 0.6, 0.3)
	await _pause(1.0)


func _clock_hands() -> void:
	Audio.sfx("alarm", 0.0, -4.0)
	Art.float_text(Game.combat.world(), global_position + Vector3(0, 3.6, 0), "Tick... tock...", Color("ffe27a"), 64, 0.8, 1.0)
	var base := randf() * TAU
	for i in 2:
		var a := base + PI * i
		Game.combat.hazard("sweep", global_position, {"dir": Vector3(sin(a), 0, cos(a)), "length": 11.0, "width": 1.1,
			"delay": 1.3, "active": 3.4, "damage": dmg, "sweep_speed": 1.1, "color": Color(0.6, 0.4, 1.0)})
	await _pause(4.8)


func _alarm_rain() -> void:
	var p: Player = Game.combat.player()
	if p == null:
		return
	Audio.sfx("alarm", 0.0, -8.0)
	for i in 6:
		var off := Vector3(randf_range(-3.5, 3.5), 0, randf_range(-3.5, 3.5)) if i > 0 else Vector3.ZERO
		Game.combat.hazard("circle", p.global_position + off, {"radius": 1.4, "delay": 1.0 + i * 0.12, "damage": dmg,
			"color": Color(1.0, 0.8, 0.3)})
	await _pause(1.9)


func _paper_storm() -> void:
	if not await _windup_shake(0.6):
		return
	var count := 14 if phase == 2 else 10
	for wave in 2:
		for i in count:
			var a := TAU * i / count + wave * PI / count
			var d := Vector3(sin(a), 0, cos(a))
			Game.combat.projectile(global_position + d * 1.2, d * 6.0, dmg, false, Color("fff4e0"), "none", "", 0.35, 3.0)
		Audio.sfx("swing", 0.2)
		if not await _pause(0.7):
			return


func _charge() -> void:
	var p: Player = Game.combat.player()
	if p == null:
		return
	var to := p.global_position - global_position
	to.y = 0
	_aim = to.normalized()
	Game.combat.hazard("line", global_position, {"dir": _aim, "length": 11.0, "width": 2.2, "delay": 0.8, "damage": 0})
	if not await _pause(0.8):
		return
	Audio.sfx("swing")
	var t := 0.0
	while t < 0.55:
		var dt := get_process_delta_time()
		position += _aim * 16.0 * dt
		_clamp_position()
		var rel := p.global_position - global_position
		rel.y = 0
		if rel.length() < 1.6:
			p.hurt(int(dmg * 1.2), global_position)
		await get_tree().process_frame
		if dead:
			return
		t += dt
	_stun = 0.8
	await _pause(0.8)


func _die() -> void:
	for m in _minions:
		if is_instance_valid(m) and not m.dead:
			m._die()
	Game.combat.main.ui.boss_bar("", 0.0, "", false)
	super._die()
