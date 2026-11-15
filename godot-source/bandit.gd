extends CharacterBody3D
const CharacterSurface := preload("res://character_surface.gd")
var gait_weight := 0.0
# Бандит — враг-человек. Тип задаётся полем kind ДО add_child:
#   "brute"   — громила с битой: бежит в ближний бой, крепкий
#   "pistol"  — стрелок: держит дистанцию, стреляет одиночными из укрытия
#   "shotgun" — с обрезом: подходит близко, бьёт очень больно
#   "rifle"   — автоматчик: стреляет очередями издалека
#
# Как думает стрелок:
#   ищет укрытие (место, где присевшего не видно, а стоя — видно игрока) →
#   бежит туда → сидит → встаёт, целится → очередь → снова прячется.
#   Пустой магазин — перезаряжается сидя (и кричит об этом).
#   Если укрытие «прострелено» (игрок обошёл) — ищет новое. Бандиты занимают
#   разные укрытия, поэтому расходятся и обходят игрока с флангов.
#   Если игрок подошёл вплотную — бьёт прикладом.

signal died

const Sfx := preload("res://sfx.gd")
const BloodFx := preload("res://blood_fx.gd")
const BanditModel := preload("res://bandit_model.gd")
const AmmoPickup := preload("res://ammo_pickup.gd")
const SND_HIT := preload("res://sounds/hit.wav")
const SND_HEADSHOT := preload("res://sounds/headshot.wav")
const SND_HURT := preload("res://sounds/bandit_hurt.wav")
const SND_DIE := preload("res://sounds/bandit_die.wav")
const SND_WHIZZ := preload("res://sounds/bullet_whizz.wav")
const SND_SWING := preload("res://sounds/melee_swing.wav")
const SND_MELEE := preload("res://sounds/melee_hit.wav")
const SND_RELOAD := preload("res://sounds/rifle_reload.wav")

const TYPES := {
	"brute": {
		"weapon": "bat", "health": 160, "speed": 4.4, "head_mult": 3.0,
		"melee_damage": 15, "melee_cooldown": 1.5,
		"drop": "medkit", "drop_chance": 0.35,
	},
	"pistol": {
		"weapon": "pistol", "health": 80, "speed": 3.8, "head_mult": 4.0,
		"damage": 7, "pellets": 1, "spread": 3.5, "mag": 8, "burst": Vector2i(2, 3), "shot_gap": 0.4,
		"reload": 1.8, "range": Vector2(7, 18), "melee_damage": 12, "melee_cooldown": 1.2,
		"snd": preload("res://sounds/shoot.wav"), "drop": "medkit", "drop_chance": 0.25,
	},
	"shotgun": {
		"weapon": "shotgun", "health": 90, "speed": 4.0, "head_mult": 4.0,
		"damage": 4, "pellets": 6, "spread": 7.0, "mag": 4, "burst": Vector2i(1, 1), "shot_gap": 1.3,
		"reload": 2.6, "range": Vector2(2.5, 9), "melee_damage": 14, "melee_cooldown": 1.2,
		"snd": preload("res://sounds/shotgun_shot.wav"), "drop": "shotgun", "drop_amount": Vector2i(3, 6),
	},
	"rifle": {
		"weapon": "rifle", "health": 80, "speed": 3.6, "head_mult": 4.0,
		"damage": 6, "pellets": 1, "spread": 2.4, "mag": 20, "burst": Vector2i(3, 6), "shot_gap": 0.12,
		"reload": 2.4, "range": Vector2(10, 24), "melee_damage": 12, "melee_cooldown": 1.2,
		"snd": preload("res://sounds/rifle_shot.wav"), "drop": "rifle", "drop_amount": Vector2i(10, 20),
	},
	# БОСС карантинной зоны: крепкий, длинные очереди, не оглушается
	"leader": {
		"weapon": "rifle", "health": 650, "speed": 3.4, "head_mult": 2.0, "boss": true,
		"name": "Главарь бандитов", "scale": 1.12,
		"damage": 8, "pellets": 1, "spread": 2.2, "mag": 40, "burst": Vector2i(5, 9), "shot_gap": 0.1,
		"reload": 2.6, "range": Vector2(8, 26), "melee_damage": 22, "melee_cooldown": 1.0,
		"snd": preload("res://sounds/rifle_shot.wav"), "drop": "sniper", "drop_amount": Vector2i(6, 10),
	},
}
const Pickup := preload("res://ammo_pickup.gd")
const Sound := preload("res://noise.gd")
const MATERIALS := ["rag", "alcohol", "blade", "explosive"]

const HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const RADIUS := 0.35
const FEET := HEIGHT * 0.5
const MELEE_RANGE := 1.9
const BLOOD := Color(0.5, 0.03, 0.03)     # у людей кровь ярче, чем у заражённых

# Реплики (показываются над головой). Одновременно кричит только один бандит.
const LINES := {
	"spot": ["Вон он!", "Вижу его!", "Он здесь!"],
	"reload": ["Перезаряжаюсь!", "Прикройте, перезаряжаюсь!", "Пустой!"],
	"flank": ["Обходи его!", "Захожу сбоку!", "Окружай!"],
	"hurt": ["А-а, задел!", "Чёрт!", "Попал, гад!"],
	"melee": ["Получай!", "Иди сюда!"],
	"cover": ["Прикрой!", "Держи его!"],
}
static var last_shout_ms := 0

var kind := "pistol"
var cfg: Dictionary
var health := 80
var speed := 3.8
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_dead := false
var melee_only := false

# ---- мозг ----
var state := "move"          # move / cover / aim / shoot / fight / chase
var state_time := 0.0
var think_timer := 0.0
var cover_point = null       # Vector3 или null
var cover_search_cd := 0.0
var mag := 0
var reloading := 0.0
var shots_left := 0
var shot_timer := 0.0
var melee_cd := 0.0
var melee_windup := 0.0
var can_see := false
var spotted := false
var repath_timer := 0.0
var strafe_dir := 1.0
var peek_fails := 0
var stun_timer := 0.0        # оглушён: кулаки, доска, дым
var blind_timer := 0.0       # в дыму — не видит
var grabbed := false         # его душит игрок
var is_boss := false          # сколько раз встал из укрытия, а игрока не видно

# ---- тело ----
var crouch := 0.0            # 0..1 плавно
var want_crouch := false
var walk_phase := 0.0
var aim_pitch := 0.0
var aiming := false
var hurt_flinch := 0.0

var parts := {}
var model: Node3D
var nav: NavigationAgent3D
var shape: CapsuleShape3D
var col: CollisionShape3D
var shout_label: Label3D
var flash: OmniLight3D

@onready var player: Node3D = get_tree().get_first_node_in_group("player")

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("bandit")
	if not TYPES.has(kind):
		kind = "pistol"
	cfg = TYPES[kind]
	melee_only = cfg.weapon == "bat"
	is_boss = cfg.get("boss", false)
	health = cfg.health
	speed = cfg.speed * randf_range(0.92, 1.08)
	mag = cfg.get("mag", 0)
	strafe_dir = -1.0 if randf() < 0.5 else 1.0
	state = "chase" if melee_only else "move"
	position.y += FEET - 0.95

	col = CollisionShape3D.new()
	shape = CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	col.shape = shape
	add_child(col)

	model = Node3D.new()
	model.position.y = -FEET
	add_child(model)
	parts = BanditModel.build(model, cfg.weapon, randi())
	model.scale = Vector3.ONE * cfg.get("scale", 1.0)
	if is_boss:
		spotted = true

	nav = NavigationAgent3D.new()
	nav.path_desired_distance = 0.6
	nav.target_desired_distance = 0.5
	nav.radius = RADIUS
	nav.path_height_offset = -FEET
	add_child(nav)

	shout_label = Label3D.new()
	shout_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shout_label.font_size = 40
	shout_label.pixel_size = 0.005
	shout_label.outline_size = 10
	shout_label.modulate = Color(1.0, 0.85, 0.6)
	shout_label.position = Vector3(0, 1.25, 0)
	shout_label.visible = false
	add_child(shout_label)

	flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.75, 0.4)
	flash.light_energy = 3.0
	flash.omni_range = 6.0
	flash.visible = false
	parts.muzzle.add_child(flash)

# ============================================================
#  Урон и смерть (тот же интерфейс, что у заражённых)
# ============================================================
func head_sphere() -> Array:
	var head: Node3D = parts.head
	return [head.to_global(Vector3(0, 0.03, 0)), 0.14]

