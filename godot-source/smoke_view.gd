extends "res://molotov_view.gd"
# Дымовая шашка в руке: серый цилиндр с запалом.

func _build(b: Node3D) -> void:
	var body_m := _mat(Color(0.3, 0.32, 0.35), 0.5, 0.5)
	var band_m := _mat(Color(0.75, 0.72, 0.65), 0.7)
	var cap := _mat(Color(0.12, 0.12, 0.12), 0.6, 0.6)
	var glove := _mat(Color(0.1, 0.1, 0.09), 0.95)
	var sleeve := _mat(Color(0.16, 0.18, 0.15), 0.95)
	var c := Node3D.new()
	c.rotation = Vector3(-0.3, 0, 0.15)
	b.add_child(c)
	_cyl(c, 0.032, 0.14, body_m, Vector3(0, 0.04, 0))
	_cyl(c, 0.033, 0.02, band_m, Vector3(0, 0.06, 0))
	_cyl(c, 0.022, 0.025, cap, Vector3(0, 0.122, 0))
	_box(b, Vector3(0.07, 0.07, 0.08), glove, Vector3(0.0, -0.03, 0.02), Vector3(-0.3, 0, 0))
	_box(b, Vector3(0.07, 0.07, 0.36), sleeve, Vector3(0.04, -0.12, 0.22), Vector3(0.5, 0, 0.1))
