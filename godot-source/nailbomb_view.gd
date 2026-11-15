extends "res://molotov_view.gd"
# Бомба с гвоздями в руке: жестяная банка, обмотанная лентой, торчат гвозди.

func _build(b: Node3D) -> void:
	var tin := _mat(Color(0.45, 0.45, 0.42), 0.4, 0.6)
	var tape := _mat(Color(0.25, 0.25, 0.22), 0.9)
	var nail := _mat(Color(0.65, 0.65, 0.6), 0.3, 0.8)
	var glove := _mat(Color(0.1, 0.1, 0.09), 0.95)
	var sleeve := _mat(Color(0.16, 0.18, 0.15), 0.95)
	var can := Node3D.new()
	can.rotation = Vector3(-0.3, 0, 0.15)
	b.add_child(can)
	_cyl(can, 0.045, 0.11, tin, Vector3(0, 0.03, 0))
	_cyl(can, 0.047, 0.03, tape, Vector3(0, 0.03, 0))
	for i in 7:
		var a := TAU * i / 7.0
		_box(can, Vector3(0.004, 0.004, 0.05), nail, Vector3(cos(a) * 0.045, 0.06 + (i % 2) * 0.02, sin(a) * 0.045), Vector3(0, -a, 0))
	_box(can, Vector3(0.02, 0.012, 0.012), _mat(Color(0.6, 0.1, 0.08), 0.5), Vector3(0, 0.095, 0))
	_box(b, Vector3(0.07, 0.07, 0.08), glove, Vector3(0.0, -0.03, 0.02), Vector3(-0.3, 0, 0))
	_box(b, Vector3(0.07, 0.07, 0.36), sleeve, Vector3(0.04, -0.12, 0.22), Vector3(0.5, 0, 0.1))
