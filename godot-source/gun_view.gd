extends Node3D
# Основа для всех моделей оружия «в руках» (вид от первого лица).
# Здесь живёт общая анимация: отдача, покачивание при ходьбе, запаздывание за мышью,
# перезарядка, смена оружия, вспышка выстрела, отодвигание от стены.
# Конкретное оружие (pistol.gd, shotgun_view.gd, rifle_view.gd) только рисует модель
# в _build() и задаёт числа в _init().

# Оружие живёт на отдельном слое 20: фонарик его не освещает (иначе пересвечивает в упор)
const VIEWMODEL_LAYER := 1 << 19

# ---- настройки, которые меняет каждое оружие в своём _init() ----
var home_pos := Vector3(0.17, -0.17, -0.4)    # где оружие «висит» относительно камеры
var recoil_back := 0.045                       # на сколько отбрасывает назад при выстреле
var recoil_up := 0.012                         # на сколько подбрасывает вверх
var recoil_pitch := 0.2                        # на сколько задирает ствол (радианы)
var slide_travel := 0.035                      # ход затвора
var flash_pos := Vector3(0, 0.035, -0.125)     # где вспышка (у дула)
var flash_length := 0.14
var flash_energy := 3.0
var reach := 0.55                              # на сколько оружие вытянуто вперёд (для стен)
var reload_style := "mag"                      # "mag" — сменный магазин, "shell" — по патрону

# ---- состояние анимации ----
var recoil := 0.0
var slide_kick := 0.0
var flash_time := 0.0
var reload_time := 0.0
var reload_length := 1.0
var reload_pulses := 1
var bob_phase := 0.0
var move_amount := 0.0
var sway := Vector2.ZERO
var draw := 0.0              # 0 — оружие поднято, 1 — опущено (смена оружия)
var sprint := 0.0            # 0..1 — оружие прижато к груди при беге
var aim := 0.0               # 0..1 — прицеливание (ПКМ): оружие по центру у глаз
var aim_target := 0.0
var has_optic := false       # есть коллиматор — экранное перекрестие при прицеливании скрывается
var ads_height := 0.065      # высота прицела над осью оружия (чтобы мушка была у центра экрана)
var sprint_target := 0.0
var wall_push := 0.0
var wall_target := 0.0

var body: Node3D             # всё оружие
var slide: Node3D            # подвижная часть (затвор, цевьё, рукоятка заряжания)
var flash: Node3D
var flash_light: OmniLight3D

