class_name Art
extends RefCounted
## Shared shaders, materials, meshes and effect helpers.
## Everything visual in the game is built from these primitives.

const TOON_LIGHT := """
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(0.0, 0.12, ndl) * 0.75 + smoothstep(0.45, 0.6, ndl) * 0.25;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * ATTENUATION * band;
}
"""

const TOON := """
shader_type spatial;
render_mode cull_back;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float rim = 0.3;
uniform vec4 rim_tint : source_color = vec4(1.0, 0.86, 0.96, 1.0);
void fragment() {
	ALBEDO = albedo.rgb * COLOR.rgb;
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = emission_color.rgb * COLOR.rgb * emission_energy + rim_tint.rgb * r * rim;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

const TOON_ALPHA := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float rim = 0.3;
uniform vec4 rim_tint : source_color = vec4(1.0, 0.86, 0.96, 1.0);
void fragment() {
	ALBEDO = albedo.rgb * COLOR.rgb;
	float r = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	EMISSION = emission_color.rgb * emission_energy + rim_tint.rgb * r * rim;
	ALPHA = albedo.a;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

const GROUND := """
shader_type spatial;
uniform vec4 color_a : source_color = vec4(0.55, 0.82, 0.5, 1.0);
uniform vec4 color_b : source_color = vec4(0.42, 0.72, 0.45, 1.0);
uniform vec4 mortar : source_color = vec4(0.6, 0.55, 0.6, 1.0);
uniform int pattern = 0;
uniform float scale = 0.18;
uniform float tile = 1.3;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 c;
	if (pattern == 0) {
		float n = noise(wpos.xz * scale) * 0.65 + noise(wpos.xz * scale * 5.0) * 0.35;
		c = mix(color_a.rgb, color_b.rgb, n);
	} else if (pattern == 1) {
		vec2 g = wpos.xz * tile;
		g.x += mod(floor(g.y), 2.0) * 0.5;
		vec2 id = floor(g);
		vec2 f = fract(g);
		float e = smoothstep(0.0, 0.07, f.x) * smoothstep(0.0, 0.07, f.y) * smoothstep(1.0, 0.93, f.x) * smoothstep(1.0, 0.93, f.y);
		vec3 stone = mix(color_a.rgb, color_b.rgb, hash(id));
		c = mix(mortar.rgb, stone, e);
	} else {
		vec2 g = wpos.xz * tile;
		float plank = fract(g.x);
		float seam = smoothstep(0.0, 0.05, plank) * smoothstep(1.0, 0.95, plank);
		float grain = noise(vec2(floor(g.x) * 13.0, wpos.z * 0.8)) * 0.5 + noise(wpos.xz * vec2(2.0, 12.0)) * 0.2;
		c = mix(mortar.rgb, mix(color_a.rgb, color_b.rgb, grain), seam);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

const WATER := """
shader_type spatial;
render_mode blend_mix, cull_back;
uniform vec4 deep : source_color = vec4(0.35, 0.55, 0.95, 1.0);
uniform vec4 shallow : source_color = vec4(0.55, 0.9, 1.0, 1.0);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float w = sin(wpos.x * 2.2 + TIME * 1.3) * sin(wpos.z * 2.6 - TIME * 1.1);
	ALBEDO = mix(deep.rgb, shallow.rgb, 0.5 + 0.5 * w);
	float glint = smoothstep(0.93, 0.99, sin(wpos.x * 6.0 + TIME * 2.0) * sin(wpos.z * 5.0 - TIME * 1.6));
	EMISSION = vec3(1.0) * glint * 0.6 + shallow.rgb * 0.12;
	ALPHA = 0.82;
	ROUGHNESS = 0.2;
}
"""

const SKY := """
shader_type sky;
uniform vec3 top = vec3(0.12, 0.1, 0.32);
uniform vec3 mid = vec3(0.45, 0.3, 0.62);
uniform vec3 horizon = vec3(1.0, 0.66, 0.68);
uniform vec3 bottom = vec3(0.2, 0.15, 0.3);
uniform vec3 moon_dir = vec3(-0.35, 0.42, -0.84);
float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453); }
void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon, mid, smoothstep(0.0, 0.25, h));
	col = mix(col, top, smoothstep(0.25, 0.75, h));
	col = mix(bottom, col, smoothstep(-0.25, 0.02, h));
	vec3 cell = floor(d * 160.0);
	float s = hash(cell);
	float tw = 0.6 + 0.4 * sin(TIME * (1.0 + s * 3.0) + s * 40.0);
	col += vec3(1.0, 0.95, 1.0) * step(0.9955, s) * smoothstep(0.08, 0.5, h) * tw;
	vec3 md = normalize(moon_dir);
	float m = dot(d, md);
	col += vec3(1.0, 0.95, 0.85) * smoothstep(0.9982, 0.9987, m);
	col += vec3(0.9, 0.8, 1.0) * pow(max(m, 0.0), 180.0) * 0.5;
	col += vec3(1.0, 0.7, 0.8) * pow(max(m, 0.0), 12.0) * 0.08;
	COLOR = col;
}
"""

static var _shaders := {}
static var _mats := {}
static var _meshes := {}
static var _textures := {}
static var font: Font


static func shader(code_name: String) -> Shader:
	if not _shaders.has(code_name):
		var s := Shader.new()
		match code_name:
			"toon": s.code = TOON + TOON_LIGHT
			"toon_alpha": s.code = TOON_ALPHA + TOON_LIGHT
			"ground": s.code = GROUND + TOON_LIGHT
			"water": s.code = WATER
			"sky": s.code = SKY
		_shaders[code_name] = s
	return _shaders[code_name]


static func get_font() -> Font:
	if font == null:
		var base: FontFile = load("res://fonts/Fredoka.ttf")
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {"wght": 600}
		font = fv
	return font


static func tex(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load("res://textures/%s.png" % name)
	return _textures[name]


## Toon material, cached per color/emission/alpha combination.
static func mat(c: Color, emit := 0.0, rim := 0.3) -> ShaderMaterial:
	var alpha := c.a < 0.99
	var key := "%s|%.2f|%.2f" % [c.to_html(true), emit, rim]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = shader("toon_alpha" if alpha else "toon")
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("rim", rim)
	if emit > 0.0:
		m.set_shader_parameter("emission_color", Color(c.r, c.g, c.b))
		m.set_shader_parameter("emission_energy", emit)
	_mats[key] = m
	return m


static func ground_mat(a: Color, b: Color, pattern := 0, tile := 1.3, mortar := Color(0.55, 0.5, 0.58)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("ground")
	m.set_shader_parameter("color_a", a)
	m.set_shader_parameter("color_b", b)
	m.set_shader_parameter("pattern", pattern)
	m.set_shader_parameter("tile", tile)
	m.set_shader_parameter("mortar", mortar)
	return m


# ---------------------------------------------------------------- meshes
static func sphere(r: float, hemi := false) -> Mesh:
	var key := "s%.3f%s" % [r, hemi]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * (1.0 if hemi else 2.0)
		m.is_hemisphere = hemi
		m.radial_segments = 20 if r > 0.15 else 10
		m.rings = 10 if r > 0.15 else 6
		_meshes[key] = m
	return _meshes[key]


static func box(size: Vector3) -> Mesh:
	var key := "b%s" % size
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


static func cyl(top: float, bottom: float, h: float, segs := 18) -> Mesh:
	var key := "c%.3f_%.3f_%.3f_%d" % [top, bottom, h, segs]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func capsule(r: float, h: float) -> Mesh:
	var key := "k%.3f_%.3f" % [r, h]
	if not _meshes.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = h
		m.radial_segments = 14
		m.rings = 6
		_meshes[key] = m
	return _meshes[key]


static func torus(inner: float, outer: float) -> Mesh:
	var key := "t%.3f_%.3f" % [inner, outer]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 20
		m.ring_segments = 10
		_meshes[key] = m
	return _meshes[key]


static func prism(size: Vector3) -> Mesh:
	var key := "p%s" % size
	if not _meshes.has(key):
		var m := PrismMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


## Adds a colored mesh part to a parent node.
static func part(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO, rot := Vector3.ZERO,
		scl := Vector3.ONE, emit := 0.0, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color, emit)
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func node(parent: Node3D, name: String, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n)
	return n


## Static collision box.
static func collider(parent: Node3D, size: Vector3, pos: Vector3, rot_y := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	body.rotation_degrees.y = rot_y
	parent.add_child(body)
	return body


static func collider_round(parent: Node3D, radius: float, height: float, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	cs.position.y = height / 2
	body.add_child(cs)
	body.position = pos
	parent.add_child(body)
	return body


# --------------------------------------------------------------- effects
static func particle_mat(tex_name: String) -> StandardMaterial3D:
	var key := "pm_" + tex_name
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex(tex_name)
	m.no_depth_test = false
	_mats[key] = m
	return m


static func _fade_ramp(c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(c.r, c.g, c.b, 1.0))
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	return g


## One-shot particle burst that frees itself.
static func burst(parent: Node, pos: Vector3, color: Color, amount := 24, tex_name := "sparkle",
		speed := 3.0, lifetime := 0.9, size := 0.3, gravity := Vector3(0, -3, 0), spread := 180.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = particle_mat(tex_name)
	p.mesh = q
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = gravity
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.color_ramp = _fade_ramp(color)
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(lifetime + 0.4).timeout.connect(p.queue_free)
	return p


## Continuous ambient particles (fireflies, sparkles, snow...).
static func ambient(parent: Node3D, pos: Vector3, extents: Vector3, color: Color, amount := 30,
		tex_name := "soft", size := 0.25, lifetime := 4.0, velocity := Vector3(0, 0.3, 0)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = particle_mat(tex_name)
	p.mesh = q
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = velocity.normalized() if velocity.length() > 0 else Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = velocity.length() * 0.5
	p.initial_velocity_max = velocity.length()
	p.gravity = Vector3.ZERO
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	g.colors = PackedColorArray([Color(color, 0), color, color, Color(color, 0)])
	p.color_ramp = g
	p.position = pos
	parent.add_child(p)
	return p


## Floating text in 3D (damage numbers, "Perfect!", etc).
static func float_text(parent: Node, pos: Vector3, text: String, color: Color, size := 72, rise := 1.2, dur := 1.1) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = get_font()
	l.font_size = size
	l.outline_size = 16
	l.outline_modulate = Color(0.22, 0.12, 0.3)
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	l.outline_render_priority = 9
	l.pixel_size = 0.006
	l.position = pos
	parent.add_child(l)
	l.scale = Vector3.ONE * 0.4
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", pos.y + rise, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, dur * 0.35).set_delay(dur * 0.65)
	tw.chain().tween_callback(l.queue_free)


static func light(parent: Node3D, pos: Vector3, color: Color, energy := 1.5, rng := 5.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	parent.add_child(l)
	return l


static func label3d(parent: Node3D, text: String, pos: Vector3, size := 48, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = get_font()
	l.font_size = size
	l.outline_size = 12
	l.outline_modulate = Color(0.3, 0.15, 0.35)
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.008
	l.position = pos
	parent.add_child(l)
	return l
