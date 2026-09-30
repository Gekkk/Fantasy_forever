extends Node
## Focused check: getting knocked out wakes you up at home, healed, able to move.

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(1.0).timeout
	main.title.visible = false
	Game.new_game("Luna", "witch", 0, 0)
	await main.load_map("city", Vector3(-20, 0, 10), false)
	main.mode = main.Mode.EXPLORE
	main.combat.spawn_enemy("bee", Vector3(-19, 0, 10), Rect2(-38, 4, 28, 12.5), "", true)
	var t := 0.0
	while t < 60.0 and main.world.map_id != "home_in":
		# Stay at 1 HP (Mochi likes to heal you!).
		Game.state["hp"] = mini(int(Game.state["hp"]), 1)
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	while t < 60.0 and main.mode != main.Mode.EXPLORE:
		if main.ui.is_dialog_open():
			main.ui._advance()
		await get_tree().create_timer(0.2).timeout
		t += 0.2
	print("RESULT map=", main.world.map_id, " hp=", Game.state["hp"], "/", Game.state["max_hp"], " mode=", main.mode)
	get_tree().quit()
