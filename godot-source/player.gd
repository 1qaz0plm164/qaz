extends CharacterBody3D
# Управляет игроком: ходьба, взгляд, оружие (пистолет, дробовик, винтовка),
# колесо выбора оружия (зажать E), фонарик (F), здоровье,
# аптечки (в колесе или клавиша 4) и сбор припасов из ящиков (зажать T),
# бег (Shift) с выносливостью, присед (нажать Ctrl), выглядывание (Z — влево, C — вправо),
# прицеливание (зажать ПКМ).

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENS = 0.002

signal died

const Sfx := preload("res://sfx.gd")
const Weapons := preload("res://weapons.gd")
const WeaponWheel := preload("res://weapon_wheel.gd")
const SND_EMPTY := preload("res://sounds/empty.wav")
const SND_FLASHLIGHT := preload("res://sounds/flashlight.wav")
const SND_HURT := preload("res://sounds/player_hurt.wav")
const SND_EQUIP := preload("res://sounds/equip.wav")
const SND_WHEEL_OPEN := preload("res://sounds/wheel_open.wav")
const SND_WHEEL_TICK := preload("res://sounds/wheel_tick.wav")
const SND_CRATE := preload("res://sounds/crate_open.wav")
const SND_PICKUP := preload("res://sounds/pickup.wav")
const SND_HEAL := preload("res://sounds/heal.wav")
const SND_BREATH := preload("res://sounds/breath_heavy.wav")
const Molotov := preload("res://molotov.gd")
const Settings := preload("res://settings.gd")
const RunStats := preload("res://run_stats.gd")
const Sound := preload("res://noise.gd")
const SND_CRAFT := preload("res://sounds/craft.wav")
const CraftMenu := preload("res://craft_menu.gd")
const HudView := preload("res://hud_view.gd")

# ---- стелс, ближний бой, крафт ----
const HEAL_TIME := 2.5           # лечение аптечкой, сек (в это время уязвимы)
const CRAFT_TIME := 1.5
# шум шагов (радиус, м): бег, ходьба, ходьба с прицелом, присед
const STEP_NOISE := {"sprint": 14.0, "walk": 7.0, "aim": 4.0, "crouch": 1.0}

# ---- бег, присед, выносливость ----
const SPRINT_SPEED := 8.0
const CROUCH_SPEED := 2.4
const STAND_HEIGHT := 2.0        # высота капсулы стоя (как в player.tscn)
const CROUCH_HEIGHT := 1.2       # высота капсулы в приседе
const STAMINA_MAX := 100.0
const STAMINA_DRAIN := 22.0      # расход в секунду при беге (~4,5 сек бега)
const STAMINA_REGEN := 18.0      # восстановление в секунду
const STAMINA_DELAY := 0.8       # пауза перед восстановлением после бега
const STAMINA_RECOVER := 35.0    # после полного изнеможения бежать можно с этого уровня
const AIM_SWAY := 0.03           # сила качания прицела при усталости (радианы)
const SPRINT_FOV_ADD := 7.0      # при беге поле зрения чуть шире
const AIM_FOV := 55.0            # поле зрения при прицеливании (обычное 75)
const AIM_SENS := 0.6            # чувствительность мыши при прицеливании
const AIM_SPREAD := 0.35         # разброс при прицеливании (доля от обычного)
const AIM_SPEED := 0.6           # скорость ходьбы при прицеливании (доля)
const LEAN_DIST := 0.45          # на сколько голова уходит вбок при выглядывании
const LEAN_ROLL := 0.2           # наклон камеры при выглядывании (радианы)

const MAX_HEALTH := 100
const MEDKIT_HEAL := 20          # сколько лечит одна аптечка
const MEDKIT_MAX := 3            # сколько аптечек можно носить
const LOOT_TIME := 1.0           # сколько держать T, чтобы забрать ящик
const LOOT_RANGE := 2.0          # с какого расстояния можно забрать

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health := 100
var is_dead := false
var flashlight: SpotLight3D

# ---- оружие ----
var weapons: Array = Weapons.LIST.duplicate(true)   # своя копия: верстак улучшает оружие
var views: Array[Node3D] = []        # модели оружия в руках (по одной на каждое)
var mags: Array[int] = []            # патроны в магазине каждого оружия
var reserve: Array[int] = []         # патроны в запасе (-1 — бесконечно)
var medkits := 0                     # аптечки в рюкзаке
var materials := {"rag": 0, "alcohol": 0, "blade": 0, "explosive": 0}
var busy := ""                       # "heal" / "craft" — руки заняты
var busy_t := 0.0
var busy_len := 1.0
var busy_mode := ""
var step_timer := 0.0
var craft_open := false
var busy_bar: ProgressBar
var craft_menu: Control
var loot_progress := 0.0             # 0..1 — сколько уже держим T

