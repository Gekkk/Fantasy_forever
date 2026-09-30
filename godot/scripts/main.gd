extends Node
## Top-level flow: title screen, exploring with real-time combat, cutscenes and saving.

enum Mode { TITLE, EXPLORE, SCRIPT, BATTLE, MENU }

signal _fight_done(result: String)

const CAM_OFFSET := Vector3(0, 11.0, 11.5)
const MUSIC := {"city": "town", "tower": "tower", "roof": "tower", "home_in": "ending",
	"cafe_in": "town", "library_in": "ending", "boutique_in": "town"}

var mode := Mode.TITLE
var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var cam: Camera3D
var world: World
var player: Player
var follower: ModelAnim
var combat: Combat
var ui: UI
var touch: TouchControls
var title: Control
var menu: Control
var story: Story

var _auto_inside := {}
var _nearest := {}
var _cooldown := 0.0
var _title_t := 0.0
var _shake := 0.0
var _in_fight := false
var _fight_target: Enemy
var _perk_showing := false
var _mochi_cd := 2.0
var _mochi_heal_cd := 0.0
var _mochi_busy := false
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

	_setup_quality()
	get_viewport().size_changed.connect(_update_render_scale)

	combat = Combat.new(self)
	add_child(combat)
	ui = UI.new()
	add_child(ui)
	touch = TouchControls.new()
	touch.visible = false
	ui.add_child(touch)
	ui.menu_button.pressed.connect(open_menu)
	story = Story.new(self)
	combat.enemy_calmed.connect(_on_enemy_calmed_for_fight)
	combat.arena_cleared.connect(_on_arena_cleared)

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


# ============================================================== quality
# Big PC screens (1440p, 4K, Retina) make the browser draw 2-4x more pixels
# than a phone. Render 3D at roughly 720p-level pixel count and upscale; UI
# stays crisp. If it's still slow, step quality down automatically.
const TARGET_PIXELS := 1280.0 * 720.0 * 1.25
var quality_level := 0
var _fps_timer := 0.0
var _fps_samples: Array = []


func _setup_quality() -> void:
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	_update_render_scale()


func _update_render_scale() -> void:
	var vp := get_viewport()
	var px := Vector2(DisplayServer.window_get_size())
	var area := maxf(1.0, px.x * px.y)
	var s := clampf(sqrt(TARGET_PIXELS / area), 0.4, 1.0)
	s *= [1.0, 0.8, 0.65][quality_level]
	vp.scaling_3d_scale = s
	vp.msaa_3d = Viewport.MSAA_2X if (s >= 0.99 and quality_level == 0) else Viewport.MSAA_DISABLED


func _watch_fps(delta: float) -> void:
	if quality_level >= 2 or mode == Mode.TITLE or mode == Mode.MENU:
		return
	_fps_timer += delta
	if _fps_timer < 1.0:
		return
	_fps_timer = 0.0
	_fps_samples.append(Engine.get_frames_per_second())
	if _fps_samples.size() < 4:
		return
	var avg := 0.0
	for f in _fps_samples:
		avg += f
	avg /= _fps_samples.size()
	_fps_samples.clear()
	if avg < 45.0:
		quality_level += 1
		if quality_level >= 2:
			sun.shadow_enabled = false
			env.glow_enabled = false
		_update_render_scale()
		print("Quality lowered to level %d (avg fps %.0f)" % [quality_level, avg])


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
	if combat:
		combat.clear()
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
	player.downed.connect(_on_player_down)
	follower = Models.cat()
	world.add_child(follower)
	follower.position = spawn + Vector3(-0.8, 0, 0.8)
	for s in world.critter_spawns:
		combat.spawn_enemy(s["id"], s["pos"], s["area"], s.get("uid", ""), false, s.get("elite", false))
	Game.state["map"] = id
	Game.state["pos"] = [spawn.x, spawn.z]
	refresh_markers()
	_snap_camera()
	Audio.play_music(MUSIC.get(id, "town"))
	Game.save_game()
	if fade:
		await ui.fade_in(0.35)


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
	cam.position = t + CAM_OFFSET * world.cam_zoom
	cam.look_at(t + Vector3(0, 0.6, 0))


