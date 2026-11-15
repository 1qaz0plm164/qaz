extends "res://level.gd"
# Локация 8: зимний Джексон. Снег, деревянный частокол, дома, конюшня, сосны в снегу.

func _build_location() -> void:
	location_name = "Джексон зимой"
	rng.seed = 2525
	_make_materials()
	_extra_materials()
	_env({"sky_top": Color(0.55, 0.6, 0.66), "horizon": Color(0.8, 0.82, 0.85),
		"ambient": Color(0.62, 0.66, 0.72), "ambient_energy": 0.6,
		"fog": Color(0.8, 0.82, 0.86), "fog_density": 0.03,
		"sun": Color(0.9, 0.92, 1.0), "sun_energy": 0.6, "sun_rot": Vector3(-30, -50, 0)})
	_add_box(Vector3(0, -0.5, 0), Vector3(130, 1, 130), mats["snow"])
	_particles("snow")
	# частокол по краю
	_wall_ring(mats["wood_dark"], 4.5)
	for side in [-1.0, 1.0]:
		var t := -HALF
		while t <= HALF:
			_add_visual(_cyl_mesh(0.25, 5.4), mats["wood_dark"], Vector3(side * (HALF + 0.1), 2.7, t))
			_add_visual(_cyl_mesh(0.25, 5.4), mats["wood_dark"], Vector3(t, 2.7, side * (HALF + 0.1)))
			t += 2.5
	# сосны за частоколом
	for i in 50:
		var a := rng.randf() * TAU
		var r := rng.randf_range(HALF + 10.0, HALF + 22.0)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = rng.randf_range(2.2, 3.2)
		cone.height = rng.randf_range(10.0, 15.0)
		cone.radial_segments = 8
		_add_visual(cone, mats["pine_snow"] if i % 3 else mats["pine"], Vector3(cos(a) * r, cone.height * 0.5, sin(a) * r))
	# улица с домами
	for hx in [-27.0, -13.0, 13.0, 26.0]:
		for hz in [-20.0, 20.0]:
			_wood_house(Vector3(hx, 0, hz), Vector3(rng.randf_range(7.0, 8.0), rng.randf_range(3.0, 4.0), rng.randf_range(6.0, 7.0)),
				["wood", "wood_dark", "wood_grey"][rng.randi() % 3], "wood_dark")
	# конюшня и церковь
	_wood_house(Vector3(0, 0, -27), Vector3(12, 5, 7), "wood", "wood_grey")
	_wood_house(Vector3(0, 0, 27), Vector3(9, 5.5, 7), "wood_grey", "wood_dark")
	_add_visual(_box_mesh(Vector3(1.4, 4.0, 1.4)), mats["wood_grey"], Vector3(0, 9.0, 27))
	# низкие заборы, сани, телеги, поленницы
	for f in [[Vector3(-20, 0, -10), 0.0, 8.0], [Vector3(20, 0, 10), 0.0, 8.0], [Vector3(-10, 0, 13), 90.0, 6.0], [Vector3(10, 0, -13), 90.0, 6.0]]:
		_add_box(f[0] + Vector3(0, 0.55, 0), Vector3(f[2], 1.1, 0.25), mats["wood_dark"], deg_to_rad(f[1]))
	_scatter(10, 32.0, 1.4, func(p: Vector3) -> void:
		_add_box(p + Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 1.0), mats["wood"], rng.randf() * TAU))
	# сосны в городке
	_scatter(16, 36.0, 1.2, func(p: Vector3) -> void:
		_tree(p, rng.randf_range(6.0, 10.0), true, true))
	# сугробы
	for i in 50:
		var p := Vector3(rng.randf_range(-38.0, 38.0), 0, rng.randf_range(-38.0, 38.0))
		var r := rng.randf_range(0.8, 2.2)
		_add_visual(_sphere_mesh(r), mats["snow"], p, Vector3.ZERO, Vector3(1.6, 0.35, 1.3))
	# фонари
	for p in [Vector3(7, 0, 9), Vector3(-7, 0, -9), Vector3(-20, 0, 9), Vector3(20, 0, -9)]:
		_add_box(p + Vector3(0, 2.0, 0), Vector3(0.16, 4.0, 0.16), mats["wood_dark"])
		_add_visual(_box_mesh(Vector3(0.35, 0.45, 0.35)), mats["lamp"], p + Vector3(0, 4.1, 0))
