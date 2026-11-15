extends Node3D
# Локация: заброшенный город после катастрофы.
# Всё строится кодом: улицы, дома, машины, мусор, растительность, туман и свет.
# Чтобы поменять вид локации, правь числа и списки в этом файле.

const HALF := 40.0          # половина ширины арены внутри окружающих домов
const WALL_DEPTH := 8.0     # толщина стен-домов по краю карты

var rng := RandomNumberGenerator.new()
var world: NavigationRegion3D          # сюда кладём всю статичную геометрию (из неё печётся навигация)
var mats := {}
var window_transforms: Array[Transform3D] = []
var spawn_points: Array[Vector3] = []

var location_name := "Заброшенный город"

func _ready() -> void:
	world = NavigationRegion3D.new()
	add_child(world)
	_make_spawn_points()
	_build_location()
	_flush_windows()
	_bake_navigation()

# Переопределяется в других локациях (level_*.gd)
func _build_location() -> void:
	rng.seed = 20261011   # одинаковая случайность: локация всегда выглядит одинаково
	_make_materials()
	_make_environment()
	_make_ground()
	_make_perimeter()
	_make_blocks()
	_make_cars()
	_make_props()
	_make_vegetation()

# ============================================================
#  Публичное: где появляются враги
# ============================================================
func get_spawn_point(from: Vector3, min_dist := 18.0) -> Vector3:
	var options: Array = spawn_points.filter(func(p: Vector3) -> bool:
		return Vector2(p.x - from.x, p.z - from.z).length() >= min_dist)
	if options.is_empty():
		options = spawn_points
	var p: Vector3 = options.pick_random()
	return p + Vector3(randf_range(-2.0, 2.0), 1.0, randf_range(-2.0, 2.0))

func _make_spawn_points() -> void:
	# углы, середины краёв и боковые проулки — везде, где свободно
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			spawn_points.append(Vector3(sx * 35.0, 0, sz * 35.0))
			spawn_points.append(Vector3(sx * 36.0, 0, sz * 18.0))
	spawn_points.append(Vector3(36, 0, 0))
	spawn_points.append(Vector3(-36, 0, 0))
	spawn_points.append(Vector3(0, 0, 36))
	spawn_points.append(Vector3(0, 0, -36))

# ============================================================
#  Материалы и текстуры (рисуются кодом)
# ============================================================
func _grain_texture(size: int, freq: float, seed_value: int, lo: float, hi: float) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.fractal_octaves = 4
	var src := n.get_seamless_image(size, size, false, false, 0.1, true)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v := lerpf(lo, hi, src.get_pixel(x, y).r)
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)

func _brick_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var bw := size / 8     # ширина кирпича
	var bh := size / 16    # высота кирпича
	var local := RandomNumberGenerator.new()
	local.seed = 77
	var shades: Array[float] = []
	for i in 8 * 16 + 16:
		shades.append(local.randf_range(0.55, 1.0))
	for y in size:
		var row := y / bh
		var off := (bw / 2) if row % 2 == 1 else 0
		for x in size:
			var xx := (x + off) % size
			var col := xx / bw
			var in_mortar := (y % bh) < 1 or (xx % bw) < 1
			var c: Color
			if in_mortar:
				c = Color(0.55, 0.55, 0.52)
			else:
				var s := shades[(row * 8 + col) % shades.size()]
				c = Color(0.62 * s, 0.3 * s, 0.22 * s)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func _textured(tex: Texture2D, tint: Color, world_scale: float, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * world_scale
	return m

func _plain(color: Color, rough := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m

func _make_materials() -> void:
	var concrete_tex := _grain_texture(128, 0.03, 1, 0.45, 0.85)
	var asphalt_tex := _grain_texture(128, 0.06, 2, 0.1, 0.3)
	var brick_tex := _brick_texture(128)
	mats["ground"] = _textured(concrete_tex, Color(0.7, 0.7, 0.66), 0.2)
	mats["asphalt"] = _textured(asphalt_tex, Color(1, 1, 1), 0.25)
	mats["concrete"] = _textured(concrete_tex, Color(0.62, 0.64, 0.62), 0.18)
	mats["brick"] = _textured(brick_tex, Color(0.85, 0.72, 0.66), 0.45)
	mats["brick_dark"] = _textured(brick_tex, Color(0.6, 0.55, 0.52), 0.45)
	mats["window"] = _plain(Color(0.02, 0.025, 0.03), 0.25)
	mats["line"] = _plain(Color(0.6, 0.5, 0.15), 0.9)
	mats["tire"] = _plain(Color(0.04, 0.04, 0.04), 0.9)
	mats["glass"] = _plain(Color(0.05, 0.07, 0.08), 0.2)
	mats["metal"] = _plain(Color(0.22, 0.24, 0.23), 0.5, 0.4)
	mats["dumpster"] = _plain(Color(0.1, 0.25, 0.18), 0.6)
	mats["leaf"] = _plain(Color(0.12, 0.26, 0.1), 1.0)
	mats["leaf2"] = _plain(Color(0.22, 0.3, 0.12), 1.0)
	mats["moss"] = _plain(Color(0.15, 0.22, 0.1), 1.0)
	mats["car0"] = _plain(Color(0.38, 0.12, 0.1), 0.55, 0.2)    # выцветший красный
	mats["car1"] = _plain(Color(0.2, 0.26, 0.32), 0.55, 0.2)    # серо-синий
	mats["car2"] = _plain(Color(0.42, 0.4, 0.32), 0.55, 0.2)    # бежевый
	mats["car3"] = _plain(Color(0.12, 0.15, 0.12), 0.55, 0.2)   # тёмно-зелёный
	mats["bus"] = _plain(Color(0.45, 0.4, 0.18), 0.6, 0.2)

# ============================================================
#  Небо, туман, свет
# ============================================================
func _make_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.26, 0.31, 0.36)
	sky_mat.sky_horizon_color = Color(0.62, 0.58, 0.5)
	sky_mat.ground_horizon_color = Color(0.5, 0.48, 0.42)
	sky_mat.ground_bottom_color = Color(0.2, 0.2, 0.2)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.55)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.52, 0.48)
	env.fog_density = 0.022

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Низкое тёплое солнце на закате: длинные тени между домами
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.78, 0.58)
	sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-28.0, 35.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

