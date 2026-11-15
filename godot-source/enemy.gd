extends CharacterBody3D
const CharacterSurface := preload("res://character_surface.gd")
var gait_weight := 0.0
# Заражённый. Один скрипт на все виды — тип задаётся полем kind ДО add_child:
#   "clicker" — щелкун: слепой, сгорбленный, щёлкает, сильно кусает
#   "runner"  — бегун: быстрый и хлипкий, бегает почти как игрок, бьёт часто, но слабо
#   "bloater" — топляк: огромный, бронированный, медленный; бросает споровые бомбы
#               и бьёт насмерть вблизи; при смерти лопается облаком спор
# Все цифры каждого вида — в таблице TYPES ниже.

signal died

const Sfx := preload("res://sfx.gd")
const SporeBomb := preload("res://spore_bomb.gd")
const SporeCloud := preload("res://spore_cloud.gd")
const SND_HIT := preload("res://sounds/hit.wav")
const SND_HEADSHOT := preload("res://sounds/headshot.wav")
const BloodFx := preload("res://blood_fx.gd")
const SND_THROW := preload("res://sounds/clicker_click.wav")

const TYPES := {
	"clicker": {
		"model": preload("res://clicker_model.gd"),
		"health": 100, "speed": 3.4, "speed_var": Vector2(0.85, 1.25),
		"damage": 10, "cooldown": 1.0, "attack_range": 1.9, "stop_distance": 1.2,
		"radius": 0.4, "height": 1.9,
		"armor": 1.0,            # множитель входящего урона (меньше — крепче)
		"knockback": 1.0,        # насколько поддаётся отбрасыванию
		# голова: центр сферы попадания относительно узла головы, радиус, множитель урона
		"head_pos": Vector3(0, 0, -0.06), "head_r": 0.22, "head_mult": 4.0,
		"clicks": true,          # щёлкает (звук щелчков)
		# звуки: idle — пока идёт (щелчки/рычание), voice — атака/крик, die — смерть
		"snd_idle": preload("res://sounds/clicker_click.wav"), "idle_db": 3.0,
		"snd_voice": preload("res://sounds/clicker_screech.wav"), "voice_db": 2.0,
		"snd_die": preload("res://sounds/enemy_die.wav"),
		"gait": 2.6,             # частота шагов
		"thrower": false,
		"vision": 0.0,           # слепой: находит только на слух
		"hearing": 1.4,          # множитель слуха
	},
	"runner": {
		"model": preload("res://runner_model.gd"),
		"health": 55, "speed": 4.7, "speed_var": Vector2(0.9, 1.1),
		"damage": 6, "cooldown": 0.65, "attack_range": 1.7, "stop_distance": 1.1,
		"radius": 0.35, "height": 1.8,
		"armor": 1.0, "knockback": 1.4,
		"head_pos": Vector3(0, 0.03, 0), "head_r": 0.15, "head_mult": 3.0,
		"clicks": false,
		"snd_idle": preload("res://sounds/runner_growl.wav"), "idle_db": -2.0,
		"snd_voice": preload("res://sounds/runner_scream.wav"), "voice_db": 2.0,
		"snd_die": preload("res://sounds/runner_die.wav"),
		"gait": 2.2,
		"thrower": false,
		"vision": 20.0, "hearing": 1.0,   # видит до 20 м (в приседе — вдвое ближе)
	},
	"bloater": {
		"model": preload("res://bloater_model.gd"),
		"health": 700, "speed": 1.8, "speed_var": Vector2(0.95, 1.05),
		"damage": 35, "cooldown": 1.8, "attack_range": 2.4, "stop_distance": 1.6,
		"radius": 0.6, "height": 2.3,
		"armor": 0.6, "knockback": 0.12,
		"head_pos": Vector3(0, 0.02, -0.05), "head_r": 0.3, "head_mult": 1.5,   # голова в броне
		"clicks": true,
		"snd_idle": preload("res://sounds/bloater_growl.wav"), "idle_db": 5.0,
		"snd_voice": preload("res://sounds/bloater_roar.wav"), "voice_db": 7.0,
		"snd_die": preload("res://sounds/bloater_roar.wav"),
		"gait": 2.4,
		"thrower": true,
		"vision": 12.0, "hearing": 1.0,
	},
	# ---------- БОССЫ ----------
	"giant_bloater": {
		"model": preload("res://bloater_model.gd"), "scale": 1.45, "boss": true, "name": "Огромный топляк",
		"health": 2400, "speed": 2.0, "speed_var": Vector2(1.0, 1.0),
		"damage": 50, "cooldown": 1.6, "attack_range": 3.2, "stop_distance": 2.2,
		"radius": 0.85, "height": 3.3,
		"armor": 0.5, "knockback": 0.0,
		"head_pos": Vector3(0, 0.02, -0.05), "head_r": 0.3, "head_mult": 1.6,
		"clicks": true,
		"snd_idle": preload("res://sounds/bloater_growl.wav"), "idle_db": 8.0,
		"snd_voice": preload("res://sounds/boss_roar.wav"), "voice_db": 8.0,
		"snd_die": preload("res://sounds/boss_roar.wav"),
		"gait": 2.0, "thrower": true, "throws": 2, "throw_cd": Vector2(3.5, 5.0),
		"vision": 30.0, "hearing": 2.0,
	},
	"rat_king": {
		"model": preload("res://bloater_model.gd"), "scale": 1.85, "boss": true, "name": "Крысиный король",
		"health": 4200, "speed": 2.3, "speed_var": Vector2(1.0, 1.0),
		"damage": 60, "cooldown": 1.5, "attack_range": 3.8, "stop_distance": 2.6,
		"radius": 1.05, "height": 4.2,
		"armor": 0.45, "knockback": 0.0,
		"head_pos": Vector3(0, 0.02, -0.05), "head_r": 0.3, "head_mult": 1.5,
		"clicks": true,
		"snd_idle": preload("res://sounds/clicker_screech.wav"), "idle_db": 8.0,
		"snd_voice": preload("res://sounds/boss_roar.wav"), "voice_db": 10.0,
		"snd_die": preload("res://sounds/boss_roar.wav"),
		"gait": 1.8, "thrower": true, "throws": 1, "throw_cd": Vector2(4.0, 6.0),
		"summon": "runner", "summon_cd": 14.0, "charge": true,
		"vision": 30.0, "hearing": 2.0,
	},
}

