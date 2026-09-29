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
		Models.hero("witch", Game.ROBE_COLORS[0], Game.HAIR_COLORS[0]),
		Models.hero("fairy", Game.ROBE_COLORS[1], Game.HAIR_COLORS[1]),
		Models.hero("elf", Game.ROBE_COLORS[2], Game.HAIR_COLORS[3]),
		Models.cat(), Models.owl(), Models.unicorn(), Models.dragon(), Models.ghost(),
		Models.humanoid({"robe": Color("5b8def"), "hair": Color("f0f0f0"), "hat": "wizard", "hair_style": "bob", "extras": ["beard"]}),
		Models.humanoid({"robe": Color("9aa3b8"), "hat": "helmet", "hair_style": "none", "extras": ["briefcase", "cape"], "accent": Color("e05a7a")}),
		Models.tiny_clock(),
	]
	for id in ["cloud", "shroom", "pigeon", "umbrella", "bee", "paper", "coffee", "clip", "printer", "email"]:
		models.append(Models.critter(id))
	var i := 0
	for m in models:
		var col := i % 7
		var row := i / 7
		m.position = Vector3(-6.0 + col * 2.0, 0, -2.5 + row * 2.4)
		add_child(m)
		i += 1
	var boss := Models.monday()
	boss.position = Vector3(9, 0, 0)
	add_child(boss)
	var cam := Camera3D.new()
	cam.fov = 40
	cam.position = Vector3(1.5, 9, 14)
	add_child(cam)
	cam.look_at(Vector3(1.5, 0.6, 0.5))
	for f in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://gallery.png")
	print("GALLERY SAVED ", ProjectSettings.globalize_path("user://gallery.png"))
	get_tree().quit()
