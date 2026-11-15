extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	load("res://main.gd").skip_menu = true
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/game-native.png")
	var player = main.get_node("Player")
	var victim = load("res://enemy.tscn").instantiate()
	victim.kind = "runner"
	main.add_child(victim)
	victim.set_physics_process(false)
	victim.global_position = player.global_position+Vector3(0,0,-3)
	await physics_frame
	await physics_frame
	var origin: Vector3 = player.camera.global_position
	var target: Vector3 = victim.head_sphere()[0]
	var result: int = player._shoot_ray(origin,(target-origin).normalized(),player.weapons[player.idx])
	assert(result == 2)
	assert(player.hit_flash > 0.0 and player.head_flash > 0.0)
	assert(get_nodes_in_group("blood_burst").size() >= 2)
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("/tmp/game-hit.png")
	main.queue_free()
	await process_frame
	print("NATIVE GAME AND BLOOD SMOKE PASSED")
	quit()