func _cam_target() -> Vector3:
	var p := player.global_position
	return Vector3(clampf(p.x, world.cam_min.x, world.cam_max.x), 0, clampf(p.z, world.cam_min.y, world.cam_max.y))


# ============================================================== process
func _process(delta: float) -> void:
	_watch_fps(delta)
	if mode == Mode.TITLE:
		_title_t += delta
		if player:
			var focus := player.position + Vector3(0.9, 1.0, 0)
			cam.position = focus + Vector3(2.2 + sin(_title_t * 0.3) * 0.4, 1.2, 5.5)
			cam.look_at(focus)
		return
	if world == null or player == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	var t := _cam_target()
	cam.position = cam.position.lerp(t + CAM_OFFSET * world.cam_zoom, minf(1.0, 5.0 * delta))
	cam.look_at(cam.position - CAM_OFFSET * world.cam_zoom + Vector3(0, 0.6, 0))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.35
	_update_follower(delta)
	player.can_move = mode == Mode.EXPLORE
	ui.update_combat(player)
	if mode != Mode.EXPLORE:
		ui.show_prompt("")
		return
	if int(Game.state.get("pending_perks", 0)) > 0 and not _perk_showing:
		_show_perk_choice()
		return
	_nearest = {}
	if _in_fight:
		ui.show_prompt("")
		return
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
	if _nearest.is_empty() and follower and not combat.any_aggro_near(player.position, 8.0):
		var to_cat := follower.position - player.position
		to_cat.y = 0
		if to_cat.length() < 1.5 and player.facing().dot(to_cat.normalized()) > 0.5:
			_nearest = {"id": "mochi", "prompt": "Talk to Mochi", "pos": follower.position}
	if not _nearest.is_empty() and combat.any_aggro_near(player.position, 6.0):
		_nearest = {}
	ui.show_prompt(_nearest.get("prompt", ""))


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## A tiny freeze-frame that makes big hits feel punchy.
func hitstop(sec: float) -> void:
	Engine.time_scale = 0.08
	await get_tree().create_timer(sec, true, false, true).timeout
	Engine.time_scale = 1.0


func _update_follower(delta: float) -> void:
	if follower == null:
		return
	_mochi_cd -= delta
	_mochi_heal_cd -= delta
	if mode == Mode.EXPLORE and not _mochi_busy:
		if _mochi_heal_cd <= 0.0 and Game.state["hp"] < Game.state["max_hp"] * 0.35 and Game.state["hp"] > 0:
			_mochi_heal()
		elif _mochi_cd <= 0.0:
			var e := combat.nearest_enemy(player.position, 7.0)
			if e and e.aggro:
				_mochi_pounce(e)
	if _mochi_busy:
		return
	var back := player.position - player.facing() * 1.2
	var to := back - follower.position
	to.y = 0
	var dist := to.length()
	if dist > 0.25:
		var speed := clampf(dist * 3.0, 0.0, 7.5)
		follower.position += to.normalized() * minf(speed * delta, dist)
		follower.rotation.y = lerp_angle(follower.rotation.y, atan2(to.x, to.z), minf(1.0, 10.0 * delta))
	follower.moving = dist > 0.35
	if dist > 8.0:
		follower.position = back


func _mochi_pounce(e: Enemy) -> void:
	_mochi_busy = true
	_mochi_cd = 3.2 * pow(0.7, Game.perk("mochi_power"))
	var start := follower.position
	var target := e.global_position + (start - e.global_position).normalized() * 0.8
	Audio.sfx("meow", 0.15, -4.0)
	follower.look_at(Vector3(e.global_position.x, follower.position.y, e.global_position.z), Vector3.UP, true)
	var tw := create_tween()
	tw.tween_property(follower, "position", target + Vector3(0, 0.6, 0), 0.18)
	tw.tween_property(follower, "position", target, 0.08)
	await tw.finished
	if is_instance_valid(e) and not e.dead:
		var dmg := int((5 + int(Game.state["level"]) * 2) * (1.0 + 0.5 * Game.perk("mochi_power")))
		e.take_damage(dmg, "none", e.global_position - follower.position, "")
		Art.burst(world, e.global_position + Vector3(0, 0.8, 0), Color("ffe0f0"), 8, "sparkle", 2, 0.4, 0.3)
	await get_tree().create_timer(0.25).timeout
	_mochi_busy = false


