extends StaticBody3D
# Ящик с припасами. Появляется в центре карты между волнами.
#   kind = "medkit" — белый ящик с красным крестом (аптечки)
#   kind = "ammo"   — армейский зелёный ящик (патроны ко всему оружию)
# Игрок подходит, зажимает T на секунду — забирает содержимое (это делает player.gd).
# После этого крышка откидывается, ящик через несколько секунд уходит под землю.

const SIZE := Vector3(0.95, 0.5, 0.6)

var kind := "ammo"
var opened := false
var lid: Node3D
var light: OmniLight3D
var t := 0.0

func _ready() -> void:
	add_to_group("crate")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	shape.position.y = SIZE.y * 0.5
	add_child(shape)
	_build()
	# появляется «выпрыгивая» из земли
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _mat(c: Color, rough := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metallic
	return m

func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

func _build() -> void:
	var med := kind == "medkit"
	var body_mat := _mat(Color(0.82, 0.8, 0.74), 0.6) if med else _mat(Color(0.24, 0.29, 0.16), 0.85)
	var edge := _mat(Color(0.25, 0.25, 0.25), 0.5, 0.6)
	var mark := _mat(Color(0.75, 0.1, 0.08), 0.6) if med else _mat(Color(0.8, 0.68, 0.2), 0.7)
	var h := SIZE.y * 0.72      # высота корпуса, остальное — крышка

	# Корпус
	_box(self, Vector3(SIZE.x, h, SIZE.z), body_mat, Vector3(0, h * 0.5, 0))
	# Металлические уголки и ручки по бокам
	for sx in [-1.0, 1.0]:
		_box(self, Vector3(0.04, h + 0.01, SIZE.z + 0.01), edge, Vector3(sx * (SIZE.x * 0.5 - 0.02), h * 0.5, 0))
		_box(self, Vector3(0.03, 0.04, 0.18), edge, Vector3(sx * (SIZE.x * 0.5 + 0.015), h * 0.7, 0))
	# Знак на передней стенке
	if med:
		_box(self, Vector3(0.16, 0.05, 0.01), mark, Vector3(0, h * 0.5, -SIZE.z * 0.5 - 0.005))
		_box(self, Vector3(0.05, 0.16, 0.01), mark, Vector3(0, h * 0.5, -SIZE.z * 0.5 - 0.005))
	else:
		_box(self, Vector3(SIZE.x * 0.7, 0.05, 0.01), mark, Vector3(0, h * 0.62, -SIZE.z * 0.5 - 0.005))
		_box(self, Vector3(SIZE.x * 0.7, 0.05, 0.01), mark, Vector3(0, h * 0.32, -SIZE.z * 0.5 - 0.005))
	# Содержимое (видно, когда крышка откинута)
	var inside := _mat(Color(0.75, 0.1, 0.08), 0.6) if med else _mat(Color(0.6, 0.48, 0.18), 0.4, 0.7)
	for i in 3:
		_box(self, Vector3(0.2, 0.06, 0.25), inside, Vector3(-0.28 + i * 0.28, h - 0.02, 0))

	# Крышка на петле у задней стенки
	lid = Node3D.new()
	lid.position = Vector3(0, h, SIZE.z * 0.5)
	add_child(lid)
	var lh := SIZE.y - h
	_box(lid, Vector3(SIZE.x + 0.02, lh, SIZE.z + 0.02), body_mat, Vector3(0, lh * 0.5, -SIZE.z * 0.5))
	if med:
		_box(lid, Vector3(0.3, 0.012, 0.09), mark, Vector3(0, lh + 0.006, -SIZE.z * 0.5))
		_box(lid, Vector3(0.09, 0.012, 0.3), mark, Vector3(0, lh + 0.006, -SIZE.z * 0.5))

	# Мягкая подсветка, чтобы ящик было видно в темноте
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.4) if med else Color(1.0, 0.85, 0.45)
	light.light_energy = 0.8
	light.omni_range = 3.5
	light.shadow_enabled = false
	light.position = Vector3(0, 1.0, 0)
	add_child(light)

func _process(delta: float) -> void:
	if opened:
		return
	t += delta
	light.light_energy = 0.6 + 0.4 * (0.5 + 0.5 * sin(t * 3.0))   # пульсирует

# Вызывает игрок, когда забрал содержимое
func open() -> void:
	if opened:
		return
	opened = true
	remove_from_group("crate")
	light.visible = false
	var tw := create_tween()
	tw.tween_property(lid, "rotation:x", 1.9, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(6.0)
	tw.tween_property(self, "position:y", position.y - 0.8, 1.2)
	tw.tween_callback(queue_free)
