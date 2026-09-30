class_name Projectile
extends Node3D
## A flying magic missile (yours) or paper airplane / raindrop (theirs).

var velocity := Vector3.ZERO
var radius := 0.4
var damage := 10
var friendly := true
var element := "none"
var status := ""
var lifetime := 2.0
var color := Color("ff9f4c")
var pierce := 0 # how many extra critters it can pass through
var mp_on_hit := 0 # the witch's wand bolts refill MP like wand hits

var _t := 0.0
var _hit: Array = []


func _ready() -> void:
	position.y = 0.9
	var core := Art.part(self, Art.sphere(0.22 if friendly else 0.26), color, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.1 if friendly else 3.0, false)
	if friendly:
		# A soft halo so the colour still reads against bright ground.
		Art.part(self, Art.sphere(0.34), Color(color, 0.35), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 0.8, false)
	core.name = "Core"
	if not friendly:
		# A pale ring underneath so enemy shots are easy to read on the ground.
		var ring := MeshInstance3D.new()
		ring.mesh = Art.torus(0.35, 0.45)
		ring.material_override = Hazard._mat(Color(color, 0.6))
		ring.position.y = -0.85
		ring.scale = Vector3(1, 0.05, 1)
		add_child(ring)
	var trail := Art.ambient(self, Vector3.ZERO, Vector3(0.05, 0.05, 0.05), color, 14, "soft", 0.35, 0.35, -velocity.normalized() * 0.5)
	trail.local_coords = false


func _process(delta: float) -> void:
	_t += delta
	position += velocity * delta
	if _t >= lifetime:
		queue_free()
		return
	var c: Combat = Game.combat
	if c == null:
		return
	if friendly:
		for e in c.enemies:
			if not is_instance_valid(e) or e.dead or _hit.has(e):
				continue
			var d: Vector3 = e.global_position - global_position
			d.y = 0
			if d.length() <= radius + e.hit_radius:
				_hit.append(e)
				e.take_damage(damage, element, velocity, status)
				if mp_on_hit > 0 and _hit.size() == 1:
					Game.heal(0, mp_on_hit)
				Art.burst(get_parent(), global_position, color, 10, "sparkle", 2.5, 0.4, 0.3)
				if _hit.size() > pierce:
					queue_free()
					return
	else:
		var p: Player = c.player()
		if p:
			var d: Vector3 = p.global_position - global_position
			d.y = 0
			if d.length() <= radius + 0.35:
				if p.hurt(damage, global_position - velocity):
					queue_free()
