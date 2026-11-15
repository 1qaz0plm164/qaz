extends "res://gun_view.gd"
# Пистолет в руке. Модель собирается из простых фигур.

func _init() -> void:
	home_pos = Vector3(0.17, -0.17, -0.4)
	flash_pos = Vector3(0, 0.035, -0.125)
	reach = 0.52

func _build(b: Node3D) -> void:
	var metal := _mat(Color(0.1, 0.1, 0.11), 0.35, 0.7)     # затвор
	var poly := _mat(Color(0.05, 0.05, 0.055), 0.8)          # рамка и рукоятка
	var glove := _mat(Color(0.1, 0.1, 0.09), 0.95)           # перчатка
	var sleeve := _mat(Color(0.16, 0.18, 0.15), 0.95)        # рукав куртки
	var sight := _mat(Color(0.75, 0.75, 0.7), 0.5)           # белая точка мушки

	# Рамка и спусковая скоба
	_box(b, Vector3(0.032, 0.026, 0.19), poly, Vector3(0, 0.0, 0.0))
	_box(b, Vector3(0.026, 0.006, 0.055), poly, Vector3(0, -0.032, -0.03))
	_box(b, Vector3(0.026, 0.03, 0.006), poly, Vector3(0, -0.018, -0.057))
	_box(b, Vector3(0.008, 0.022, 0.008), metal, Vector3(0, -0.02, -0.002))      # крючок
	_box(b, Vector3(0.036, 0.115, 0.055), poly, Vector3(0, -0.07, 0.075), Vector3(-0.22, 0, 0))   # рукоятка

	# Затвор с мушкой и целиком
	_box(slide, Vector3(0.034, 0.038, 0.205), metal, Vector3(0, 0.032, -0.005))
	_box(slide, Vector3(0.012, 0.012, 0.012), metal, Vector3(0, 0.058, 0.088))
	_box(slide, Vector3(0.004, 0.004, 0.004), sight, Vector3(0, 0.0645, 0.088))
	_box(slide, Vector3(0.007, 0.011, 0.01), metal, Vector3(0, 0.0585, -0.095))
	_box(slide, Vector3(0.003, 0.003, 0.003), sight, Vector3(0, 0.064, -0.095))
	for i in 5:
		_box(slide, Vector3(0.036, 0.03, 0.003), poly, Vector3(0, 0.034, 0.055 + i * 0.008))

	# Рука
	_box(b, Vector3(0.062, 0.075, 0.075), glove, Vector3(0.012, -0.05, 0.085), Vector3(-0.22, 0, 0))
	_box(b, Vector3(0.026, 0.03, 0.07), glove, Vector3(-0.026, 0.0, 0.03))
	_box(b, Vector3(0.07, 0.07, 0.38), sleeve, Vector3(0.03, -0.125, 0.3), Vector3(0.38, 0, 0.12))