# ============================================================
#  Помощники для построения
# ============================================================
func _add_box(pos: Vector3, size: Vector3, mat: Material, rot_y := 0.0, parent: Node3D = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot_y
	(parent if parent else world).add_child(body)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	return body

# Только картинка, без столкновений
func _add_visual(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	(parent if parent else world).add_child(mi)
	return mi

func _box_mesh(size: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm

func _cyl_mesh(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	return c

func _sphere_mesh(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 5
	return s

# Окна собираем в один MultiMesh — тысячи окон, один вызов отрисовки
func _windows(face_center: Vector3, out: Vector3, length: float, height: float) -> void:
	var along := Vector3.UP.cross(out)
	var y := 3.0
	while y + 1.4 < height:
		var u := -length * 0.5 + 2.0
		while u <= length * 0.5 - 2.0:
			if rng.randf() > 0.2:   # часть окон «выбита» — просто глухая стена
				var origin := face_center + along * u + Vector3(0, y, 0) + out * 0.05
				window_transforms.append(Transform3D(Basis(along, Vector3.UP, out), origin))
			u += 4.0
		y += 3.6

func _flush_windows() -> void:
	if window_transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _box_mesh(Vector3(1.7, 2.2, 0.2))
	mm.instance_count = window_transforms.size()
	for i in window_transforms.size():
		mm.set_instance_transform(i, window_transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mats["window"]
	world.add_child(mmi)

# Дом: коробка + окна на указанных сторонах
func _building(base_center: Vector3, size: Vector3, mat: Material, window_faces: Array) -> void:
	_add_box(base_center + Vector3(0, size.y * 0.5, 0), size, mat)
	for out in window_faces:
		var o: Vector3 = out
		var half := size.x * 0.5 if absf(o.x) > 0.5 else size.z * 0.5
		var length := size.z if absf(o.x) > 0.5 else size.x
		_windows(base_center + o * half, o, length, size.y)
	# крышная надстройка (только вид)
	_add_visual(_box_mesh(Vector3(size.x * 0.3, 1.6, size.z * 0.25)), mats["concrete"],
		base_center + Vector3(size.x * 0.15, size.y + 0.8, -size.z * 0.1))

func _clear_ok(p: Vector3) -> bool:
	if Vector2(p.x, p.z).length() < 7.0:    # место старта игрока
		return false
	for sp in spawn_points:
		if Vector2(p.x - sp.x, p.z - sp.z).length() < 4.0:
			return false
	return true

func _in_block(p: Vector3) -> bool:
	return absf(p.x) > 12.0 and absf(p.x) < 32.0 and absf(p.z) > 12.0 and absf(p.z) < 32.0

# ============================================================
#  Земля и дороги
# ============================================================
func _make_ground() -> void:
	_add_box(Vector3(0, -0.5, 0), Vector3(130, 1, 130), mats["ground"])
	# две дороги крестом (только вид, пол под ними общий)
	_add_visual(_box_mesh(Vector3(HALF * 2.0, 0.03, 12.0)), mats["asphalt"], Vector3(0, 0.015, 0))
	_add_visual(_box_mesh(Vector3(12.0, 0.035, HALF * 2.0)), mats["asphalt"], Vector3(0, 0.0175, 0))
	# разметка
	for i in range(-6, 7):
		var d := i * 6.0
		if absf(d) > 7.0:
			_add_visual(_box_mesh(Vector3(3.0, 0.01, 0.2)), mats["line"], Vector3(d, 0.04, 0))
			_add_visual(_box_mesh(Vector3(0.2, 0.01, 3.0)), mats["line"], Vector3(0, 0.045, d))

# ============================================================
#  Дома по краю карты и внутри
# ============================================================
func _make_perimeter() -> void:
	for side in [-1.0, 1.0]:
		for i in 5:
			var h := rng.randf_range(10.0, 18.0)
			var m: Material = mats["brick"] if (i + int(side)) % 2 == 0 else mats["brick_dark"]
			# стены по бокам (x = ±44), смотрят окнами внутрь
			_building(Vector3(side * (HALF + WALL_DEPTH * 0.5), 0, -40.0 + i * 20.0),
				Vector3(WALL_DEPTH, h, 20.0), m, [Vector3(-side, 0, 0)])
		for i in 4:
			var h2 := rng.randf_range(10.0, 18.0)
			var m2: Material = mats["concrete"] if (i + int(side)) % 2 == 0 else mats["brick_dark"]
			# стены спереди/сзади (z = ±44)
			_building(Vector3(-30.0 + i * 20.0, 0, side * (HALF + WALL_DEPTH * 0.5)),
				Vector3(20.0, h2, WALL_DEPTH), m2, [Vector3(0, 0, -side)])

func _make_blocks() -> void:
	var faces := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var i := 0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var size := Vector3(rng.randf_range(14.0, 17.0), rng.randf_range(8.0, 13.0), rng.randf_range(14.0, 17.0))
			var center := Vector3(sx * 22.0 + rng.randf_range(-1.0, 1.0), 0, sz * 22.0 + rng.randf_range(-1.0, 1.0))
			var m: Material = mats["brick"] if i % 2 == 0 else mats["concrete"]
			_building(center, size, m, faces)
			i += 1

# ============================================================
#  Машины, автобус, баррикады
# ============================================================
func _car(pos: Vector3, rot_deg: float, mat_name: String) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = deg_to_rad(rot_deg)
	world.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.9, 1.5, 4.3)
	cs.shape = bs
	cs.position.y = 0.75
	body.add_child(cs)
	var mat: Material = mats[mat_name]
	_add_visual(_box_mesh(Vector3(1.9, 0.65, 4.3)), mat, Vector3(0, 0.6, 0), Vector3.ZERO, Vector3.ONE, body)
	_add_visual(_box_mesh(Vector3(1.7, 0.6, 2.3)), mat, Vector3(0, 1.2, -0.2), Vector3.ZERO, Vector3.ONE, body)
	_add_visual(_box_mesh(Vector3(1.74, 0.35, 2.34)), mats["glass"], Vector3(0, 1.25, -0.2), Vector3.ZERO, Vector3.ONE, body)
	for wx in [-0.95, 0.95]:
		for wz in [-1.35, 1.35]:
			_add_visual(_cyl_mesh(0.35, 0.25), mats["tire"], Vector3(wx, 0.35, wz), Vector3(0, 0, PI * 0.5), Vector3.ONE, body)

func _bus(pos: Vector3, rot_deg: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = deg_to_rad(rot_deg)
	world.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.6, 3.2, 11.0)
	cs.shape = bs
	cs.position.y = 1.6
	body.add_child(cs)
	_add_visual(_box_mesh(Vector3(2.6, 2.9, 11.0)), mats["bus"], Vector3(0, 1.75, 0), Vector3.ZERO, Vector3.ONE, body)
	_add_visual(_box_mesh(Vector3(2.64, 0.9, 10.0)), mats["glass"], Vector3(0, 2.35, 0), Vector3.ZERO, Vector3.ONE, body)
	for wz in [-3.6, 3.6]:
		for wx in [-1.3, 1.3]:
			_add_visual(_cyl_mesh(0.5, 0.3), mats["tire"], Vector3(wx, 0.5, wz), Vector3(0, 0, PI * 0.5), Vector3.ONE, body)

func _make_cars() -> void:
	# позиция x, z, поворот в градусах, цвет — расставлены так, чтобы создавать укрытия
	var cars := [
		[-8.0, 9.5, 12.0, "car0"], [9.0, -9.0, -80.0, "car1"], [3.0, 17.0, 85.0, "car2"],
		[-4.0, -18.0, 95.0, "car3"], [20.0, 3.5, 4.0, "car1"], [25.0, -3.0, 8.0, "car0"],
		[10.0, 34.0, 20.0, "car2"], [-36.0, 10.0, 90.0, "car3"], [37.0, -12.0, 100.0, "car0"],
		[-10.0, -33.0, 60.0, "car1"], [-10.0, 22.0, 100.0, "car2"], [9.5, 8.0, 75.0, "car3"],
	]
	for c in cars:
		var p := Vector3(c[0], 0, c[1])
		if _clear_ok(p):
			_car(p, c[2], c[3])
	_bus(Vector3(-18.0, 0, 2.0), 3.0)

func _make_props() -> void:
	# бетонные барьеры — линии укрытий
	var barrier_lines := [
		[Vector3(-6, 0, -12), 0.0, 4], [Vector3(11, 0, 11), 90.0, 3],
		[Vector3(-12, 0, -8), 90.0, 3], [Vector3(31.5, 0, 7), 0.0, 2],
	]
	for line in barrier_lines:
		var start: Vector3 = line[0]
		var rot: float = deg_to_rad(line[1])
		var along := Vector3(cos(rot), 0, -sin(rot))
		for i in int(line[2]):
			var p: Vector3 = start + along * (i * 2.6)
			if _clear_ok(p):
				_add_box(p + Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 2.4), mats["concrete"], rot + PI * 0.5)

	# мусорные баки
	for p in [Vector3(-14, 0, 12), Vector3(14, 0, -12), Vector3(33, 0, 20), Vector3(-33, 0, -20), Vector3(8, 0, 30)]:
		if _clear_ok(p):
			_add_box(p + Vector3(0, 0.6, 0), Vector3(1.8, 1.2, 1.0), mats["dumpster"], rng.randf_range(0, PI))
			_add_visual(_box_mesh(Vector3(1.9, 0.08, 1.1)), mats["metal"], p + Vector3(0, 1.24, 0))

	# куски бетона и завалы — случайные укрытия
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 400:
		tries += 1
		var p := Vector3(rng.randf_range(-37.0, 37.0), 0, rng.randf_range(-37.0, 37.0))
		if _in_block(p) or not _clear_ok(p):
			continue
		var s := Vector3(rng.randf_range(0.8, 2.4), rng.randf_range(0.5, 1.3), rng.randf_range(0.8, 2.2))
		_add_box(p + Vector3(0, s.y * 0.5, 0), s, mats["concrete"], rng.randf_range(0, PI))
		# рядом россыпь мелких обломков (только вид)
		for k in 4:
			var q := p + Vector3(rng.randf_range(-1.8, 1.8), 0, rng.randf_range(-1.8, 1.8))
			var cs := rng.randf_range(0.15, 0.4)
			_add_visual(_box_mesh(Vector3(cs, cs * 0.7, cs)), mats["concrete"], q + Vector3(0, cs * 0.35, 0),
				Vector3(rng.randf(), rng.randf() * TAU, rng.randf()))
		placed += 1

	# фонарные столбы
	for p in [Vector3(7, 0, 7), Vector3(-7, 0, -7), Vector3(7, 0, -22), Vector3(-7, 0, 22), Vector3(-30, 0, 4), Vector3(30, 0, -4)]:
		_add_box(p + Vector3(0, 3.0, 0), Vector3(0.18, 6.0, 0.18), mats["metal"])
		_add_visual(_box_mesh(Vector3(1.4, 0.14, 0.3)), mats["metal"], p + Vector3(0.6, 6.0, 0))

# ============================================================
#  Растительность: природа забирает город обратно
# ============================================================
func _make_vegetation() -> void:
	# заросли кустов
	for i in 70:
		var p := Vector3(rng.randf_range(-39.0, 39.0), 0, rng.randf_range(-39.0, 39.0))
		if _in_block(p) or not _clear_ok(p):
			continue
		var r := rng.randf_range(0.5, 1.2)
		var m: Material = mats["leaf"] if rng.randf() > 0.4 else mats["leaf2"]
		_add_visual(_sphere_mesh(r), m, p + Vector3(0, r * 0.35, 0), Vector3.ZERO, Vector3(1.3, 0.6, 1.3))
	# пятна травы и мха на асфальте и бетоне
	for i in 40:
		var p := Vector3(rng.randf_range(-39.0, 39.0), 0, rng.randf_range(-39.0, 39.0))
		if _in_block(p):
			continue
		_add_visual(_box_mesh(Vector3(rng.randf_range(2.0, 6.0), 0.05, rng.randf_range(2.0, 6.0))), mats["moss"],
			Vector3(p.x, 0.05, p.z), Vector3(0, rng.randf() * TAU, 0))
	# плющ на стенах домов
	for i in 24:
		var side := rng.randf() > 0.5
		var x := rng.randf_range(-38.0, 38.0)
		var h := rng.randf_range(3.0, 8.0)
		var z := rng.randf_range(-38.0, 38.0)
		if side:
			_add_visual(_box_mesh(Vector3(rng.randf_range(0.6, 1.6), h, 0.15)), mats["moss"],
				Vector3(x, h * 0.5, (HALF if rng.randf() > 0.5 else -HALF) * 1.0))
		else:
			_add_visual(_box_mesh(Vector3(0.15, h, rng.randf_range(0.6, 1.6))), mats["moss"],
				Vector3((HALF if rng.randf() > 0.5 else -HALF) * 1.0, h * 0.5, z))

# ============================================================
#  Навигация: враги находят дорогу между домами и машинами
# ============================================================
func _bake_navigation() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.cell_size = 0.25
	world.navigation_mesh = nm
	world.bake_navigation_mesh(false)

# ============================================================
#  Общие помощники для остальных локаций (level_*.gd)
# ============================================================

# Свободен ли прямоугольник (центр, полуразмеры по x/z): не на старте игрока и не на точках появления врагов
func _area_ok(c: Vector3, hx: float, hz: float, start_r := 7.0) -> bool:
	if _rect_dist(Vector2.ZERO, c, hx, hz) < start_r:
		return false
	for sp in spawn_points:
		if _rect_dist(Vector2(sp.x, sp.z), c, hx, hz) < 3.5:
			return false
	return absf(c.x) + hx < HALF + 0.5 and absf(c.z) + hz < HALF + 0.5

func _rect_dist(p: Vector2, c: Vector3, hx: float, hz: float) -> float:
	var dx := maxf(absf(p.x - c.x) - hx, 0.0)
	var dz := maxf(absf(p.y - c.z) - hz, 0.0)
	return Vector2(dx, dz).length()

# Небо/туман/солнце одним вызовом
func _env(o: Dictionary) -> void:
	var env := Environment.new()
	if o.get("sky", true):
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = o.get("sky_top", Color(0.3, 0.35, 0.4))
		sky_mat.sky_horizon_color = o.get("horizon", Color(0.6, 0.6, 0.55))
		sky_mat.ground_horizon_color = o.get("horizon", Color(0.6, 0.6, 0.55)).darkened(0.15)
		sky_mat.ground_bottom_color = Color(0.15, 0.15, 0.15)
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = o.get("bg", Color(0.02, 0.02, 0.02))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = o.get("ambient", Color(0.45, 0.5, 0.55))
	env.ambient_light_energy = o.get("ambient_energy", 0.55)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = o.get("fog", Color(0.5, 0.52, 0.48))
	env.fog_density = o.get("fog_density", 0.022)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	if o.get("sun_energy", 0.9) > 0.0:
		var sun := DirectionalLight3D.new()
		sun.light_color = o.get("sun", Color(1.0, 0.85, 0.7))
		sun.light_energy = o.get("sun_energy", 0.9)
		sun.rotation_degrees = o.get("sun_rot", Vector3(-35.0, 40.0, 0.0))
		sun.shadow_enabled = o.get("shadows", true)
		sun.directional_shadow_max_distance = 80.0
		add_child(sun)

func _extra_materials() -> void:
	var wood_tex := _plank_texture(128)
	var rock_tex := _grain_texture(128, 0.05, 5, 0.35, 0.75)
	var soft_tex := _grain_texture(128, 0.02, 9, 0.8, 1.0)
	var tile_tex := _tile_texture(128)
	mats["wood"] = _textured(wood_tex, Color(0.62, 0.48, 0.34), 0.35)
	mats["wood_dark"] = _textured(wood_tex, Color(0.36, 0.28, 0.21), 0.35)
	mats["wood_grey"] = _textured(wood_tex, Color(0.5, 0.48, 0.44), 0.35)
	mats["rock"] = _textured(rock_tex, Color(0.55, 0.53, 0.5), 0.15)
	mats["snow"] = _textured(soft_tex, Color(0.86, 0.88, 0.92), 0.1, 0.9)
	mats["dirt"] = _textured(rock_tex, Color(0.42, 0.35, 0.26), 0.12)
	mats["forest_floor"] = _textured(rock_tex, Color(0.3, 0.32, 0.18), 0.1)
	mats["sand"] = _textured(soft_tex, Color(0.66, 0.6, 0.48), 0.1)
	mats["tile"] = _textured(tile_tex, Color(0.8, 0.8, 0.76), 0.25, 0.5)
	mats["tile_dark"] = _textured(tile_tex, Color(0.42, 0.44, 0.42), 0.25, 0.5)
	mats["bark"] = _plain(Color(0.25, 0.19, 0.14), 1.0)
	mats["pine"] = _plain(Color(0.08, 0.18, 0.11), 1.0)
	mats["pine_snow"] = _plain(Color(0.55, 0.6, 0.6), 1.0)
	mats["sandbag"] = _plain(Color(0.46, 0.42, 0.3), 1.0)
	mats["canvas"] = _plain(Color(0.28, 0.3, 0.2), 1.0)
	mats["olive"] = _plain(Color(0.2, 0.24, 0.15), 0.7, 0.2)
	mats["rust"] = _plain(Color(0.36, 0.2, 0.12), 0.9, 0.3)
	mats["white"] = _plain(Color(0.78, 0.78, 0.76), 0.7)
	mats["red"] = _plain(Color(0.5, 0.08, 0.06), 0.7)
	mats["yellow"] = _plain(Color(0.7, 0.55, 0.1), 0.7, 0.2)
	mats["cont0"] = _plain(Color(0.45, 0.14, 0.1), 0.7, 0.3)
	mats["cont1"] = _plain(Color(0.12, 0.25, 0.4), 0.7, 0.3)
	mats["cont2"] = _plain(Color(0.2, 0.35, 0.2), 0.7, 0.3)
	mats["cont3"] = _plain(Color(0.6, 0.45, 0.15), 0.7, 0.3)
	var w := StandardMaterial3D.new()
	w.albedo_color = Color(0.1, 0.16, 0.15, 0.82)
	w.roughness = 0.08
	w.metallic = 0.3
	w.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats["water"] = w
	var f := StandardMaterial3D.new()
	f.albedo_color = Color(0.5, 0.52, 0.5, 0.35)
	f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	f.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["chain"] = f
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1.0, 0.9, 0.7)
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats["lamp"] = lamp

func _plank_texture(size: int) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = 31
	n.frequency = 0.08
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var ph := size / 8
	for y in size:
		var row := y / ph
		for x in size:
			var v := 0.75 + 0.25 * n.get_noise_2d(x * 0.15, y * 3.0 + row * 50.0)
			if y % ph == 0:
				v = 0.35
			v *= 0.85 + 0.15 * float((row * 37) % 5) / 4.0
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)

func _tile_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var t := size / 4
	var local := RandomNumberGenerator.new()
	local.seed = 8
	for y in size:
		for x in size:
			var v := 0.92 - 0.12 * float(((x / t) * 3 + (y / t) * 5) % 4) / 3.0
			if x % t < 1 or y % t < 1:
				v = 0.4
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)

# Глухая стена-коробка вокруг арены (для локаций без домов по краю)
func _wall_ring(mat: Material, height: float) -> void:
	var d := HALF + WALL_DEPTH * 0.5
	var long := HALF * 2.0 + WALL_DEPTH * 2.0
	_add_box(Vector3(d, height * 0.5, 0), Vector3(WALL_DEPTH, height, long), mat)
	_add_box(Vector3(-d, height * 0.5, 0), Vector3(WALL_DEPTH, height, long), mat)
	_add_box(Vector3(0, height * 0.5, d), Vector3(long, height, WALL_DEPTH), mat)
	_add_box(Vector3(0, height * 0.5, -d), Vector3(long, height, WALL_DEPTH), mat)

# Скалы по краю: невидимо-сплошная стена + нагромождение камней перед ней
func _cliff_ring(mat: Material) -> void:
	_wall_ring(mat, 9.0)
	for side in 4:
		var t := -HALF
		while t < HALF:
			var s := Vector3(rng.randf_range(3.0, 6.0), rng.randf_range(4.0, 11.0), rng.randf_range(3.0, 6.0))
			var inset := HALF + rng.randf_range(0.2, 1.5)
			var p: Vector3
			match side:
				0: p = Vector3(inset, 0, t)
				1: p = Vector3(-inset, 0, t)
				2: p = Vector3(t, 0, inset)
				_: p = Vector3(t, 0, -inset)
			_add_visual(_box_mesh(s), mat, p + Vector3(0, s.y * 0.4, 0),
				Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2)))
			t += rng.randf_range(3.0, 5.0)

