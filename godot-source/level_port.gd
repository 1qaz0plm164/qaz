extends "res://level.gd"
# Локация 6: морской порт на закате. Ряды контейнеров, краны у причала, склады, вода за краем.

func _build_location() -> void:
	location_name = "Порт"
	rng.seed = 6620
	_make_materials()
	_extra_materials()
	_env({"sky_top": Color(0.3, 0.3, 0.42), "horizon": Color(0.85, 0.55, 0.35),
		"ambient": Color(0.55, 0.47, 0.45), "ambient_energy": 0.55,
		"fog": Color(0.62, 0.5, 0.42), "fog_density": 0.017,
		"sun": Color(1.0, 0.62, 0.38), "sun_energy": 1.0, "sun_rot": Vector3(-14, 10, 0)})
	# причал заканчивается на z = +40, дальше вода
	_add_box(Vector3(0, -0.5, -12.5), Vector3(130, 1, 105), mats["concrete"])
	_add_box(Vector3(0, -4.0, 60), Vector3(130, 1, 40), mats["sand"])
	_add_visual(_box_mesh(Vector3(200, 0.02, 120)), mats["water"], Vector3(0, -0.9, 100))
	_add_visual(_box_mesh(Vector3(130, 3.5, 0.6)), mats["concrete"], Vector3(0, -1.75, 40.3))
	# склады по трём сторонам
	for i in 4:
		var h := rng.randf_range(9.0, 14.0)
		_building(Vector3(-30.0 + i * 20.0, 0, -(HALF + WALL_DEPTH * 0.5)), Vector3(20.0, h, WALL_DEPTH), mats["metal"] if i % 2 == 0 else mats["brick_dark"], [Vector3(0, 0, 1)])
	for side in [-1.0, 1.0]:
		for i in 4:
			var h := rng.randf_range(8.0, 13.0)
			_building(Vector3(side * (HALF + WALL_DEPTH * 0.5), 0, -30.0 + i * 20.0), Vector3(WALL_DEPTH, h, 20.0), mats["concrete"] if i % 2 == 0 else mats["metal"], [Vector3(-side, 0, 0)])
	# край причала: тумбы и невидимая стена, чтобы не свалиться в воду
	var edge := _add_box(Vector3(0, 2.0, HALF + 0.2), Vector3(HALF * 2.0, 4.0, 0.4), mats["concrete"])
	edge.get_child(0).visible = false
	for i in 14:
		_add_visual(_cyl_mesh(0.25, 0.6), mats["metal"], Vector3(-36.0 + i * 5.5, 0.3, HALF - 0.3))
	_add_visual(_box_mesh(Vector3(HALF * 2.0, 0.08, 0.3)), mats["yellow"], Vector3(0, 0.04, HALF - 0.9))
	# корабль у причала (только вид)
	_add_visual(_box_mesh(Vector3(70, 9, 14)), mats["rust"], Vector3(-5, 1.5, 58))
	_add_visual(_box_mesh(Vector3(14, 8, 10)), mats["white"], Vector3(-28, 10, 58))
	for i in 5:
		_add_visual(_box_mesh(Vector3(6, 2.6, 12)), mats["cont%d" % (i % 4)], Vector3(-10.0 + i * 7.0, 7.3, 58))
	# портовые краны
	for cx in [-16.0, 16.0]:
		for dx in [-3.0, 3.0]:
			_add_box(Vector3(cx + dx, 9.0, 34.0), Vector3(0.8, 18.0, 0.8), mats["yellow"])
		_add_visual(_box_mesh(Vector3(7.0, 1.2, 1.2)), mats["yellow"], Vector3(cx, 18.0, 34.0))
		_add_visual(_box_mesh(Vector3(1.2, 1.2, 40.0)), mats["yellow"], Vector3(cx, 19.0, 40.0))
		_add_visual(_box_mesh(Vector3(3.0, 2.5, 3.0)), mats["yellow"], Vector3(cx, 20.5, 31.0))
	# контейнеры: ряды с проходами
	var conts := [
		[Vector3(-12, 0, -14), 0.0, 2], [Vector3(-12, 0, -22), 0.0, 1], [Vector3(-16, 0, -14), 0.0, 3],
		[Vector3(12, 0, 12), 0.0, 2], [Vector3(16, 0, 12), 0.0, 1], [Vector3(12, 0, 20), 0.0, 1],
		[Vector3(-22, 0, 10), 90.0, 2], [Vector3(-22, 0, 14), 90.0, 1],
		[Vector3(22, 0, -10), 90.0, 2], [Vector3(22, 0, -14), 90.0, 3],
		[Vector3(-4, 0, 24), 90.0, 1], [Vector3(4, 0, -26), 90.0, 2],
		[Vector3(-28, 0, -6), 0.0, 1], [Vector3(28, 0, 26), 0.0, 1],
		[Vector3(-26, 0, 28), 90.0, 2], [Vector3(26, 0, -28), 90.0, 1],
	]
	var i := 0
	for c in conts:
		_container(c[0], c[1], "cont%d" % (i % 4), c[2])
		i += 1
	# погрузчики, поддоны, бочки
	for f in [Vector3(8, 0, -10), Vector3(-9, 0, 9), Vector3(-30, 0, 20)]:
		var b := _add_box(f + Vector3(0, 0.9, 0), Vector3(1.3, 1.8, 2.4), mats["yellow"], rng.randf() * TAU)
		_add_visual(_box_mesh(Vector3(1.1, 0.08, 1.2)), mats["metal"], Vector3(0, -0.8, -1.7), Vector3.ZERO, Vector3.ONE, b)
	_scatter(16, 34.0, 1.2, func(p: Vector3) -> void:
		_add_box(p + Vector3(0, 0.5, 0), Vector3(1.2, 1.0, 1.2), mats["wood"], rng.randf() * TAU))
	_scatter(14, 34.0, 1.0, func(p: Vector3) -> void:
		for k in rng.randi_range(1, 3):
			_add_box(p + Vector3(k * 0.65, 0.5, 0), Vector3(0.6, 1.0, 0.6), mats["rust"]))
	for i2 in 25:
		var p := Vector3(rng.randf_range(-38.0, 38.0), 0, rng.randf_range(-38.0, 38.0))
		_add_visual(_box_mesh(Vector3(rng.randf_range(1.0, 4.0), 0.04, rng.randf_range(1.0, 4.0))), mats["rust"], Vector3(p.x, 0.02, p.z), Vector3(0, rng.randf() * TAU, 0))