func _mochi_heal() -> void:
	_mochi_heal_cd = 18.0
	var amt := int(Game.state["max_hp"] * 0.15) + 5
	Game.heal(amt)
	Audio.sfx("purr")
	Art.burst(world, player.position + Vector3(0, 0.6, 0), Color("ff9fc4"), 14, "heart", 1.5, 1.2, 0.3, Vector3(0, 1.5, 0))
	Art.float_text(world, follower.position + Vector3(0, 1.2, 0), "Purr~ +%d" % amt, Color("ffb3d9"), 60)


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.EXPLORE and _cooldown <= 0.0:
		if event.is_action_pressed("confirm"):
			get_viewport().set_input_as_handled()
			if _nearest.is_empty():
				player.attack()
			else:
				interact(_nearest["id"])
		elif event.is_action_pressed("cancel") and not _in_fight:
			get_viewport().set_input_as_handled()
			open_menu()
	elif mode == Mode.MENU and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		close_menu()
	elif event.is_action_pressed("confirm") and not ui.is_dialog_open():
		# The A button / E press whichever button is highlighted on any screen.
		var f := get_viewport().gui_get_focus_owner()
		if f is BaseButton and f.is_visible_in_tree() and not (f as BaseButton).disabled:
			get_viewport().set_input_as_handled()
			(f as BaseButton).pressed.emit()


func interact(id: String) -> void:
	if mode != Mode.EXPLORE or _in_fight:
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


# =============================================================== fights
## Lets the player fight in real time from inside a story script.
## Returns "win" when `target` is cheered up (or the arena is cleared), "lose" if knocked out.
func fight(target: Enemy = null) -> String:
	_in_fight = true
	_fight_target = target
	mode = Mode.EXPLORE
	touch.set_joystick(true)
	Audio.play_music("boss" if target and target is Boss else "battle", 0.5)
	if target:
		target.aggro = true
	var result: String = await _fight_done
	_in_fight = false
	_fight_target = null
	mode = Mode.SCRIPT
	player.can_move = false
	if result == "win":
		Audio.play_music("victory", 0.2)
		await get_tree().create_timer(2.5).timeout
		Audio.play_music(MUSIC.get(world.map_id, "town"), 1.0)
	return result


## Arena version: a barrier locks you in with waves of critters.
func fight_arena(center: Vector3, radius: float, waves: Array) -> String:
	combat.start_arena(center, radius, waves)
	return await fight(null)


func _on_enemy_calmed_for_fight(e: Enemy) -> void:
	if _in_fight and _fight_target != null and e == _fight_target:
		_fight_done.emit("win")


func _on_arena_cleared() -> void:
	if _in_fight and _fight_target == null:
		_fight_done.emit("win")


func _on_player_down() -> void:
	combat.end_arena(false)
	if _in_fight:
		_fight_done.emit("lose")
		await get_tree().process_frame
		await _wake_up_at_home()
	else:
		run_script(_wake_up_at_home)


func _wake_up_at_home() -> void:
	mode = Mode.SCRIPT
	await get_tree().create_timer(1.0).timeout
	await ui.fade_out(0.6)
	Game.full_heal()
	ui.boss_bar("", 0.0, "", false)
	var bedside := Vector3(-2.2, 0, -1.2)
	await load_map("home_in", bedside, false)
	Audio.play_music(MUSIC.get(world.map_id, "town"), 0.5)
	await ui.fade_in(0.6)
	await ui.say("Mochi", "Mrrow. You dozed off out there, so I dragged you home. You're welcome. (HP and MP restored!)")


# =============================================================== perks
func queue_perk_choice() -> void:
	pass # picked up in _process once it's safe to pause


func _show_perk_choice() -> void:
	_perk_showing = true
	get_tree().paused = true
	var choices := Game.perk_choices()
	if choices.is_empty():
		Game.state["pending_perks"] = 0
	else:
		var id: String = await ui.choose_perk(choices)
		Game.add_perk(id)
		Game.state["pending_perks"] = maxi(0, int(Game.state["pending_perks"]) - 1)
		Art.burst(world, player.position + Vector3(0, 1, 0), Color("ffe27a"), 30, "star", 4, 1.0, 0.35)
	get_tree().paused = false
	_perk_showing = false
	Game.save_game()


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
