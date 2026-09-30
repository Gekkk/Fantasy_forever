class_name Player
extends CharacterBody3D
## The hero: movement plus real-time combat (wand combo, dodge-dash, skills).

signal downed

const SPEED := 5.4
const ACCEL := 40.0

var model: ModelAnim
var can_move := true
var state := "normal" # normal | attack | dash | cast | hurt | dead
var skill_cd := {}
var invuln := 0.0

var _st := 0.0
var _combo := 0
var _combo_window := 0.0
var _queued_attack := false
var _hit_done := false
var _dash_cd := 0.0
var _dash_dir := Vector3.FORWARD
var _hurt_t := 99.0
var _mp_regen := 0.0
var _hp_regen := 0.0
var _trail_t := 0.0
var _step_timer := 0.0
var _dust_timer := 0.0
var _warn_t := 0.0
var barrier := 0
var _barrier_t := 0.0
var _bubble: MeshInstance3D


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.3
	cs.shape = cap
	cs.position.y = 0.65
	add_child(cs)
	rebuild_model()


func rebuild_model() -> void:
	var rot := 0.0
	if model:
		rot = model.rotation.y
		model.queue_free()
	var dye = Rpg.robe_dye()
	var robe: Color = dye if dye != null else Game.robe_color()
	model = Models.hero(Game.state.get("style", "witch"), robe, Game.hair_color(), bool(Game.state.get("girl", true)))
	model.rotation.y = rot
	add_child(model)


func face(dir: Vector3) -> void:
	if dir.length() > 0.01:
		model.rotation.y = atan2(dir.x, dir.z)


func facing() -> Vector3:
	return Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))


func dash_ready() -> float:
	return _dash_cd


# ================================================================ input
func _unhandled_input(event: InputEvent) -> void:
	if not can_move or state == "dead":
		return
	var handled := true
	if event.is_action_pressed("attack"):
		attack()
	elif event.is_action_pressed("dash"):
		dash()
	elif event.is_action_pressed("skill1"):
		cast(0)
	elif event.is_action_pressed("skill2"):
		cast(1)
	elif event.is_action_pressed("skill3"):
		cast(2)
	elif event.is_action_pressed("skill4"):
		cast(3)
	elif event.is_action_pressed("use_muffin"):
		use_item("muffin")
	elif event.is_action_pressed("use_tea"):
		use_item("tea")
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


# ================================================================ update
func _process(delta: float) -> void:
	_st += delta
	_combo_window -= delta
	_dash_cd = maxf(0.0, _dash_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	_hurt_t += delta
	_warn_t -= delta
	if _barrier_t > 0.0:
		_barrier_t -= delta
		if _barrier_t <= 0.0:
			barrier = 0
			_show_bubble(false)
	for k in skill_cd:
		skill_cd[k] = maxf(0.0, skill_cd[k] - delta)
	_regen(delta)

	var input := Vector2.ZERO
	if can_move and state != "dead":
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(input.x, 0, input.y)
	var spd := SPEED * float(Rpg.d("move"))
	match state:
		"normal":
			var target := dir * spd
			velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
			velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
			if dir.length() > 0.1:
				model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), minf(1.0, 16.0 * delta))
		"attack":
			velocity = velocity.move_toward(Vector3.ZERO, 30.0 * delta)
			if not _hit_done and _st >= 0.1:
				_hit_done = true
				_do_hit()
			if _st >= _swing_time():
				if _queued_attack:
					_start_swing()
				else:
					state = "normal"
					_combo_window = 0.5
		"dash":
			velocity = _dash_dir * 16.0
			_trail_t -= delta
			if _trail_t <= 0.0:
				_trail_t = 0.04
				Art.burst(get_parent(), global_position + Vector3(0, 0.7, 0), Color("ffc2e0"), 3, "sparkle", 0.5, 0.35, 0.3, Vector3.ZERO)
				if Game.perk("star_trail") > 0 and Game.combat:
					Game.combat.hazard("circle", global_position, {"radius": 0.9, "delay": 0.05, "damage": int(Game.state["atk"] * 0.5),
						"friendly": true, "element": "arcane", "color": Color(1, 0.8, 0.95)})
			if _st >= 0.2:
				state = "normal"
				velocity *= 0.3
		"cast":
			velocity = velocity.move_toward(dir * spd * 0.3, ACCEL * delta)
			if _st >= 0.25:
				state = "normal"
		"hurt":
			velocity = velocity.move_toward(Vector3.ZERO, 25.0 * delta)
			if _st >= 0.22:
				state = "normal"
		"dead":
			velocity = Vector3.ZERO
	velocity.y = 0.0
	move_and_slide()
	position.y = 0.0
	if Game.combat and Game.combat.arena_active:
		position = Game.combat.clamp_to_arena(position)

	var moving := Vector2(velocity.x, velocity.z).length() > 0.5 and state == "normal"
	model.moving = moving
	model.visible = true if invuln <= 0.0 or state == "dash" else (int(invuln * 20.0) % 2 == 0)
	if moving:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.32
			Audio.sfx("step", 0.15, -10.0)
		_dust_timer -= delta
		if _dust_timer <= 0.0:
			_dust_timer = 0.25
			Art.burst(get_parent(), global_position + Vector3(0, 0.1, 0), Color(1, 1, 1, 0.5), 3, "soft", 0.6, 0.5, 0.25, Vector3(0, 0.5, 0), 60)