# ---- Восприятие (как в TLOU) ----
const WANDER_SPEED := 0.4       # бродит медленно (доля от скорости)
const SEARCH_SPEED := 0.75
const HUNT_AFTER := 40.0        # столько бродит, не заметив игрока, потом идёт искать
const LOSE_TIME := 7.0          # столько без звуков/вида игрока — и теряет его
const VIEW_ANGLE := 65.0        # полуугол обзора, градусы
const ALERT_RADIUS := 10.0      # крик заметившего поднимает соседей
const ClickerModel := preload("res://clicker_model.gd")
const Sound := preload("res://noise.gd")
const Pickup := preload("res://ammo_pickup.gd")
const PARTS := {"clicker": 3, "runner": 2, "bloater": 12, "giant_bloater": 40, "rat_king": 80}
const MATERIALS := ["rag", "alcohol", "blade", "explosive"]

# Броски топляка
const THROW_MIN := 6.0          # ближе — не бросает, идёт бить
const THROW_MAX := 24.0
const THROW_WINDUP := 0.6       # замах перед броском, стоит на месте

const DIRECT_DISTANCE := 3.0    # ближе этого идёт напрямую, без навигации

var kind := "clicker"
var cfg: Dictionary

var health := 100
var speed := 3.4
var feet := 0.95                # от центра капсулы до пола
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var attack_timer := 0.0
var is_dead := false

var click_timer := 0.0
var repath_timer := 0.0
var walk_phase := 0.0
var anim_time := 0.0
var head_snap := 0.0
var stagger_timer := 0.0
var throw_timer := 0.0          # пауза между бросками
var windup := 0.0               # > 0 — идёт замах

# ---- восприятие ----
var aware := "wander"            # wander — не знает о вас, search — ищет, chase — заметил
var search_pos := Vector3.ZERO
var search_timer := 0.0
var wander_target := Vector3.ZERO
var wander_timer := 0.0
var unaware_time := 0.0
var suspicion := 0.0             # 0..1 — бегун «присматривается»
var last_seen := 0.0             # сек назад видел игрока
var last_heard := 0.0            # сек назад слышал игрока
var perceive_timer := 0.0
var indicator: Label3D
var stun_timer := 0.0            # оглушён (кулаки, доска, дымовая шашка)
var grabbed := false             # его душит игрок
var is_boss := false
var size_k := 1.0
var summon_timer := 0.0
var charge_time := 0.0
var charge_cd := 6.0
var charge_dir := Vector3.ZERO
var throws_left := 0