func _tree(p: Vector3, h: float, pine := true, snow := false) -> void:
	_add_box(p + Vector3(0, h * 0.5, 0), Vector3(0.45, h, 0.45), mats["bark"], rng.randf() * TAU)
	if pine:
		var m: Material = mats["pine_snow"] if snow else mats["pine"]
		var layers := 3
		for i in layers:
			var r := lerpf(2.2, 0.9, float(i) / layers) * h / 9.0
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = r
			cone.height = h * 0.38
			cone.radial_segments = 8
			_add_visual(cone, m, p + Vector3(0, h * (0.4 + 0.2 * i), 0))
	else:
		for i in 3:
			var r := rng.randf_range(1.4, 2.2)
			var off := Vector3(rng.randf_range(-0.8, 0.8), h * 0.8 + rng.randf_range(-0.5, 0.8), rng.randf_range(-0.8, 0.8))
			_add_visual(_sphere_mesh(r), mats["leaf"] if i % 2 == 0 else mats["leaf2"], p + off)

func _rock(p: Vector3, s: Vector3) -> void:
	_add_box(p + Vector3(0, s.y * 0.4, 0), s, mats["rock"], rng.randf() * TAU)

func _log(p: Vector3, rot: float, length: float) -> void:
	_add_box(p + Vector3(0, 0.35, 0), Vector3(0.7, 0.7, length), mats["bark"], rot)

