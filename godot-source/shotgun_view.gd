extends "res://gun_view.gd"
# Помповый дробовик: длинный ствол, трубка с патронами, деревянные цевьё и приклад.
# После каждого выстрела цевьё («помпа») отъезжает назад и возвращается.

var pump_timer := 0.0

func _init() -> void:
	home_pos = Vector3(0.14, -0.17, -0.36)
	recoil_back = 0.09
	recoil_up = 0.02
	recoil_pitch = 0.32
	slide_travel = 0.0            # помпой управляем сами (ниже)
	flash_pos = Vector3(0, 0.022, -0.74)
	flash_length = 0.26
	flash_energy = 5.0
	reach = 1.0
	reload_style = "shell"
	ads_height = 0.05

func _build(b: Node3D) -> void:
	var metal := _mat(Color(0.09, 0.09, 0.1), 0.4, 0.7)
	var wood := _mat(Color(0.26, 0.15, 0.07), 0.75)
	var poly := _mat(Color(0.05, 0.05, 0.055), 0.8)
	var glove := _mat(Color(0.1, 0.1, 0.09), 0.95)
	var sleeve := _mat(Color(0.16, 0.18, 0.15), 0.95)

	# Ствольная коробка, ствол и трубка магазина
	_box(b, Vector3(0.045, 0.07, 0.22), metal, Vector3(0, 0.0, 0.0))
	_tube(b, 0.014, 0.62, metal, Vector3(0, 0.022, -0.41))
	_tube(b, 0.012, 0.46, metal, Vector3(0, -0.014, -0.335))
	_box(b, Vector3(0.008, 0.012, 0.01), metal, Vector3(0, 0.044, -0.715))      # мушка
	_box(b, Vector3(0.03, 0.03, 0.02), metal, Vector3(0, -0.014, -0.56))        # заглушка трубки
	# Спусковая скоба и рукоятка
	_box(b, Vector3(0.026, 0.006, 0.06), poly, Vector3(0, -0.04, 0.03))
	_box(b, Vector3(0.008, 0.022, 0.008), metal, Vector3(0, -0.028, 0.03))
	_box(b, Vector3(0.036, 0.09, 0.05), wood, Vector3(0, -0.085, 0.115), Vector3(-0.3, 0, 0))
	# Приклад
	_box(b, Vector3(0.04, 0.085, 0.32), wood, Vector3(0, -0.03, 0.3), Vector3(0.1, 0, 0))
	_box(b, Vector3(0.042, 0.095, 0.02), poly, Vector3(0, -0.045, 0.46), Vector3(0.1, 0, 0))

	# Правая рука на рукоятке
	_box(b, Vector3(0.062, 0.07, 0.075), glove, Vector3(0.012, -0.075, 0.12), Vector3(-0.3, 0, 0))
	_box(b, Vector3(0.07, 0.07, 0.38), sleeve, Vector3(0.05, -0.15, 0.33), Vector3(0.38, 0, 0.12))

	# Помпа (цевьё) с левой рукой — всё это ездит вместе
	_box(slide, Vector3(0.052, 0.046, 0.2), wood, Vector3(0, -0.038, -0.3))
	for i in 5:
		_box(slide, Vector3(0.054, 0.03, 0.006), poly, Vector3(0, -0.04, -0.37 + i * 0.03))
	_box(slide, Vector3(0.07, 0.065, 0.1), glove, Vector3(-0.012, -0.052, -0.3))
	_box(slide, Vector3(0.07, 0.07, 0.36), sleeve, Vector3(-0.17, -0.17, -0.12), Vector3(0.5, -0.75, -0.05))

func fire() -> void:
	super.fire()
	pump_timer = 0.0001

func cancel_reload() -> void:
	super.cancel_reload()

# Цевьё: пауза после выстрела → назад → вперёд
func _animate_parts(delta: float, _slide_pull: float) -> void:
	var z := 0.0
	if pump_timer > 0.0:
		pump_timer += delta
		var q := (pump_timer - 0.3) / 0.45
		if q >= 1.0:
			pump_timer = 0.0
		elif q > 0.0:
			z = sin(q * PI) * 0.09
	slide.position.z = z