func _regen(delta: float) -> void:
	if state == "dead" or Game.state.is_empty():
		return
	_mp_regen += delta
	var mp_every := 0.9 if Game.flag("pearl_charm") else 1.4
	if _mp_regen >= mp_every:
		_mp_regen = 0.0
		if Game.state["mp"] < Game.state["max_mp"]:
			Game.heal(0, 1)
	if _hurt_t > 5.0 and Game.combat and not Game.combat.any_aggro_near(global_position, 10.0):
		_hp_regen += delta
		var hp_every := (0.25 if Game.perk("cozy_regen") > 0 else 0.5) / float(Rpg.d("regen"))
		if _hp_regen >= hp_every:
			_hp_regen = 0.0
			if Game.state["hp"] < Game.state["max_hp"]:
				Game.heal(1)


# ================================================================ attacks
func _aim_assist(range: float) -> void:
	if Game.combat == null:
		return
	var e: Enemy = Game.combat.nearest_enemy(global_position, range)
	if e:
		face(e.global_position - global_position)


func attack() -> void:
	if state == "attack":
		if _st > _swing_time() * 0.4:
			_queued_attack = true
		return
	if state != "normal":
		return
	_start_swing()


## Hits per combo: the elf's daggers chain four, the others three.
func _combo_len() -> int:
	return 4 if Rpg.role() == "elf" else 3


func _is_finisher() -> bool:
	return _combo == _combo_len() - 1


func _swing_time() -> float:
	var t: float
	match Rpg.role():
		"witch": t = 0.4 if _is_finisher() else 0.3
		"fairy": t = 0.46 if _is_finisher() else 0.34
		_: t = 0.36 if _is_finisher() else 0.22
	return t / float(Rpg.d("aspd"))


func _start_swing() -> void:
	_combo = (_combo + 1) % _combo_len() if (_combo_window > 0.0 or state == "attack") else 0
	state = "attack"
	_st = 0.0
	_hit_done = false
	_queued_attack = false
	var fin := _is_finisher()
	match Rpg.role():
		"witch":
			_aim_assist(13.0)
			velocity = Vector3.ZERO
			Audio.sfx("sparkle", 0.1, -4.0)
			model.action("Spellcast_Shoot", 3.0 if not fin else 2.2)
		"fairy":
			_aim_assist(5.0)
			velocity = facing() * (2.0 if not fin else 3.5)
			Audio.sfx("swing", 0.05, -3.0)
			model.action(["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal", "Spellcast_Shoot"][_combo], 2.0)
		_:
			_aim_assist(5.0)
			velocity = facing() * (4.0 if not fin else 6.0)
			Audio.sfx("swing", 0.08, -1.0)
			model.action(["Dualwield_Melee_Attack_Slice", "Dualwield_Melee_Attack_Chop", "Dualwield_Melee_Attack_Slice", "Dualwield_Melee_Attack_Stab"][_combo], 2.8 if not fin else 2.0)


func _attack_power() -> float:
	var fin := _is_finisher()
	var mult: float
	match Rpg.role():
		"witch": mult = 0.8 if fin else 0.95 # the finisher fires three
		"fairy": mult = 1.5 if fin else 0.85
		_: mult = 1.7 if fin else 0.75
	if fin:
		mult += 0.35 * Game.perk("combo_master")
	return float(Game.state["atk"]) * mult * (1.0 + 0.2 * Game.perk("sparkle_edge"))