func take_damage(amount: int, knockback := Vector3.ZERO, hit_pos := Vector3.INF, headshot := false) -> void:
	if is_dead:
		return
	health -= maxi(1, roundi(amount * (cfg.head_mult if headshot else 1.0)))
	if hit_pos.is_finite():
		BloodFx.spawn(get_parent(), hit_pos, knockback, headshot or health <= 0, self, BLOOD)
	if headshot:
		Sfx.play_3d(self, SND_HEADSHOT, hit_pos if hit_pos.is_finite() else global_position, 2.0)
	if health <= 0:
		die()
		return
	Sfx.play_3d(self, SND_HURT, global_position + Vector3(0, 0.6, 0), 0.0, 1.0, 0.1)
	hurt_flinch = 1.0
	velocity += Vector3(knockback.x, 0, knockback.z) * 0.5
	if randf() < 0.3:
		shout("hurt")
	# под огнём стоя — прячемся, не дострелив очередь
	if (state == "aim" or state == "shoot") and cover_point != null and randf() < 0.6:
		_set_state("cover")
	if not spotted:
		spotted = true

func is_aware() -> bool:
	return spotted

# Шум игрока: бандит настораживается и знает, где вы
func hear(pos: Vector3, radius: float, by_player := true) -> void:
	if is_dead or grabbed or not by_player:
		return
	if global_position.distance_to(pos) < radius and not spotted:
		spotted = true
		shout("spot")

func can_be_stunned() -> bool:
	return not is_boss

func stun(t: float) -> void:
	if is_dead or is_boss:
		return
	stun_timer = maxf(stun_timer, t)
	shooting_stop()

func blind(t: float) -> void:
	blind_timer = maxf(blind_timer, t)

func shooting_stop() -> void:
	shots_left = 0
	melee_windup = 0.0
	aiming = false

func start_grab() -> void:
	grabbed = true
	collision_mask = 0
	velocity = Vector3.ZERO
	shout_label.visible = false

func finish_grab() -> void:
	if is_dead:
		return
	health = 0
	die(true)

