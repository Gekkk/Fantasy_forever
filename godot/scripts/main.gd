extends Node
## Top-level flow: title screen, exploring, battles, cutscenes and saving.

enum Mode { TITLE, EXPLORE, SCRIPT, BATTLE, MENU }

const CAM_OFFSET := Vector3(0, 11.0, 11.5)
const MUSIC := {"city": "town", "tower": "tower", "roof": "tower"}

var mode := Mode.TITLE
var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var cam: Camera3D
var world: World
var player: Player
var follower: ModelAnim
var critters: Array = []
var ui: UI
var touch: TouchControls
var title: Control
var menu: Control
var story: Story

var _auto_inside := {}
var _nearest := {}
var _cooldown := 0.0
var _swing_cd := 0.0
var _title_t := 0.0
var _autotest := false


func _ready() -> void:
	_autotest = OS.get_cmdline_user_args().has("--autotest")
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = Art.shader("sky")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_blur = 1.5
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 40
	add_child(cam)

	ui = UI.new()
	add_child(ui)
	touch = TouchControls.new()
	touch.visible = false
	ui.add_child(touch)
	ui.menu_button.pressed.connect(open_menu)
	story = Story.new(self)

	title = TitleScreen.new()
	ui.add_child(title)
	title.start_new.connect(_on_start_new)
	title.continue_game.connect(_on_continue)
	title.preview_changed.connect(_on_preview_changed)
	_show_title()
	if _autotest:
		var t = load("res://tests/autotest.gd").new()
		t.main = self
		add_child(t)


# ================================================================ title
func _show_title() -> void:
	mode = Mode.TITLE
	ui.show_hud(false)
	touch.visible = false
	Game.new_game(Game.DEFAULT_NAME, "witch", 0, 0)
	if Game.has_save():
		var s := Game.state.duplicate(true)
		if Game.load_game():
			pass
		else:
			Game.state = s
	_load_world("city")
	player = Player.new()
	player.can_move = false
	world.add_child(player)
	player.position = Vector3(-15, 0, -6.2)
	player.face(Vector3(0.3, 0, 1))
	title.visible = true
	title.call("refresh", Game.has_save())
	Audio.play_music("town")


func _on_preview_changed(style: String, robe: int, hair: int) -> void:
	Game.state["style"] = style
	Game.state["robe"] = robe
	Game.state["hair"] = hair
	player.rebuild_model()
	player.face(Vector3(0.3, 0, 1))


func _on_start_new(hero_name: String, style: String, robe: int, hair: int) -> void:
	Game.new_game(hero_name, style, robe, hair)
	title.visible = false
	await _enter_game(true)


func _on_continue() -> void:
	if not Game.load_game():
		return
	title.visible = false
	await _enter_game(false)


func _enter_game(is_new: bool) -> void:
	mode = Mode.SCRIPT
	Audio.sfx("sparkle")
	await ui.fade_out(0.4)
	var p = Game.state["pos"]
	await load_map(Game.state["map"], Vector3(float(p[0]), 0, float(p[1]) if p.size() == 2 else float(p[2])), false)
	ui.show_hud(true)
	ui.refresh()
	touch.visible = DisplayServer.is_touchscreen_available()
	await ui.fade_in(0.5)
	if is_new:
		await run_script(story.intro)
	else:
		mode = Mode.EXPLORE
		ui.toast("Welcome back, %s!" % Game.state["name"], "hp")


# ================================================================= maps
func _load_world(id: String) -> void:
	if world:
		world.queue_free()
	for c in critters:
		if is_instance_valid(c):
			c.queue_free()
	critters.clear()
	_auto_inside.clear()
	world = World.new()
	world.name = "World"
	add_child(world)
	world.build(id)
	_apply_env(world.env)


func load_map(id: String, spawn: Vector3, fade := true) -> void:
	if fade:
		await ui.fade_out(0.35)
	_load_world(id)
	player = Player.new()
	world.add_child(player)
	player.position = spawn
	follower = Models.cat()
	world.add_child(follower)
	follower.position = spawn + Vector3(-0.8, 0, 0.8)
	for s in world.critter_spawns:
		_spawn_critter(s)
	Game.state["map"] = id
	Game.state["pos"] = [spawn.x, spawn.z]
	refresh_markers()
	_snap_camera()
	Audio.play_music(MUSIC.get(id, "town"))
	Game.save_game()
	if fade:
		await ui.fade_in(0.35)


func _spawn_critter(s: Dictionary) -> void:
	var c := Critter.new()
	c.enemy_id = s["id"]
	c.area = s["area"]
	c.uid = s.get("uid", "")
	c.player = player
	c.position = s["pos"]
	world.add_child(c)
	c.touched.connect(_on_critter_touched)
	critters.append(c)