func _container(p: Vector3, rot_deg: float, mat_name: String, stack := 1) -> void:
	for i in stack:
		var body := _add_box(p + Vector3(0, 1.3 + i * 2.6, 0), Vector3(2.5, 2.6, 6.0), mats[mat_name if i == 0 else "cont%d" % ((i + mat_name.hash()) % 4)], deg_to_rad(rot_deg))
		for k in 5:
			_add_visual(_box_mesh(Vector3(2.56, 2.5, 0.08)), mats["metal"], Vector3(0, 0, -2.4 + k * 1.2), Vector3.ZERO, Vector3.ONE, body)

func _sandbags(start: Vector3, rot_deg: float, count: int) -> void:
	var rot := deg_to_rad(rot_deg)
	var along := Vector3(cos(rot), 0, -sin(rot))
	for i in count:
		var p := start + along * (i * 1.6)
		var b := _add_box(p + Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 0.8), mats["sandbag"], rot)
		for k in 2:
			_add_visual(_box_mesh(Vector3(0.75, 0.22, 0.85)), mats["sandbag"], Vector3(-0.4 + k * 0.8, 0.55, 0),
				Vector3(0, 0, rng.randf_range(-0.1, 0.1)), Vector3.ONE, b)

func _fence(a: Vector3, b: Vector3, h := 2.4) -> void:
	var mid := (a + b) * 0.5
	var len := a.distance_to(b)
	var rot := atan2(b.x - a.x, b.z - a.z)
	var body := _add_box(mid + Vector3(0, h * 0.5, 0), Vector3(0.06, h, len), mats["chain"], rot)
	var n := int(len / 3.0)
	for i in n + 1:
		_add_visual(_box_mesh(Vector3(0.08, h + 0.2, 0.08)), mats["metal"], Vector3(0, 0.1, -len * 0.5 + i * len / maxf(n, 1)), Vector3.ZERO, Vector3.ONE, body)
	_add_visual(_box_mesh(Vector3(0.05, 0.05, len)), mats["metal"], Vector3(0, h * 0.5, 0), Vector3.ZERO, Vector3.ONE, body)