# ---- бег, присед, выносливость ----
var stamina := STAMINA_MAX
var stamina_delay := 0.0
var exhausted := false               # выдохся: бежать нельзя, прицел качает
var sprinting := false
var crouching := false
var aiming := false                  # зажата ПКМ
var lean_amount := 0.0               # -1 влево … 1 вправо (плавно)
var lean_world := Vector3.ZERO       # смещение головы в мире (для бандитов)
var crouch_amount := 0.0             # 0..1 плавно, для камеры
var sway_amount := 0.0
var sway_time := 0.0
var head_base_y := 0.0
var base_fov := 75.0
var body_shape: CapsuleShape3D
@onready var body_collision: CollisionShape3D = $CollisionShape3D
var idx := 0                         # какое оружие сейчас в руках
var fire_cooldown := 0.0
var shoot_buffer := 0.0              # запоминаем нажатие, если выстрел чуть раньше паузы
var reloading := false
var reload_token := 0                # меняется при отмене/смене — старые таймеры замолкают
var switching := false
var cam_kick := 0.0                  # отдача камеры
var hit_flash := 0.0                 # красный прицел при попадании
var head_flash := 0.0                # прицел-крестик при попадании в голову
var wheel: Control
var wheel_open := false
var medkit_slot := 0                 # номер аптечки в колесе (сразу после оружия)

# элементы HUD, которые создаются кодом
var medkit_label: Label
var loot_label: Label
var loot_bar: ProgressBar
var msg_label: Label
var msg_tween: Tween
var stamina_bar: ProgressBar
var stamina_fill: StyleBoxFlat
var crouch_label: Label
var scope_overlay: ColorRect          # чёрная маска оптического прицела
var hurt_overlay: ColorRect           # красная вспышка по краям экрана при ранении

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/RayCast3D
@onready var health_label: Label = $HUD/HealthLabel
@onready var ammo_label: Label = $HUD/AmmoLabel
@onready var crosshair: Label = $HUD/Crosshair

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ray.add_exception(self)   # луч не должен попадать в самого игрока
	_make_flashlight()
	# своя копия капсулы, чтобы менять её высоту в приседе
	body_shape = body_collision.shape.duplicate()
	body_shape.height = STAND_HEIGHT
	body_collision.shape = body_shape
	head_base_y = head.position.y
	base_fov = camera.fov

	# Все виды оружия лежат в руках, но показано только одно
	for i in weapons.size():
		var v: Node3D = weapons[i].view.new()
		camera.add_child(v)
		v.visible = i == 0
		views.append(v)
		mags.append(weapons[i].get("start", weapons[i].mag))
		reserve.append(weapons[i].reserve)
	medkit_slot = weapons.size()

	# Колесо выбора оружия
	wheel = WeaponWheel.new()
	$HUD.add_child(wheel)
	_refresh_wheel()

	_make_hud()
	health_label.text = "Здоровье: " + str(health)
	_update_hud()

# Надписи, которых нет в player.tscn: аптечки, подсказка сбора, сообщения
func _make_hud() -> void:
	scope_overlay = ColorRect.new()
	scope_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