func _apply_env(p: Dictionary) -> void:
	if p.is_empty():
		return
	sky_mat.set_shader_parameter("top", p["top"])
	sky_mat.set_shader_parameter("mid", p["mid"])
	sky_mat.set_shader_parameter("horizon", p["horizon"])
	env.ambient_light_color = p["ambient"]
	env.ambient_light_energy = p["ambient_energy"]
	sun.light_color = p["sun_color"]
	sun.light_energy = p["sun_energy"]
	sun.rotation_degrees = p["sun_rot"]
	env.fog_enabled = p["fog_density"] > 0.0
	env.fog_light_color = p["fog"]
	env.fog_density = p["fog_density"]


func refresh_markers() -> void:
	if world:
		world.set_markers(story.marker_ids())
	ui.refresh()


func _snap_camera() -> void:
	cam.current = true
	var t := _cam_target()
	cam.position = t + CAM_OFFSET
	cam.look_at(t + Vector3(0, 0.6, 0))


func _cam_target() -> Vector3:
	var p := player.global_position
	return Vector3(clampf(p.x, world.cam_min.x, world.cam_max.x), 0, clampf(p.z, world.cam_min.y, world.cam_max.y))


# ============================================================== process
func _process(delta: float) -> void:
	if mode == Mode.TITLE:
		_title_t += delta
		if player:
			var focus := player.position + Vector3(0.9, 1.0, 0)
			cam.position = focus + Vector3(2.2 + sin(_title_t * 0.3) * 0.4, 1.2, 5.5)
			cam.look_at(focus)
		return
	if mode == Mode.BATTLE or world == null or player == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_swing_cd = maxf(0.0, _swing_cd - delta)
	var t := _cam_target()
	cam.position = cam.position.lerp(t + CAM_OFFSET, minf(1.0, 5.0 * delta))
	cam.look_at(cam.position - CAM_OFFSET + Vector3(0, 0.6, 0))
	_update_follower(delta)
	player.can_move = mode == Mode.EXPLORE
	if mode != Mode.EXPLORE:
		ui.show_prompt("")
		return
	_nearest = {}
	var best := 1e9
	for it in world.interactables:
		var d := Vector2(player.position.x - it["pos"].x, player.position.z - it["pos"].z).length()
		if it["auto"]:
			if d < it["radius"]:
				if not _auto_inside.has(it["id"]):
					_auto_inside[it["id"]] = true
					interact(it["id"])
					return
			else:
				_auto_inside.erase(it["id"])
			continue
		if d < it["radius"] and d < best:
			best = d
			_nearest = it
	if _nearest.is_empty() and follower and not _critter_in_front():
		var to_cat := follower.position - player.position
		to_cat.y = 0
		if to_cat.length() < 1.5 and _forward().dot(to_cat.normalized()) > 0.5:
			_nearest = {"id": "mochi", "prompt": "Talk to Mochi", "pos": follower.position}
	ui.show_prompt(_nearest.get("prompt", ""))


func _update_follower(delta: float) -> void:
	if follower == null:
		return
	var back := player.position - Vector3(sin(player.model.rotation.y), 0, cos(player.model.rotation.y)) * 1.2
	var to := back - follower.position
	to.y = 0
	var dist := to.length()
	if dist > 0.25:
		var speed := clampf(dist * 3.0, 0.0, 7.0)
		follower.position += to.normalized() * minf(speed * delta, dist)
		follower.rotation.y = lerp_angle(follower.rotation.y, atan2(to.x, to.z), minf(1.0, 10.0 * delta))
	follower.moving = dist > 0.35
	if dist > 8.0:
		follower.position = back


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.EXPLORE and _cooldown <= 0.0:
		if event.is_action_pressed("confirm"):
			get_viewport().set_input_as_handled()
			if _critter_in_front() or _nearest.is_empty():
				_wand_swing()
			else:
				interact(_nearest["id"])
		elif event.is_action_pressed("cancel"):
			get_viewport().set_input_as_handled()
			open_menu()
	elif mode == Mode.MENU and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		close_menu()
	elif event.is_action_pressed("confirm") and not ui.is_dialog_open():
		# The A button / Z / E press whichever button is highlighted on any
		# screen (results, ending, menus), not only Enter and Space.
		var f := get_viewport().gui_get_focus_owner()
		if f is BaseButton and f.is_visible_in_tree() and not (f as BaseButton).disabled:
			get_viewport().set_input_as_handled()
			(f as BaseButton).pressed.emit()


func interact(id: String) -> void:
	if mode != Mode.EXPLORE:
		return
	if world.npcs.has(id):
		var npc: Node3D = world.npcs[id]
		var dir := player.position - npc.position
		if id != "sparkle" and id != "marina":
			npc.rotation.y = atan2(dir.x, dir.z)
		player.face(-dir)
	run_script(story.interact.bind(id))


## Runs a cutscene/dialog coroutine with movement locked, then hands control back.
func run_script(fn: Callable) -> void:
	mode = Mode.SCRIPT
	player.can_move = false
	ui.show_prompt("")
	touch.set_joystick(false)
	await fn.call()
	if mode == Mode.SCRIPT:
		mode = Mode.EXPLORE
	touch.set_joystick(true)
	_cooldown = 0.25
	refresh_markers()
	if mode == Mode.EXPLORE:
		Game.state["pos"] = [player.position.x, player.position.z]
		Game.save_game()