func die(quiet := false) -> void:
	is_dead = true
	grabbed = false
	if randf() < 0.4:
		_spawn_pickup(MATERIALS.pick_random(), 1)
	died.emit()
	remove_from_group("enemy")
	remove_from_group("bandit")
	collision_layer = 0
	collision_mask = 0
	shout_label.visible = false
	flash.visible = false
	if not quiet:
		Sfx.play_3d(self, SND_DIE, global_position)
	_drop_loot()
	# соседи реагируют
	for b in get_tree().get_nodes_in_group("bandit"):
		if b.global_position.distance_to(global_position) < 20.0 and randf() < 0.5:
			b.shout("cover")
			break
	var tw := create_tween()
	tw.tween_property(model, "rotation:x", 1.5 if randf() < 0.5 else -1.5, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(model, "position:y", -FEET + 0.15, 0.5)
	tw.tween_interval(6.0)
	tw.tween_property(model, "position:y", -FEET - 1.5, 1.5)
	tw.tween_callback(queue_free)

const MOLOTOV_DROP := 0.3      # шанс, что с любого бандита выпадет коктейль Молотова
const SNIPER_DROP := 0.3       # шанс патронов к снайперке у стрелка с винтовкой

func _drop_loot() -> void:
	if randf() < MOLOTOV_DROP:
		_spawn_pickup("molotov", 1)
	if kind == "rifle" and randf() < SNIPER_DROP:
		_spawn_pickup("sniper", randi_range(2, 4))
	var what: String = cfg.get("drop", "")
	var amount := 0
	if what == "medkit":
		if randf() > cfg.get("drop_chance", 0.0):
			return
		amount = 1
	elif what != "":
		var r: Vector2i = cfg.drop_amount
		amount = randi_range(r.x, r.y)
	else:
		return
	_spawn_pickup(what, amount)

func _spawn_pickup(what: String, amount: int) -> void:
	var p := AmmoPickup.new()
	p.what = what
	p.amount = amount
	p.position = global_position - Vector3(0, FEET - 0.15, 0) + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
	get_parent().add_child(p)

# ============================================================
#  Реплики над головой
# ============================================================
func shout(kind_of_line: String, force := false) -> void:
	var now := Time.get_ticks_msec()
	if not force and now - last_shout_ms < 2500:
		return
	last_shout_ms = now
	var lines: Array = LINES[kind_of_line]
	shout_label.text = lines.pick_random()
	shout_label.visible = true
	shout_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(shout_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(shout_label.hide)

# ============================================================
#  Каждый кадр
# ============================================================
func _physics_process(delta: float) -> void:
	if is_dead or player == null:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	if grabbed:
		velocity = Vector3.ZERO
		return
	if stun_timer > 0.0:
		stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		want_crouch = false
		aiming = false
		hurt_flinch = 1.0
		move_and_slide()
		_update_body(delta)
		_animate(delta)
		return
	blind_timer -= delta

	state_time += delta
	melee_cd -= delta
	cover_search_cd -= delta
	hurt_flinch = move_toward(hurt_flinch, 0.0, delta * 3.0)

	var to_player := player.global_position - global_position
	var flat := Vector3(to_player.x, 0, to_player.z)
	var dist := flat.length()

	think_timer -= delta
	if think_timer <= 0.0:
		think_timer = randf_range(0.2, 0.3)
		can_see = blind_timer <= 0.0 and not Sound.in_smoke(get_tree(), player.global_position) \
			and _clear(_eye(), _player_aim_point())
		if can_see and not spotted:
			spotted = true
			shout("spot")

	# Перезарядка идёт в любом состоянии
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			mag = cfg.mag

	# Вплотную — удар (у стрелков прикладом)
	if melee_windup > 0.0:
		melee_windup -= delta
		if melee_windup <= 0.0:
			if dist < MELEE_RANGE + 0.3 and player.has_method("take_damage"):
				player.take_damage(cfg.melee_damage)
				Sfx.play_3d(self, SND_MELEE, player.global_position)
	elif dist < MELEE_RANGE and melee_cd <= 0.0:
		melee_windup = 0.45 if melee_only else 0.35
		melee_cd = cfg.melee_cooldown
		Sfx.play_3d(self, SND_SWING, global_position + Vector3(0, 0.5, 0))
		if randf() < 0.3:
			shout("melee")

	if melee_only:
		_brute(delta, flat, dist)
	else:
		_gunner(delta, flat, dist)

	move_and_slide()
	_update_body(delta)
	_animate(delta)

# ---------- Громила: бежит и бьёт ----------
func _brute(delta: float, flat: Vector3, dist: float) -> void:
	want_crouch = false
	aiming = false
	if dist > 1.3:
		var dir := _nav_dir(player.global_position, delta)
		_move(dir, speed, delta)
	else:
		_move(Vector3.ZERO, speed, delta)
		_face(flat, delta)

# ---------- Стрелок ----------
func _gunner(delta: float, flat: Vector3, dist: float) -> void:
	var rng_v: Vector2 = cfg["range"]
	match state:
		"move":
			# бежим к укрытию; если его нет — к игроку, пока не окажемся на дистанции
			want_crouch = false
			aiming = false
			if kind == "shotgun" and can_see and dist < rng_v.y:
				cover_point = null
				_set_state("fight")
				return
			if cover_point == null and cover_search_cd <= 0.0:
				_pick_cover()
			if cover_point != null:
				var cp: Vector3 = cover_point
				if Vector2(cp.x - global_position.x, cp.z - global_position.z).length() < 0.6:
					_set_state("cover")
				else:
					_move(_nav_dir(cp, delta), speed, delta)
			else:
				if can_see and dist >= rng_v.x and dist <= rng_v.y:
					_set_state("fight")
				else:
					_move(_nav_dir(player.global_position, delta), speed, delta)
			if state_time > 8.0:   # застряли — переоценить
				cover_point = null
				_set_state("move")
		"cover":
			# сидим, перезаряжаемся, ждём момента
			want_crouch = true
			aiming = false
			_move(Vector3.ZERO, speed, delta)
			_face(flat, delta)
			if mag <= 0 and reloading <= 0.0:
				_start_reload()
			# укрытие прострелено (видно даже сидя) или игрок вне дистанции — меняем
			if state_time > 0.4 and _clear(_eye_at(0.75), _player_aim_point()):
				_relocate()
			elif dist > rng_v.y * 1.25 or dist < rng_v.x * 0.6:
				_relocate()
			elif state_time > randf_range(1.0, 2.2) and reloading <= 0.0:
				_set_state("aim")
		"aim":
			# встаём и целимся (короткая пауза — шанс для игрока)
			want_crouch = false
			aiming = true
			_move(Vector3.ZERO, speed, delta)
			_face(flat, delta)
			if crouch < 0.2 and state_time > 0.45:
				if can_see:
					peek_fails = 0
					shots_left = randi_range(cfg.burst.x, cfg.burst.y)
					shot_timer = 0.0
					_set_state("shoot")
				elif state_time > 1.0:
					peek_fails += 1
					if peek_fails >= 2:
						peek_fails = 0
						cover_point = null
						_set_state("fight")   # хватит прятаться — выходим в открытую
					else:
						_relocate()        # игрок ушёл из виду
		"shoot":
			want_crouch = false
			aiming = true
			_move(Vector3.ZERO, speed, delta)
			_face(flat, delta)
			shot_timer -= delta
			if shot_timer <= 0.0 and shots_left > 0 and mag > 0 and reloading <= 0.0:
				_fire()
				shots_left -= 1
				shot_timer = cfg.shot_gap
			if shots_left <= 0 or mag <= 0:
				if mag <= 0:
					_start_reload()
				_set_state("cover" if cover_point != null else "fight")
		"fight":
			# укрытия нет: стоим/шагаем вбок и стреляем
			want_crouch = false
			aiming = true
			_face(flat, delta)
			var side := flat.normalized().cross(Vector3.UP) * strafe_dir
			if randf() < delta * 0.4:
				strafe_dir = -strafe_dir
			if kind == "shotgun" and dist > 4.5:
				# с дробовиком — напролом, стреляя на ходу
				_move(_nav_dir(player.global_position, delta), speed * 0.8, delta)
			else:
				_move(side if reloading <= 0.0 else -flat.normalized(), speed * 0.45, delta)
			if mag <= 0 and reloading <= 0.0:
				_start_reload()
			shot_timer -= delta
			if can_see and shot_timer <= 0.0 and mag > 0 and reloading <= 0.0 and state_time > 0.5:
				_fire()
				shot_timer = cfg.shot_gap * randf_range(1.5, 3.0)
			var too_close := dist < rng_v.x * 0.5 and kind != "shotgun"
			if not can_see or dist > rng_v.y * 1.2 or too_close or state_time > 6.0:
				cover_search_cd = 0.0
				_set_state("move")

func _set_state(s: String) -> void:
	state = s
	state_time = 0.0

func _relocate() -> void:
	cover_point = null
	cover_search_cd = 0.0
	_set_state("move")

func _start_reload() -> void:
	reloading = cfg.reload
	shout("reload")
	Sfx.play_3d(self, SND_RELOAD, global_position, -6.0)

# ============================================================
#  Поиск укрытия
# ============================================================
# Хорошее укрытие: присевшего не видно, стоя — игрок виден; на нужной дистанции;
# недалеко от бандита; не занято другим бандитом.
func _pick_cover() -> void:
	cover_search_cd = 1.2
	var map := get_world_3d().navigation_map
	var target := _player_aim_point()
	var rng_v: Vector2 = cfg["range"]
	var mid := (rng_v.x + rng_v.y) * 0.5
	var taken: Array[Vector3] = []
	for b in get_tree().get_nodes_in_group("bandit"):
		if b != self and b.cover_point != null:
			taken.append(b.cover_point)
	var best = null
	var best_score := -INF
	for i in 28:
		var a := randf() * TAU
		var r := randf_range(2.0, 12.0)
		var c := NavigationServer3D.map_get_closest_point(map, global_position + Vector3(cos(a) * r, 0, sin(a) * r))
		var d := Vector2(c.x - target.x, c.z - target.z).length()
		if d < rng_v.x or d > rng_v.y * 1.1:
			continue
		var floor_y := _floor_at(c)
		if _clear(Vector3(c.x, floor_y + 0.8, c.z), target):
			continue                      # сидя видно — не укрытие
		if not _clear(Vector3(c.x, floor_y + 1.4, c.z), target):
			continue                      # стоя не видно — неоткуда стрелять
		var score := -c.distance_to(global_position) * 0.5 - absf(d - mid) * 0.25 + randf() * 2.0
		for t in taken:
			if t.distance_to(c) < 4.0:
				score -= 8.0
		if score > best_score:
			best_score = score
			best = c
	if best != null:
		var was_far: bool = cover_point == null and (best as Vector3).distance_to(global_position) > 6.0
		cover_point = best
		if was_far and randf() < 0.35:
			shout("flank")

# ============================================================
#  Стрельба
# ============================================================
func _fire() -> void:
	mag -= 1
	var muzzle: Vector3 = parts.muzzle.global_position
	# если ствол «в стене» (упёрся в укрытие) — стреляем от глаз
	if not _clear(_eye(), muzzle):
		muzzle = _eye()
	Sfx.play_3d(self, cfg.snd, muzzle, 0.0, 1.0, 0.06)
	flash.visible = true
	get_tree().create_timer(0.05).timeout.connect(_hide_flash)

	var target := _player_aim_point()
	var base_dir := (target - muzzle).normalized()
	# разброс: шире, если игрок бежит, и для каждой следующей пули в очереди
	var spread: float = cfg.spread
	var pv: Vector3 = player.get("velocity")
	if player.get("sprinting"):
		spread *= 1.8                     # бегущего трудно подстрелить
	elif Vector2(pv.x, pv.z).length() > 1.0:
		spread *= 1.3                     # идущего — чуть труднее
	if shots_left > 0 and state == "shoot":
		spread *= 1.0 + 0.12 * (randi_range(cfg.burst.x, cfg.burst.y) - shots_left)   # очередь «уводит»
	var aim_basis := Basis.looking_at(base_dir)
	for i in cfg.pellets:
		var t := tan(deg_to_rad(spread))
		var a := randf() * TAU
		var r := sqrt(randf()) * t
		var dir := (base_dir + aim_basis.x * cos(a) * r + aim_basis.y * sin(a) * r).normalized()
		_bullet(muzzle, dir)

func _hide_flash() -> void:
	if is_instance_valid(flash):
		flash.visible = false

func _bullet(from: Vector3, dir: Vector3) -> void:
	var to := from + dir * 80.0
	var hit := _ray(from, to, 1 | 2)
	var end: Vector3 = to if hit.is_empty() else hit.position
	_tracer(from, end)
	# голова игрока может торчать из-за укрытия вне его капсулы (выглядывание)
	var head: Vector3 = player.head_point() if player.has_method("head_point") else player.global_position + Vector3(0, 0.6, 0)
	var seg := end - from
	var k := clampf((head - from).dot(seg) / maxf(seg.length_squared(), 0.001), 0.0, 1.0)
	var closest := from + seg * k
	var head_hit := closest.distance_to(head) < 0.2 and k < 0.999
	if (not hit.is_empty() and hit.collider == player) or head_hit:
		var dmg: float = cfg.damage
		if kind == "shotgun":   # дробь слабеет с расстоянием
			dmg *= clampf(1.0 - (from.distance_to(end) - 5.0) / 15.0, 0.3, 1.0)
		player.take_damage(maxi(1, roundi(dmg)))
		return
	# промах рядом с головой — свист пули
	if closest.distance_to(head) < 1.6:
		Sfx.play_3d(self, SND_WHIZZ, closest, 2.0, 1.0, 0.15)

# Трассер: тонкая светящаяся полоска на долю секунды
func _tracer(from: Vector3, to: Vector3) -> void:
	var seg_len := from.distance_to(to)
	if seg_len < 0.5:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, seg_len)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.5, 0.8)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(mi)
	mi.global_transform = Transform3D(Basis.looking_at((to - from).normalized()), (from + to) * 0.5)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.08)
	tw.tween_callback(mi.queue_free)

