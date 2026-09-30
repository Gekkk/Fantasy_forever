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
	model = Models.hero(Game.state.get("style", "witch"), Game.robe_color(), Game.hair_color())
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
	for k in skill_cd:
		skill_cd[k] = maxf(0.0, skill_cd[k] - delta)
	_regen(delta)

	var input := Vector2.ZERO
	if can_move and state != "dead":
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(input.x, 0, input.y)
	var spd := SPEED * (1.0 + 0.12 * Game.perk("swift"))
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
		var hp_every := 0.25 if Game.perk("cozy_regen") > 0 else 0.5
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


func _swing_time() -> float:
	return 0.44 if _combo == 2 else 0.3


func _start_swing() -> void:
	_combo = (_combo + 1) % 3 if (_combo_window > 0.0 or state == "attack") else 0
	state = "attack"
	_st = 0.0
	_hit_done = false
	_queued_attack = false
	_aim_assist(5.5)
	velocity = facing() * (5.5 if _combo == 2 else 3.5)
	Audio.sfx("swing", 0.05, -2.0)
	var arm: Node3D = model.find_child("ArmR", true, false)
	if arm:
		var tw := create_tween()
		tw.tween_property(arm, "rotation:x", -2.4, 0.07)
		tw.tween_property(arm, "rotation:x", 0.7, 0.1)
		tw.tween_property(arm, "rotation:x", 0.0, 0.12)


func _do_hit() -> void:
	var reach := 2.2 + (0.5 if _combo == 2 else 0.0)
	var power := 1.8 if _combo == 2 else 1.0
	var base := float(Game.state["atk"]) * power * (1.0 + 0.2 * Game.perk("sparkle_edge"))
	var fwd := facing()
	_slash_fx(fwd, _combo == 2)
	if Game.combat == null:
		return
	var hits := 0
	var crit_hit := false
	for e in Game.combat.enemies.duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector3 = e.global_position - global_position
		rel.y = 0
		if rel.length() > reach + e.hit_radius:
			continue
		if rel.length() > 0.8 and fwd.dot(rel.normalized()) < 0.2:
			continue
		var dmg := base * randf_range(0.9, 1.1)
		if randf() < 0.12 * Game.perk("crit"):
			dmg *= 2.0
			crit_hit = true
		e.take_damage(int(round(dmg)), "arcane", rel, "")
		hits += 1
	if hits > 0:
		Game.heal(0, 1 + Game.perk("mana_bloom"))
		if _combo == 2 or crit_hit:
			Game.combat.main.hitstop(0.06)
			Game.combat.main.shake(0.18)


func _slash_fx(fwd: Vector3, big: bool) -> void:
	var w := get_parent()
	var arc := MeshInstance3D.new()
	arc.mesh = Art.torus(1.1, 1.5 if not big else 1.9)
	arc.material_override = Art.mat(Color(1.0, 0.75, 0.92, 0.55), 1.5)
	arc.scale = Vector3(1, 0.08, 1)
	arc.position = global_position + fwd * 0.7 + Vector3(0, 0.8, 0)
	w.add_child(arc)
	var tw := arc.create_tween()
	tw.tween_property(arc, "scale", Vector3(1.4, 0.02, 1.4), 0.16)
	tw.tween_callback(arc.queue_free)
	for i in 5:
		var a := -0.9 + i * 0.45
		var p := global_position + fwd.rotated(Vector3.UP, a) * (1.4 if not big else 1.9) + Vector3(0, 0.8, 0)
		Art.burst(w, p, Color("fff3b0") if i % 2 else Color("ffb3d9"), 3, "sparkle", 1.2, 0.35, 0.3, Vector3.ZERO)


func dash() -> void:
	if _dash_cd > 0.0 or state == "dash" or state == "dead":
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dash_dir = Vector3(input.x, 0, input.y).normalized() if input.length() > 0.2 else facing()
	face(_dash_dir)
	state = "dash"
	_st = 0.0
	invuln = maxf(invuln, 0.34)
	_dash_cd = 0.75 * (1.0 - 0.35 * Game.perk("quick_step"))
	Audio.sfx("swing", 0.1, 1.0)


