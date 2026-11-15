extends "res://level.gd"
# Локация 2: лесное шоссе. Скалы по краю, сосны, брошенные машины на дороге, хижина лесника.

func _build_location() -> void:
	location_name = "Лесное шоссе"
	rng.seed = 7302
	_make_materials()
	_extra_materials()
	_env({"sky_top": Color(0.32, 0.38, 0.4), "horizon": Color(0.55, 0.6, 0.55),
		"ambient": Color(0.45, 0.52, 0.48), "ambient_energy": 0.55,
		"fog": Color(0.45, 0.52, 0.47), "fog_density": 0.03,
		"sun": Color(0.95, 0.9, 0.75), "sun_energy": 0.75, "sun_rot": Vector3(-42, -30, 0)})
	_add_box(Vector3(0, -0.5, 0), Vector3(130, 1, 130), mats["forest_floor"])
	# шоссе через всю карту
	_add_visual(_box_mesh(Vector3(HALF * 2.0, 0.03, 11.0)), mats["asphalt"], Vector3(0, 0.015, 0))
	for i in range(-6, 7):
		if i % 2 == 0:
			_add_visual(_box_mesh(Vector3(3.0, 0.01, 0.2)), mats["line"], Vector3(i * 6.0, 0.04, 0))
	_cliff_ring(mats["rock"])
	# сосны вокруг (не на дороге)
	for i in 90:
		var p := Vector3(rng.randf_range(-38.0, 38.0), 0, rng.randf_range(-38.0, 38.0))
		if absf(p.z) < 7.5 or not _area_ok(p, 1.2, 1.2):
			continue
		_tree(p, rng.randf_range(7.0, 12.0), rng.randf() > 0.2)
	# машины на шоссе — укрытия
	for c in [[-12.0, 2.5, 80.0, "car0"], [14.0, -2.0, 95.0, "car1"], [24.0, 2.8, 70.0, "car3"],
			[-25.0, -2.5, 100.0, "car2"], [9.0, 3.0, 20.0, "car2"], [-8.0, -3.0, 160.0, "car3"]]:
		_car(Vector3(c[0], 0, c[1]), c[2], c[3])
	_bus(Vector3(-20.0, 0, 3.5), 84.0)
	# хижина лесника и вышка
	_wood_house(Vector3(-22, 0, -25), Vector3(8, 3.2, 6), "wood_dark", "wood_grey")
	_tower(Vector3(23, 0, 24))
	# поваленные деревья, валуны, кусты
	_scatter(10, 34.0, 2.5, func(p: Vector3) -> void:
		if absf(p.z) > 6.0:
			_log(p, rng.randf() * TAU, rng.randf_range(4.0, 7.0)))
	_scatter(18, 36.0, 1.5, func(p: Vector3) -> void:
		_rock(p, Vector3(rng.randf_range(1.0, 2.6), rng.randf_range(0.8, 1.8), rng.randf_range(1.0, 2.4))))
	for i in 60:
		var p := Vector3(rng.randf_range(-38.0, 38.0), 0, rng.randf_range(-38.0, 38.0))
		if absf(p.z) < 6.0:
			continue
		var r := rng.randf_range(0.5, 1.1)
		_add_visual(_sphere_mesh(r), mats["leaf"] if rng.randf() > 0.4 else mats["leaf2"], p + Vector3(0, r * 0.3, 0), Vector3.ZERO, Vector3(1.3, 0.6, 1.3))
	for i in 30:
		var p := Vector3(rng.randf_range(-38.0, 38.0), 0, rng.randf_range(-38.0, 38.0))
		_add_visual(_box_mesh(Vector3(rng.randf_range(2.0, 6.0), 0.05, rng.randf_range(2.0, 6.0))), mats["moss"],
			Vector3(p.x, 0.05, p.z), Vector3(0, rng.randf() * TAU, 0))