# ============================================================
#  Помощники
# ============================================================
func _eye() -> Vector3:
	return _eye_at(lerpf(1.45, 0.8, crouch))

func _eye_at(h: float) -> Vector3:
	return global_position + Vector3(0, h - FEET, 0)

func _player_aim_point() -> Vector3:
	# игрок выглядывает из-за угла — целимся в голову, тело спрятано
	var lean = player.get("lean_amount")
	if lean != null and absf(lean) > 0.35 and player.has_method("head_point"):
		return player.head_point() - Vector3(0, 0.08, 0)
	var crouched: bool = player.get("crouching") == true
	return player.global_position + Vector3(0, -0.2 if crouched else 0.25, 0)

# Луч по миру, который не задевает бандитов и заражённых
func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var ex: Array[RID] = [get_rid()]
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, ex)
	var hit := space.intersect_ray(q)
	var guard := 0
	while not hit.is_empty() and hit.collider is Node and (hit.collider as Node).is_in_group("enemy") and guard < 8:
		ex.append(hit.rid)
		q.exclude = ex
		hit = space.intersect_ray(q)
		guard += 1
	return hit

# Высота пола под точкой (точка навигации бывает чуть выше земли)
func _floor_at(p: Vector3) -> float:
	var hit := _ray(p + Vector3(0, 0.5, 0), p + Vector3(0, -2.0, 0), 1)
	return hit.position.y if not hit.is_empty() else p.y