func _tent(p: Vector3, rot_deg: float) -> void:
	var body := _add_box(p + Vector3(0, 1.0, 0), Vector3(3.6, 2.0, 4.6), mats["canvas"], deg_to_rad(rot_deg))
	body.get_child(0).visible = false
	var pr := PrismMesh.new()
	pr.size = Vector3(3.8, 2.2, 4.8)
	_add_visual(pr, mats["canvas"], Vector3(0, 0.1, 0), Vector3.ZERO, Vector3.ONE, body)

func _tower(p: Vector3) -> void:
	for dx in [-1.2, 1.2]:
		for dz in [-1.2, 1.2]:
			_add_box(p + Vector3(dx, 3.0, dz), Vector3(0.25, 6.0, 0.25), mats["wood_dark"])
	_add_visual(_box_mesh(Vector3(3.2, 0.25, 3.2)), mats["wood_dark"], p + Vector3(0, 6.0, 0))
	_add_visual(_box_mesh(Vector3(3.2, 1.0, 0.1)), mats["wood_dark"], p + Vector3(0, 6.6, 1.55))
	_add_visual(_box_mesh(Vector3(3.2, 1.0, 0.1)), mats["wood_dark"], p + Vector3(0, 6.6, -1.55))
	var roof := PrismMesh.new()
	roof.size = Vector3(3.6, 1.0, 3.6)
	_add_visual(roof, mats["metal"], p + Vector3(0, 8.4, 0))
	for dx in [-1.5, 1.5]:
		_add_visual(_box_mesh(Vector3(0.12, 1.8, 0.12)), mats["wood_dark"], p + Vector3(dx, 7.0, 1.5))
		_add_visual(_box_mesh(Vector3(0.12, 1.8, 0.12)), mats["wood_dark"], p + Vector3(dx, 7.0, -1.5))

