class_name World
extends Node3D
## Builds one explorable map (city, tower or rooftop) entirely from code.

class Batch:
	## Groups many copies of a mesh into one MultiMesh draw call.
	var groups := {}

	func add(mesh: Mesh, color: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, emit := 0.0) -> void:
		var key := "%d|%.2f" % [mesh.get_instance_id(), emit]
		if not groups.has(key):
			groups[key] = {"mesh": mesh, "emit": emit, "x": [], "c": []}
		var r := rot * (PI / 180.0)
		var b := Basis.from_euler(r) * Basis.from_scale(scl)
		groups[key]["x"].append(Transform3D(b, pos))
		groups[key]["c"].append(color)

	func flush(parent: Node3D) -> void:
		for key in groups:
			var g: Dictionary = groups[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = g["mesh"]
			mm.instance_count = g["x"].size()
			for i in mm.instance_count:
				mm.set_instance_transform(i, g["x"][i])
				mm.set_instance_color(i, g["c"][i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = Art.mat(Color.WHITE, g["emit"])
			parent.add_child(mmi)
		groups.clear()


var map_id := ""
var interactables: Array = [] # {id, pos, radius, prompt, auto}
var npcs := {} # id -> ModelAnim
var critter_spawns: Array = [] # {id, pos, area, uid}
var spawns := {}
var cam_min := Vector2(-10, -10)
var cam_max := Vector2(10, 10)
var env := {}
var markers := {} # interactable id -> Label3D "!"

var batch := Batch.new()
var _floaters: Array = [] # [node, base_y, phase, amp]
var _spinners: Array = [] # [node, speed_deg]
var _tram: Node3D
var _t := 0.0


func build(id: String) -> void:
	map_id = id
	match id:
		"city": _build_city()
		"tower": _build_tower()
		"roof": _build_roof()
	batch.flush(self)


func _process(delta: float) -> void:
	_t += delta
	for f in _floaters:
		var n: Node3D = f[0]
		if is_instance_valid(n):
			n.position.y = f[1] + sin(_t * 1.4 + f[2]) * f[3]
	for s in _spinners:
		var n: Node3D = s[0]
		if is_instance_valid(n):
			n.rotation_degrees.y += s[1] * delta
	if _tram:
		_tram.position.x += delta * 4.0
		if _tram.position.x > 40:
			_tram.position.x = -40
	for id in markers:
		var m: Label3D = markers[id]
		m.position.y = m.get_meta("base_y") + sin(_t * 4.0) * 0.12


# ============================================================ helpers
func add_interactable(id: String, pos: Vector3, radius: float, prompt: String, auto := false) -> void:
	interactables.append({"id": id, "pos": pos, "radius": radius, "prompt": prompt, "auto": auto})


func add_npc(id: String, model: ModelAnim, pos: Vector3, rot_y: float, prompt: String, radius := 1.8) -> ModelAnim:
	model.position = pos
	model.rotation_degrees.y = rot_y
	add_child(model)
	npcs[id] = model
	add_interactable(id, pos, radius, prompt)
	Art.collider_round(self, 0.35, 1.2, pos)
	return model


func set_markers(ids: Array) -> void:
	for id in markers.keys():
		if not ids.has(id):
			markers[id].queue_free()
			markers.erase(id)
	for it in interactables:
		if ids.has(it["id"]) and not markers.has(it["id"]):
			var h := 2.6
			if npcs.has(it["id"]):
				h = npcs[it["id"]].height * npcs[it["id"]].scale.y + 0.6
			var l := Art.label3d(self, "!", it["pos"] + Vector3(0, h, 0), 110, Color("ffd36b"))
			l.set_meta("base_y", it["pos"].y + h)
			l.no_depth_test = true
			markers[it["id"]] = l


func floater(n: Node3D, amp := 0.2) -> void:
	_floaters.append([n, n.position.y, randf() * TAU, amp])


func spinner(n: Node3D, speed := 30.0) -> void:
	_spinners.append([n, speed])


func tree(pos: Vector3, blossom := false, s := 1.0) -> void:
	var trunk := Color("a87a5c")
	batch.add(Art.cyl(0.18, 0.26, 1.4), trunk, pos + Vector3(0, 0.7, 0) * s, Vector3.ZERO, Vector3.ONE * s)
	var cols := [Color("ffb3d1"), Color("ffc9df"), Color("ff9fc4")] if blossom else [Color("6fcf7d"), Color("8fdc86"), Color("5dbb70")]
	batch.add(Art.sphere(0.95), cols[0], pos + Vector3(0, 1.9, 0) * s, Vector3.ZERO, Vector3.ONE * s)
	batch.add(Art.sphere(0.7), cols[1], pos + Vector3(-0.5, 2.4, 0.25) * s, Vector3.ZERO, Vector3.ONE * s)
	batch.add(Art.sphere(0.65), cols[2], pos + Vector3(0.55, 2.3, -0.2) * s, Vector3.ZERO, Vector3.ONE * s)
	Art.collider_round(self, 0.45 * s, 2.0, pos)


func pine(pos: Vector3, s := 1.0) -> void:
	batch.add(Art.cyl(0.14, 0.2, 0.8), Color("a87a5c"), pos + Vector3(0, 0.4, 0) * s, Vector3.ZERO, Vector3.ONE * s)
	batch.add(Art.cyl(0.0, 1.0, 1.5), Color("4fae7a"), pos + Vector3(0, 1.4, 0) * s, Vector3.ZERO, Vector3.ONE * s)
	batch.add(Art.cyl(0.0, 0.75, 1.2), Color("63c08a"), pos + Vector3(0, 2.2, 0) * s, Vector3.ZERO, Vector3.ONE * s)
	Art.collider_round(self, 0.4 * s, 2.0, pos)


func bush(pos: Vector3, s := 1.0, flowers := true) -> void:
	for o in [Vector3(0, 0.35, 0), Vector3(0.35, 0.28, 0.1), Vector3(-0.35, 0.28, -0.05)]:
		batch.add(Art.sphere(0.42), Color("6cc978"), pos + o * s, Vector3.ZERO, Vector3.ONE * s)
	if flowers:
		var fc := [Color("ff8fb8"), Color("ffe27a"), Color("ffffff"), Color("c3a6ff")]
		for i in 5:
			var a := i * 1.3
			batch.add(Art.sphere(0.08), fc[(i + int(pos.x)) % 4], pos + Vector3(cos(a) * 0.45, 0.6 + (i % 2) * 0.15, sin(a) * 0.3 + 0.2) * s)


func flower_bed(center: Vector3, size: Vector2, count: int) -> void:
	var fc := [Color("ff8fb8"), Color("ffe27a"), Color("ffffff"), Color("c3a6ff"), Color("ff9f7a")]
	for i in count:
		var p := center + Vector3(randf_range(-size.x, size.x) / 2, 0, randf_range(-size.y, size.y) / 2)
		var h := randf_range(0.15, 0.35)
		batch.add(Art.cyl(0.015, 0.015, h), Color("5fae55"), p + Vector3(0, h / 2, 0))
		batch.add(Art.sphere(0.09), fc[i % fc.size()], p + Vector3(0, h, 0), Vector3.ZERO, Vector3(1, 0.7, 1))


func grass_tufts(center: Vector3, size: Vector2, count: int) -> void:
	for i in count:
		var p := center + Vector3(randf_range(-size.x, size.x) / 2, 0, randf_range(-size.y, size.y) / 2)
		batch.add(Art.cyl(0.0, 0.07, 0.3), Color("7fcf6f"), p + Vector3(0, 0.12, 0), Vector3(randf_range(-15, 15), 0, randf_range(-15, 15)))


func lamp(pos: Vector3, with_light := true, color := Color("ffd98a")) -> void:
	batch.add(Art.cyl(0.07, 0.1, 2.8), Color("5a4a7a"), pos + Vector3(0, 1.4, 0))
	batch.add(Art.cyl(0.18, 0.18, 0.1), Color("5a4a7a"), pos + Vector3(0, 2.85, 0))
	batch.add(Art.sphere(0.24), color, pos + Vector3(0, 3.1, 0), Vector3.ZERO, Vector3.ONE, 2.2)
	batch.add(Art.cyl(0.0, 0.22, 0.25), Color("5a4a7a"), pos + Vector3(0, 3.45, 0))
	if with_light:
		Art.light(self, pos + Vector3(0, 2.9, 0), color, 1.6, 6.5)
	Art.collider_round(self, 0.15, 2.0, pos)


func bench(pos: Vector3, rot_y := 0.0) -> void:
	var n := Art.node(self, "Bench", pos)
	n.rotation_degrees.y = rot_y
	Art.part(n, Art.box(Vector3(1.6, 0.1, 0.5)), Color("c98a5c"), Vector3(0, 0.45, 0))
	Art.part(n, Art.box(Vector3(1.6, 0.45, 0.08)), Color("c98a5c"), Vector3(0, 0.75, -0.22))
	for x in [-0.65, 0.65]:
		Art.part(n, Art.box(Vector3(0.08, 0.45, 0.45)), Color("5a4a7a"), Vector3(x, 0.22, 0))
	Art.collider(self, Vector3(1.6, 1, 0.6), pos + Vector3(0, 0.5, 0), rot_y)


func sign_board(pos: Vector3, text: String, color := Color("fff4e0"), size := 36, rot_y := 0.0) -> void:
	var n := Art.node(self, "Sign", pos)
	n.rotation_degrees.y = rot_y
	var w := 0.25 + text.length() * 0.16
	Art.part(n, Art.box(Vector3(w, 0.6, 0.08)), Color("8b5a3c"), Vector3.ZERO)
	Art.part(n, Art.box(Vector3(w - 0.12, 0.48, 0.1)), color, Vector3.ZERO)
	var l := Label3D.new()
	l.text = text
	l.font = Art.get_font()
	l.font_size = size
	l.modulate = Color("5a3a6a")
	l.outline_size = 0
	l.pixel_size = 0.006
	l.position = Vector3(0, 0, 0.07)
	n.add_child(l)


func shard(id: String, pos: Vector3) -> void:
	if Game.state["shards"].has(id):
		return
	var n := Art.node(self, "Shard_" + id, pos + Vector3(0, 0.9, 0))
	var crystal := Art.part(n, Art.sphere(0.22), Color("c9a6ff"), Vector3.ZERO, Vector3(0, 0, 45), Vector3(0.7, 1.4, 0.7), 2.0)
	crystal.name = "Crystal"
	Art.ambient(n, Vector3.ZERO, Vector3(0.4, 0.4, 0.4), Color("e0c8ff"), 8, "sparkle", 0.2, 1.2)
	Art.light(n, Vector3.ZERO, Color("c9a6ff"), 1.0, 3.0)
	floater(n, 0.15)
	spinner(n, 90)
	add_interactable("shard_" + id, pos, 1.1, "", true)


func invisible_wall(size: Vector3, pos: Vector3) -> void:
	Art.collider(self, size, pos)


func ground_plane(size: Vector2, mat: Material, y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = mat
	mi.position.y = y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func slab(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func window_grid(center: Vector3, cols: int, rows: int, spacing: Vector2, face_z: float, colors: Array) -> void:
	for r in rows:
		for c in cols:
			var p := Vector3(center.x + (c - (cols - 1) / 2.0) * spacing.x, center.y + (r - (rows - 1) / 2.0) * spacing.y, face_z)
			var col: Color = colors[(r * 7 + c * 3) % colors.size()]
			batch.add(Art.box(Vector3(0.62, 0.8, 0.08)), Color("5a4a8a"), p)
			batch.add(Art.box(Vector3(0.5, 0.68, 0.1)), col, p + Vector3(0, 0, 0.01), Vector3.ZERO, Vector3.ONE, 1.4)


# ================================================================ CITY
func _build_city() -> void:
	env = {
		"top": Vector3(0.14, 0.11, 0.36), "mid": Vector3(0.5, 0.33, 0.66), "horizon": Vector3(1.0, 0.68, 0.66),
		"ambient": Color("c7b3f0"), "ambient_energy": 0.32, "sun_color": Color("ffd9c2"), "sun_energy": 0.8,
		"sun_rot": Vector3(-42, -35, 0), "fog": Color("d9b8e8"), "fog_density": 0.006,
	}
	cam_min = Vector2(-15, -9.5)
	cam_max = Vector2(15, 11)
	spawns = {"start": Vector3(-15, 0, -6.5), "home": Vector3(-15, 0, -7.2), "tower": Vector3(15, 0, -6.9),
		"cafe": Vector3(0, 0, -7.2)}

	ground_plane(Vector2(140, 120), Art.ground_mat(Color("86cf78"), Color("68b86a")), 0.0)
	var plaza := Art.ground_mat(Color("dcb9d6"), Color("cfaacb"), 1, 1.2, Color("a98aa8"))
	slab(Vector3(54, 0.04, 3.8), Vector3(0, 0.02, -6.2), plaza)
	slab(Vector3(54, 0.04, 1.6), Vector3(0, 0.02, 0.6), plaza)
	var road := Art.ground_mat(Color("857daa"), Color("766e9c"), 1, 0.9, Color("5b5480"))
	slab(Vector3(54, 0.045, 4.2), Vector3(0, 0.022, -2.3), road)
	for x in range(-24, 25, 3):
		if abs(x + 9) > 2 and abs(x - 9) > 2:
			batch.add(Art.box(Vector3(1.4, 0.02, 0.18)), Color("ffe08a"), Vector3(x, 0.05, -2.3))
	for cx in [-9, 9]:
		for i in 6:
			batch.add(Art.box(Vector3(0.35, 0.02, 3.6)), Color("fbf7ff"), Vector3(cx - 1.5 + i * 0.6, 0.05, -2.3))
	var dirt := Art.ground_mat(Color("e0bf8c"), Color("d2ad78"), 0)
	slab(Vector3(2.2, 0.03, 11), Vector3(-9, 0.015, 7.2), dirt)
	slab(Vector3(26, 0.03, 2.0), Vector3(1.5, 0.015, 12.3), dirt)
	slab(Vector3(2.0, 0.03, 11), Vector3(14.5, 0.015, 7.2), dirt)

	_build_home(Vector3(-15, 0, -11))
	_build_cafe(Vector3(0, 0, -11.5))
	_build_spellwork(Vector3(15, 0, -13))

	# Street furniture
	for x in [-20, -10, 0, 10, 20]:
		lamp(Vector3(x + 2.5, 0, -4.6), x % 20 == 0)
	for x in [-18, -4, 5, 19]:
		lamp(Vector3(x, 0, 1.3), false, Color("ffc2e0"))
	var mailbox := Art.node(self, "Mailbox", Vector3(-6, 0, -5.6))
	Art.part(mailbox, Art.cyl(0.06, 0.06, 1.0), Color("5a4a7a"), Vector3(0, 0.5, 0))
	Art.part(mailbox, Art.box(Vector3(0.5, 0.45, 0.6)), Color("5b8def"), Vector3(0, 1.15, 0))
	Art.part(mailbox, Art.cyl(0.25, 0.25, 0.6), Color("5b8def"), Vector3(0, 1.38, 0), Vector3(90, 0, 0))
	Art.collider_round(self, 0.3, 1.5, Vector3(-6, 0, -5.6))
	sign_board(Vector3(11.5, 1.9, 1.3), "Sky-Tram Stop", Color("e0f0ff"), 30)
	batch.add(Art.cyl(0.05, 0.05, 1.7), Color("5a4a7a"), Vector3(11.5, 0.85, 1.25))
	# Potion vending machine (very modern, very magical)
	var vend := Art.node(self, "Vending", Vector3(-22, 0, -6))
	Art.part(vend, Art.box(Vector3(1.3, 2.2, 0.9)), Color("ff8fb8"), Vector3(0, 1.1, 0))
	Art.part(vend, Art.box(Vector3(0.9, 1.3, 0.1)), Color("bfe8ff"), Vector3(0, 1.3, 0.45), Vector3.ZERO, Vector3.ONE, 0.6)
	for i in 6:
		Art.part(vend, Art.sphere(0.08), [Color("ff6b8a"), Color("7cff9a"), Color("7cc8ff")][i % 3], Vector3(-0.25 + (i % 3) * 0.25, 1.05 + int(i / 3) * 0.45, 0.5), Vector3.ZERO, Vector3.ONE, 2.0, false)
	Art.collider(self, Vector3(1.3, 2, 0.9), Vector3(-22, 1, -6))

	# Sky-tram: a little flying bus with a balloon
	_tram = Art.node(self, "Tram", Vector3(-30, 7.5, -2.3))
	Art.part(_tram, Art.capsule(0.9, 3.6), Color("ffd36b"), Vector3.ZERO, Vector3(0, 0, 90))
	Art.part(_tram, Art.capsule(0.95, 2.4), Color("ff8fb8"), Vector3(0, 1.4, 0), Vector3(0, 0, 90))
	for i in 4:
		Art.part(_tram, Art.box(Vector3(0.5, 0.45, 0.1)), Color("fff3b0"), Vector3(-1.1 + i * 0.7, 0.1, 0.85), Vector3.ZERO, Vector3.ONE, 1.5, false)
	Art.ambient(_tram, Vector3(-2, 0, 0), Vector3(0.3, 0.3, 0.3), Color("ffe8a0"), 12, "sparkle", 0.3, 1.0, Vector3(-1, 0, 0))

	# Petal Park
	var pond_c := Vector3(6, 0, 8.5)
	var water := MeshInstance3D.new()
	water.mesh = Art.cyl(3.0, 3.0, 0.06, 40)
	var wm := ShaderMaterial.new()
	wm.shader = Art.shader("water")
	water.material_override = wm
	water.position = pond_c + Vector3(0, 0.05, 0)
	add_child(water)
	Art.part(self, Art.torus(2.9, 3.4), Color("d8cfe8"), pond_c + Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1, 1.6, 1))
	var fountain := Art.node(self, "Fountain", pond_c)
	Art.part(fountain, Art.cyl(0.7, 0.9, 0.5), Color("e8e0f5"), Vector3(0, 0.25, 0))
	Art.part(fountain, Art.cyl(0.2, 0.25, 1.1), Color("e8e0f5"), Vector3(0, 0.9, 0))
	var crystal := Art.part(fountain, Art.sphere(0.35), Color("8fe8ff"), Vector3(0, 1.9, 0), Vector3.ZERO, Vector3(0.7, 1.4, 0.7), 2.2)
	floater(crystal, 0.15)
	Art.light(fountain, Vector3(0, 1.9, 0), Color("8fe8ff"), 1.5, 6.0)
	var spray := Art.ambient(fountain, Vector3(0, 1.5, 0), Vector3(0.2, 0.1, 0.2), Color("c8f0ff"), 24, "soft", 0.18, 1.2, Vector3(0, 2.0, 0))
	spray.gravity = Vector3(0, -3.5, 0)
	spray.spread = 25
	Art.collider_round(self, 3.3, 1.0, pond_c)
	batch.add(Art.sphere(0.6), Color("b8aed0"), pond_c + Vector3(2.2, 0.1, 1.6), Vector3.ZERO, Vector3(1.2, 0.5, 1))
	# Lily pads
	for a in [0.5, 2.3, 4.0]:
		batch.add(Art.cyl(0.35, 0.35, 0.02), Color("6cc978"), pond_c + Vector3(cos(a) * 2.0, 0.1, sin(a) * 2.0))
		batch.add(Art.sphere(0.08), Color("ffc2e0"), pond_c + Vector3(cos(a) * 2.0, 0.16, sin(a) * 2.0))

	flower_bed(Vector3(-16, 0, 6.5), Vector2(6, 3), 70)
	flower_bed(Vector3(-4, 0, 7.5), Vector2(5, 3), 55)
	flower_bed(Vector3(-15, 0, 10.5), Vector2(4, 2), 35)
	flower_bed(Vector3(19, 0, 6), Vector2(3, 4), 40)
	flower_bed(Vector3(0, 0, 3.5), Vector2(10, 0.8), 45)
	grass_tufts(Vector3(0, 0, 8), Vector2(44, 12), 220)
	bench(Vector3(-12, 0, 5.3), 180)
	bench(Vector3(-5.5, 0, 10.5), 0)
	bench(Vector3(18, 0, 11), -90)
	lamp(Vector3(-9, 0, 4.5), true, Color("ffc2e0"))
	lamp(Vector3(12, 0, 12), false, Color("ffc2e0"))
	Art.ambient(self, Vector3(0, 1.2, 9), Vector3(20, 1.0, 5), Color("fff3a0"), 60, "soft", 0.22, 5.0)

	# Trees around the edges and in the park
	# Low hedge along the south edge so nothing blocks the camera.
	for i in 30:
		bush(Vector3(-23 + i * 1.6, 0, 15.2), 0.8, i % 3 == 0)
	for z in [4, 8, 12]:
		tree(Vector3(-23, 0, z), z == 8, 1.0)
		tree(Vector3(23, 0, z), z == 4, 1.0)
	for p in [Vector3(-19, 0, 4.5), Vector3(-14, 0, 9.3), Vector3(-2, 0, 5.2), Vector3(11.5, 0, 5), Vector3(20, 0, 7)]:
		tree(p, randf() < 0.5)
	for p in [Vector3(-21, 0, -9), Vector3(-9.5, 0, -10.5), Vector3(-7, 0, -13), Vector3(6.5, 0, -11), Vector3(8, 0, -13.5), Vector3(22, 0, -9)]:
		pine(p, 1.1)
	for p in [Vector3(-18.3, 0, -8.3), Vector3(-11.7, 0, -8.3), Vector3(-4, 0, -8.2), Vector3(4, 0, -8.2), Vector3(-21.5, 0, 2), Vector3(21.5, 0, 2)]:
		bush(p)

	# Distant floating islands and hills for that fantasy skyline
	for data in [[Vector3(-30, 14, -55), 5.0], [Vector3(10, 18, -70), 7.0], [Vector3(38, 11, -50), 4.0], [Vector3(-55, 20, -80), 8.0]]:
		_island(data[0], data[1])
	for i in 7:
		batch.add(Art.sphere(12.0, true), Color("8a7bc0").lerp(Color("b49ad8"), i / 7.0), Vector3(-70 + i * 24, -1, -85 - (i % 2) * 10), Vector3.ZERO, Vector3(1.3, 0.8, 1))

	# Boundaries
	invisible_wall(Vector3(60, 4, 1), Vector3(0, 2, -15.5))
	invisible_wall(Vector3(60, 4, 1), Vector3(0, 2, 15.2))
	invisible_wall(Vector3(1, 4, 40), Vector3(-24, 2, 0))
	invisible_wall(Vector3(1, 4, 40), Vector3(24, 2, 0))

	# Shards
	shard("s1", Vector3(-21.5, 0, -12.5))
	shard("s2", Vector3(10.5, 0, 12.8))
	shard("s3", Vector3(22, 0, -2.3))

	# People of Moonbrook
	add_npc("pip", Models.owl(), Vector3(-7.2, 0, -5.2), 20, "Talk to Pip")
	add_npc("sparkle", Models.unicorn(), Vector3(9.8, 0, 0.9), 150, "Talk to Sparkle", 2.0)
	add_npc("reginald", Models.humanoid({"robe": Color("9aa3b8"), "hat": "helmet", "hair_style": "none",
		"extras": ["briefcase", "cape", "tie"], "accent": Color("e05a7a")}), Vector3(-12, 0, 0.9), 200, "Talk to Sir Reginald")
	add_npc("merlo", Models.humanoid({"robe": Color("5b8def"), "hair": Color("f0f0f0"), "hat": "wizard",
		"hair_style": "bob", "extras": ["beard"], "accent": Color("ffd36b")}), Vector3(-12, 0, 6.3), 0, "Talk to Grandpa Merlo")
	var marina := Models.humanoid({"robe": Color("5fd6c9"), "hair": Color("ff9fc4"), "hair_style": "long",
		"extras": ["tail_fin"], "accent": Color("c3a6ff")})
	add_npc("marina", marina, pond_c + Vector3(2.2, 0.35, 1.6), -30, "Talk to Marina", 2.8)

	add_interactable("home", Vector3(-15, 0, -8.2), 1.6, "Enter Home")
	add_interactable("cafe", Vector3(0, 0, -8.1), 1.6, "Enter the Bubbling Cauldron")
	add_interactable("tower_door", Vector3(15, 0, -9.1), 1.4, "", true)
	if Game.state["quest"] == 2:
		spawn_badge(Vector3(-18, 0, 12))

	critter_spawns = []
	var west := Rect2(-21, 3.8, 16, 10)
	var east := Rect2(10.5, 3.8, 10.5, 10)
	for i in 3:
		critter_spawns.append({"id": Game.PARK_POOL.pick_random(), "pos": Vector3(randf_range(-20, -6), 0, randf_range(5, 13)), "area": west})
	for i in 2:
		critter_spawns.append({"id": Game.PARK_POOL.pick_random(), "pos": Vector3(randf_range(12, 20), 0, randf_range(5, 13)), "area": east})


func spawn_badge(pos: Vector3) -> void:
	var n := Art.node(self, "Badge", pos + Vector3(0, 0.6, 0))
	Art.part(n, Art.box(Vector3(0.4, 0.5, 0.05)), Color("fff4e0"), Vector3.ZERO, Vector3(0, 0, 10), Vector3.ONE, 0.6)
	Art.part(n, Art.sphere(0.1), Color("ff7eb6"), Vector3(0, 0.08, 0.04), Vector3.ZERO, Vector3.ONE, 1.0)
	Art.ambient(n, Vector3.ZERO, Vector3(0.4, 0.3, 0.4), Color("ffd36b"), 10, "sparkle", 0.22, 1.2)
	floater(n, 0.1)
	spinner(n, 60)
	add_interactable("badge", pos, 2.2, "", true)
	var cloud := Models.critter("cloud")
	cloud.position = pos + Vector3(1.4, 0, -0.6)
	cloud.rotation_degrees.y = 200
	add_child(cloud)
	var pigeon := Models.critter("pigeon")
	pigeon.position = pos + Vector3(-1.3, 0, -0.4)
	pigeon.rotation_degrees.y = 160
	add_child(pigeon)
	npcs["badge_gang_a"] = cloud
	npcs["badge_gang_b"] = pigeon


func _island(pos: Vector3, s: float) -> void:
	var n := Art.node(self, "Island", pos)
	Art.part(n, Art.cyl(1.0 * s, 0.1 * s, 1.6 * s, 10), Color("9a7fb8"), Vector3(0, -0.8 * s, 0), Vector3.ZERO, Vector3.ONE, 0.0, false)
	Art.part(n, Art.cyl(1.02 * s, 1.0 * s, 0.25 * s, 14), Color("8fd48a"), Vector3(0, 0.1 * s, 0), Vector3.ZERO, Vector3.ONE, 0.0, false)
	for i in 3:
		var a := i * 2.1
		Art.part(n, Art.sphere(0.28 * s), Color("ffb3d1") if i == 1 else Color("6fcf7d"), Vector3(cos(a) * 0.5 * s, 0.5 * s, sin(a) * 0.5 * s), Vector3.ZERO, Vector3.ONE, 0.0, false)
	Art.part(n, Art.sphere(0.08 * s), Color("fff3b0"), Vector3(0, 0.9 * s, 0), Vector3.ZERO, Vector3.ONE, 3.0, false)
	floater(n, 0.6)


func _build_home(c: Vector3) -> void:
	var n := Art.node(self, "Home", c)
	var wall := Color("ffd9e6")
	Art.part(n, Art.box(Vector3(6, 3.2, 5)), wall, Vector3(0, 1.6, 0))
	Art.part(n, Art.box(Vector3(6.2, 0.35, 5.2)), Color("e8b7cc"), Vector3(0, 0.17, 0))
	Art.part(n, Art.prism(Vector3(7.0, 2.4, 5.8)), Color("9d7bd8"), Vector3(0, 4.4, 0))
	Art.part(n, Art.box(Vector3(0.8, 1.6, 0.8)), Color("e8a0b8"), Vector3(1.8, 5.0, -1.0))
	var smoke := Art.ambient(n, Vector3(1.8, 6.0, -1.0), Vector3(0.1, 0.1, 0.1), Color(1, 1, 1, 0.6), 10, "soft", 0.6, 3.0, Vector3(0.2, 0.8, 0))
	smoke.scale_amount_max = 2.0
	# Round wooden door
	Art.part(n, Art.box(Vector3(1.3, 1.8, 0.12)), Color("b0744c"), Vector3(0, 0.9, 2.52))
	Art.part(n, Art.cyl(0.65, 0.65, 0.12), Color("b0744c"), Vector3(0, 1.8, 2.52), Vector3(90, 0, 0))
	Art.part(n, Art.sphere(0.07), Color("ffd36b"), Vector3(0.4, 0.95, 2.62), Vector3.ZERO, Vector3.ONE, 1.0, false)
	Art.part(n, Art.box(Vector3(1.8, 0.12, 0.9)), Color("e8b7cc"), Vector3(0, 0.06, 3.0))
	for x in [-1.9, 1.9]:
		Art.part(n, Art.box(Vector3(1.2, 1.2, 0.1)), Color.WHITE, Vector3(x, 1.9, 2.52))
		Art.part(n, Art.box(Vector3(1.0, 1.0, 0.12)), Color("ffe6a8"), Vector3(x, 1.9, 2.53), Vector3.ZERO, Vector3.ONE, 1.2)
		Art.part(n, Art.box(Vector3(1.3, 0.28, 0.35)), Color("ff9fc4"), Vector3(x, 1.2, 2.7))
		for i in 4:
			Art.part(n, Art.sphere(0.1), [Color("ffe27a"), Color("ffffff"), Color("c3a6ff"), Color("ff6b8a")][i], Vector3(x - 0.45 + i * 0.3, 1.42, 2.7), Vector3.ZERO, Vector3.ONE, 0.2, false)
	Art.light(n, Vector3(0, 2.6, 3.2), Color("ffcf8a"), 1.2, 5.0)
	var heart := Art.part(n, Art.sphere(0.25), Color("ff7eb6"), Vector3(0, 3.8, 2.95), Vector3.ZERO, Vector3(1, 1, 0.3), 1.2, false)
	heart.name = "HeartSign"
	Art.collider(self, Vector3(6.2, 4, 5.2), c + Vector3(0, 2, 0))


func _build_cafe(c: Vector3) -> void:
	var n := Art.node(self, "Cafe", c)
	Art.part(n, Art.cyl(2.9, 3.1, 3.4, 28), Color("fff1dc"), Vector3(0, 1.7, 0))
	Art.part(n, Art.sphere(4.4, true), Color("ff6b8a"), Vector3(0, 3.2, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
	Art.part(n, Art.cyl(4.4, 4.4, 0.25, 28), Color("ff8fa3"), Vector3(0, 3.2, 0))
	for ab in [[0.5, 0.5], [-0.7, 0.45], [0.0, 1.05], [1.4, 0.3], [-1.5, 0.3], [2.6, 0.7], [-0.2, 0.2]]:
		var a: float = ab[0]
		var b: float = ab[1]
		var sp := Vector3(sin(a) * cos(b) * 4.35, 3.2 + sin(b) * 4.35 * 0.8, cos(a) * cos(b) * 4.35)
		Art.part(n, Art.sphere(0.5), Color("fff8f0"), sp, Vector3(-rad_to_deg(b) + 90, rad_to_deg(a), 0), Vector3(1, 0.3, 1), 0.0, false)
	# Door and round windows
	Art.part(n, Art.box(Vector3(1.4, 2.0, 0.2)), Color("8a5a3c"), Vector3(0, 1.0, 3.0))
	Art.part(n, Art.cyl(0.7, 0.7, 0.2), Color("8a5a3c"), Vector3(0, 2.0, 3.0), Vector3(90, 0, 0))
	Art.part(n, Art.cyl(0.3, 0.3, 0.22), Color("ffe6a8"), Vector3(0, 1.9, 3.03), Vector3(90, 0, 0), Vector3.ONE, 1.4, false)
	for a in [-0.75, 0.75]:
		var p := Vector3(sin(a) * 3.0, 2.0, cos(a) * 3.0)
		Art.part(n, Art.cyl(0.5, 0.5, 0.2), Color.WHITE, p, Vector3(90, rad_to_deg(a), 0))
		Art.part(n, Art.cyl(0.4, 0.4, 0.22), Color("ffe6a8"), p * 1.005, Vector3(90, rad_to_deg(a), 0), Vector3.ONE, 1.3, false)
	# Striped awning
	for i in 7:
		Art.part(n, Art.box(Vector3(0.36, 0.08, 1.0)), Color("ff8fb8") if i % 2 == 0 else Color.WHITE, Vector3(-1.08 + i * 0.36, 3.0, 3.25), Vector3(20, 0, 0))
	# Outdoor tables with mushroom parasols
	for x in [-3.6, 3.6]:
		var t := Art.node(n, "Table", Vector3(x, 0, 3.6))
		Art.part(t, Art.cyl(0.08, 0.1, 0.8), Color("8b5a3c"), Vector3(0, 0.4, 0))
		Art.part(t, Art.cyl(0.55, 0.55, 0.08), Color("fff1dc"), Vector3(0, 0.8, 0))
		Art.part(t, Art.cyl(0.04, 0.04, 1.4), Color("fff1dc"), Vector3(0, 1.5, 0))
		Art.part(t, Art.sphere(0.9, true), Color("ffb3c8") if x < 0 else Color("c3a6ff"), Vector3(0, 2.1, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
		Art.part(t, Art.cyl(0.05, 0.08, 0.2), Color("ffffff"), Vector3(0.2, 0.92, 0.1))
		Art.collider_round(self, 0.6, 1.0, c + Vector3(x, 0, 3.6))
	# The bubbling cauldron
	var caul := Art.node(n, "Cauldron", Vector3(4.2, 0, 1.3))
	Art.part(caul, Art.sphere(0.8), Color("4a3a5a"), Vector3(0, 0.7, 0), Vector3.ZERO, Vector3(1, 0.85, 1))
	Art.part(caul, Art.cyl(0.7, 0.7, 0.1), Color("7cff9a"), Vector3(0, 1.3, 0), Vector3.ZERO, Vector3.ONE, 2.0)
	Art.ambient(caul, Vector3(0, 1.4, 0), Vector3(0.4, 0.05, 0.4), Color("b8ffcf"), 16, "soft", 0.45, 1.8, Vector3(0, 1.0, 0))
	Art.light(caul, Vector3(0, 1.8, 0), Color("7cff9a"), 1.2, 4.0)
	Art.collider_round(self, 0.9, 1.4, c + Vector3(4.2, 0, 1.3))
	sign_board(c + Vector3(0, 3.35, 3.45), "Bubbling Cauldron", Color("fff4e0"), 34)
	Art.light(n, Vector3(0, 2.4, 3.8), Color("ffcf8a"), 1.3, 5.5)
	Art.collider_round(self, 3.2, 3.0, c)


func _build_spellwork(c: Vector3) -> void:
	var n := Art.node(self, "Spellwork", c)
	var stone := Color("b9a6e8")
	var trim := Color("8f78d0")
	var win := [Color("ffe6a0"), Color("bfe0ff"), Color("ffe6a0"), Color("ffc2e0"), Color("ffe6a0")]
	var tiers := [[Vector3(8, 5, 7), 2.5], [Vector3(7, 5, 6), 7.5], [Vector3(5.8, 4.5, 5), 12.25], [Vector3(4.4, 4, 4), 16.5]]
	for t in tiers:
		var size: Vector3 = t[0]
		var y: float = t[1]
		Art.part(n, Art.box(size), stone, Vector3(0, y, 0))
		Art.part(n, Art.box(Vector3(size.x + 0.3, 0.3, size.z + 0.3)), trim, Vector3(0, y + size.y / 2, 0))
		var cols := int(size.x / 1.2)
		var rows := int(size.y / 1.4)
		window_grid(c + Vector3(0, y + 0.2, 0), cols, rows, Vector2(1.2, 1.3), c.z + size.z / 2 + 0.03, win)
	# Spire, crystal and floating rune ring
	Art.part(n, Art.cyl(0.0, 2.4, 5.0), Color("6a4fb8"), Vector3(0, 21.0, 0))
	var crystal := Art.part(n, Art.sphere(0.8), Color("8fe8ff"), Vector3(0, 25.0, 0), Vector3.ZERO, Vector3(0.7, 1.5, 0.7), 2.5)
	floater(crystal, 0.4)
	spinner(crystal, 40)
	var ring := Art.node(n, "Ring", Vector3(0, 13.0, 0))
	Art.part(ring, Art.torus(4.6, 4.9), Color("ff9fd8"), Vector3.ZERO, Vector3(8, 0, 0), Vector3.ONE, 1.8, false)
	for i in 6:
		var a := i * TAU / 6
		Art.part(ring, Art.box(Vector3(0.4, 0.4, 0.4)), Color("fff3b0"), Vector3(cos(a) * 4.75, 0, sin(a) * 4.75), Vector3(45, 45, 0), Vector3.ONE, 2.5, false)
	spinner(ring, 18)
	# Entrance
	Art.part(n, Art.box(Vector3(2.6, 3.0, 0.3)), Color("5a4a8a"), Vector3(0, 1.5, 3.55))
	Art.part(n, Art.cyl(1.3, 1.3, 0.3), Color("5a4a8a"), Vector3(0, 3.0, 3.55), Vector3(90, 0, 0))
	Art.part(n, Art.box(Vector3(2.1, 2.8, 0.32)), Color("7cc8ff"), Vector3(0, 1.4, 3.56), Vector3.ZERO, Vector3.ONE, 0.9)
	Art.part(n, Art.box(Vector3(0.06, 2.8, 0.34)), Color("5a4a8a"), Vector3(0, 1.4, 3.57))
	for i in 3:
		Art.part(n, Art.box(Vector3(3.6 - i * 0.4, 0.15, 0.6)), Color("d8cfe8"), Vector3(0, 0.075 + i * 0.15, 4.3 - i * 0.35))
	for x in [-2.2, 2.2]:
		Art.part(n, Art.box(Vector3(0.9, 2.2, 0.08)), Color("ff8fb8"), Vector3(x, 3.4, 3.56))
		Art.part(n, Art.sphere(0.12), Color("ffd36b"), Vector3(x, 2.35, 3.62), Vector3.ZERO, Vector3.ONE, 2.0, false)
	Art.light(n, Vector3(0, 2.5, 5.0), Color("9fd8ff"), 2.0, 7.0)
	sign_board(c + Vector3(0, 5.0, 3.75), "Spellwork Tower", Color("f1e8ff"), 40)
	Art.ambient(n, Vector3(0, 3, 4.5), Vector3(3, 2, 1), Color("c8e8ff"), 20, "sparkle", 0.2, 2.5)
	Art.collider(self, Vector3(8.2, 5, 7.2), c + Vector3(0, 2.5, 0))


# =============================================================== TOWER
func _build_tower() -> void:
	env = {
		"top": Vector3(0.08, 0.06, 0.2), "mid": Vector3(0.2, 0.14, 0.38), "horizon": Vector3(0.4, 0.28, 0.5),
		"ambient": Color("f0d8c8"), "ambient_energy": 0.34, "sun_color": Color("fff0e0"), "sun_energy": 0.7,
		"sun_rot": Vector3(-65, -20, 0), "fog": Color("3a2c55"), "fog_density": 0.0,
	}
	cam_min = Vector2(-7, -8.5)
	cam_max = Vector2(7, 10.5)
	spawns = {"entrance": Vector3(0, 0, 12.2), "stairs": Vector3(0, 0, -7.8)}
	ground_plane(Vector2(200, 200), Art.mat(Color("2a1f40")), -0.05)
	slab(Vector3(26, 0.1, 29), Vector3(0, 0.0, 0), Art.ground_mat(Color("d29a6c"), Color("c0875c"), 2, 0.9, Color("94603e")))
	var rug := Art.ground_mat(Color("ffb3d1"), Color("ffa3c6"), 0)
	slab(Vector3(8, 0.03, 4), Vector3(2, 0.06, 10), rug)
	slab(Vector3(22, 0.03, 9), Vector3(0, 0.06, 0), Art.ground_mat(Color("93b0e3"), Color("839fd6"), 1, 0.7, Color("6d88c0")))
	var wall := Color("d9c9f2")
	# North, west, east walls (cutaway: no south wall so the camera can see in)
	Art.part(self, Art.box(Vector3(26.6, 6, 0.6)), wall, Vector3(0, 3, -14.8))
	for x in [-13.3, 13.3]:
		Art.part(self, Art.box(Vector3(0.6, 6, 30)), wall, Vector3(x, 3, 0))
		Art.collider(self, Vector3(0.6, 6, 30), Vector3(x, 3, 0))
	Art.collider(self, Vector3(26.6, 6, 0.6), Vector3(0, 3, -14.8))
	Art.part(self, Art.box(Vector3(26.6, 0.5, 0.4)), Color("b8a4e0"), Vector3(0, 0.25, 14.6))
	Art.collider(self, Vector3(11.5, 2, 0.4), Vector3(-7.7, 1, 14.6))
	Art.collider(self, Vector3(11.5, 2, 0.4), Vector3(7.7, 1, 14.6))
	for x in [-9, -3, 3, 9]:
		for z in [-14.45]:
			batch.add(Art.box(Vector3(2.2, 2.6, 0.1)), Color("8f78d0"), Vector3(x, 3.4, z))
			batch.add(Art.box(Vector3(1.9, 2.3, 0.12)), Color("3a3f8a"), Vector3(x, 3.4, z + 0.01), Vector3.ZERO, Vector3.ONE, 0.8)
			for i in 4:
				batch.add(Art.sphere(0.04), Color("fff8d0"), Vector3(x - 0.7 + i * 0.45, 3.0 + (i % 2) * 0.9, z + 0.08), Vector3.ZERO, Vector3.ONE, 3.0)
	for z in [-9.0, 0.0, 9.0]:
		for x in [-12.95, 12.95]:
			batch.add(Art.box(Vector3(0.12, 2.4, 2.0)), Color("3a3f8a"), Vector3(x, 3.4, z), Vector3.ZERO, Vector3.ONE, 0.8)
	# Bookshelves with glowing magic tomes
	for data in [[Vector3(-12.5, 0, -2), 90], [Vector3(-12.5, 0, 3), 90], [Vector3(12.5, 0, -2), -90], [Vector3(12.5, 0, 6), -90]]:
		_bookshelf(data[0], data[1])
	# Divider with the magic ward
	for x in [-7.75, 7.75]:
		Art.part(self, Art.box(Vector3(10.5, 2.4, 0.5)), Color("c9b6ec"), Vector3(x, 1.2, -6))
		Art.collider(self, Vector3(10.5, 2.4, 0.5), Vector3(x, 1.2, -6))
	for x in [-2.6, 2.6]:
		Art.part(self, Art.cyl(0.35, 0.4, 3.2), Color("8f78d0"), Vector3(x, 1.6, -6))
		Art.part(self, Art.sphere(0.3), Color("c9a6ff"), Vector3(x, 3.5, -6), Vector3.ZERO, Vector3.ONE, 2.0)
	if Game.state["quest"] < 5:
		var ward := Art.part(self, Art.box(Vector3(4.8, 3.2, 0.2)), Color(0.75, 0.45, 1.0, 0.45), Vector3(0, 1.6, -6), Vector3.ZERO, Vector3.ONE, 1.2, false)
		ward.name = "Ward"
		Art.ambient(self, Vector3(0, 1.6, -6), Vector3(2.3, 1.5, 0.2), Color("e0b8ff"), 30, "sparkle", 0.22, 1.5)
		Art.collider(self, Vector3(4.8, 3.2, 0.5), Vector3(0, 1.6, -6)).name = "WardBody"
		add_interactable("ward", Vector3(0, 0, -5.2), 1.6, "Inspect the magic ward")
	# Stairs up to the rooftop
	for i in 6:
		Art.part(self, Art.box(Vector3(4, 0.35 * (i + 1), 0.9)), Color("d8cfe8"), Vector3(0, 0.175 * (i + 1), -9.5 - i * 0.9))
	Art.collider(self, Vector3(4.2, 2.2, 5.6), Vector3(0, 1.1, -12.4))
	Art.label3d(self, "Rooftop", Vector3(0, 3.4, -11), 64, Color("fff3c4"))
	add_interactable("stairs", Vector3(0, 0, -8.6), 1.3, "", true)
	# Office desks with glowing screens
	for x in [-8.5, -3.5, 3.5, 8.5]:
		for z in [-3.2, 2.2]:
			_desk(Vector3(x, 0, z))
	# Lobby: reception desk, sofa, plants, floating candles
	Art.part(self, Art.box(Vector3(4.2, 1.1, 1.1)), Color("c98a5c"), Vector3(-5, 0.55, 9.2))
	Art.part(self, Art.box(Vector3(4.4, 0.12, 1.3)), Color("f1e3ee"), Vector3(-5, 1.15, 9.2))
	Art.part(self, Art.sphere(0.12), Color("ffd36b"), Vector3(-4, 1.3, 9.4), Vector3.ZERO, Vector3.ONE, 2.0)
	Art.collider(self, Vector3(4.2, 1.2, 1.1), Vector3(-5, 0.6, 9.2))
	sign_board(Vector3(-5, 0.6, 9.8), "Reception", Color("fff4e0"), 30)
	var sofa := Art.node(self, "Sofa", Vector3(6, 0, 11.5))
	Art.part(sofa, Art.box(Vector3(3, 0.5, 1.1)), Color("9d86e8"), Vector3(0, 0.35, 0))
	Art.part(sofa, Art.box(Vector3(3, 0.8, 0.3)), Color("9d86e8"), Vector3(0, 0.8, -0.45))
	for x in [-1.4, 1.4]:
		Art.part(sofa, Art.box(Vector3(0.3, 0.7, 1.1)), Color("8a72d8"), Vector3(x, 0.5, 0))
	Art.collider(self, Vector3(3, 1, 1.1), Vector3(6, 0.5, 11.5))
	for p in [Vector3(-11.8, 0, 13), Vector3(11.8, 0, 13), Vector3(-11.8, 0, -5), Vector3(11.8, 0, -5), Vector3(-8.5, 0, -13.5), Vector3(8.5, 0, -13.5)]:
		_plant(p)
	for i in 10:
		var cn := Art.node(self, "Candle", Vector3(randf_range(-11, 11), randf_range(3.6, 4.6), randf_range(-12, 12)))
		Art.part(cn, Art.cyl(0.07, 0.07, 0.3), Color("fff4e0"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 0.0, false)
		Art.part(cn, Art.sphere(0.07), Color("ffcf6b"), Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1, 1.5, 1), 4.0, false)
		floater(cn, 0.2)
	for p in [Vector3(-6, 3.6, 9), Vector3(6, 3.6, 9), Vector3(-6, 3.6, -1), Vector3(6, 3.6, -1), Vector3(0, 3.6, -10)]:
		Art.light(self, p, Color("ffd9a8"), 1.3, 8.0)
	# Water cooler
	var wc := Art.node(self, "Cooler", Vector3(11.5, 0, 1))
	Art.part(wc, Art.box(Vector3(0.6, 1.0, 0.6)), Color("f0f0f8"), Vector3(0, 0.5, 0))
	Art.part(wc, Art.cyl(0.25, 0.25, 0.6), Color(0.6, 0.85, 1.0, 0.7), Vector3(0, 1.3, 0), Vector3.ZERO, Vector3.ONE, 0.5)
	Art.collider(self, Vector3(0.6, 1.5, 0.6), Vector3(11.5, 0.7, 1))

	add_interactable("exit", Vector3(0, 0, 14.3), 1.6, "", true)
	shard("s4", Vector3(11.3, 0, -4.2))
	shard("s5", Vector3(-11.3, 0, 12.3))

	add_npc("dot", Models.dragon(), Vector3(-5, 0, 8.1), 0, "Talk to Dot", 2.2)
	add_npc("fern", Models.humanoid({"robe": Color("5fc9a8"), "hair": Color("c9703a"), "hair_style": "bun",
		"extras": ["ears", "glasses", "papers"], "accent": Color("ffe6a0")}), Vector3(10.5, 0, 4.5), -120, "Talk to Fern")
	add_npc("ghost", Models.ghost(), Vector3(5, 0, -4.8), 200, "Talk to Boo-b")

	critter_spawns = []
	var office := Rect2(-10.5, -4.8, 21, 9.4)
	var gremlin_types := ["paper", "coffee", "printer"]
	for i in 3:
		var uid := "g%d" % (i + 1)
		if not Game.flag("beat_" + uid):
			critter_spawns.append({"id": gremlin_types[i], "pos": Vector3(-7 + i * 7, 0, -0.5 + (i % 2) * 2), "area": office, "uid": uid})
	critter_spawns.append({"id": Game.OFFICE_POOL.pick_random(), "pos": Vector3(0, 0, 4), "area": office})


func _desk(p: Vector3) -> void:
	batch.add(Art.box(Vector3(2.2, 0.12, 1.1)), Color("d4a275"), p + Vector3(0, 0.8, 0))
	for sx in [-1, 1]:
		batch.add(Art.box(Vector3(0.1, 0.8, 1.0)), Color("b8875c"), p + Vector3(1.0 * sx, 0.4, 0))
	batch.add(Art.box(Vector3(0.9, 0.6, 0.08)), Color("4a4a60"), p + Vector3(0, 1.25, -0.3))
	batch.add(Art.box(Vector3(0.8, 0.5, 0.09)), [Color("8ff0ff"), Color("ffc2e0"), Color("c3ffb0")][int(abs(p.x + p.z)) % 3], p + Vector3(0, 1.25, -0.29), Vector3.ZERO, Vector3.ONE, 1.4)
	batch.add(Art.cyl(0.35, 0.35, 0.1), Color("9d86e8"), p + Vector3(0, 0.45, 0.9))
	batch.add(Art.box(Vector3(0.6, 0.6, 0.1)), Color("9d86e8"), p + Vector3(0, 0.8, 1.2))
	batch.add(Art.cyl(0.07, 0.06, 0.12), Color("fff4e0"), p + Vector3(0.7, 0.92, 0.2))
	Art.collider(self, Vector3(2.2, 1, 1.1), p + Vector3(0, 0.5, 0))


func _plant(p: Vector3) -> void:
	batch.add(Art.cyl(0.3, 0.22, 0.5), Color("e98f6f"), p + Vector3(0, 0.25, 0))
	for o in [Vector3(0, 0.8, 0), Vector3(0.25, 0.65, 0.1), Vector3(-0.2, 0.7, -0.1)]:
		batch.add(Art.sphere(0.32), Color("6cc978"), p + o)
	Art.collider_round(self, 0.35, 1.0, p)


func _bookshelf(p: Vector3, rot_y: float) -> void:
	var n := Art.node(self, "Shelf", p)
	n.rotation_degrees.y = rot_y
	Art.part(n, Art.box(Vector3(2.4, 3.0, 0.5)), Color("a87a5c"), Vector3(0, 1.5, 0))
	var cols := [Color("ff8fb8"), Color("7cc8ff"), Color("ffd36b"), Color("9d86e8"), Color("7cff9a")]
	for row in 3:
		for i in 7:
			var glow := 1.2 if (i + row) % 5 == 0 else 0.0
			Art.part(n, Art.box(Vector3(0.22, 0.6, 0.38)), cols[(i + row * 2) % 5], Vector3(-0.9 + i * 0.3, 0.55 + row * 0.9, 0.08), Vector3(0, 0, (i % 3 - 1) * 4.0), Vector3.ONE, glow, false)
	Art.collider(self, Vector3(2.4, 3, 0.6), p + Vector3(0, 1.5, 0), rot_y)


# ============================================================= ROOFTOP
func _build_roof() -> void:
	env = {
		"top": Vector3(0.05, 0.04, 0.18), "mid": Vector3(0.16, 0.12, 0.36), "horizon": Vector3(0.55, 0.32, 0.55),
		"ambient": Color("a6b8ff"), "ambient_energy": 0.35, "sun_color": Color("cfd8ff"), "sun_energy": 0.8,
		"sun_rot": Vector3(-50, 30, 0), "fog": Color("2a2050"), "fog_density": 0.004,
	}
	cam_min = Vector2(-4, -3.5)
	cam_max = Vector2(4, 6.5)
	spawns = {"stairs": Vector3(0, 0, 6.8)}
	slab(Vector3(1, 1, 1), Vector3(0, -40, 0), Art.mat(Color.BLACK))
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = Art.cyl(10, 10, 0.6, 48)
	floor_mi.material_override = Art.ground_mat(Color("c3b8dc"), Color("afa3cc"), 1, 1.0, Color("8f84b0"))
	floor_mi.position.y = -0.3
	add_child(floor_mi)
	Art.part(self, Art.cyl(10.2, 9.0, 3.0, 48), Color("8f78d0"), Vector3(0, -2.1, 0))
	for i in 28:
		var a := i * TAU / 28
		batch.add(Art.box(Vector3(1.9, 0.9, 0.4)), Color("b9a6e8"), Vector3(cos(a) * 9.8, 0.45, sin(a) * 9.8), Vector3(0, -rad_to_deg(a) + 90, 0))
		if i % 4 == 0:
			batch.add(Art.sphere(0.2), Color("ffd98a"), Vector3(cos(a) * 9.8, 1.1, sin(a) * 9.8), Vector3.ZERO, Vector3.ONE, 3.0)
	var ring := StaticBody3D.new()
	for i in 24:
		var a := i * TAU / 24
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.8, 2, 1)
		cs.shape = bs
		cs.position = Vector3(cos(a) * 9.6, 1, sin(a) * 9.6)
		cs.rotation.y = -a + PI / 2
		ring.add_child(cs)
	add_child(ring)
	# The great clock face of Spellwork Tower
	var clock := Art.node(self, "BigClock", Vector3(0, 6.5, -12))
	Art.part(clock, Art.cyl(5.2, 5.2, 0.6, 48), Color("8f78d0"), Vector3.ZERO, Vector3(90, 0, 0))
	Art.part(clock, Art.cyl(4.7, 4.7, 0.62, 48), Color("fff4e0"), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, 0.5)
	Art.part(clock, Art.torus(4.6, 5.0), Color("ffd36b"), Vector3(0, 0, 0.3), Vector3(90, 0, 0), Vector3.ONE, 0.8)
	for i in 12:
		var a := i * TAU / 12
		Art.part(clock, Art.box(Vector3(0.25, 0.7, 0.1)), Color("5a4a8a"), Vector3(sin(a) * 4.0, cos(a) * 4.0, 0.35), Vector3(0, 0, -rad_to_deg(a)))
	var hands := Art.node(clock, "Hands", Vector3(0, 0, 0.4))
	Art.part(hands, Art.box(Vector3(0.25, 3.2, 0.08)), Color("5a4a8a"), Vector3(0, 1.4, 0))
	Art.part(hands, Art.box(Vector3(0.3, 2.2, 0.08)), Color("5a4a8a"), Vector3(0.8, 0.6, 0), Vector3(0, 0, -60))
	Art.light(self, Vector3(0, 5, -9), Color("fff0c0"), 1.5, 10)
	# Floating crystals and city lights far below
	for i in 8:
		var a := i * TAU / 8 + 0.3
		var cr := Art.part(self, Art.sphere(0.4), [Color("8fe8ff"), Color("ff9fd8")][i % 2], Vector3(cos(a) * 12.5, 2.5 + (i % 3), sin(a) * 12.5), Vector3.ZERO, Vector3(0.6, 1.4, 0.6), 2.5, false)
		floater(cr, 0.5)
	for i in 260:
		var a := randf() * TAU
		var r := randf_range(18, 70)
		batch.add(Art.box(Vector3(0.5, 0.5, 0.5)), [Color("ffe6a0"), Color("ffc2e0"), Color("bfe0ff")][i % 3], Vector3(cos(a) * r, randf_range(-32, -26), sin(a) * r), Vector3.ZERO, Vector3.ONE, 3.0)
	Art.ambient(self, Vector3(0, 3, 0), Vector3(9, 2, 9), Color("fff3a0"), 40, "sparkle", 0.2, 4.0)
	add_interactable("down", Vector3(0, 0, 8.6), 1.2, "", true)
	Art.part(self, Art.box(Vector3(2.4, 0.2, 1.4)), Color("5a4a8a"), Vector3(0, 0.02, 8.8))
	Art.label3d(self, "Stairs", Vector3(0, 1.4, 9.2), 48, Color("fff3c4"))
	add_npc("ghost_roof", Models.ghost(), Vector3(-3.2, 0, 5.5), 160, "Talk to Boo-b")
	if Game.state["quest"] >= 6:
		add_npc("clock_friend", Models.tiny_clock(), Vector3(0, 0, -4), 0, "Talk to the Tiny Clock")
	else:
		var boss := Models.monday()
		boss.scale = Vector3.ONE * 0.8
		add_npc("boss", boss, Vector3(0, 0, -4.2), 0, "Face the Monday Monster", 3.2)
		Art.light(self, Vector3(0, 2.5, -2.5), Color("ff6b8a"), 2.0, 7.0)
