extends "res://level.gd"
# Локация 4: заброшенный торговый центр. Крыша с проломами, колонны, киоски, витрины, споры в воздухе.

func _build_location() -> void:
	location_name = "Торговый центр"
	rng.seed = 4417
	_make_materials()
	_extra_materials()
	_env({"sky": false, "bg": Color(0.05, 0.05, 0.05),
		"ambient": Color(0.5, 0.48, 0.42), "ambient_energy": 0.3,
		"fog": Color(0.12, 0.12, 0.1), "fog_density": 0.035,
		"sun": Color(1.0, 0.92, 0.78), "sun_energy": 1.1, "sun_rot": Vector3(-62, 25, 0)})
	_add_box(Vector3(0, -0.5, 0), Vector3(130, 1, 130), mats["tile"])
	_wall_ring(mats["concrete"], 10.0)
	_particles("spores")
	# крыша из плит с проломами (только вид, свет проходит в дыры)
	for ix in 8:
		for iz in 8:
			var cx := -35.0 + ix * 10.0
			var cz := -35.0 + iz * 10.0
			var hole := (ix == 3 or ix == 4) and (iz == 3 or iz == 4) or rng.randf() < 0.15
			if not hole:
				_add_visual(_box_mesh(Vector3(10.0, 0.4, 10.0)), mats["concrete"], Vector3(cx, 10.2, cz))
			else:
				for k in 3:   # обломки под проломом
					var s := Vector3(rng.randf_range(0.8, 2.0), rng.randf_range(0.3, 0.8), rng.randf_range(0.8, 2.0))
					var p := Vector3(cx + rng.randf_range(-4, 4), 0, cz + rng.randf_range(-4, 4))
					if _area_ok(p, s.x * 0.6, s.z * 0.6):
						_add_box(p + Vector3(0, s.y * 0.5, 0), s, mats["concrete"], rng.randf() * TAU)
	# балкон второго этажа и витрины по стенам
	for side in [-1.0, 1.0]:
		_add_visual(_box_mesh(Vector3(4.0, 0.4, HALF * 2.0)), mats["concrete"], Vector3(side * (HALF - 2.0), 4.8, 0))
		_add_visual(_box_mesh(Vector3(HALF * 2.0, 0.4, 4.0)), mats["concrete"], Vector3(0, 4.8, side * (HALF - 2.0)))
		_add_visual(_box_mesh(Vector3(0.1, 1.0, HALF * 2.0)), mats["metal"], Vector3(side * (HALF - 4.0), 5.5, 0))
		_add_visual(_box_mesh(Vector3(HALF * 2.0, 1.0, 0.1)), mats["metal"], Vector3(0, 5.5, side * (HALF - 4.0)))
		var signs := ["red", "yellow", "cont1", "cont2", "white"]
		for i in 8:
			var t := -35.0 + i * 10.0
			var shop_mat: Material = mats[signs[(i + int(side)) % signs.size()]]
			_add_visual(_box_mesh(Vector3(0.1, 2.8, 7.0)), mats["glass"], Vector3(side * (HALF - 0.05), 1.6, t))
			_add_visual(_box_mesh(Vector3(0.15, 0.8, 6.0)), shop_mat, Vector3(side * (HALF - 0.1), 3.6, t))
			_add_visual(_box_mesh(Vector3(7.0, 2.8, 0.1)), mats["glass"], Vector3(t, 1.6, side * (HALF - 0.05)))
			_add_visual(_box_mesh(Vector3(6.0, 0.8, 0.15)), shop_mat, Vector3(t, 3.6, side * (HALF - 0.1)))
	# колонны
	for x in [-28.0, -14.0, 14.0, 28.0]:
		for z in [-28.0, -14.0, 14.0, 28.0]:
			_add_box(Vector3(x, 5.0, z), Vector3(1.0, 10.0, 1.0), mats["white"])
	# киоски, скамейки, клумбы
	for k in [Vector3(9, 0, 9), Vector3(-9, 0, -9), Vector3(-9, 0, 10), Vector3(10, 0, -9), Vector3(-22, 0, 3), Vector3(22, 0, -3)]:
		_kiosk(k)
	for b in [Vector3(0, 0, 13), Vector3(0, 0, -13), Vector3(13, 0, 0), Vector3(-13, 0, 0)]:
		_add_box(b + Vector3(0, 0.25, 0), Vector3(2.4, 0.5, 0.6), mats["wood"], PI * 0.5 if absf(b.x) > 0.1 else 0.0)
	for pl in [Vector3(-20, 0, -20), Vector3(20, 0, 20), Vector3(-20, 0, 20), Vector3(20, 0, -20)]:
		_add_box(pl + Vector3(0, 0.45, 0), Vector3(2.2, 0.9, 2.2), mats["concrete"])
		_add_visual(_cyl_mesh(0.15, 3.0), mats["bark"], pl + Vector3(0, 2.2, 0))
		_add_visual(_sphere_mesh(1.4), mats["leaf2"], pl + Vector3(0, 3.8, 0))
	# сломанные эскалаторы
	for e in [Vector3(-30, 0, -8), Vector3(30, 0, 8)]:
		_add_box(e + Vector3(0, 0.8, 0), Vector3(2.4, 1.6, 9.0), mats["metal"])
		_add_visual(_box_mesh(Vector3(2.2, 0.3, 10.0)), mats["tile_dark"], e + Vector3(0, 2.6, 0), Vector3(0.45, 0, 0))
	# супермаркет: ряды стеллажей
	for i in 5:
		_add_box(Vector3(18.0 + i * 3.2, 1.0, -27.0), Vector3(0.7, 2.0, 6.0), mats["metal"])
	# тележки, мусор
	_scatter(16, 36.0, 1.0, func(p: Vector3) -> void:
		_add_box(p + Vector3(0, 0.5, 0), Vector3(0.6, 1.0, 0.9), mats["metal"], rng.randf() * TAU))
	for i in 60:
		var p := Vector3(rng.randf_range(-38.0, 38.0), 0, rng.randf_range(-38.0, 38.0))
		var cs := rng.randf_range(0.1, 0.35)
		_add_visual(_box_mesh(Vector3(cs, cs * 0.5, cs)), mats["concrete"], p + Vector3(0, cs * 0.25, 0), Vector3(0, rng.randf() * TAU, 0))
	for i in 18:
		var p := Vector3(rng.randf_range(-38.0, 38.0), 0, rng.randf_range(-38.0, 38.0))
		_add_visual(_box_mesh(Vector3(rng.randf_range(1.5, 4.0), 0.04, rng.randf_range(1.5, 4.0))), mats["moss"], Vector3(p.x, 0.03, p.z), Vector3(0, rng.randf() * TAU, 0))

func _kiosk(p: Vector3) -> void:
	_add_box(p + Vector3(0, 0.55, 0), Vector3(3.0, 1.1, 1.6), mats["wood"], 0.0)
	for dx in [-1.4, 1.4]:
		_add_visual(_box_mesh(Vector3(0.08, 2.4, 0.08)), mats["metal"], p + Vector3(dx, 1.2, 0))
	_add_visual(_box_mesh(Vector3(3.4, 0.12, 2.0)), mats["red"], p + Vector3(0, 2.45, 0))
