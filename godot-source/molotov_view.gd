extends "res://gun_view.gd"
# Коктейль Молотова в руке: бутылка с горящей тряпкой. «Выстрел» — бросок.

var flame: Node3D
var flame_light: OmniLight3D
var throw_t := 0.0          # идёт анимация броска
var has_bottle := true
var t_acc := 0.0

func _init() -> void:
	home_pos = Vector3(0.2, -0.2, -0.34)
	reach = 0.4
	ads_height = 0.0

func _build(b: Node3D) -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.35, 0.45, 0.25, 0.75)
	glass.roughness = 0.1
	glass.metallic = 0.2
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var liquid := _mat(Color(0.55, 0.35, 0.1), 0.3)
	var rag := _mat(Color(0.55, 0.5, 0.42), 1.0)
	var glove := _mat(Color(0.1, 0.1, 0.09), 0.95)
	var sleeve := _mat(Color(0.16, 0.18, 0.15), 0.95)
	# бутылка стоит вертикально, горлышко вверх и чуть вперёд
	var bottle := Node3D.new()
	bottle.rotation = Vector3(-0.35, 0, 0.15)
	b.add_child(bottle)
	_cyl(bottle, 0.034, 0.15, liquid, Vector3(0, -0.02, 0))
	_cyl(bottle, 0.038, 0.17, glass, Vector3(0, 0.0, 0))
	_cyl(bottle, 0.014, 0.07, glass, Vector3(0, 0.12, 0))
	_box(bottle, Vector3(0.03, 0.05, 0.03), rag, Vector3(0, 0.17, 0), Vector3(0.2, 0.3, 0.1))
	_box(bottle, Vector3(0.012, 0.06, 0.02), rag, Vector3(0.012, 0.13, 0.015), Vector3(0.3, 0, -0.3))
	# пламя на тряпке
	flame = Node3D.new()
	flame.position = Vector3(0, 0.22, 0)
	bottle.add_child(flame)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.55, 0.15)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for a in [0.0, PI * 0.5]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.05, 0.09)
		q.mesh = qm
		q.material_override = fm
		q.rotation.y = a
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.layers = VIEWMODEL_LAYER
		flame.add_child(q)
	flame_light = OmniLight3D.new()
	flame_light.light_color = Color(1.0, 0.6, 0.25)
	flame_light.light_energy = 1.2
	flame_light.omni_range = 4.0
	flame.add_child(flame_light)
	# рука держит бутылку
	_box(b, Vector3(0.07, 0.07, 0.08), glove, Vector3(0.0, -0.03, 0.02), Vector3(-0.3, 0, 0))
	_box(b, Vector3(0.07, 0.07, 0.36), sleeve, Vector3(0.04, -0.12, 0.22), Vector3(0.5, 0, 0.1))

func _cyl(parent: Node3D, r: float, h: float, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	mi.mesh = cm
	_finish(mi, parent, mat, pos, Vector3.ZERO)

# Бросок: рука уходит назад-вверх и резко вперёд, бутылка исчезает
func fire() -> void:
	throw_t = 0.0001

# Есть ли ещё бутылки (если нет — рука пустая)
func set_has_bottle(on: bool) -> void:
	has_bottle = on
	if throw_t <= 0.0:
		body.visible = on

func _animate_parts(delta: float, _slide_pull: float) -> void:
	t_acc += delta
	if flame:
		flame.scale = Vector3(1.0, randf_range(0.8, 1.25), 1.0)
		flame_light.light_energy = 1.0 + sin(t_acc * 23.0) * 0.2 + randf() * 0.3
	if throw_t <= 0.0:
		body.position = Vector3.ZERO
		body.rotation = Vector3.ZERO
		return
	throw_t += delta
	var t := throw_t
	if t < 0.18:          # замах
		var p := t / 0.18
		body.position = Vector3(0.05, 0.12, 0.1) * p
		body.rotation = Vector3(0.9, 0, -0.2) * p
		body.visible = true
	elif t < 0.3:         # бросок вперёд
		var p := (t - 0.18) / 0.12
		body.position = Vector3(0.05, 0.12, 0.1).lerp(Vector3(-0.05, 0.05, -0.25), p)
		body.rotation = Vector3(0.9, 0, -0.2).lerp(Vector3(-1.0, 0, 0.1), p)
	elif t < 0.65:        # рука пустая, ниже экрана
		body.visible = false
		body.position = Vector3(0, -0.3, 0)
	elif t < 0.95:        # достаём новую бутылку
		var p := (t - 0.65) / 0.3
		body.visible = has_bottle
		body.position = Vector3(0, -0.3, 0).lerp(Vector3.ZERO, p)
		body.rotation = Vector3.ZERO
	else:
		throw_t = 0.0
		body.position = Vector3.ZERO
		body.visible = has_bottle