// Маска оптического прицела: чёрное всё, кроме круга; тонкое перекрестие и затемнение к краю линзы
void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 d = (FRAGCOORD.xy - res * 0.5) / res.y;
	float r = length(d);
	float R = 0.46;
	float outside = smoothstep(R - 0.004, R, r);
	float vign = smoothstep(R * 0.55, R, r) * 0.55;
	float line_w = 1.2 / res.y;
	float thick = 4.0 / res.y;
	float cross = 0.0;
	if (abs(d.x) < line_w && r < R) cross = 1.0;
	if (abs(d.y) < line_w && r < R) cross = 1.0;
	if (abs(d.x) < thick && abs(d.y) > R * 0.55 && r < R) cross = 1.0;
	if (abs(d.y) < thick && abs(d.x) > R * 0.55 && r < R) cross = 1.0;
	float a = max(outside, max(vign, cross * 0.9));
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
"""
	var smat := ShaderMaterial.new()
	smat.shader = sh
	scope_overlay.material = smat
	scope_overlay.visible = false
	$HUD.add_child(scope_overlay)
	$HUD.move_child(scope_overlay, 0)

	medkit_label = Label.new()
	medkit_label.visible = false
	$HUD.add_child(medkit_label)
	# новый HUD рисует здоровье, патроны и прицел сам; старые надписи прячем
	health_label.visible = false
	ammo_label.visible = false
	crosshair.self_modulate.a = 0.0
	var hud := HudView.new()
	hud.player = self
	$HUD.add_child(hud)

	busy_bar = ProgressBar.new()
	busy_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	busy_bar.offset_left = -120.0
	busy_bar.offset_right = 120.0
	busy_bar.offset_top = 100.0
	busy_bar.offset_bottom = 114.0
	busy_bar.max_value = 1.0
	busy_bar.show_percentage = false
	busy_bar.visible = false
	$HUD.add_child(busy_bar)
	craft_menu = CraftMenu.new()
	$HUD.add_child(craft_menu)

	loot_label = _center_label(130.0, 26)
	loot_bar = ProgressBar.new()
	loot_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loot_bar.offset_left = -120.0
	loot_bar.offset_right = 120.0
	loot_bar.offset_top = 175.0
	loot_bar.offset_bottom = 189.0
	loot_bar.max_value = 1.0
	loot_bar.show_percentage = false
	loot_bar.visible = false
	$HUD.add_child(loot_bar)

	# Шкала выносливости внизу по центру (видна, только когда не полная)
	stamina_bar = ProgressBar.new()
	stamina_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	stamina_bar.offset_left = -130.0
	stamina_bar.offset_right = 130.0
	stamina_bar.offset_top = -34.0
	stamina_bar.offset_bottom = -28.0
	stamina_bar.max_value = STAMINA_MAX
	stamina_bar.value = STAMINA_MAX
	stamina_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(3)
	stamina_fill = StyleBoxFlat.new()
	stamina_fill.bg_color = Color(1.0, 0.8, 0.45)
	stamina_fill.set_corner_radius_all(3)
	stamina_bar.add_theme_stylebox_override("background", bg)
	stamina_bar.add_theme_stylebox_override("fill", stamina_fill)
	stamina_bar.modulate.a = 0.0
	$HUD.add_child(stamina_bar)

	crouch_label = Label.new()
	crouch_label.position = Vector2(1, 112)
	crouch_label.add_theme_font_size_override("font_size", 24)
	crouch_label.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	crouch_label.text = "Присед"
	crouch_label.visible = false
	crouch_label.self_modulate.a = 0.0
	$HUD.add_child(crouch_label)

	hurt_overlay = ColorRect.new()
	hurt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_overlay.color = Color(0.7, 0.0, 0.0, 0.0)
	$HUD.add_child(hurt_overlay)
	$HUD.move_child(hurt_overlay, 0)

	msg_label = _center_label(-170.0, 30)
	msg_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	msg_label.modulate.a = 0.0

func _center_label(y: float, size: int) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.offset_left = -400.0
	l.offset_right = 400.0
	l.offset_top = y
	l.offset_bottom = y + 40.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.visible = false
	$HUD.add_child(l)
	return l

# Короткое сообщение над прицелом («+1 аптечка», «Нет патронов»)
func show_message(text: String, color := Color(0.6, 1.0, 0.6)) -> void:
	msg_label.text = text
	msg_label.add_theme_color_override("font_color", color)
	msg_label.visible = true
	msg_label.modulate.a = 1.0
	if msg_tween:
		msg_tween.kill()
	msg_tween = create_tween()
	msg_tween.tween_interval(1.6)
	msg_tween.tween_property(msg_label, "modulate:a", 0.0, 0.5)

# ============================================================
#  Фонарик (F)
# ============================================================
func _make_flashlight() -> void:
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(1.0, 0.95, 0.82)
	flashlight.light_energy = 6.0
	flashlight.spot_range = 32.0
	flashlight.spot_angle = 32.0
	flashlight.spot_attenuation = 0.8
	# тени от фонарика: увеличенный сдвиг убирает «полосы» (shadow acne) на машинах и ящиках
	flashlight.shadow_enabled = Settings.shadows
	flashlight.shadow_bias = 0.15
	flashlight.shadow_normal_bias = 3.0
	flashlight.shadow_blur = 1.5
	flashlight.light_cull_mask = 0xFFFFF & ~(1 << 19)   # не светит на оружие в руках
	flashlight.position = Vector3(0.2, -0.15, -0.1)
	flashlight.visible = false   # в начале игры фонарик выключен (включается на F)
	camera.add_child(flashlight)

# ============================================================
#  Ввод
# ============================================================
func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return

	if event is InputEventKey and not event.echo:
		var key: int = event.physical_keycode
		# Присед: нажать Ctrl — сесть, ещё раз — встать
		if event.pressed and (key == KEY_CTRL):
			if crouching:
				if _can_stand():
					_set_crouch(false)
			else:
				_set_crouch(true)
		# Крафт: зажать Tab, цифрой выбрать рецепт
		elif key == KEY_TAB:
			craft_open = event.pressed and busy == ""
			_refresh_craft()
		elif craft_open and event.pressed and key >= KEY_1 and key < KEY_1 + Weapons.RECIPES.size():
			_craft(key - KEY_1)
		# Фонарик
		elif event.pressed and key == KEY_F:
			flashlight.visible = not flashlight.visible
			Sfx.play(self, SND_FLASHLIGHT, -6.0, 1.0, 0.05)
		# Колесо выбора: зажать E
		elif key == KEY_E:
			if event.pressed and busy == "":
				_open_wheel()
			elif wheel_open:
				_close_wheel(true)
		# Цифры 1, 2, 3 — оружие, 4 — аптечка
		elif event.pressed and key >= KEY_1 and key <= KEY_1 + medkit_slot and busy == "":
			if wheel_open:
				wheel.select_slot(key - KEY_1)
				_close_wheel(true)
			else:
				_select_slot(key - KEY_1)

	if event is InputEventMouseMotion:
		if wheel_open:
			# пока открыто колесо, мышь выбирает оружие, а не крутит камеру
			if wheel.move_cursor(event.relative):
				Sfx.play(self, SND_WHEEL_TICK, -6.0, 1.0, 0.0)
		else:
			views[idx].add_look(event.relative)
			var sens := MOUSE_SENS * Settings.sens * (float(weapons[idx].get("aim_sens", AIM_SENS)) if aiming else 1.0)
			rotate_y(-event.relative.x * sens)
			head.rotate_x(-event.relative.y * sens)
			head.rotation.x = clampf(head.rotation.x, -1.4, 1.4)

func _open_wheel() -> void:
	if wheel_open:
		return
	wheel_open = true
	_refresh_wheel()
	wheel.open(idx)
	Sfx.play(self, SND_WHEEL_OPEN, -6.0, 1.0, 0.0)

func _close_wheel(apply: bool) -> void:
	wheel_open = false
	var chosen: int = wheel.close()
	if apply:
		_select_slot(chosen)

# Слот колеса: оружие — взять в руки, аптечка — вылечиться
func _select_slot(i: int) -> void:
	if i == medkit_slot:
		use_medkit()
	else:
		equip(i)

func _refresh_wheel() -> void:
	var names: Array = []
	var ids: Array = []
	var ammo: Array = []
	for i in weapons.size():
		names.append(weapons[i].name)
		ids.append(weapons[i].id)
		if weapons[i].get("throwable", false):
			ammo.append("x%d" % mags[i])
		else:
			ammo.append("%d | %s" % [mags[i], _reserve_text(i)])
	names.append("Аптечка")
	ids.append("medkit")
	ammo.append("x%d" % medkits)
	wheel.set_data(names, ids, ammo)

func _reserve_text(i: int) -> String:
	return "∞" if reserve[i] < 0 else str(reserve[i])

# ============================================================
#  Каждый кадр физики
# ============================================================
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# прицеливание: зажать ПКМ
	aiming = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not wheel_open and not is_dead \
		and not weapons[idx].get("throwable", false) and busy == ""
	# бег из приседа — сначала встаём (если есть место)
	if crouching and Input.is_physical_key_pressed(KEY_SHIFT) and not aiming and _can_stand():
		_set_crouch(false)

	if Input.is_action_just_pressed("jump") and is_on_floor() and not crouching:
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# бег: зажать Shift. Пока стреляешь — не бежишь.
	sprinting = Input.is_physical_key_pressed(KEY_SHIFT) and input_dir.length() > 0.1 \
		and not crouching and not exhausted and not wheel_open and not Input.is_action_pressed("shoot") and not aiming \
		and busy == ""
	var speed := SPRINT_SPEED if sprinting else (CROUCH_SPEED if crouching else SPEED)
	if aiming:
		speed *= AIM_SPEED
	if busy == "heal" or busy == "craft":
		speed *= 0.5
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	_update_busy(delta)
	_step_noise(delta)
	_update_stamina(delta)
	_update_body_feel(delta)

	# оружие в руках: покачивание при ходьбе и отодвигание от стены
	var cur := views[idx]
	cur.set_motion(Vector2(velocity.x, velocity.z).length() if is_on_floor() else 0.0)
	cur.set_sprint(sprinting)
	cur.set_aim(aiming and not switching)
	# оптика: когда приложился к прицелу — модель оружия скрыта, на экране маска прицела
	if weapons[idx].get("scope", false):
		var scoped: bool = aiming and not switching and cur.aim > 0.9
		scope_overlay.visible = scoped
		cur.body.visible = not scoped
	else:
		scope_overlay.visible = false
	cur.set_wall_distance(ray.global_position.distance_to(ray.get_collision_point()) if ray.is_colliding() else 100.0)

	# отдача камеры и красный прицел при попадании
	cam_kick = lerpf(cam_kick, 0.0, minf(1.0, delta * 8.0))
	# качание прицела от усталости: двигаем саму камеру, поэтому пули летят туда же
	sway_time += delta
	var sway_target := 0.0
	if exhausted:
		sway_target = AIM_SWAY * clampf(1.0 - stamina / STAMINA_RECOVER, 0.35, 1.0)
	sway_amount = lerpf(sway_amount, sway_target, minf(1.0, delta * 3.0))
	camera.rotation.x = cam_kick + (sin(sway_time * 1.9) * 0.6 + sin(sway_time * 0.8) * 0.4) * sway_amount
	camera.rotation.y = sin(sway_time * 1.3 + 1.0) * sway_amount
	hit_flash = move_toward(hit_flash, 0.0, delta * 5.0)
	hurt_overlay.color.a = move_toward(hurt_overlay.color.a, 0.0, delta * 0.8)
	head_flash = move_toward(head_flash, 0.0, delta)
	crosshair.modulate = Color(1, 1, 1).lerp(Color(1, 0.15, 0.1), minf(1.0, hit_flash))
	crosshair.text = "X" if head_flash > 0.0 else "+"
	crosshair.visible = not (views[idx].has_optic and views[idx].aim > 0.6 and head_flash <= 0.0)

	_update_loot(delta)

	# стрельба
	fire_cooldown -= delta
	shoot_buffer -= delta
	var w: Dictionary = weapons[idx]
	if not wheel_open and not switching and busy == "" and not craft_open:
		if w.auto:
			if Input.is_action_pressed("shoot"):
				try_fire()
		else:
			if Input.is_action_just_pressed("shoot"):
				shoot_buffer = 0.15
			if shoot_buffer > 0.0 and try_fire():
				shoot_buffer = 0.0
		if Input.is_action_just_pressed("reload"):
			start_reload()

# ============================================================
#  Бег, присед, выносливость
# ============================================================
func _update_stamina(delta: float) -> void:
	if sprinting and Vector2(velocity.x, velocity.z).length() > 1.0:
		stamina -= STAMINA_DRAIN * delta
		stamina_delay = STAMINA_DELAY
		if stamina <= 0.0:
			stamina = 0.0
			exhausted = true
			sprinting = false
			Sfx.play(self, SND_BREATH, -4.0, 1.0, 0.03)
	else:
		stamina_delay -= delta
		if stamina_delay <= 0.0:
			stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)
	if exhausted and stamina >= STAMINA_RECOVER:
		exhausted = false

	# шкала: видна, пока выносливость не полная; красная, когда выдохся
	stamina_bar.value = stamina
	stamina_fill.bg_color = Color(0.9, 0.3, 0.25) if exhausted else Color(1.0, 0.8, 0.45)
	var target_alpha := 1.0 if stamina < STAMINA_MAX else 0.0
	stamina_bar.modulate.a = move_toward(stamina_bar.modulate.a, target_alpha, delta * (4.0 if target_alpha > 0.0 else 1.5))

# Камера опускается в приседе, при беге чуть шире поле зрения
func _update_body_feel(delta: float) -> void:
	crouch_amount = move_toward(crouch_amount, 1.0 if crouching else 0.0, delta * 6.0)
	head.position.y = head_base_y - (STAND_HEIGHT - CROUCH_HEIGHT) * crouch_amount
	var fov_target := base_fov + (SPRINT_FOV_ADD if sprinting else 0.0)
	if aiming:
		fov_target = weapons[idx].get("aim_fov", AIM_FOV)
	camera.fov = lerpf(camera.fov, fov_target, minf(1.0, delta * 10.0))
	_update_lean(delta)

# Выглядывание: зажать Z (влево) или C (вправо). Голова уходит вбок, камера наклоняется.
# Сквозь стену выглянуть нельзя: смещение ограничивается лучом вбок.
func _update_lean(delta: float) -> void:
	var want := 0.0
	if not sprinting and not wheel_open and not is_dead:
		if Input.is_physical_key_pressed(KEY_C):
			want += 1.0
		if Input.is_physical_key_pressed(KEY_Z):
			want -= 1.0
	lean_amount = move_toward(lean_amount, want, delta * 5.0)
	var side := global_transform.basis.x * signf(lean_amount)
	var allowed := LEAN_DIST
	if absf(lean_amount) > 0.01:
		var from := global_position + Vector3(0, head.position.y, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + side * (LEAN_DIST + 0.25), 1, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			allowed = maxf(0.0, from.distance_to(hit.position) - 0.25)
	var offset := clampf(absf(lean_amount) * LEAN_DIST, 0.0, allowed) * signf(lean_amount)
	head.position.x = offset
	head.position.y -= absf(offset) * 0.12
	camera.rotation.z = -lean_amount * LEAN_ROLL
	lean_world = global_transform.basis.x * offset

# Где голова игрока (для бандитов: по ней они целятся, когда игрок выглядывает)
func head_point() -> Vector3:
	return camera.global_position

func _set_crouch(on: bool) -> void:
	crouching = on
	body_shape.height = CROUCH_HEIGHT if on else STAND_HEIGHT
	# низ капсулы остаётся на месте, уменьшается сверху
	body_collision.position.y = -(STAND_HEIGHT - body_shape.height) * 0.5
	crouch_label.visible = on

# Есть ли место, чтобы встать (не упрёмся ли головой)
func _can_stand() -> bool:
	return not test_move(global_transform, Vector3(0, STAND_HEIGHT - CROUCH_HEIGHT, 0))

# ============================================================
#  Стрельба
# ============================================================
func try_fire() -> bool:
	if fire_cooldown > 0.0:
		return false
	var w: Dictionary = weapons[idx]
	if w.get("throwable", false):
		if switching or views[idx].throw_t > 0.0:
			return false
		if mags[idx] <= 0:
			Sfx.play(self, SND_EMPTY, -6.0)
			fire_cooldown = 0.35
			show_message("Нет коктейлей", Color(1.0, 0.5, 0.4))
			return false
		_throw()
		return true
	if reloading:
		# дробовик можно перебить выстрелом, остальные — нет
		if w.shell_reload and mags[idx] > 0:
			cancel_reload()
		else:
			return false
	if mags[idx] <= 0:
		Sfx.play(self, SND_EMPTY)
		fire_cooldown = 0.35
		if reserve[idx] == 0:
			show_message("Нет патронов", Color(1.0, 0.5, 0.4))
		else:
			start_reload()
		return false
	_fire()
	return true

func _fire() -> void:
	var w: Dictionary = weapons[idx]
	mags[idx] -= 1
	fire_cooldown = w.interval
	views[idx].fire()
	Sfx.play(self, w.snd_shot, w.volume)
	Sound.make(get_tree(), global_position, w.get("noise", 30.0))
	cam_kick += w.kick
	if w.snd_after != null:
		_play_after(w.after_delay, w.snd_after, idx)

	# Каждая пуля летит по своему лучу из центра экрана; у дробовика их 8 в конусе
	var origin := camera.global_position
	var b := camera.global_transform.basis
	var spread_tan := tan(deg_to_rad(w.spread * (float(w.get("aim_spread", AIM_SPREAD)) if aiming else 1.0)))
	var best_hit := 0
	for i in w.pellets:
		var dir := -b.z
		if w.spread > 0.0:
			var a := randf() * TAU
			var r := sqrt(randf()) * spread_tan
			dir = (dir + b.x * cos(a) * r + b.y * sin(a) * r).normalized()
		best_hit = maxi(best_hit, _shoot_ray(origin, dir, w))
	RunStats.shots += 1
	if best_hit >= 1:
		RunStats.hits += 1
	if best_hit >= 2:
		RunStats.headshots += 1
	_update_hud()

# Бросок коктейля Молотова: бутылка вылетает чуть правее камеры и летит по дуге
func _throw() -> void:
	var w: Dictionary = weapons[idx]
	mags[idx] -= 1
	RunStats.molotovs += 1
	fire_cooldown = w.interval
	views[idx].fire()
	Sfx.play(self, w.snd_shot, w.volume)
	var my := idx
	_update_hud()
	await get_tree().create_timer(0.24).timeout   # бутылка срывается с руки в момент броска
	if not is_inside_tree() or is_dead:
		return
	var b := camera.global_transform.basis
	var m := Molotov.new()
	m.kind = w.get("projectile", "molotov")
	m.exclude = [get_rid()]
	m.velocity = (-b.z * float(w.throw_speed) + b.y * 3.0) + Vector3(velocity.x, 0, velocity.z) * 0.5
	get_parent().add_child(m)
	m.global_position = camera.global_position - b.z * 0.4 + b.x * 0.12
	if idx == my:
		views[idx].set_has_bottle(mags[idx] > 0)

# Возвращает 0 — мимо, 1 — попал во врага, 2 — в голову
func _shoot_ray(origin: Vector3, dir: Vector3, w: Dictionary) -> int:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 120.0, 1, [get_rid()])
	var hit := space.intersect_ray(q)
	var max_t := 120.0 if hit.is_empty() else origin.distance_to(hit.position)

	# Попадание в голову: проверяем луч против сферы головы каждого врага.
	# Голова может торчать за пределы капсулы (щелкун) или прятаться внутри неё (бегун),
	# поэтому для того же врага, в чью капсулу попали, разрешаем чуть «прострелить» вглубь.
	var head_enemy: Object = null
	var head_t := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.has_method("head_sphere"):
			continue
		var hs: Array = e.head_sphere()
		var t := _ray_sphere(origin, dir, hs[0], hs[1])
		if t < 0.0:
			continue
		var limit := max_t
		if not hit.is_empty() and hit.collider == e:
			limit += 0.8
		if t < limit and t < head_t:
			head_t = t
			head_enemy = e

	var target: Object = null
	var pos := Vector3.ZERO
	var headshot := false
	if head_enemy:
		target = head_enemy
		pos = origin + dir * head_t
		headshot = true
	elif not hit.is_empty():
		target = hit.collider
		pos = hit.position
	if target and target.has_method("take_damage"):
		# урон падает с расстоянием (заметно у дробовика)
		var dist := origin.distance_to(pos)
		var f := lerpf(1.0, w.min_factor, clampf((dist - w.falloff_start) / maxf(w.falloff_end - w.falloff_start, 0.01), 0.0, 1.0))
		target.take_damage(maxi(1, roundi(w.damage * f)), dir * w.knockback, pos, headshot)
		hit_flash = 1.0
		if headshot:
			head_flash = 0.25
			return 2
		return 1
	return 0

# Расстояние вдоль луча до сферы (или -1, если луч мимо)
func _ray_sphere(origin: Vector3, dir: Vector3, center: Vector3, radius: float) -> float:
	var oc := origin - center
	var b := oc.dot(dir)
	var c := oc.dot(oc) - radius * radius
	var disc := b * b - c
	if disc < 0.0:
		return -1.0
	var s := sqrt(disc)
	var t := -b - s
	if t < 0.0:
		t = -b + s
	return t if t >= 0.0 else -1.0

# Звук, который идёт с задержкой после выстрела (передёргивание помпы)
func _play_after(delay: float, stream: AudioStream, weapon_index: int) -> void:
	await get_tree().create_timer(delay).timeout
	if is_inside_tree() and weapon_index == idx and not is_dead:
		Sfx.play(self, stream, -2.0, 1.0, 0.0)

# ============================================================
#  Перезарядка
# ============================================================
func start_reload() -> void:
	var w: Dictionary = weapons[idx]
	if w.get("throwable", false):
		return
	if reloading or switching or mags[idx] >= w.mag:
		return
	if reserve[idx] == 0:
		show_message("Нет патронов", Color(1.0, 0.5, 0.4))
		return
	reloading = true
	reload_token += 1
	var token := reload_token
	var my_weapon := idx
	ammo_label.text = "Перезарядка..."

	if w.shell_reload:
		# по одному патрону, пока магазин не заполнится
		var need: int = w.mag - mags[idx]
		if reserve[idx] >= 0:
			need = mini(need, reserve[idx])
		views[idx].play_reload(need * w.shell_time + 0.2, need)
		while mags[my_weapon] < w.mag and reserve[my_weapon] != 0:
			await get_tree().create_timer(w.shell_time).timeout
			if token != reload_token or not is_inside_tree():
				return
			mags[my_weapon] += 1
			if reserve[my_weapon] > 0:
				reserve[my_weapon] -= 1
			Sfx.play(self, w.snd_reload, -2.0, 1.0, 0.1)
		views[my_weapon].cancel_reload()
	else:
		Sfx.play(self, w.snd_reload, -2.0, 1.0, 0.0)
		views[idx].play_reload(w.reload_time)
		await get_tree().create_timer(w.reload_time).timeout
		if token != reload_token or not is_inside_tree():
			return
		var take: int = w.mag - mags[my_weapon]
		if reserve[my_weapon] >= 0:
			take = mini(take, reserve[my_weapon])
			reserve[my_weapon] -= take
		mags[my_weapon] += take

	reloading = false
	_update_hud()

func cancel_reload() -> void:
	reload_token += 1
	reloading = false
	views[idx].cancel_reload()
	_update_hud()

# ============================================================
#  Смена оружия
# ============================================================
func equip(i: int) -> void:
	if i == idx or i < 0 or i >= weapons.size() or switching:
		return
	switching = true
	cancel_reload()
	shoot_buffer = 0.0

	# опускаем старое...
	var old := views[idx]
	var tw := create_tween()
	tw.tween_property(old, "draw", 1.0, 0.13)
	await tw.finished
	old.visible = false

	# ...поднимаем новое
	idx = i
	var nv := views[i]
	nv.draw = 1.0
	nv.visible = true
	Sfx.play(self, SND_EQUIP, -4.0, 1.0, 0.05)
	fire_cooldown = maxf(fire_cooldown, 0.1)
	_update_hud()
	var tw2 := create_tween()
	tw2.tween_property(nv, "draw", 0.0, 0.2)
	await tw2.finished
	switching = false

func _update_hud() -> void:
	if reloading:
		ammo_label.text = "Перезарядка..."
	else:
		if weapons[idx].get("throwable", false):
			ammo_label.text = "%s: x%d" % [weapons[idx].name, mags[idx]]
		else:
			ammo_label.text = "%s: %d / %s" % [weapons[idx].name, mags[idx], _reserve_text(idx)]
	for i in weapons.size():
		if weapons[i].get("throwable", false) and views.size() > i and views[i].throw_t <= 0.0:
			views[i].set_has_bottle(mags[i] > 0)
	if medkit_label:
		medkit_label.text = "Аптечки: %d / %d" % [medkits, MEDKIT_MAX]
	_refresh_craft()
	if wheel:
		_refresh_wheel()

# ============================================================
#  Здоровье
# ============================================================
func take_damage(amount: int) -> void:
	if is_dead:
		return
	health = maxi(health - amount, 0)
	Sfx.play(self, SND_HURT)
	hurt_overlay.color.a = clampf(0.15 + amount * 0.012, 0.15, 0.45)
	health_label.text = "Здоровье: " + str(health)
	if health <= 0:
		die()

func heal(amount: int) -> void:
	health = mini(health + amount, MAX_HEALTH)
	health_label.text = "Здоровье: " + str(health)

func use_medkit() -> void:
	if is_dead:
		return
	if medkits <= 0:
		Sfx.play(self, SND_EMPTY, -6.0)
		show_message("Нет аптечек", Color(1.0, 0.5, 0.4))
		return
	if health >= MAX_HEALTH:
		show_message("Здоровье полное", Color(1, 1, 1))
		return
	if busy != "":
		return
	# лечение занимает время: оружие опущено, идти можно медленно, урон по-прежнему проходит
	_start_busy("heal", HEAL_TIME)
	Sfx.play(self, SND_HEAL, -2.0, 1.0, 0.03)

# ============================================================
#  Ящики с припасами (зажать T рядом с ящиком)
# ============================================================
func _nearest_crate() -> Variant:
	var best = null
	var best_d := LOOT_RANGE
	for c in get_tree().get_nodes_in_group("crate"):
		var d := Vector2(c.global_position.x - global_position.x, c.global_position.z - global_position.z).length()
		if d < best_d:
			best_d = d
			best = c
	return best

# Можно ли сейчас забрать ящик. Пустая строка — можно, иначе — причина
func _loot_block_reason(kind: String) -> String:
	if kind == "medkit":
		return "Аптечек максимум" if medkits >= MEDKIT_MAX else ""
	for i in weapons.size():
		if reserve[i] >= 0 and reserve[i] < weapons[i].reserve_max:
			return ""
		if weapons[i].get("throwable", false) and weapons[i].id == "molotov" and mags[i] < weapons[i].mag:
			return ""
	return "Патронов максимум"

func _update_loot(delta: float) -> void:
	var crate = _nearest_crate()
	if crate == null or wheel_open or is_dead:
		loot_progress = 0.0
		loot_label.visible = false
		loot_bar.visible = false
		return
	var what := "аптечку" if crate.kind == "medkit" else "патроны"
	var reason := _loot_block_reason(crate.kind)
	loot_label.visible = true
	if reason != "":
		loot_label.text = reason
		loot_bar.visible = false
		loot_progress = 0.0
		return
	loot_label.text = "Удерживайте [T] — взять " + what
	if Input.is_physical_key_pressed(KEY_T):
		loot_progress += delta / LOOT_TIME
		loot_bar.visible = true
		loot_bar.value = loot_progress
		if loot_progress >= 1.0:
			loot_progress = 0.0
			_loot(crate)
	else:
		loot_progress = 0.0
		loot_bar.visible = false

func _loot(crate) -> void:
	crate.open()
	Sfx.play_3d(self, SND_CRATE, crate.global_position)
	Sfx.play(self, SND_PICKUP, -3.0)
	if crate.kind == "medkit":
		var n := mini(1, MEDKIT_MAX - medkits)
		medkits += n
		var extra := ""
		for m in ["rag", "alcohol"]:
			if randf() < 0.5 and materials[m] < Weapons.MATERIAL_MAX:
				materials[m] += 1
				extra += ", %s +1" % Weapons.MATERIAL_NAMES[m]
		show_message("+%d аптечка%s" % [n, extra])
	else:
		var parts: Array[String] = []
		for i in weapons.size():
			var w: Dictionary = weapons[i]
			if w.get("throwable", false):
				if w.id == "molotov" and mags[i] < w.mag:     # в ящике с патронами всегда лежит один коктейль
					mags[i] += 1
					parts.append("%s +1" % w.name)
				continue
			if reserve[i] < 0:
				continue
			var range_: Array = w.crate_ammo
			var add: int = mini(randi_range(range_[0], range_[1]), w.reserve_max - reserve[i])
			if add > 0:
				reserve[i] += add
				parts.append("%s +%d" % [w.name, add])
		# ещё случайные материалы для крафта
		for k in randi_range(1, 2):
			var m: String = materials.keys().pick_random()
			if materials[m] < Weapons.MATERIAL_MAX:
				materials[m] += 1
				parts.append("%s +1" % Weapons.MATERIAL_NAMES[m])
		show_message("Ящик: " + ", ".join(parts))
	loot_bar.visible = false
	_update_hud()

# Трофеи с бандитов
func add_ammo(weapon_id: String, amount: int) -> int:
	for i in weapons.size():
		if weapons[i].id == weapon_id and reserve[i] >= 0:
			var add: int = mini(amount, weapons[i].reserve_max - reserve[i])
			if add > 0:
				reserve[i] += add
				Sfx.play(self, SND_PICKUP, -4.0)
				show_message("%s +%d" % [weapons[i].name, add])
				_update_hud()
			return add
	return 0

func add_molotov() -> bool:
	for i in weapons.size():
		if weapons[i].id == "molotov":
			if mags[i] >= weapons[i].mag:
				return false
			mags[i] += 1
			Sfx.play(self, SND_PICKUP, -4.0)
			show_message("+1 коктейль Молотова")
			_update_hud()
			return true
	return false

func add_medkit() -> bool:
	if medkits >= MEDKIT_MAX:
		return false
	medkits += 1
	Sfx.play(self, SND_PICKUP, -4.0)
	show_message("+1 аптечка")
	_update_hud()
	return true

# ============================================================
#  Материалы, детали, доска
# ============================================================
func add_material(id: String, n := 1) -> bool:
	if not materials.has(id) or materials[id] >= Weapons.MATERIAL_MAX:
		return false
	materials[id] = mini(materials[id] + n, Weapons.MATERIAL_MAX)
	Sfx.play(self, SND_PICKUP, -6.0)
	show_message("+%d %s" % [n, Weapons.MATERIAL_NAMES[id].to_lower()], Color(0.9, 0.85, 0.6))
	_update_hud()
	return true

# ============================================================
#  Занятые руки: лечение, крафт
# ============================================================
func _start_busy(kind: String, seconds: float, mode := "") -> void:
	busy = kind
	busy_t = 0.0
	busy_len = seconds
	busy_mode = mode
	craft_open = false
	_refresh_craft()
	if reloading:
		cancel_reload()
	var tw := create_tween()
	tw.tween_property(views[idx], "draw", 1.0, 0.15)
	busy_bar.visible = true

func _end_busy() -> void:
	busy = ""
	busy_bar.visible = false
	camera.rotation.z = 0.0
	var tw := create_tween()
	tw.tween_property(views[idx], "draw", 0.0, 0.2)
	fire_cooldown = maxf(fire_cooldown, 0.25)

func _update_busy(delta: float) -> void:
	if busy == "":
		return
	busy_t += delta
	busy_bar.value = busy_t / busy_len
	if busy_t < busy_len:
		return
	if busy == "heal":
		medkits -= 1
		RunStats.medkits += 1
		heal(MEDKIT_HEAL)
		show_message("+%d здоровья" % MEDKIT_HEAL)
	elif busy == "craft":
		_finish_craft(int(busy_mode))
	_end_busy()
	_update_hud()

# ============================================================
#  Стелс: шаги шумят — враги идут на звук
# ============================================================
func _step_noise(delta: float) -> void:
	var sp := Vector2(velocity.x, velocity.z).length()
	if sp < 0.5 or not is_on_floor():
		step_timer = minf(step_timer, 0.1)
		return
	step_timer -= delta
	if step_timer > 0.0:
		return
	var kind := "walk"
	if sprinting:
		kind = "sprint"
	elif crouching:
		kind = "crouch"
	elif aiming:
		kind = "aim"
	step_timer = 0.28 if sprinting else 0.4
	Sound.make(get_tree(), global_position, STEP_NOISE[kind])

# ============================================================
#  Крафт: зажать Tab, нажать цифру рецепта
# ============================================================
func _craft_target_full(r: Dictionary) -> bool:
	match r.makes:
		"medkit": return medkits >= MEDKIT_MAX
		_:
			for i in weapons.size():
				if weapons[i].id == r.makes:
					return mags[i] >= weapons[i].mag
	return true

func _can_craft(r: Dictionary) -> bool:
	for m in r.needs:
		if materials[m] <= 0:
			return false
	return true

func _craft(i: int) -> void:
	if busy != "":
		return
	var r: Dictionary = Weapons.RECIPES[i]
	if not _can_craft(r):
		Sfx.play(self, SND_EMPTY, -6.0)
		show_message("Не хватает материалов", Color(1.0, 0.5, 0.4))
		return
	if _craft_target_full(r):
		show_message("%s: больше не унести" % r.name, Color(1, 1, 1))
		return
	Sfx.play(self, SND_CRAFT, -2.0)
	_start_busy("craft", CRAFT_TIME, str(i))

func _finish_craft(i: int) -> void:
	var r: Dictionary = Weapons.RECIPES[i]
	if not _can_craft(r) or _craft_target_full(r):
		return
	for m in r.needs:
		materials[m] -= 1
	match r.makes:
		"medkit": medkits += 1
		_:
			for k in weapons.size():
				if weapons[k].id == r.makes:
					mags[k] += 1
	show_message("Собрано: " + r.name, Color(0.9, 0.85, 0.6))
	_update_hud()

func _refresh_craft() -> void:
	if not craft_menu:
		return
	if craft_open:
		craft_menu.open(self)
	else:
		craft_menu.close()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	if wheel_open:
		_close_wheel(false)
	died.emit()   # Main покажет экран смерти
