extends "res://level.gd"
# Локация 3: затопленный квартал. Дождь, вода по щиколотку, лодки, полуразрушенные дома.

func _build_location() -> void:
	location_name = "Затопленный квартал"
	rng.seed = 5511
	_make_materials()
	_extra_materials()
	_env({"sky_top": Color(0.18, 0.21, 0.25), "horizon": Color(0.38, 0.41, 0.44),
		"ambient": Color(0.38, 0.43, 0.5), "ambient_energy": 0.5,
		"fog": Color(0.33, 0.36, 0.4), "fog_density": 0.032,
		"sun": Color(0.75, 0.8, 0.9), "sun_energy": 0.45, "sun_rot": Vector3(-55, 20, 0)})
	_add_box(Vector3(0, -0.5, 0), Vector3(130, 1, 130), mats["asphalt"])
	_water(0.18)
	_particles("rain")
	_make_perimeter()
	# два длинных дома и один низкий
	var faces := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	_building(Vector3(-21, 0, 0), Vector3(10, 10, 20), mats["brick_dark"], faces)
	_building(Vector3(21, 0, 0), Vector3(10, 7, 20), mats["concrete"], faces)
	_building(Vector3(0, 0, 23), Vector3(12, 6, 7), mats["brick"], faces)
	# разрушенные стены — остатки домов
	for w in [[Vector3(-8, 0, -20), 0.0, 9.0], [Vector3(-13, 0, -24), 90.0, 7.0], [Vector3(10, 0, -22), 0.0, 8.0],
			[Vector3(14, 0, -27), 90.0, 6.0], [Vector3(-27, 0, 24), 0.0, 6.0], [Vector3(26, 0, 25), 90.0, 6.0]]:
		var h := rng.randf_range(1.4, 3.5)
		_add_box(w[0] + Vector3(0, h * 0.5, 0), Vector3(w[2], h, 0.5), mats["brick"], deg_to_rad(w[1]))
	# лодки
	for b in [[Vector3(-9, 0, 9), 30.0], [Vector3(10, 0, -9), -60.0], [Vector3(-4, 0, -30), 80.0], [Vector3(30, 0, -28), 10.0], [Vector3(-30, 0, -28), 120.0]]:
		_boat(b[0], b[1])
	# машины в воде
	for c in [[8.0, 10.0, 15.0, "car1"], [-11.0, -9.0, 75.0, "car0"], [3.0, -14.0, 100.0, "car3"],
			[-30.0, 12.0, 0.0, "car2"], [30.0, 12.0, 0.0, "car0"]]:
		var p := Vector3(c[0], 0, c[1])
		if _area_ok(p, 2.2, 2.2):
			_car(p, c[2], c[3])
	# плавающий мусор, ящики
	_scatter(16, 36.0, 1.2, func(p: Vector3) -> void:
		var s := rng.randf_range(0.6, 1.1)
		_add_box(p + Vector3(0, s * 0.5, 0), Vector3(s, s, s), mats["wood_dark"], rng.randf() * TAU))
	_scatter(14, 36.0, 1.5, func(p: Vector3) -> void:
		var s := Vector3(rng.randf_range(0.8, 2.2), rng.randf_range(0.5, 1.2), rng.randf_range(0.8, 2.0))
		_add_box(p + Vector3(0, s.y * 0.5, 0), s, mats["concrete"], rng.randf() * TAU))
	for i in 30:
		var p := Vector3(rng.randf_range(-38.0, 38.0), 0.2, rng.randf_range(-38.0, 38.0))
		_add_visual(_box_mesh(Vector3(rng.randf_range(0.3, 1.2), 0.04, rng.randf_range(0.2, 0.8))), mats["wood_grey"], p, Vector3(0, rng.randf() * TAU, 0))
	# плющ
	for i in 20:
		var h := rng.randf_range(3.0, 7.0)
		_add_visual(_box_mesh(Vector3(rng.randf_range(0.6, 1.6), h, 0.15)), mats["moss"],
			Vector3(rng.randf_range(-38.0, 38.0), h * 0.5, HALF if rng.randf() > 0.5 else -HALF))

func _boat(p: Vector3, rot_deg: float) -> void:
	var body := _add_box(p + Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 4.6), mats["white"], deg_to_rad(rot_deg))
	var nose := PrismMesh.new()
	nose.size = Vector3(1.8, 1.4, 0.9)
	_add_visual(nose, mats["white"], Vector3(0, 0, -2.7), Vector3(-PI * 0.5, 0, 0), Vector3.ONE, body)
	_add_visual(_box_mesh(Vector3(1.84, 0.15, 4.62)), mats["red"], Vector3(0, -0.2, 0), Vector3.ZERO, Vector3.ONE, body)
	_add_visual(_box_mesh(Vector3(1.4, 0.1, 0.4)), mats["wood"], Vector3(0, 0.4, 0.6), Vector3.ZERO, Vector3.ONE, body)