# Деревянный дом со скатной крышей (стороны по осям)
func _wood_house(c: Vector3, size: Vector3, mat_name := "wood", roof_mat := "wood_dark") -> void:
	_add_box(c + Vector3(0, size.y * 0.5, 0), size, mats[mat_name])
	var pr := PrismMesh.new()
	pr.size = Vector3(size.x + 0.8, 2.4, size.z + 0.8)
	_add_visual(pr, mats[roof_mat], c + Vector3(0, size.y + 1.2, 0))
	for out in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var half: float = size.x * 0.5 if absf(out.x) > 0.5 else size.z * 0.5
		var length: float = size.z if absf(out.x) > 0.5 else size.x
		var along: Vector3 = Vector3.UP.cross(out)
		var u := -length * 0.5 + 1.6
		while u <= length * 0.5 - 1.6:
			window_transforms.append(Transform3D(Basis(along * 0.7, Vector3.UP * 0.6, out), c + out * (half + 0.02) + along * u + Vector3(0, 1.7, 0)))
			u += 2.8

func _water(y: float, size := 130.0) -> void:
	_add_visual(_box_mesh(Vector3(size, 0.02, size)), mats["water"], Vector3(0, y, 0))

func _omni(p: Vector3, color: Color, energy := 1.5, range_m := 12.0) -> void:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.shadow_enabled = false
	add_child(l)
	_add_visual(_sphere_mesh(0.18), mats["lamp"], p)

