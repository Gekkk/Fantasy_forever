extends Node
## Renders one gameplay view under several lighting setups (dev tool).

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(1.0).timeout
	main.title.visible = false
	Game.new_game("Luna", OS.get_environment("LOOK_STYLE") if OS.get_environment("LOOK_STYLE") != "" else "witch", 1, 1)
	var map: String = OS.get_environment("LOOK_MAP") if OS.get_environment("LOOK_MAP") != "" else "city"
	var pos := Vector3(-6, 0, -3.5) if map == "city" else Vector3(0, 0, 1.5)
	if OS.get_environment("LOOK_POS") != "":
		var pp := OS.get_environment("LOOK_POS").split(",")
		pos = Vector3(float(pp[0]), 0, float(pp[1]))
	await main.load_map(map, pos, false)
	main.mode = main.Mode.EXPLORE
	for e in main.combat.enemies:
		e.set_process(false)
	main.ui.show_hud(true)
	main.ui.refresh()
	var variants := {
		"a_current": {},
	}
	var base := {}
	for k in ["glow_enabled", "tonemap_mode", "tonemap_exposure", "ambient_light_energy", "glow_intensity", "glow_blend_mode", "adjustment_enabled"]:
		base[k] = main.env.get(k)
	if OS.get_environment("LOOK_TOP") != "":
		main.set_process(false)
		main.ui.visible = false
		main.cam.fov = 60
		main.cam.position = Vector3(0, 80, 2)
		main.cam.look_at(Vector3(0, 0, -2))
	if OS.get_environment("LOOK_SWING") != "":
		main.player.face(Vector3(1, 0, 0.3))
		Engine.time_scale = 0.25
		var k := 0
		for hit in 3:
			main.player.attack()
			for f in 3:
				await get_tree().create_timer(0.06 * 0.25 * 2.0).timeout
				get_viewport().get_texture().get_image().save_png("user://swing_%d.png" % k)
				k += 1
			await get_tree().create_timer(0.1).timeout
		get_tree().quit()
		return
	for name in variants:
		for k in base:
			main.env.set(k, base[k])
		for k in variants[name]:
			main.env.set(k, variants[name][k])
		for i in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://look_%s_%s.png" % [map, name])
		print("LOOK ", name)
	get_tree().quit()