var parts := {}
var base := {}                  # исходная поза частей модели (для анимации)
var model: Node3D
var nav: NavigationAgent3D
var click_player: AudioStreamPlayer3D
var voice_player: AudioStreamPlayer3D

@onready var player: Node3D = get_tree().get_first_node_in_group("player")

func _ready() -> void:
	add_to_group("enemy")
	if not TYPES.has(kind):
		kind = "clicker"
	cfg = TYPES[kind]
	is_boss = cfg.get("boss", false)
	size_k = cfg.get("scale", 1.0)
	summon_timer = cfg.get("summon_cd", 0.0) * 0.6
	health = cfg.health
	speed = cfg.speed * randf_range(cfg.speed_var.x, cfg.speed_var.y)
	anim_time = randf() * 10.0
	click_timer = randf_range(0.2, 1.2)
	throw_timer = randf_range(2.0, 4.0)

	# Своя капсула (общий ресурс из сцены не трогаем — он один на всех врагов)
	var shape := CapsuleShape3D.new()
	shape.radius = cfg.radius
	shape.height = cfg.height
	$CollisionShape3D.shape = shape
	feet = cfg.height * 0.5
	position.y += feet - 0.95   # точка появления рассчитана на щелкуна

	model = Node3D.new()
	model.position.y = -feet
	model.scale = Vector3.ONE * size_k
	add_child(model)
	parts = cfg.model.build(model, randi())
	if kind == "rat_king":
		_fuse_clickers()
	base = {
		"lean": parts.torso.rotation.x,
		"torso_y": parts.torso.position.y,
		"arm": parts.arms[0].rotation.x,
		"head_x": parts.head.rotation.x,
	}

	nav = NavigationAgent3D.new()
	nav.path_desired_distance = 0.6
	nav.target_desired_distance = 1.0
	nav.radius = cfg.radius
	nav.path_height_offset = -feet
	add_child(nav)

	click_player = _make_player(cfg.snd_idle, cfg.idle_db)
	voice_player = _make_player(cfg.snd_voice, cfg.voice_db)

	indicator = Label3D.new()
	indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	indicator.no_depth_test = true
	indicator.font_size = 72
	indicator.pixel_size = 0.004
	indicator.outline_size = 14
	indicator.position.y = feet + 0.45
	indicator.visible = false
	add_child(indicator)

	if is_boss:
		aware = "chase"
	else:
		wander_target = _roam_point()

# Крысиный король: на теле топляка — сросшиеся щелкуны
func _fuse_clickers() -> void:
	for side in [-1.0, 1.0]:
		var n := Node3D.new()
		n.position = Vector3(side * 0.55, 0.55, 0.15)
		n.rotation = Vector3(0.4, side * 0.9, side * 0.5)
		n.scale = Vector3.ONE * 0.7
		parts.torso.add_child(n)
		ClickerModel.build(n, randi())
	var back := Node3D.new()
	back.position = Vector3(0, 0.9, 0.35)
	back.rotation = Vector3(-0.9, PI, 0)
	back.scale = Vector3.ONE * 0.65
	parts.torso.add_child(back)
	ClickerModel.build(back, randi())

func is_aware() -> bool:
	return aware == "chase"

# ============================================================
#  Восприятие: слух и зрение
# ============================================================
# Шум (Sound.make): pos — где шумнуло, radius — насколько слышно, by_player — шумит игрок
func hear(pos: Vector3, radius: float, by_player := true) -> void:
	if is_dead or grabbed:
		return
	var d := global_position.distance_to(pos)
	var r: float = radius * cfg.get("hearing", 1.0)
	if d > r:
		return
	if by_player:
		last_heard = 0.0
	if aware == "chase":
		return
	var to_p := player.global_position.distance_to(global_position) if player else 99.0
	if by_player and (d < r * 0.45 or to_p < 5.0):
		_set_chase()
	else:
		_go_search(pos)