# Падающий снег / летающие споры / пепел
func _particles(kind: String) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	p.mesh = q
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.local_coords = false
	match kind:
		"snow":
			q.size = Vector2(0.06, 0.06)
			m.albedo_color = Color(1, 1, 1, 0.9)
			p.amount = 900
			p.lifetime = 9.0
			p.position = Vector3(0, 14, 0)
			p.emission_box_extents = Vector3(42, 1, 42)
			p.gravity = Vector3(0.4, -1.6, 0.2)
			p.initial_velocity_min = 0.0
			p.initial_velocity_max = 0.4
		"rain":
			q.size = Vector2(0.015, 0.5)
			m.albedo_color = Color(0.7, 0.75, 0.8, 0.35)
			m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			p.amount = 1200
			p.lifetime = 1.0
			p.position = Vector3(0, 14, 0)
			p.emission_box_extents = Vector3(42, 1, 42)
			p.gravity = Vector3(0, -30, 0)
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 6.0
			p.direction = Vector3(0, -1, 0)
		_:   # споры: медленно парят в воздухе
			q.size = Vector2(0.05, 0.05)
			m.albedo_color = Color(0.85, 0.8, 0.55, 0.6)
			p.amount = 500
			p.lifetime = 12.0
			p.position = Vector3(0, 2.5, 0)
			p.emission_box_extents = Vector3(38, 2.5, 38)
			p.gravity = Vector3(0, 0.03, 0)
			p.initial_velocity_min = 0.05
			p.initial_velocity_max = 0.2
			p.spread = 180.0
	p.preprocess = p.lifetime
	add_child(p)

# Разбросать мелочь по карте: fn(p) вызывается для свободных точек
func _scatter(count: int, extent: float, min_free: float, fn: Callable) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 20:
		tries += 1
		var p := Vector3(rng.randf_range(-extent, extent), 0, rng.randf_range(-extent, extent))
		if not _area_ok(p, min_free, min_free):
			continue
		fn.call(p)
		placed += 1