func _clear(from: Vector3, to: Vector3) -> bool:
	return _ray(from, to, 1).is_empty()

func _nav_dir(target: Vector3, delta: float) -> Vector3:
	var flat := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	if flat.length() < 2.0:
		return flat.normalized()
	repath_timer -= delta
	if repath_timer <= 0.0 or nav.target_position.distance_to(target) > 1.5:
		nav.target_position = target
		repath_timer = randf_range(0.3, 0.5)
	if nav.is_navigation_finished():
		return flat.normalized()
	var d := nav.get_next_path_position() - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.05 else flat.normalized()

func _move(dir: Vector3, spd: float, delta: float) -> void:
	if crouch > 0.5:
		spd *= 0.5
	if dir != Vector3.ZERO:
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		if not aiming:
			_face(dir, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)

func _face(dir: Vector3, delta: float) -> void:
	if dir.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 10.0))

# Присед: капсула ниже (пули игрока проходят над укрытием), низ остаётся на месте
func _update_body(delta: float) -> void:
	crouch = move_toward(crouch, 1.0 if want_crouch else 0.0, delta * 5.0)
	shape.height = lerpf(HEIGHT, CROUCH_HEIGHT, crouch)
	col.position.y = -(HEIGHT - shape.height) * 0.5
	# наклон оружия к цели
	var shoulder := _eye_at(lerpf(1.45, 0.7, crouch))
	var t := _player_aim_point() - shoulder
	aim_pitch = atan2(t.y, Vector2(t.x, t.z).length())

