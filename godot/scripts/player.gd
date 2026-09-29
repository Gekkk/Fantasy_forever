class_name Player
extends CharacterBody3D
## The hero in the overworld: smooth 8-direction movement with a little bounce.

const SPEED := 5.2
const ACCEL := 30.0

var model: ModelAnim
var can_move := true
var _step_timer := 0.0
var _dust_timer := 0.0


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


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if can_move:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(input.x, 0, input.y)
	var target := dir * SPEED
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
	velocity.y = 0.0
	move_and_slide()
	position.y = 0.0
	var moving := Vector2(velocity.x, velocity.z).length() > 0.5
	model.moving = moving
	if dir.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), minf(1.0, 14.0 * delta))
	if moving:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.32
			Audio.sfx("step", 0.15, -10.0)
		_dust_timer -= delta
		if _dust_timer <= 0.0:
			_dust_timer = 0.25
			Art.burst(get_parent(), global_position + Vector3(0, 0.1, 0), Color(1, 1, 1, 0.5), 3, "soft", 0.6, 0.5, 0.25, Vector3(0, 0.5, 0), 60)