func _go_search(pos: Vector3) -> void:
	if aware == "chase":
		return
	aware = "search"
	search_pos = pos + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	search_timer = 3.0
	repath_timer = 0.0
	_show_indicator("?", Color(1.0, 0.85, 0.3))

func _set_chase() -> void:
	if aware == "chase" or is_dead:
		return
	aware = "chase"
	last_seen = 0.0
	last_heard = 0.0
	suspicion = 0.0
	repath_timer = 0.0
	_voice()
	_show_indicator("!", Color(1.0, 0.25, 0.2), 1.5)
	# крик поднимает соседей: они идут на звук
	for e in get_tree().get_nodes_in_group("enemy"):
		if e != self and e.has_method("hear") and e.global_position.distance_to(global_position) < ALERT_RADIUS:
			e.hear(player.global_position, ALERT_RADIUS, false)

func _show_indicator(text: String, color: Color, hide_after := 0.0) -> void:
	indicator.text = text
	indicator.modulate = color
	indicator.visible = true
	if hide_after > 0.0:
		var t := text
		get_tree().create_timer(hide_after).timeout.connect(func() -> void:
			if is_instance_valid(indicator) and indicator.text == t:
				indicator.visible = false)

func _can_see_player() -> bool:
	var vis: float = cfg.get("vision", 0.0)
	if vis <= 0.0 or player == null:
		return false
	if Sound.in_smoke(get_tree(), player.global_position):
		return false
	var range_m := vis
	if player.get("crouching"):
		range_m *= 0.55
	var fl = player.get("flashlight")
	if fl and fl.visible:
		range_m += 6.0
	var eye := global_position + Vector3(0, feet * 0.8, 0)
	var target: Vector3 = player.head_point() if player.has_method("head_point") else player.global_position
	var to := target - eye
	if to.length() > range_m:
		return false
	if aware != "chase":
		var fwd := -global_transform.basis.z
		if rad_to_deg(fwd.angle_to(Vector3(to.x, 0, to.z))) > VIEW_ANGLE:
			return false
	var q := PhysicsRayQueryParameters3D.create(eye, target, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.collider == player

func _perceive(delta: float) -> void:
	last_seen += delta
	last_heard += delta
	perceive_timer -= delta
	if perceive_timer > 0.0:
		return
	perceive_timer = 0.2
	var d := global_position.distance_to(player.global_position)
	if d < 1.8 and aware != "chase":          # наткнулся вплотную
		_set_chase()
		return
	var sees := _can_see_player()
	if sees:
		last_seen = 0.0
	if aware != "chase":
		if sees:
			var range_m: float = cfg.get("vision", 20.0)
			suspicion += 0.2 * clampf(1.6 - d / range_m, 0.35, 1.6) * 2.2
			if suspicion >= 1.0:
				_set_chase()
			elif suspicion > 0.3 and aware == "wander":
				_go_search(player.global_position)
		else:
			suspicion = maxf(0.0, suspicion - 0.05)
	elif not is_boss and last_seen > LOSE_TIME and last_heard > LOSE_TIME and d > 5.0:
		# потерял игрока: идёт туда, где его последний раз слышал/видел
		aware = "chase_lost"
		_go_search_force(player.global_position + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)))

func _go_search_force(pos: Vector3) -> void:
	aware = "wander"
	_go_search(pos)

# Случайная точка для блуждания: недалеко от игрока, чтобы встречи всё-таки случались
func _roam_point() -> Vector3:
	var c: Vector3 = player.global_position if player else Vector3.ZERO
	var a := randf() * TAU
	var r := randf_range(8.0, 18.0)
	var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
	p.x = clampf(p.x, -36.0, 36.0)
	p.z = clampf(p.z, -36.0, 36.0)
	var map := get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(map, p)

# Оглушить (кулаки, доска, дымовая шашка). Топляки и боссы не оглушаются.
func stun(t: float) -> void:
	if is_dead or cfg.thrower or is_boss:
		return
	stun_timer = maxf(stun_timer, t)
	_show_indicator("✱", Color(0.8, 0.8, 1.0), t)

func can_be_stunned() -> bool:
	return not (cfg.thrower or is_boss)