func _do_hit() -> void:
	if Game.combat == null:
		return
	var fwd := facing()
	var base := _attack_power()
	var fin := _is_finisher()
	if fin and Game.perk("combo_master") > 0:
		Game.combat.hazard("ring", global_position, {"delay": 0.02, "active": 0.5, "damage": int(base * 0.6), "friendly": true,
			"element": "arcane", "ring_speed": 12.0, "ring_max": 4.5, "color": Color(1.0, 0.7, 0.95)})
	match Rpg.role():
		"witch":
			# Magic bolts from the wand tip; the third shot fans out three stars.
			var n := 3 if fin else 1
			for i in n:
				var d := fwd.rotated(Vector3.UP, (i - (n - 1) / 2.0) * 0.22)
				var crit := randf() < float(Rpg.d("crit"))
				var pr: Projectile = Game.combat.projectile(global_position + d * 0.7 + Vector3(0, 0.15, 0), d * 19.0,
					int(round(base * randf_range(0.9, 1.1) * (2.0 if crit else 1.0))), true,
					Color("ffe27a") if crit else Color("ff9fe0"), "arcane", "", 0.42 if not fin else 0.5, 0.75)
				pr.mp_on_hit = int(Rpg.d("mp_hit"))
		"fairy":
			# A wide petal wave; every critter it touches heals you a little.
			_slash_fx(fwd, fin, Color("7ee8b0") if not fin else Color("ff9fd0"), 3.3 if not fin else 3.8)
			var hits := _melee_hit(fwd, 3.2 if not fin else 3.7, -0.15, base)
			if hits > 0:
				var heal := mini(hits, 3) * maxi(1, int(Game.state["max_hp"] * 0.012))
				Game.heal(heal)
				Art.float_text(get_parent(), global_position + Vector3(0.3, 2.0, 0), "+%d" % heal, Color("9fffb8"), 48, 0.6, 0.8)
		_:
			# Twin daggers: short reach, very fast.
			_slash_fx(fwd, fin, Color("bfe8ff") if not fin else Color("7cc8ff"), 1.7 if not fin else 2.3)
			_melee_hit(fwd, 1.9 if not fin else 2.4, 0.2, base)


## Hits every critter in a cone in front; returns how many were hit.
func _melee_hit(fwd: Vector3, reach: float, min_dot: float, base: float) -> int:
	var hits := 0
	var crit_hit := false
	for e in Game.combat.enemies.duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector3 = e.global_position - global_position
		rel.y = 0
		if rel.length() > reach + e.hit_radius:
			continue
		if rel.length() > 0.8 and fwd.dot(rel.normalized()) < min_dot:
			continue
		var dmg := base * randf_range(0.9, 1.1)
		if randf() < float(Rpg.d("crit")):
			dmg *= 2.0
			crit_hit = true
		e.take_damage(int(round(dmg)), "arcane", rel, "")
		hits += 1
	if hits > 0:
		Game.heal(0, int(Rpg.d("mp_hit")))
		if _is_finisher() or crit_hit:
			Game.combat.main.hitstop(0.06)
			Game.combat.main.shake(0.18)
	return hits


func _slash_fx(fwd: Vector3, big: bool, col := Color("ff4fa8"), reach := 0.0) -> void:
	var w := get_parent()
	# A crescent that sweeps with the wand: diagonal, the other way, then a big flat finisher.
	var arc := MeshInstance3D.new()
	var outer := reach if reach > 0.0 else (2.6 if big else 2.1)
	arc.mesh = Art.slash_mesh(outer * 0.4, outer, deg_to_rad(200.0 if big else 150.0))
	var m := ShaderMaterial.new()
	m.shader = Art.shader("slash")
	m.set_shader_parameter("color", col)
	arc.material_override = m
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var roll: float = 0.0 if big else [0.45, -0.35, 0.3][_combo % 3]
	var flip := -1.0 if _combo % 2 == 1 else 1.0
	arc.basis = Basis.looking_at(-fwd, Vector3.UP) * Basis(Vector3.FORWARD, roll) * Basis.from_scale(Vector3(flip, 1, 1))
	arc.position = global_position + Vector3(0, 1.0 if not big else 0.6, 0) + fwd * 0.35
	w.add_child(arc)
	var dur := 0.2 if not big else 0.28
	var tw := arc.create_tween()
	tw.tween_method(func(v: float): m.set_shader_parameter("progress", v), 0.0, 1.5, dur)
	tw.parallel().tween_method(func(v: float): m.set_shader_parameter("fade", v), 1.0, 0.0, dur).set_delay(dur * 0.45)
	tw.parallel().tween_property(arc, "scale", arc.scale * 1.12, dur)
	tw.tween_callback(arc.queue_free)
	# A few sparkles fly off the tip of the swing.
	var tip := global_position + fwd.rotated(Vector3.UP, 0.6 * flip) * (1.9 if big else 1.5) + Vector3(0, 0.8, 0)
	Art.burst(w, tip, Color("fff3b0"), 4 if not big else 10, "sparkle", 2.0, 0.35, 0.25, Vector3.ZERO)
	if big:
		Art.burst(w, global_position + fwd * 1.4 + Vector3(0, 0.2, 0), Color("e0c8ff"), 12, "star", 3.0, 0.45, 0.3, Vector3.ZERO)