func cast(slot: int) -> void:
	if state == "dead" or state == "dash" or state == "hurt":
		return
	var sid: String = Game.SKILL_ORDER[slot]
	var sk: Dictionary = Game.SKILLS[sid]
	if not Game.state["spells"].has(sid):
		_warn("You haven't learned that spell yet!")
		return
	if skill_cd.get(sid, 0.0) > 0.0:
		Audio.sfx("ui_cancel", 0.0, -8.0)
		return
	if Game.state["mp"] < int(sk["mp"]):
		_warn("Not enough MP! Wand hits restore MP.")
		return
	Game.heal(0, -int(sk["mp"]))
	skill_cd[sid] = float(sk["cd"])
	state = "cast"
	_st = 0.0
	var atk := float(Game.state["atk"])
	var w := get_parent()
	var arm: Node3D = model.find_child("ArmR", true, false)
	if arm:
		var tw := create_tween()
		tw.tween_property(arm, "rotation:x", -2.6, 0.08)
		tw.tween_interval(0.15)
		tw.tween_property(arm, "rotation:x", 0.0, 0.15)
	match sid:
		"flame":
			_aim_assist(12.0)
			Audio.sfx("fire")
			var fwd := facing()
			for i in 3:
				var d := fwd.rotated(Vector3.UP, (i - 1) * 0.22)
				Game.combat.projectile(global_position + d * 0.6, d * 14.0, int(atk * 1.3 * (1.0 + 0.3 * Game.perk("fire_heart"))),
					true, Color("ff8a4c"), "fire", "burn", 0.5, 1.2)
		"frost":
			Audio.sfx("ice")
			var r := 3.4 * (1.0 + 0.25 * Game.perk("frost_touch"))
			Game.combat.hazard("circle", global_position, {"radius": r, "delay": 0.05, "damage": int(atk * 1.1),
				"friendly": true, "element": "ice", "status": "freeze", "color": Color(0.6, 0.85, 1.0)})
			var ring := MeshInstance3D.new()
			ring.mesh = Art.torus(0.9, 1.0)
			ring.material_override = Art.mat(Color(0.75, 0.92, 1.0, 0.7), 2.0)
			ring.position = global_position + Vector3(0, 0.2, 0)
			ring.scale = Vector3(0.3, 0.2, 0.3)
			w.add_child(ring)
			var tw := ring.create_tween()
			tw.tween_property(ring, "scale", Vector3(r, 0.2, r), 0.25)
			tw.tween_property(ring, "scale", Vector3(r * 1.05, 0.01, r * 1.05), 0.2)
			tw.tween_callback(ring.queue_free)
			Art.burst(w, global_position + Vector3(0, 0.5, 0), Color("bfe8ff"), 30, "sparkle", r * 2.0, 0.6, 0.35, Vector3.ZERO)
		"heal":
			Audio.sfx("heal")
			var amt := int(Game.state["max_hp"] * 0.35) + 10
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
			for i in 4:
				targets.append(global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
			for pos in targets.slice(0, 12):
				Game.combat.hazard("circle", pos, {"radius": 1.5, "delay": 0.45, "damage": int(atk * 2.2), "friendly": true,
					"element": "arcane", "status": "stun", "color": Color(1.0, 0.9, 0.4)})
				var star := Art.part(w, Art.sphere(0.35), Color("fff3b0"), pos + Vector3(0, 8, 0), Vector3.ZERO, Vector3.ONE, 3.0, false)
				var tw := star.create_tween()
				tw.tween_property(star, "position:y", 0.3, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.tween_callback(star.queue_free)


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
	Game.heal(-dmg)
	invuln = 0.8
	_hurt_t = 0.0
	var away := global_position - from
	away.y = 0
	velocity = (away.normalized() if away.length() > 0.01 else -facing()) * 7.0
	state = "hurt"
	_st = 0.0
	Audio.sfx("hurt", 0.1)
	Art.float_text(get_parent(), global_position + Vector3(0.2, 1.9, 0), "-%d" % dmg, Color("ff8fa3"), 72)
	Art.burst(get_parent(), global_position + Vector3(0, 1, 0), Color.WHITE, 10, "sparkle", 3.0, 0.4, 0.3)
	if Game.combat:
		Game.combat.main.shake(0.25)
	if Game.state["hp"] <= 0:
		state = "dead"
		var tw := create_tween()
		tw.tween_property(model, "rotation_degrees:z", 80.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		downed.emit()
	return true


func revive() -> void:
	state = "normal"
	invuln = 1.5
	model.rotation_degrees.z = 0.0
