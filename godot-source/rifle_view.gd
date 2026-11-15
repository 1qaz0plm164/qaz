extends "res://gun_view.gd"
# Штурмовая винтовка: приклад, ствольная коробка, магазин, цевьё, коллиматорный прицел.

func _init() -> void:
	home_pos = Vector3(0.13, -0.16, -0.34)
	recoil_back = 0.03
	recoil_up = 0.008
	recoil_pitch = 0.1
	slide_travel = 0.045
	flash_pos = Vector3(0, 0.012, -0.7)
	flash_length = 0.17
	flash_energy = 3.5
	reach = 0.95
	ads_height = 0.072
	has_optic = true

func _build(b: Node3D) -> void:
	var metal := _mat(Color(0.1, 0.1, 0.11), 0.4, 0.7)
	var poly := _mat(Color(0.06, 0.06, 0.065), 0.8)
	var glove := _mat(Color(0.1, 0.1, 0.09), 0.95)
	var sleeve := _mat(Color(0.16, 0.18, 0.15), 0.95)

	# Корпус, цевьё, ствол, дульный тормоз
	_box(b, Vector3(0.046, 0.075, 0.3), metal, Vector3(0, 0.0, 0.0))
	_box(b, Vector3(0.054, 0.06, 0.3), poly, Vector3(0, 0.004, -0.3))
	_tube(b, 0.011, 0.2, metal, Vector3(0, 0.012, -0.55))
	_box(b, Vector3(0.03, 0.03, 0.05), metal, Vector3(0, 0.012, -0.66))
	# Мушка на стволе (низкая — не мешает точке)
	_box(b, Vector3(0.005, 0.016, 0.006), metal, Vector3(0, 0.036, -0.58))
	# Коллиматорный прицел: основание, открытая рамка, прозрачное стекло, красная точка
	_box(b, Vector3(0.03, 0.01, 0.07), metal, Vector3(0, 0.042, -0.01))
	var fz := -0.03     # плоскость рамки
	var c := 0.072      # центр окна по высоте (= ads_height)
	var w := 0.042      # внешняя ширина рамки
	var h := 0.034      # внешняя высота рамки
	var t := 0.003      # толщина ободка
	_box(b, Vector3(t, h, 0.03), metal, Vector3(-w * 0.5 + t * 0.5, c, fz))
	_box(b, Vector3(t, h, 0.03), metal, Vector3(w * 0.5 - t * 0.5, c, fz))
	_box(b, Vector3(w, t, 0.03), metal, Vector3(0, c + h * 0.5 - t * 0.5, fz))
	_box(b, Vector3(w, t * 1.5, 0.03), metal, Vector3(0, c - h * 0.5 + t * 0.75, fz))
	_box(b, Vector3(0.012, c - h * 0.5 - 0.046, 0.024), metal, Vector3(0, (c - h * 0.5 + 0.046) * 0.5, fz))
	var gl := StandardMaterial3D.new()
	gl.albedo_color = Color(0.4, 0.75, 0.7, 0.12)
	gl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gl.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gl.cull_mode = BaseMaterial3D.CULL_DISABLED
	_box(b, Vector3(w - 2 * t, h - 2.5 * t, 0.001), gl, Vector3(0, c, fz - 0.012))
	var dot := StandardMaterial3D.new()
	dot.albedo_color = Color(1.0, 0.12, 0.08)
	dot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var d := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.0012
	sm.height = 0.0024
	sm.radial_segments = 8
	sm.rings = 4
	d.mesh = sm
	_finish(d, b, dot, Vector3(0, c, fz - 0.011), Vector3.ZERO)
	# Приклад, рукоятка, магазин
	_box(b, Vector3(0.04, 0.1, 0.3), poly, Vector3(0, -0.025, 0.3), Vector3(0.08, 0, 0))
	_box(b, Vector3(0.036, 0.1, 0.05), poly, Vector3(0, -0.09, 0.1), Vector3(-0.3, 0, 0))
	_box(b, Vector3(0.032, 0.14, 0.06), metal, Vector3(0, -0.105, -0.05), Vector3(-0.15, 0, 0))
	_box(b, Vector3(0.026, 0.006, 0.06), poly, Vector3(0, -0.05, 0.04))

	# Подвижная рукоятка заряжания
	_box(slide, Vector3(0.03, 0.022, 0.045), metal, Vector3(0.036, 0.034, 0.06))

	# Правая рука на рукоятке
	_box(b, Vector3(0.062, 0.07, 0.075), glove, Vector3(0.012, -0.085, 0.115), Vector3(-0.3, 0, 0))
	_box(b, Vector3(0.07, 0.07, 0.38), sleeve, Vector3(0.05, -0.16, 0.34), Vector3(0.38, 0, 0.12))
	# Левая рука на цевье
	_box(b, Vector3(0.07, 0.06, 0.11), glove, Vector3(-0.008, -0.048, -0.3))
	_box(b, Vector3(0.07, 0.07, 0.36), sleeve, Vector3(-0.18, -0.17, -0.14), Vector3(0.5, -0.75, -0.05))