func dash() -> void:
	if _dash_cd > 0.0 or state == "dash" or state == "dead":
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dash_dir = Vector3(input.x, 0, input.y).normalized() if input.length() > 0.2 else facing()
	face(_dash_dir)
	state = "dash"
	_st = 0.0
	model.action("Dodge_Forward", 2.6)
	invuln = maxf(invuln, 0.34)
	_dash_cd = 0.75 * float(Rpg.d("dash"))
	Audio.sfx("swing", 0.1, 1.0)


func cast(slot: int) -> void:
	if state == "dead" or state == "dash" or state == "hurt":
		return
	var sid := Rpg.slot_skill(slot)
	if sid == "":
		_warn("No skill in this slot. Set one up in Menu > Skills.")
		return
	if skill_cd.get(sid, 0.0) > 0.0:
		Audio.sfx("ui_cancel", 0.0, -8.0)
		return
	if Game.state["mp"] < Rpg.skill_mp(sid):
		_warn("Not enough MP! Wand hits restore MP.")
		return
	Game.heal(0, -Rpg.skill_mp(sid))
	skill_cd[sid] = Rpg.skill_cd(sid)
	state = "cast"
	_st = 0.0
	var r := Rpg.rank(sid)
	var el: String = Rpg.ACTIVES[sid]["element"]
	var sp := float(Rpg.d("matk")) * Rpg.element_mult(el)
	var w := get_parent()
	model.action({"heal": "Spellcast_Raise", "starfall": "Spellcast_Long", "shield": "Spellcast_Raise", "blink": "Dodge_Forward"}.get(sid, "Spellcast_Shoot"), 2.0)
	match sid:
		"flame":
			_aim_assist(12.0)
			Audio.sfx("fire")
			var fwd := facing()
			var n := 3 + int((r - 1) / 2)
			for i in n:
				var d := fwd.rotated(Vector3.UP, (i - (n - 1) / 2.0) * 0.2)
				Game.combat.projectile(global_position + d * 0.6, d * 14.0, int(sp * (1.0 + 0.25 * (r - 1))),
					true, Color("ff8a4c"), "fire", "burn", 0.5, 1.2)
		"frost":
			Audio.sfx("ice")
			var rad := (3.2 + 0.3 * (r - 1)) * (1.0 + 0.25 * Game.perk("frost_touch"))
			Game.combat.hazard("circle", global_position, {"radius": rad, "delay": 0.05, "damage": int(sp * (0.9 + 0.2 * (r - 1))),
				"friendly": true, "element": "ice", "status": "freeze", "color": Color(0.6, 0.85, 1.0)})
			_ring_fx(rad, Color(0.75, 0.92, 1.0, 0.7))
			Art.burst(w, global_position + Vector3(0, 0.5, 0), Color("bfe8ff"), 30, "sparkle", rad * 2.0, 0.6, 0.35, Vector3.ZERO)
		"heal":
			Audio.sfx("heal")
			var amt := int((Game.state["max_hp"] * (0.3 + 0.06 * (r - 1)) + sp * 0.5) * float(Rpg.d("heal")))
			Game.heal(amt)
			Art.float_text(w, global_position + Vector3(0, 2, 0), "+%d" % amt, Color("9fffb8"), 80)
			Art.burst(w, global_position + Vector3(0, 0.3, 0), Color("9fffb8"), 26, "heart", 2.5, 1.2, 0.3, Vector3(0, 2, 0))
		"starfall":
			Audio.sfx("starfall")
			Game.combat.main.shake(0.3)
			var targets: Array = []
			for e in Game.combat.enemies:
				if is_instance_valid(e) and not e.dead and (e.global_position - global_position).length() < 11.0:
					targets.append(e.global_position)
			for i in 4 + 2 * (r - 1):
				targets.append(global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
			for pos in targets.slice(0, 10 + 2 * r):
				Game.combat.hazard("circle", pos, {"radius": 1.5, "delay": 0.45, "damage": int(sp * (1.8 + 0.3 * (r - 1))), "friendly": true,
					"element": "arcane", "status": "stun", "color": Color(1.0, 0.9, 0.4)})
				var star := Art.part(w, Art.sphere(0.35), Color("fff3b0"), pos + Vector3(0, 8, 0), Vector3.ZERO, Vector3.ONE, 3.0, false)
				var tw := star.create_tween()
				tw.tween_property(star, "position:y", 0.3, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.tween_callback(star.queue_free)
		"bolt":
			_aim_assist(14.0)
			Audio.sfx("sparkle", 0.1)
			var fwd := facing()
			var pr: Projectile = Game.combat.projectile(global_position + fwd * 0.7 + Vector3(0, 0.2, 0), fwd * 22.0,
				int(sp * (1.1 + 0.25 * (r - 1))), true, Color("ffb3e6"), "arcane", "", 0.45, 1.0)
			pr.pierce = r
		"blink":
			Audio.sfx("swing", 0.1, 2.0)
			var fwd := facing()
			var from := global_position
			var to := from + fwd * 5.0
			if Game.combat.arena_active:
				to = Game.combat.clamp_to_arena(to)
			var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.6, 0), to + Vector3(0, 0.6, 0))
			q.exclude = [get_rid()]
			var hit := get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				to = (hit["position"] as Vector3) - fwd * 0.5
				to.y = 0.0
			invuln = maxf(invuln, 0.45)
			Art.burst(w, from + Vector3(0, 0.8, 0), Color("fff3b0"), 20, "sparkle", 2.5, 0.5, 0.35, Vector3.ZERO)
			global_position = to
			Game.combat.hazard("circle", to, {"radius": 2.4, "delay": 0.05, "damage": int(sp * (1.0 + 0.4 * (r - 1))), "friendly": true,
				"element": "arcane", "color": Color(1.0, 0.95, 0.6)})
			_ring_fx(2.4, Color(1.0, 0.95, 0.6, 0.7))
		"thunder":
			Audio.sfx("starfall", 0.1, -2.0)
			var hit_list: Array = []
			var cur := global_position
			for i in 3 + r:
				var best: Enemy = null
				var bd := 9.0
				for e in Game.combat.enemies:
					if not is_instance_valid(e) or e.dead or hit_list.has(e):
						continue
					var dd := cur.distance_to(e.global_position)
					if dd < bd:
						bd = dd
						best = e
				if best == null:
					break
				_zap(cur + Vector3(0, 1.0, 0), best.global_position + Vector3(0, 0.8, 0))
				best.take_damage(int(sp * (1.2 + 0.25 * (r - 1)) * pow(0.9, i)), "arcane", best.global_position - cur, "stun")
				hit_list.append(best)
				cur = best.global_position
			if hit_list.is_empty():
				_zap(global_position + Vector3(0, 1.0, 0), global_position + facing() * 4.0 + Vector3(0, 0.3, 0))
			Game.combat.main.shake(0.2)
		"shield":
			Audio.sfx("buff")
			barrier = int(Game.state["max_hp"] * (0.25 + 0.1 * (r - 1)))
			_barrier_t = 6.0
			_show_bubble(true)
			Art.float_text(w, global_position + Vector3(0, 2, 0), "Shield %d" % barrier, Color("aee0ff"), 72)