# Тихое убийство: игрок схватил
func start_grab() -> void:
	grabbed = true
	collision_mask = 0
	velocity = Vector3.ZERO
	indicator.visible = false
	click_player.stop()

func finish_grab() -> void:
	if is_dead:
		return
	health = 0
	die(true)

func _make_player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.unit_size = 10.0
	p.max_distance = 60.0
	add_child(p)
	return p

# Сфера головы в мире — по ней игрок проверяет попадание в голову
func head_sphere() -> Array:
	var head: Node3D = parts.head
	return [head.to_global(cfg.head_pos), cfg.head_r * size_k]

func take_damage(amount: int, knockback := Vector3.ZERO, hit_pos := Vector3.INF, headshot := false) -> void:
	if is_dead:
		return
	var mult: float = cfg.armor * (cfg.head_mult if headshot else 1.0)
	health -= maxi(1, roundi(amount * mult))
	if hit_pos.is_finite():
		BloodFx.spawn(get_parent(), hit_pos, knockback, headshot or health <= 0, self)
	if headshot:
		Sfx.play_3d(self, SND_HEADSHOT, hit_pos if hit_pos.is_finite() else global_position, 2.0)
		stagger_timer = maxf(stagger_timer, 0.25 if not cfg.thrower else 0.0)
	var push: Vector3 = Vector3(knockback.x, 0.0, knockback.z) * float(cfg.knockback)
	if push != Vector3.ZERO and health > 0:
		velocity += push
		var flat := Vector2(velocity.x, velocity.z).limit_length(7.0)
		velocity.x = flat.x
		velocity.z = flat.y
		stagger_timer = clampf(stagger_timer + push.length() * 0.12, 0.0, 0.35)
	if health <= 0:
		die()
	else:
		Sfx.play_3d(self, SND_HIT, global_position + Vector3(0, 0.5, 0), 0.0, 0.75 if cfg.thrower else 1.0)
		# ранили — сразу знает, где игрок
		if aware != "chase" and stun_timer <= 0.0:
			_set_chase()
		head_snap = 3.0 if headshot else 1.5
		# бегун, по которому попали, на миг срывается на визг
		if kind == "runner" and not voice_player.playing and randf() < 0.3:
			_voice()

