extends "res://level.gd"
# Локация 7: станция метро. Темнота, поезда на путях, колонны, турникеты, споры. Без фонарика — никак.

func _build_location() -> void:
	location_name = "Станция метро"
	rng.seed = 1207
	_make_materials()
	_extra_materials()
	_env({"sky": false, "bg": Color(0.0, 0.0, 0.0),
		"ambient": Color(0.35, 0.4, 0.45), "ambient_energy": 0.22,
		"fog": Color(0.02, 0.025, 0.03), "fog_density": 0.045, "sun_energy": 0.0})
	_add_box(Vector3(0, -0.5, 0), Vector3(130, 1, 130), mats["tile_dark"])
	_wall_ring(mats["tile"], 7.5)
	_add_visual(_box_mesh(Vector3(HALF * 2.0 + 4, 0.5, HALF * 2.0 + 4)), mats["concrete"], Vector3(0, 7.5, 0))
	_particles("spores")
	# пути с поездами
	for tx in [-12.0, 12.0]:
		_add_visual(_box_mesh(Vector3(4.0, 0.03, HALF * 2.0)), mats["dirt"], Vector3(tx, 0.015, 0))
		for rx in [-0.75, 0.75]:
			_add_visual(_box_mesh(Vector3(0.1, 0.12, HALF * 2.0)), mats["metal"], Vector3(tx + rx, 0.06, 0))
		var z := 0.0
		while z < HALF * 2.0:
			_add_visual(_box_mesh(Vector3(2.4, 0.06, 0.25)), mats["wood_dark"], Vector3(tx, 0.03, -HALF + z))
			z += 1.2
	_carriage(Vector3(12, 0, -20), 1)
	_carriage(Vector3(12, 0, 22), 2)
	_carriage(Vector3(-12, 0, 14), 0)
	# колонны
	for x in [-24.0, -5.0, 5.0, 24.0]:
		for z in [-28.0, -16.0, 16.0, 28.0]:
			_add_box(Vector3(x, 3.75, z), Vector3(1.0, 7.5, 1.0), mats["tile"])
	# турникеты и касса
	for i in 6:
		_add_box(Vector3(-32.0 + i * 1.8, 0.5, -26.0), Vector3(0.3, 1.0, 1.2), mats["metal"])
	_add_box(Vector3(-30, 1.3, 26), Vector3(5, 2.6, 3), mats["white"])
	_add_visual(_box_mesh(Vector3(4.6, 0.8, 0.05)), mats["glass"], Vector3(-30, 1.8, 24.47))
	# скамейки, обрушенный потолок, мусор
	for b in [Vector3(-24, 0, -6), Vector3(-24, 0, 6), Vector3(24, 0, -6), Vector3(24, 0, 6), Vector3(-5, 0, -22), Vector3(5, 0, 22)]:
		_add_box(b + Vector3(0, 0.25, 0), Vector3(0.6, 0.5, 2.6), mats["wood"])
	_scatter(14, 34.0, 1.6, func(p: Vector3) -> void:
		var s := Vector3(rng.randf_range(1.0, 2.6), rng.randf_range(0.5, 1.4), rng.randf_range(1.0, 2.4))
		_add_box(p + Vector3(0, s.y * 0.5, 0), s, mats["concrete"], rng.randf() * TAU))
	for i in 50:
		var p := Vector3(rng.randf_range(-38.0, 38.0), 0, rng.randf_range(-38.0, 38.0))
		var cs := rng.randf_range(0.1, 0.35)
		_add_visual(_box_mesh(Vector3(cs, cs * 0.5, cs)), mats["concrete"], p + Vector3(0, cs * 0.25, 0), Vector3(0, rng.randf() * TAU, 0))
	# редкие уцелевшие лампы
	_omni(Vector3(0, 6.8, -18), Color(1.0, 0.75, 0.45), 1.3, 14.0)
	_omni(Vector3(-26, 6.8, 20), Color(1.0, 0.75, 0.45), 1.1, 12.0)
	_omni(Vector3(28, 6.8, 0), Color(0.6, 0.85, 1.0), 1.0, 12.0)
	_omni(Vector3(-20, 6.8, -30), Color(1.0, 0.4, 0.3), 1.0, 10.0)
	_omni(Vector3(0, 6.8, 6), Color(1.0, 0.8, 0.55), 0.8, 10.0)

func _carriage(p: Vector3, color_i: int) -> void:
	var body := _add_box(p + Vector3(0, 1.75, 0), Vector3(3.0, 3.5, 16.0), mats[["metal", "white", "cont1"][color_i]])
	for side in [-1.0, 1.0]:
		var z := -6.5
		while z <= 6.5:
			_add_visual(_box_mesh(Vector3(0.05, 1.0, 1.6)), mats["glass"], Vector3(side * 1.52, 0.5, z), Vector3.ZERO, Vector3.ONE, body)
			z += 2.6
		_add_visual(_box_mesh(Vector3(0.05, 0.25, 16.0)), mats["red"], Vector3(side * 1.52, -0.6, 0), Vector3.ZERO, Vector3.ONE, body)