func _ring_fx(r: float, c: Color) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = Art.torus(0.9, 1.0)
	ring.material_override = Art.mat(c, 2.0)
	ring.position = global_position + Vector3(0, 0.2, 0)
	ring.scale = Vector3(0.3, 0.2, 0.3)
	get_parent().add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3(r, 0.2, r), 0.25)
	tw.tween_property(ring, "scale", Vector3(r * 1.05, 0.01, r * 1.05), 0.2)
	tw.tween_callback(ring.queue_free)


## A zig-zag lightning bolt between two points.
func _zap(a: Vector3, b: Vector3) -> void:
	var w := get_parent()
	var pts: Array = [a]
	for i in range(1, 6):
		var t := i / 6.0
		pts.append(a.lerp(b, t) + Vector3(randf_range(-0.35, 0.35), randf_range(-0.25, 0.25), randf_range(-0.35, 0.35)))
	pts.append(b)
	for i in pts.size() - 1:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.09, 0.09, p0.distance_to(p1))
		seg.mesh = bm
		seg.material_override = Art.mat(Color("fff6a8"), 4.0)
		w.add_child(seg)
		seg.global_position = (p0 + p1) / 2.0
		seg.look_at(p1, Vector3.UP if absf((p1 - p0).normalized().y) < 0.95 else Vector3.RIGHT)
		var tw := seg.create_tween()
		tw.tween_interval(0.12)
		tw.tween_property(seg, "scale", Vector3(0.1, 0.1, 1), 0.1)
		tw.tween_callback(seg.queue_free)
	Art.burst(w, b, Color("fff6a8"), 10, "sparkle", 2.5, 0.35, 0.3, Vector3.ZERO)


