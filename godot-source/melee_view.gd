extends Node3D
# Ближний бой в кадре: кулак или доска с гвоздями проносится справа налево.
# Висит на камере, видна только во время удара.

const VIEWMODEL_LAYER := 1 << 19
const SWING := 0.32

var t := -1.0
var fist: Node3D
var plank: Node3D

func _ready() -> void:
	visible = false
	var glove := _mat(Color(0.1, 0.1, 0.09))
	var sleeve := _mat(Color(0.16, 0.18, 0.15))
	var wood := _mat(Color(0.42, 0.32, 0.2))
	var nail := _mat(Color(0.6, 0.6, 0.58))
	nail.metallic = 0.8
	fist = Node3D.new()
	add_child(fist)
	_box(fist, Vector3(0.09, 0.08, 0.1), glove, Vector3.ZERO)
	_box(fist, Vector3(0.08, 0.08, 0.4), sleeve, Vector3(0.02, -0.02, 0.24))
	plank = Node3D.new()
	add_child(plank)
	_box(plank, Vector3(0.08, 0.08, 0.1), glove, Vector3(0, 0, 0.1))
	_box(plank, Vector3(0.08, 0.08, 0.4), sleeve, Vector3(0.02, -0.02, 0.32))
	_box(plank, Vector3(0.05, 0.11, 0.75), wood, Vector3(0, 0.02, -0.28))
	for i in 4:
		_box(plank, Vector3(0.1, 0.006, 0.006), nail, Vector3(0, 0.05, -0.45 - i * 0.06))

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m

func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.layers = VIEWMODEL_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func swing(with_plank: bool) -> void:
	fist.visible = not with_plank
	plank.visible = with_plank
	t = 0.0
	visible = true

func _process(delta: float) -> void:
	if t < 0.0:
		return
	t += delta
	var p := clampf(t / SWING, 0.0, 1.0)
	var e := p * p * (3.0 - 2.0 * p)
	# справа-сверху → центр → влево-вниз
	position = Vector3(lerpf(0.35, -0.3, e), lerpf(-0.1, -0.25, e) + sin(p * PI) * 0.08, -0.45 + sin(p * PI) * -0.1)
	rotation = Vector3(-0.2 + sin(p * PI) * 0.3, lerpf(-0.9, 0.9, e), lerpf(-0.6, 0.5, e))
	if p >= 1.0:
		t = -1.0
		visible = false