func _forward() -> Vector3:
	return Vector3(sin(player.model.rotation.y), 0, cos(player.model.rotation.y))


func _critter_in_front() -> Critter:
	var fwd := _forward()
	for c in critters:
		if not is_instance_valid(c) or not c.active:
			continue
		var to: Vector3 = c.position - player.position
		to.y = 0
		if to.length() < 2.2 and fwd.dot(to.normalized()) > 0.3:
			return c
	return null


func _wand_swing() -> void:
	if _swing_cd > 0.0:
		return
	_swing_cd = 0.45
	Audio.sfx("swing", 0.1)
	var fwd := Vector3(sin(player.model.rotation.y), 0, cos(player.model.rotation.y))
	Art.burst(world, player.position + fwd * 0.9 + Vector3(0, 0.9, 0), Color("fff3b0"), 10, "sparkle", 2.0, 0.5, 0.25, Vector3.ZERO)
	var arm: Node3D = player.model.find_child("ArmR", true, false)
	if arm:
		var tw := create_tween()
		tw.tween_property(arm, "rotation:x", -2.2, 0.08)
		tw.tween_property(arm, "rotation:x", 0.0, 0.18)
	var c := _critter_in_front()
	if c:
		c.active = false
		start_encounter(c, true)


# ============================================================== battles
func _on_critter_touched(c: Critter) -> void:
	if mode != Mode.EXPLORE:
		c.active = true
		return
	start_encounter(c, false)


func start_encounter(c: Critter, strike: bool) -> void:
	var ids: Array = [c.enemy_id]
	var pool: Array = Game.PARK_POOL if world.map_id == "city" else Game.OFFICE_POOL
	var lvl := int(Game.state["level"])
	var extra := 0
	if lvl >= 2:
		extra = randi_range(0, mini(2, lvl - 1))
	for i in extra:
		ids.append(pool.pick_random())
	var area := "park" if world.map_id == "city" else "office"
	run_script(func():
		var result: String = await battle(ids, area, strike)
		if result == "win":
			if c.uid != "":
				Game.set_flag("beat_" + c.uid)
			critters.erase(c)
			c.queue_free()
			await story.after_battle(c.uid)
		elif is_instance_valid(c):
			c.active = true)


## Plays a whole battle and returns "win", "lose" or "flee".
func battle(ids: Array, area: String, strike := false) -> String:
	mode = Mode.BATTLE
	player.can_move = false
	ui.show_prompt("")
	touch.set_joystick(false)
	Audio.sfx("encounter")
	Audio.play_music("boss" if ids.has("monday") else "battle", 0.4)
	await ui.fade_out(0.45)
	world.visible = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	ui.show_hud(false)
	var b := Battle.new()
	b.setup(ids, area, strike)
	add_child(b)
	await ui.fade_in(0.35)
	var result: String = await b.finished
	await ui.fade_out(0.4)
	b.queue_free()
	world.visible = true
	world.process_mode = Node.PROCESS_MODE_INHERIT
	cam.current = true
	ui.show_hud(true)
	ui.refresh()
	mode = Mode.SCRIPT
	if result == "lose":
		Game.full_heal()
		var home: Vector3 = Vector3(-15, 0, -6.5)
		if world.map_id != "city":
			await load_map("city", home, false)
		else:
			player.position = home
		_snap_camera()
		Audio.play_music(MUSIC.get(world.map_id, "town"), 0.5)
		await ui.fade_in(0.5)
		await ui.say("Mochi", "Mrrow. You dozed off out there, so I dragged you home. You're welcome. (HP and MP restored!)")
	else:
		Audio.play_music(MUSIC.get(world.map_id, "town"), 0.8)
		await ui.fade_in(0.4)
		_invulnerable(2.0)
	Game.save_game()
	return result


func _invulnerable(sec: float) -> void:
	player.set_meta("invulnerable", true)
	var tw := create_tween().set_loops(int(sec / 0.2))
	tw.tween_property(player.model, "visible", false, 0.1)
	tw.tween_property(player.model, "visible", true, 0.1)
	await get_tree().create_timer(sec).timeout
	if is_instance_valid(player):
		player.set_meta("invulnerable", false)
		player.model.visible = true


# ================================================================= menu
func open_menu() -> void:
	if mode != Mode.EXPLORE:
		return
	mode = Mode.MENU
	Audio.sfx("menu")
	menu = PauseMenu.new()
	menu.closed.connect(close_menu)
	ui.add_child(menu)


func close_menu() -> void:
	if menu:
		menu.queue_free()
		menu = null
	Audio.sfx("ui_cancel")
	mode = Mode.EXPLORE
	_cooldown = 0.2


func back_to_title() -> void:
	if menu:
		menu.queue_free()
		menu = null
	await ui.fade_out(0.5)
	_show_title()
	await ui.fade_in(0.5)