func _show_bubble(on: bool) -> void:
	if on and _bubble == null:
		_bubble = MeshInstance3D.new()
		_bubble.mesh = Art.sphere(1.0)
		_bubble.material_override = Art.mat(Color(0.7, 0.88, 1.0, 0.28), 0.8, 0.9)
		_bubble.position.y = 0.8
		_bubble.scale = Vector3(0.9, 1.0, 0.9)
		add_child(_bubble)
	elif not on and _bubble:
		_bubble.queue_free()
		_bubble = null


func use_item(id: String) -> void:
	if Game.item_count(id) <= 0:
		_warn("No %s left! Buy more at the cafe." % Game.ITEMS[id]["name"])
		return
	if id == "muffin" and Game.state["hp"] >= Game.state["max_hp"]:
		_warn("You're already full of energy!")
		return
	Game.state["items"][id] = Game.item_count(id) - 1
	if id == "muffin":
		Game.heal(50)
		Audio.sfx("heal")
		Art.float_text(get_parent(), global_position + Vector3(0, 2, 0), "+50 HP", Color("9fffb8"), 72)
	else:
		Game.heal(0, 15)
		Audio.sfx("buff")
		Art.float_text(get_parent(), global_position + Vector3(0, 2, 0), "+15 MP", Color("9fd0ff"), 72)


func _warn(text: String) -> void:
	if _warn_t > 0.0:
		return
	_warn_t = 1.5
	Audio.sfx("ui_cancel", 0.0, -6.0)
	if Game.combat:
		Game.combat.main.ui.toast(text)


# ================================================================ damage
## Returns true if the hit landed.
func hurt(dmg: int, from: Vector3) -> bool:
	if invuln > 0.0 or state == "dead" or not can_move:
		return false
	dmg = Rpg.mitigate(dmg)
	if barrier > 0:
		var soak := mini(barrier, dmg)
		barrier -= soak
		dmg -= soak
		Art.float_text(get_parent(), global_position + Vector3(-0.3, 2.1, 0), "(%d)" % soak, Color("aee0ff"), 56)
		if barrier <= 0:
			_show_bubble(false)
		if dmg <= 0:
			invuln = 0.4
			Audio.sfx("ice", 0.1, -6.0)
			return true
	Game.heal(-dmg)
	invuln = 0.8
	_hurt_t = 0.0
	var away := global_position - from
	away.y = 0
	velocity = (away.normalized() if away.length() > 0.01 else -facing()) * 7.0
	state = "hurt"
	_st = 0.0
	model.action("Hit_A", 1.6)
	Audio.sfx("hurt", 0.1)
	Art.float_text(get_parent(), global_position + Vector3(0.2, 1.9, 0), "-%d" % dmg, Color("ff8fa3"), 72)
	Art.burst(get_parent(), global_position + Vector3(0, 1, 0), Color.WHITE, 10, "sparkle", 3.0, 0.4, 0.3)
	if Game.combat:
		Game.combat.main.shake(0.25)
	if Game.state["hp"] <= 0:
		state = "dead"
		if model is KayChar:
			model.action("Death_A", 1.0, true)
		else:
			var tw := create_tween()
			tw.tween_property(model, "rotation_degrees:z", 80.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		downed.emit()
	return true


func revive() -> void:
	state = "normal"
	invuln = 1.5
	model.rotation_degrees.z = 0.0
	model.clear_action()
