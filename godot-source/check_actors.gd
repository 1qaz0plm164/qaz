extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	await physics_frame
	await physics_frame
	var region := NavigationRegion3D.new()
	var navmesh := NavigationMesh.new()
	navmesh.vertices = PackedVector3Array([Vector3(-20,0,-20),Vector3(20,0,-20),Vector3(20,0,20),Vector3(-20,0,20)])
	navmesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = navmesh
	root.add_child(region)
	await physics_frame
	NavigationServer3D.map_force_update(root.world_3d.navigation_map)
	for family in ["enemy","bandit"]:
		var script = load("res://"+family+".gd")
		for kind in script.TYPES:
			var actor = load("res://enemy.tscn").instantiate() if family == "enemy" else script.new()
			actor.kind = kind
			root.add_child(actor)
			actor.set_physics_process(false)
			actor.set_process(false)
			actor.velocity = Vector3(2,0,0)
			for i in 90:
				if family == "enemy":
					actor._animate(1.0/60.0,true)
				else:
					actor._animate(1.0/60.0)
			assert(actor.gait_weight > 0.99)
			actor.velocity = Vector3.ZERO
			for i in 90:
				if family == "enemy":
					actor._animate(1.0/60.0,false)
				else:
					actor._animate(1.0/60.0)
			assert(actor.gait_weight < 0.001)
			assert(actor.head_sphere()[0].is_finite())
			actor.free()
	print("ALL TEN ACTOR VARIANTS PASSED")
	quit()