# ============================================================
#  Помощники для сборки модели
# ============================================================
func _mat(color: Color, rough := 0.6, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m

func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	_finish(mi, parent, mat, pos, rot)
	return mi

# Цилиндр, лежащий вдоль оси Z (ствол, трубка)
func _tube(parent: Node3D, radius: float, length: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = length
	cm.radial_segments = 10
	mi.mesh = cm
	_finish(mi, parent, mat, pos, Vector3(PI * 0.5, 0, 0))
	return mi

func _finish(mi: MeshInstance3D, parent: Node3D, mat: Material, pos: Vector3, rot: Vector3) -> void:
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = VIEWMODEL_LAYER
	parent.add_child(mi)

# Переопределяется в конкретном оружии: нарисовать модель
func _build(_body: Node3D) -> void:
	pass

# Переопределяется, если нужна особая анимация частей (например, помпа дробовика)
func _animate_parts(_delta: float, slide_pull: float) -> void:
	slide.position.z = slide_kick * slide_travel + slide_pull * slide_travel

# ============================================================
#  Сборка
# ============================================================
func _ready() -> void:
	position = home_pos
	body = Node3D.new()
	add_child(body)
	slide = Node3D.new()
	body.add_child(slide)
	_build(body)
	_build_flash()

func _build_flash() -> void:
	flash = Node3D.new()
	flash.position = flash_pos
	flash.visible = false
	body.add_child(flash)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.75, 0.3)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for a in [0.0, PI * 0.25, PI * 0.5, PI * 0.75]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(flash_length, flash_length * 0.25)
		q.mesh = qm
		q.material_override = fm
		q.rotation.z = a
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.layers = VIEWMODEL_LAYER
		flash.add_child(q)
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color(1.0, 0.7, 0.35)
	flash_light.light_energy = flash_energy
	flash_light.omni_range = 9.0
	flash_light.shadow_enabled = false
	flash_light.visible = false
	flash.add_child(flash_light)

# ============================================================
#  Команды от игрока
# ============================================================
func fire() -> void:
	recoil = 1.0
	slide_kick = 1.0
	flash_time = 0.05
	flash.rotation.z = randf() * TAU
	flash.scale = Vector3.ONE * randf_range(0.8, 1.3)
	flash.visible = true
	flash_light.visible = true

func play_reload(seconds: float, pulses := 1) -> void:
	reload_length = maxf(seconds, 0.1)
	reload_pulses = maxi(pulses, 1)
	reload_time = 0.0001

func cancel_reload() -> void:
	reload_time = 0.0

func add_look(relative: Vector2) -> void:
	sway += relative * 0.0006

func set_motion(speed: float) -> void:
	move_amount = clampf(speed / 5.0, 0.0, 1.6)   # при беге покачивание сильнее

func set_aim(on: bool) -> void:
	aim_target = 1.0 if on else 0.0

func set_sprint(on: bool) -> void:
	sprint_target = 1.0 if on else 0.0

# Расстояние до препятствия перед камерой: если близко — оружие отодвигается назад
func set_wall_distance(d: float) -> void:
	wall_target = clampf(reach - d + 0.05, 0.0, 0.45)

# ============================================================
#  Анимация каждый кадр
# ============================================================
func _process(delta: float) -> void:
	if flash_time > 0.0:
		flash_time -= delta
		if flash_time <= 0.0:
			flash.visible = false
			flash_light.visible = false

	recoil = move_toward(recoil, 0.0, delta * 9.0)
	slide_kick = move_toward(slide_kick, 0.0, delta * 14.0)
	sway = sway.lerp(Vector2.ZERO, minf(1.0, delta * 8.0))
	sway = sway.clamp(Vector2(-0.07, -0.07), Vector2(0.07, 0.07))
	wall_push = lerpf(wall_push, wall_target, minf(1.0, delta * 14.0))
	sprint = move_toward(sprint, sprint_target, delta * 6.0)
	aim = move_toward(aim, aim_target, delta * 7.0)

	bob_phase += delta * (4.0 + 9.0 * move_amount)
	var bob := Vector3(
		sin(bob_phase) * 0.006 * (0.3 + move_amount),
		absf(cos(bob_phase)) * -0.008 * (0.3 + move_amount),
		0.0)

	# при прицеливании оружие выходит в центр, покачивание и запаздывание слабее
	var ads_pos := Vector3(0.0, -ads_height, home_pos.z + 0.06)
	var steady := 1.0 - 0.75 * aim
	var pos := home_pos.lerp(ads_pos, aim) + bob * steady
	var rot := Vector3(-sway.y, -sway.x, 0.0) * steady

	# отдача
	pos.z += recoil * recoil_back
	pos.y += recoil * recoil_up
	rot.x += recoil * recoil_pitch

	# упёрлись в стену: отодвигаем оружие назад и задираем ствол
	pos.z += wall_push
	pos.y -= wall_push * 0.3
	rot.x += wall_push * 1.0

	# бег: оружие уходит вниз и поворачивается стволом влево
	pos.x -= sprint * 0.04
	pos.y -= sprint * 0.07
	pos.z += sprint * 0.04
	rot.x -= sprint * 0.25
	rot.y += sprint * 0.75
	rot.z += sprint * 0.35

	# смена оружия: опускаем вниз
	pos.y -= draw * 0.22
	pos.z += draw * 0.05
	rot.x += draw * 0.7

	# перезарядка
	var slide_pull := 0.0
	if reload_time > 0.0:
		reload_time += delta
		var p := reload_time / reload_length
		if p >= 1.0:
			reload_time = 0.0
		elif reload_style == "shell":
			# по патрону: оружие наклонено, на каждый патрон небольшой «толчок»
			var env := minf(1.0, sin(clampf(p, 0.0, 1.0) * PI) * 3.0)
			pos.y -= env * 0.05
			pos.x -= env * 0.03
			rot.x += env * 0.45
			rot.z += env * 0.5
			pos.y += sin(p * reload_pulses * TAU) * 0.012 * env
		else:
			var dip := sin(clampf(p * 1.05, 0.0, 1.0) * PI)
			pos.y -= dip * 0.1
			pos.x -= dip * 0.04
			rot.x += dip * 0.55
			rot.z += dip * 0.75
			if p > 0.72 and p < 0.88:
				slide_pull = sin((p - 0.72) / 0.16 * PI)

	position = pos
	rotation = rot
	_animate_parts(delta, slide_pull)
