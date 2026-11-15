extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for kind in ["runner","clicker","bloater","bandit"]:
		for seed_value in [0,42,999]:
			var model := Node3D.new()
			root.add_child(model)
			var parts: Dictionary = load("res://character_surface.gd").build(model,kind,seed_value)
			assert(parts.legs.size()==2 and parts.knees.size()==2 and parts.elbows.size()==2)
			for frame in 120:
				load("res://character_surface.gd").gait(parts,frame*0.1,1.0,1.0/60.0)
			assert(absf(parts.knees[0].rotation.x)+absf(parts.knees[1].rotation.x)>0.01)
			for frame in 120:
				load("res://character_surface.gd").gait(parts,0,0,1.0/60.0)
			assert(absf(parts.knees[0].rotation.x)<0.001)
			await process_frame
			model.queue_free()
			await process_frame
	for weapon in ["bat","pistol","shotgun","rifle"]:
		var model := Node3D.new()
		root.add_child(model)
		var parts: Dictionary = load("res://bandit_model.gd").build(model,weapon,42)
		assert(parts.gun.get_parent()==parts.arms[1])
		assert(parts.muzzle.get_parent()==parts.gun)
		await process_frame
		model.queue_free()
		await process_frame
	print("CHARACTER CONTRACTS PASSED")
	quit()
