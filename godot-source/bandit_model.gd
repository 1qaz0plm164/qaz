extends RefCounted
const Surface := preload("res://character_surface.gd")
static func _mat(color: Color, rough := 0.85, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m

static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s

static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 4
	return c

static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

static func _tube(r: float, length: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = length
	c.radial_segments = 8
	return c

static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func build(root: Node3D, weapon: String, seed_value := 0) -> Dictionary:
	var parts := Surface.build(root,"bandit",seed_value)
	var arms: Array = parts.arms
	var gear := _mat(Color(0.22,0.2,0.14))
	# ---------- Оружие в правой руке (ствол вдоль -Z оружия) ----------
	var gun := Node3D.new()
	gun.position = Vector3(0, -0.64, 0)
	gun.rotation.x = -PI * 0.5            # -Z оружия смотрит вдоль руки
	arms[1].add_child(gun)
	var metal := _mat(Color(0.08, 0.08, 0.09), 0.4, 0.7)
	var wood := _mat(Color(0.3, 0.18, 0.08), 0.75)
	var length := 0.2
	match weapon:
		"bat":
			var bat := _tube(0.025, 0.75)
			bat.top_radius = 0.045             # толстый конец (смотрит от руки)
			_add(gun, bat, wood, Vector3(0, 0, -0.32), Vector3(-PI * 0.5, 0, 0))
			length = 0.7
		"pistol":
			_add(gun, _box(Vector3(0.03, 0.045, 0.18)), metal, Vector3(0, 0.03, -0.06))
			_add(gun, _box(Vector3(0.028, 0.09, 0.04)), metal, Vector3(0, -0.02, 0.0), Vector3(0.2, 0, 0))
			length = 0.16
		"shotgun":
			_add(gun, _tube(0.016, 0.62), metal, Vector3(0, 0.03, -0.35), Vector3(PI * 0.5, 0, 0))
			_add(gun, _box(Vector3(0.05, 0.05, 0.12)), wood, Vector3(0, 0.0, -0.3))             # цевьё
			_add(gun, _box(Vector3(0.05, 0.07, 0.2)), metal, Vector3(0, 0.02, -0.02))
			_add(gun, _box(Vector3(0.045, 0.09, 0.3)), wood, Vector3(0, -0.02, 0.2), Vector3(0.12, 0, 0))   # приклад
			length = 0.66
		"rifle":
			_add(gun, _box(Vector3(0.05, 0.08, 0.32)), metal, Vector3(0, 0.02, -0.08))
			_add(gun, _tube(0.013, 0.36), metal, Vector3(0, 0.035, -0.42), Vector3(PI * 0.5, 0, 0))
			_add(gun, _box(Vector3(0.035, 0.14, 0.06)), metal, Vector3(0, -0.07, -0.12), Vector3(-0.25, 0, 0))   # магазин
			_add(gun, _box(Vector3(0.04, 0.08, 0.24)), gear, Vector3(0, -0.01, 0.2))                            # приклад
			length = 0.6
	var muzzle := Node3D.new()
	muzzle.position = Vector3(0, 0.03, -length)
	gun.add_child(muzzle)

	parts.gun = gun
	parts.muzzle = muzzle
	return parts
