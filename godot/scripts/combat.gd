class_name Combat
extends Node
## Real-time combat hub: keeps track of critters, spawns attacks and loot,
## handles XP/level-ups and "arena" fights where a magic barrier locks you in.

signal enemy_calmed(e: Enemy)
signal arena_cleared

var main
var enemies: Array = []

var arena_active := false
var arena_center := Vector3.ZERO
var arena_radius := 8.0
var _arena_waves: Array = []
var _arena_nodes: Array = []
var _arena_barrier: Node3D


func _init(m) -> void:
	main = m
	Game.combat = self


func player() -> Player:
	if main.player and is_instance_valid(main.player) and main.mode != main.Mode.TITLE:
		return main.player
	return null


func world() -> Node3D:
	return main.world


func clear() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	end_arena(false)


# ---------------------------------------------------------------- spawning
func spawn_enemy(id: String, pos: Vector3, area: Rect2, uid := "", aggro := false, elite := false) -> Enemy:
	var e: Enemy
	if id == "monday" or id == "printer_king":
		e = Boss.new()
	else:
		e = Enemy.new()
	e.id = id
	e.area = area
	e.uid = uid
	e.elite = elite
	e.position = pos
	world().add_child(e)
	enemies.append(e)
	if aggro:
		e.aggro = true
	return e


func projectile(from: Vector3, vel: Vector3, dmg: int, friendly: bool, color: Color, elem := "none", status := "", radius := 0.4, life := 2.2) -> Projectile:
	var p := Projectile.new()
	p.velocity = vel
	p.damage = dmg
	p.friendly = friendly
	p.color = color
	p.element = elem
	p.status = status
	p.radius = radius
	p.lifetime = life
	p.position = from
	world().add_child(p)
	return p


func hazard(shape: String, pos: Vector3, opts: Dictionary) -> Hazard:
	var h := Hazard.new()
	h.shape = shape
	for k in opts:
		h.set(k, opts[k])
	h.position = pos
	world().add_child(h)
	return h


func drop_loot(pos: Vector3, xp: int, coins: int, tier := 0) -> void:
	# Gear: sometimes from critters, often from elites, always from bosses.
	var ilvl := int(Game.state["level"]) + tier
	var find := float(Rpg.d("find"))
	match tier:
		0:
			if randf() < 0.08 * find:
				_pickup("item", pos, 0, Rpg.random_item(ilvl, 0.1 * (find - 1.0)))
		1:
			if randf() < 0.55 * find:
				_pickup("item", pos, 0, Rpg.random_item(ilvl, 0.3, 1))
		2:
			for i in 2:
				_pickup("item", pos, 0, Rpg.random_item(ilvl, 0.6, 2))
	var orbs := clampi(xp / 3, 1, 8)
	for i in orbs:
		_pickup("xp", pos, xp / orbs + (1 if i < xp % orbs else 0))
	var coin_mult := 1.0 + 0.5 * Game.perk("lucky_star")
	var total := int(round(coins * coin_mult))
	for i in clampi(total / 2, 1, 6):
		_pickup("coin", pos, maxi(1, total / clampi(total / 2, 1, 6)))
	var r := randf()
	var muffin_chance := 0.07 + 0.05 * Game.perk("lucky_star")
	if r < muffin_chance:
		_pickup("muffin", pos, 1)
	elif r < muffin_chance + 0.05:
		_pickup("tea", pos, 1)
	elif r < muffin_chance + 0.2:
		_pickup("heart", pos, 12)


func _pickup(kind: String, pos: Vector3, value: int, item := {}) -> void:
	var p := Pickup.new()
	p.kind = kind
	p.value = value
	p.item = item
	p.position = pos
	world().add_child.call_deferred(p)


# ---------------------------------------------------------------- xp
func gain_xp(n: int) -> void:
	var gained := Game.add_xp(n)
	if gained > 0:
		Audio.sfx("level_up")
		var pl := player()
		if pl:
			Art.burst(world(), pl.global_position + Vector3(0, 1, 0), Color("ffe27a"), 40, "star", 5, 1.3, 0.4, Vector3(0, 1, 0))
			Art.float_text(world(), pl.global_position + Vector3(0, 2.4, 0), "LEVEL UP!", Color("ffe27a"), 90, 1.5, 1.6)
		main.ui.toast("Level %d! +%d attribute and +%d skill points (Menu)" % [Game.state["level"],
			Rpg.ATTR_PER_LEVEL * gained, Rpg.SKILL_POINTS_PER_LEVEL * gained], "gem")
		main.ui.refresh()


