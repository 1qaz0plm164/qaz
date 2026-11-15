extends "res://level.gd"
# Локация 5: карантинная зона. Бетонная стена с колючкой, вышки, палатки, мешки с песком, контейнеры.

func _build_location() -> void:
	location_name = "Карантинная зона"
	rng.seed = 9031
	_make_materials()
	_extra_materials()
	_env({"sky_top": Color(0.4, 0.43, 0.47), "horizon": Color(0.62, 0.63, 0.62),
		"ambient": Color(0.5, 0.52, 0.55), "ambient_energy": 0.6,
		"fog": Color(0.55, 0.56, 0.56), "fog_density": 0.02,
		"sun": Color(0.95, 0.92, 0.85), "sun_energy": 0.8, "sun_rot": Vector3(-48, 60, 0)})
	_add_box(Vector3(0, -0.5, 0), Vector3(130, 1, 130), mats["concrete"])
	_add_visual(_box_mesh(Vector3(10.0, 0.03, HALF * 2.0)), mats["asphalt"], Vector3(0, 0.015, 0))
	_wall_ring(mats["concrete"], 6.0)
	# колючая проволока по верху стены и дома за стеной
	for side in [-1.0, 1.0]:
		_add_visual(_cyl_mesh(0.25, HALF * 2.0), mats["metal"], Vector3(side * (HALF + 0.3), 6.3, 0), Vector3(PI * 0.5, 0, 0))
		_add_visual(_cyl_mesh(0.25, HALF * 2.0), mats["metal"], Vector3(0, 6.3, side * (HALF + 0.3)), Vector3(0, 0, PI * 0.5))
		for i in 4:
			var h := rng.randf_range(12.0, 22.0)
			_add_visual(_box_mesh(Vector3(14.0, h, 10.0)), mats["brick_dark"], Vector3(-30.0 + i * 20.0, h * 0.5, side * 56.0))
			_add_visual(_box_mesh(Vector3(10.0, h, 14.0)), mats["concrete"], Vector3(side * 56.0, h * 0.5, -30.0 + i * 20.0))
	# вышки по углам
	for t in [Vector3(-28, 0, -28), Vector3(28, 0, 28), Vector3(28, 0, -28), Vector3(-28, 0, 28)]:
		_tower(t)
	# КПП в центре: мешки с песком и будка
	_sandbags(Vector3(-11, 0, 8), 0.0, 4)
	_sandbags(Vector3(5, 0, -8.5), 0.0, 4)
	_sandbags(Vector3(-9, 0, -12), 90.0, 3)
	_sandbags(Vector3(9, 0, 13), 90.0, 3)
	_add_box(Vector3(8.5, 1.3, 0), Vector3(2.5, 2.6, 2.5), mats["white"])
	_add_visual(_box_mesh(Vector3(2.7, 0.2, 2.7)), mats["red"], Vector3(8.5, 2.7, 0))
	for z in [-4.5, 4.5]:
		_add_visual(_box_mesh(Vector3(0.15, 0.15, 4.0)), mats["red"], Vector3(-6.5, 1.1, z))
		_add_box(Vector3(-6.5, 0.5, z + (2.2 if z > 0 else -2.2)), Vector3(0.3, 1.0, 0.3), mats["metal"])
	# палаточный лагерь
	for i in 3:
		for j in 2:
			_tent(Vector3(-27.0 + i * 6.5, 0, -12.0 + j * 7.0), 0.0)
	# контейнеры и склад
	_container(Vector3(20, 0, -14), 0.0, "cont0", 2)
	_container(Vector3(24, 0, -10), 90.0, "cont1")
	_container(Vector3(16, 0, 22), 90.0, "cont2", 2)
	_container(Vector3(-16, 0, 24), 0.0, "cont3")
	_building(Vector3(-22, 0, 18), Vector3(9, 5, 7), mats["concrete"], [Vector3(1, 0, 0), Vector3(0, 0, -1)])
	# грузовики
	_truck(Vector3(4, 0, 22), 0.0)
	_truck(Vector3(-4, 0, -24), 180.0)
	# заборы-сетки с проходами
	_fence(Vector3(14, 0, 6), Vector3(28, 0, 6))
	_fence(Vector3(-28, 0, -20), Vector3(-14, 0, -20))
	_fence(Vector3(-14, 0, 30), Vector3(-14, 0, 38))
	# бетонные блоки и ящики
	_scatter(14, 34.0, 1.6, func(p: Vector3) -> void:
		_add_box(p + Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 2.4), mats["concrete"], rng.randf() * TAU))
	_scatter(12, 34.0, 1.2, func(p: Vector3) -> void:
		_add_box(p + Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.0), mats["olive"], rng.randf() * TAU))
	# прожекторы на столбах
	for p in [Vector3(12, 0, 12), Vector3(-12, 0, -16), Vector3(-30, 0, 6), Vector3(30, 0, -4)]:
		_add_box(p + Vector3(0, 3.5, 0), Vector3(0.2, 7.0, 0.2), mats["metal"])
		_add_visual(_box_mesh(Vector3(0.8, 0.5, 0.4)), mats["lamp"], p + Vector3(0, 7.0, 0))

func _truck(p: Vector3, rot_deg: float) -> void:
	var body := StaticBody3D.new()
	body.position = p
	body.rotation.y = deg_to_rad(rot_deg)
	world.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.5, 3.0, 7.5)
	cs.shape = bs
	cs.position.y = 1.5
	body.add_child(cs)
	_add_visual(_box_mesh(Vector3(2.4, 1.9, 2.0)), mats["olive"], Vector3(0, 1.45, -2.6), Vector3.ZERO, Vector3.ONE, body)
	_add_visual(_box_mesh(Vector3(2.5, 0.6, 5.5)), mats["olive"], Vector3(0, 0.9, 0.9), Vector3.ZERO, Vector3.ONE, body)
	_add_visual(_box_mesh(Vector3(2.5, 1.9, 5.3)), mats["canvas"], Vector3(0, 2.1, 1.0), Vector3.ZERO, Vector3.ONE, body)
	_add_visual(_box_mesh(Vector3(2.0, 0.6, 0.05)), mats["glass"], Vector3(0, 1.9, -3.62), Vector3.ZERO, Vector3.ONE, body)
	for wz in [-2.6, 0.6, 2.6]:
		for wx in [-1.15, 1.15]:
			_add_visual(_cyl_mesh(0.5, 0.35), mats["tire"], Vector3(wx, 0.5, wz), Vector3(0, 0, PI * 0.5), Vector3.ONE, body)
