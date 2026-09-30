extends Node3D
## Renders every model in a grid and saves a screenshot (dev tool).

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = Art.shader("sky")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9a6e8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = Color("fff0dc")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 20)
	floor_mi.mesh = pm
	floor_mi.material_override = Art.ground_mat(Color("9fdc8f"), Color("7cc97a"))
	add_child(floor_mi)
	var models: Array = [
		Models.hero("witch", Game.ROBE_COLORS[1], Game.HAIR_COLORS[1], true),
		Models.hero("fairy", Game.ROBE_COLORS[0], Game.HAIR_COLORS[2], true),
		Models.hero("elf", Game.ROBE_COLORS[2], Game.HAIR_COLORS[4], true),
		Models.hero("witch", Game.ROBE_COLORS[3], Game.HAIR_COLORS[0], false),
		Models.hero("elf", Game.ROBE_COLORS[4], Game.HAIR_COLORS[3], false),
	]
	var i := 0
	for m in models:
		m.position = Vector3(-3.2 + i * 1.6, 0, 0)
		m.rotation_degrees.y = 0
		add_child(m)
		i += 1
	await get_tree().process_frame
	var cam := Camera3D.new()
	cam.fov = 40
	cam.position = Vector3(0, 1.6, 5.2)
	add_child(cam)
	cam.look_at(Vector3(0, 1.1, 0))
	for f in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://gallery.png")
	print("GALLERY SAVED ", ProjectSettings.globalize_path("user://gallery.png"))
	get_tree().quit()