func on_calmed(e: Enemy) -> void:
	enemies.erase(e)
	var fid: String = e.id
	Game.state["friends"][fid] = int(Game.state["friends"].get(fid, 0)) + 1
	enemy_calmed.emit(e)
	main.story.on_enemy_calmed(e)
	if arena_active:
		_check_arena()


func nearest_enemy(from: Vector3, max_dist: float) -> Enemy:
	var best: Enemy = null
	var bd := max_dist
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = (e.global_position - from).length()
		if d < bd:
			bd = d
			best = e
	return best


func any_aggro_near(from: Vector3, dist: float) -> bool:
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.aggro and (e.global_position - from).length() < dist:
			return true
	return false


# ---------------------------------------------------------------- arenas
## Locks the player inside a glowing ring and sends waves of critters.
## waves: Array of Arrays of enemy ids. Await `arena_cleared` for the win.
func start_arena(center: Vector3, radius: float, waves: Array) -> void:
	arena_active = true
	arena_center = center
	arena_radius = radius
	_arena_waves = waves.duplicate(true)
	_arena_barrier = Node3D.new()
	_arena_barrier.position = center
	world().add_child(_arena_barrier)
	var ring := MeshInstance3D.new()
	ring.mesh = Art.cyl(radius, radius, 2.4, 48)
	var m := Hazard._mat(Color(0.8, 0.5, 1.0, 0.18))
	ring.material_override = m
	ring.position.y = 1.2
	_arena_barrier.add_child(ring)
	var top := MeshInstance3D.new()
	top.mesh = Art.torus(radius - 0.1, radius + 0.1)
	top.material_override = Art.mat(Color("e0b8ff"), 2.0)
	top.position.y = 0.05
	top.scale = Vector3(1, 0.2, 1)
	_arena_barrier.add_child(top)
	Art.ambient(_arena_barrier, Vector3(0, 1.2, 0), Vector3(radius, 1.0, radius), Color("e0b8ff"), 40, "sparkle", 0.25, 2.0)
	Audio.sfx("alarm", 0.0, -6.0)
	_next_wave()


func _next_wave() -> void:
	if _arena_waves.is_empty():
		end_arena(true)
		return
	var wave: Array = _arena_waves.pop_front()
	var n := wave.size()
	for i in n:
		var a := TAU * i / n + randf() * 0.4
		var pos := arena_center + Vector3(cos(a), 0, sin(a)) * arena_radius * 0.6
		var area := Rect2(arena_center.x - arena_radius, arena_center.z - arena_radius, arena_radius * 2, arena_radius * 2)
		var e := spawn_enemy(wave[i], pos, area, "", true)
		_arena_nodes.append(e)
		Art.burst(world(), pos + Vector3(0, 0.8, 0), Color("e0b8ff"), 20, "sparkle", 3, 0.8, 0.35)


func _check_arena() -> void:
	for e in _arena_nodes:
		if is_instance_valid(e) and not e.dead:
			return
	_arena_nodes.clear()
	if _arena_waves.is_empty():
		end_arena(true)
	else:
		main.ui.toast("Here comes another wave!", "star_gold")
		get_tree().create_timer(1.2).timeout.connect(_next_wave)


func end_arena(won: bool) -> void:
	if not arena_active:
		return
	arena_active = false
	if is_instance_valid(_arena_barrier):
		var b := _arena_barrier
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector3(1.2, 0.01, 1.2), 0.4)
		tw.tween_callback(b.queue_free)
	_arena_barrier = null
	_arena_waves.clear()
	_arena_nodes.clear()
	if won:
		Audio.sfx("perfect")
		arena_cleared.emit()


func clamp_to_arena(p: Vector3) -> Vector3:
	if not arena_active:
		return p
	var d := p - arena_center
	d.y = 0
	if d.length() > arena_radius - 0.5:
		d = d.normalized() * (arena_radius - 0.5)
		return Vector3(arena_center.x + d.x, p.y, arena_center.z + d.z)
	return p