# ============================================================
#  Анимация
# ============================================================
func _animate(delta: float) -> void:
	var legs: Array = parts.legs
	var arms: Array = parts.arms
	var torso: Node3D = parts.torso
	var head: Node3D = parts.head
	var hv := Vector2(velocity.x, velocity.z).length()
	var moving := hv > 0.3
	if moving:
		walk_phase += delta * hv * 2.4
	gait_weight = move_toward(gait_weight, 1.0 if moving else 0.0, delta * 5.0)
	CharacterSurface.gait(parts, walk_phase, gait_weight, delta, true)
	var swing := sin(walk_phase) * gait_weight * (1.0 - crouch)

	# ноги: шаг или присед (одна вперёд, другая назад — «на колено»)
	legs[0].rotation.x = lerpf(swing * 0.7, -1.0, crouch)
	legs[1].rotation.x = lerpf(-swing * 0.7, 1.0, crouch)
	torso.position.y = 0.95 - crouch * 0.45 + absf(sin(walk_phase)) * 0.03 * (1.0 if moving else 0.0)
	torso.rotation.x = -crouch * 0.15 - hurt_flinch * 0.25 + (0.12 if moving and not aiming else 0.0) * -1.0

	var r_target: float
	var l_target: float
	if melee_only:
		# бита: замах над головой и удар вниз
		if melee_windup > 0.0:
			r_target = 3.0
		elif melee_cd > cfg.melee_cooldown - 0.25:
			r_target = 1.1
		else:
			r_target = 0.35 - swing * 0.3
		l_target = swing * 0.6
	elif melee_windup > 0.0:
		r_target = 0.3       # замах прикладом
		l_target = 0.3
	elif aiming:
		r_target = PI * 0.5 + aim_pitch
		l_target = PI * 0.5 + aim_pitch
	else:
		r_target = 0.75      # оружие «наготове», стволом вниз
		l_target = 0.85
	if reloading > 0.0 and not melee_only:
		l_target = 0.5 + sin(Time.get_ticks_msec() * 0.01) * 0.2
	var k := minf(1.0, delta * (18.0 if melee_windup > 0.0 or melee_cd > cfg.melee_cooldown - 0.25 else 10.0))
	arms[1].rotation.x = lerp_angle(arms[1].rotation.x, r_target, k)
	arms[0].rotation.x = lerp_angle(arms[0].rotation.x, l_target, k)
	# левая рука тянется к цевью
	arms[0].rotation.y = lerpf(arms[0].rotation.y, -0.45 if (aiming and not melee_only) else 0.0, k)
	head.rotation.x = -aim_pitch * 0.5 if aiming else 0.0
