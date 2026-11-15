extends "res://gun_view.gd"
# Снайперская винтовка с продольно-скользящим затвором и оптическим прицелом.

var bolt: Node3D            # рукоятка затвора
var bolt_t := 0.0           # 0 — затвор закрыт; идёт цикл после выстрела

func _init() -> void:
	home_pos = Vector3(0.14, -0.17, -0.36)
	recoil_back = 0.07
	recoil_up = 0.02
	recoil_pitch = 0.22
	slide_travel = 0.0
	flash_pos = Vector3(0, 0.012, -0.86)
	flash_length = 0.22
	flash_energy = 4.0
	reach = 1.1
	ads_height = 0.085
	has_optic = true

func _build(b: Node3D) -> void:
	var metal := _mat(Color(0.09, 0.09, 0.1), 0.4, 0.7)
	var wood := _mat(Color(0.3, 0.2, 0.12), 0.8)
	var glove := _mat(Color(0.1, 0.1, 0.09), 0.95)
	var sleeve := _mat(Color(0.2, 0.17, 0.13), 0.95)
	var lens := _mat(Color(0.15, 0.3, 0.35), 0.1, 0.6)

	# ложа, приклад, ствольная коробка, длинный ствол
	_box(b, Vector3(0.05, 0.06, 0.55), wood, Vector3(0, -0.012, -0.12))
	_box(b, Vector3(0.045, 0.11, 0.26), wood, Vector3(0, -0.04, 0.3), Vector3(0.1, 0, 0))
	_box(b, Vector3(0.04, 0.045, 0.2), metal, Vector3(0, 0.03, 0.02))
	_tube(b, 0.011, 0.5, metal, Vector3(0, 0.025, -0.6))
	_tube(b, 0.016, 0.06, metal, Vector3(0, 0.025, -0.84))
	_box(b, Vector3(0.03, 0.06, 0.04), metal, Vector3(0, -0.06, -0.02))   # магазин
	_box(b, Vector3(0.032, 0.08, 0.04), wood, Vector3(0, -0.075, 0.12), Vector3(-0.35, 0, 0))   # рукоятка
	# оптический прицел: кольца, труба, объектив и окуляр
	for z in [-0.06, 0.08]:
		_box(b, Vector3(0.02, 0.035, 0.016), metal, Vector3(0, 0.062, z))
	_tube(b, 0.017, 0.3, metal, Vector3(0, ads_height, 0.0))
	_tube(b, 0.025, 0.07, metal, Vector3(0, ads_height, -0.16))
	_tube(b, 0.022, 0.06, metal, Vector3(0, ads_height, 0.15))
	_tube(b, 0.021, 0.004, lens, Vector3(0, ads_height, -0.197))
	_box(b, Vector3(0.016, 0.022, 0.022), metal, Vector3(0, ads_height + 0.022, 0.0))
	# затвор
	bolt = Node3D.new()
	bolt.position = Vector3(0.025, 0.035, 0.08)
	b.add_child(bolt)
	_box(bolt, Vector3(0.05, 0.01, 0.01), metal, Vector3(0.025, 0, 0))
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.011
	sm.height = 0.022
	knob.mesh = sm
	_finish(knob, bolt, metal, Vector3(0.05, 0, 0), Vector3.ZERO)
	# руки
	_box(b, Vector3(0.062, 0.07, 0.075), glove, Vector3(0.012, -0.08, 0.13), Vector3(-0.3, 0, 0))
	_box(b, Vector3(0.07, 0.07, 0.38), sleeve, Vector3(0.05, -0.155, 0.36), Vector3(0.38, 0, 0.12))
	_box(b, Vector3(0.07, 0.06, 0.11), glove, Vector3(-0.008, -0.05, -0.3))
	_box(b, Vector3(0.07, 0.07, 0.36), sleeve, Vector3(-0.18, -0.17, -0.14), Vector3(0.5, -0.75, -0.05))

func fire() -> void:
	super.fire()
	bolt_t = 0.0001

# Цикл затвора после выстрела: вверх — назад — вперёд — вниз
func _animate_parts(delta: float, slide_pull: float) -> void:
	var up := 0.0
	var back := 0.0
	if bolt_t > 0.0:
		bolt_t += delta
		var t := bolt_t - 0.35          # сперва отдача, потом рука на затвор
		if t > 0.0:
			var p := t / 0.55
			up = clampf(p / 0.2, 0.0, 1.0) * clampf((1.0 - p) / 0.2, 0.0, 1.0)
			back = sin(clampf((p - 0.15) / 0.65, 0.0, 1.0) * PI)
			if p >= 1.0:
				bolt_t = 0.0
	back = maxf(back, slide_pull)
	up = maxf(up, minf(slide_pull * 2.0, 1.0))
	bolt.rotation.z = up * 1.2
	bolt.position.z = 0.08 + back * 0.07