func die(quiet := false) -> void:
	is_dead = true
	grabbed = false
	indicator.visible = false
	if not quiet:
		Sfx.play_3d(self, cfg.snd_die, global_position, 3.0 if cfg.thrower else 0.0, 0.8 if cfg.thrower else 1.0)
	if randf() < (0.15 if not is_boss else 1.0):
		var pk := Pickup.new()
		pk.what = MATERIALS.pick_random()
		pk.amount = 1
		pk.position = global_position - Vector3(0, feet - 0.15, 0)
		get_parent().add_child(pk)
	died.emit()
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 0
	click_player.stop()
	voice_player.stop()
	if cfg.thrower:
		# топляк лопается — вокруг тела остаётся облако спор
		_spawn_cloud(global_position - Vector3(0, feet, 0), 3.2, 6.0)
	var tw := create_tween()
	tw.tween_property(model, "rotation:x", 1.45, 0.55 if not cfg.thrower else 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(4.0)
	tw.tween_property(model, "position:y", -feet - 2.0, 1.5)
	tw.tween_callback(queue_free)

func _voice() -> void:
	voice_player.pitch_scale = randf_range(0.92, 1.08)
	voice_player.play()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if grabbed:                         # игрок держит — дёргается, но не вырывается
		velocity = Vector3.ZERO
		anim_time += delta
		parts.torso.rotation.z = sin(anim_time * 22.0) * 0.12
		parts.arms[0].rotation.x = base.arm - 1.2 + sin(anim_time * 17.0) * 0.4
		parts.arms[1].rotation.x = base.arm - 1.0 + sin(anim_time * 19.0) * 0.4
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if stun_timer > 0.0:                # оглушён: шатается, не атакует
		stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		anim_time += delta
		parts.torso.rotation.x = base.lean + 0.35 + sin(anim_time * 3.0) * 0.1
		parts.torso.rotation.z = sin(anim_time * 2.3) * 0.15
		if stun_timer <= 0.0:
			indicator.visible = false
			_set_chase()
		return

	var moving := false
	if stagger_timer > 0.0:
		stagger_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
		move_and_slide()
		_animate(delta, false)
		return

	if player:
		_perceive(delta)
		if aware == "chase":
			moving = _chase(delta)
		else:
			moving = _roam(delta)

	move_and_slide()

	# Щёлканье (щелкун, топляк) или рычание (бегун)
	click_timer -= delta
	if click_timer <= 0.0:
		click_player.pitch_scale = randf_range(0.9, 1.1)
		if kind == "clicker":
			click_timer = randf_range(1.2, 2.0) if moving else randf_range(1.8, 3.0)
		else:
			click_timer = randf_range(2.2, 4.0)
		click_player.play()
		head_snap = maxf(head_snap, 0.8)

	_animate(delta, moving)

# Не знает о вас: бродит или идёт проверить шум
func _roam(delta: float) -> bool:
	var target := wander_target
	var spd := speed * WANDER_SPEED
	if aware == "search":
		target = search_pos
		spd = speed * SEARCH_SPEED
	else:
		unaware_time += delta
		if unaware_time > HUNT_AFTER:       # долго никого — идёт искать туда, где игрок
			unaware_time = 0.0
			_go_search(player.global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
			return false
	var flat := target - global_position
	flat.y = 0.0
	if flat.length() < 1.2:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
		if aware == "search":
			search_timer -= delta
			rotation.y += sin(anim_time * 1.3) * delta * 1.5    # оглядывается
			if search_timer <= 0.0:
				aware = "wander"
				indicator.visible = false
				wander_target = _roam_point()
		else:
			wander_timer -= delta
			if wander_timer <= 0.0:
				wander_target = _roam_point()
				wander_timer = randf_range(1.0, 3.0)
		return false
	var dir := _nav_dir(target, flat, delta)
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	_face(dir, delta)
	return true

# Заметил: прежнее поведение — бежит, бьёт, бросает споры
func _chase(delta: float) -> bool:
	var moving := false
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	# ---- боссы: призыв и рывок ----
	if cfg.has("summon"):
		summon_timer -= delta
		if summon_timer <= 0.0:
			summon_timer = cfg.summon_cd
			_summon()
	if cfg.get("charge", false):
		charge_cd -= delta
		if charge_time > 0.0:
			charge_time -= delta
			velocity.x = charge_dir.x * speed * 3.2
			velocity.z = charge_dir.z * speed * 3.2
			_face(charge_dir, delta)
			if dist < cfg.attack_range and attack_timer <= 0.0:
				player.take_damage(40)
				attack_timer = cfg.cooldown
				charge_time = 0.0
			attack_timer -= delta
			return true
		if charge_cd <= 0.0 and dist > 9.0 and dist < 26.0:
			charge_cd = randf_range(9.0, 13.0)
			charge_time = 1.4
			charge_dir = to_player.normalized()
			_voice()
			return true

	# ---- бросок спор (топляки) ----
	if cfg.thrower:
		throw_timer -= delta
		if windup > 0.0:
			windup -= delta
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			_face(to_player, delta)
			if windup <= 0.0:
				_throw()
				throws_left -= 1
				if throws_left > 0:
					windup = THROW_WINDUP * 0.6
			_animate(delta, false)
			return false
		if throw_timer <= 0.0 and dist > THROW_MIN and dist < THROW_MAX:
			windup = THROW_WINDUP
			throws_left = cfg.get("throws", 1)
			_voice()
			var cd: Vector2 = cfg.get("throw_cd", Vector2(5.0, 8.0))
			throw_timer = randf_range(cd.x, cd.y)

	var dir := Vector3.ZERO
	if dist > cfg.stop_distance:
		dir = _move_direction(to_player, dist, delta)
	if dir != Vector3.ZERO:
		moving = true
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_face(dir, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
		if dist > 0.01:
			_face(to_player, delta)

	# ---- атака вблизи ----
	attack_timer -= delta
	if attack_timer <= 0.0 and dist < cfg.attack_range and player.has_method("take_damage"):
		player.take_damage(cfg.damage)
		_voice()
		head_snap = 2.0
		attack_timer = cfg.cooldown
	return moving

func _nav_dir(target: Vector3, flat: Vector3, delta: float) -> Vector3:
	if flat.length() < DIRECT_DISTANCE:
		return flat.normalized()
	repath_timer -= delta
	if repath_timer <= 0.0:
		nav.target_position = target
		repath_timer = randf_range(0.4, 0.7)
	if nav.is_navigation_finished():
		return flat.normalized()
	var d := nav.get_next_path_position() - global_position
	d.y = 0.0
	if d.length() < 0.05:
		return flat.normalized()
	return d.normalized()

func _summon() -> void:
	var main := get_parent()
	if not main.has_method("spawn_extra"):
		return
	_voice()
	for i in 2:
		var a := randf() * TAU
		main.spawn_extra(cfg.summon, global_position + Vector3(cos(a) * 2.5, 0, sin(a) * 2.5))

func _face(dir: Vector3, delta: float) -> void:
	var turn := 9.0 if not cfg.thrower else 4.0
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * turn))

func _move_direction(to_player: Vector3, dist: float, delta: float) -> Vector3:
	if dist < DIRECT_DISTANCE:
		return to_player.normalized()
	repath_timer -= delta
	if repath_timer <= 0.0:
		nav.target_position = player.global_position
		repath_timer = randf_range(0.25, 0.4)
	if nav.is_navigation_finished():
		return to_player.normalized()
	var d := nav.get_next_path_position() - global_position
	d.y = 0.0
	if d.length() < 0.05:
		return to_player.normalized()
	return d.normalized()

# ---------- Бросок споровой бомбы ----------
func _throw() -> void:
	var from := global_position + Vector3(0, feet + 0.4, 0) + global_transform.basis.x * 0.5
	var target := player.global_position - Vector3(0, 0.9, 0)   # под ноги игроку
	if player is CharacterBody3D:
		target += (player as CharacterBody3D).velocity * Vector3(1, 0, 1) * 0.5   # чуть на упреждение
	var bomb := SporeBomb.new()
	bomb.setup(from, target, self)
	get_parent().add_child(bomb)
	Sfx.play_3d(self, SND_THROW, from, 0.0, 0.55)

func _spawn_cloud(pos: Vector3, radius: float, life: float) -> void:
	var c := SporeCloud.new()
	c.radius = radius
	c.lifetime = life
	c.position = pos
	get_parent().add_child(c)

# ---------- Анимация ----------
func _animate(delta: float, moving: bool) -> void:
	anim_time += delta
	if moving:
		walk_phase += delta * Vector2(velocity.x, velocity.z).length() * cfg.gait
	gait_weight = move_toward(gait_weight, 1.0 if moving else 0.0, delta * 5.0)
	CharacterSurface.gait(parts, walk_phase, gait_weight, delta)
	var swing := sin(walk_phase)
	var amount := gait_weight
	var legs: Array = parts.legs
	var arms: Array = parts.arms
	var torso: Node3D = parts.torso
	var head: Node3D = parts.head
	var step := 0.85 if kind == "runner" else (0.4 if cfg.thrower else 0.65)

	legs[0].rotation.x = swing * step * amount
	legs[1].rotation.x = -swing * step * amount
	arms[0].rotation.x = base.arm - swing * step * 0.7 * amount
	arms[1].rotation.x = base.arm + swing * step * 0.7 * amount
	torso.rotation.x = base.lean + sin(walk_phase * 2.0) * 0.05 * amount
	torso.rotation.z = sin(walk_phase) * (0.08 if kind == "bloater" else 0.0) * amount   # топляк переваливается
	torso.position.y = base.torso_y + absf(sin(walk_phase)) * 0.05 * amount

	# замах для броска: правая рука уходит назад и вверх
	if windup > 0.0:
		var k := 1.0 - windup / THROW_WINDUP
		arms[1].rotation.x = lerpf(base.arm, -2.6, minf(1.0, k * 1.6))

	head_snap = move_toward(head_snap, 0.0, delta * 6.0)
	var jitter := 1.0 if kind == "clicker" else (0.5 if kind == "runner" else 0.25)
	if aware == "wander" and kind == "runner":
		jitter = 0.2
	head.rotation.y = (sin(anim_time * 11.0) * 0.1 + sin(anim_time * 5.3) * 0.2) * jitter
	head.rotation.z = sin(anim_time * 8.7) * 0.08 * jitter
	head.rotation.x = base.head_x - head_snap * 0.25
