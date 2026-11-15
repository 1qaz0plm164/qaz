extends Node3D
# Управляет волнами врагов, счётом, экраном смерти и рекордом

const ENEMY_SCENE := preload("res://enemy.tscn")
const SAVE_PATH := "user://save.cfg"
const Sfx := preload("res://sfx.gd")
const SND_WAVE := preload("res://sounds/wave_start.wav")
const SND_GAME_OVER := preload("res://sounds/game_over.wav")
const SND_WAVE_CLEAR := preload("res://sounds/wave_clear.wav")
const SupplyCrate := preload("res://supply_crate.gd")
const Bandit := preload("res://bandit.gd")
const Menus := preload("res://menus.gd")
const Settings := preload("res://settings.gd")
const RunStats := preload("res://run_stats.gd")
const Pickup := preload("res://ammo_pickup.gd")
const MUSIC_CALM := preload("res://sounds/music_calm.ogg")
const MUSIC_COMBAT := preload("res://sounds/music_combat.ogg")
const SND_NOTICE := preload("res://sounds/notice.wav")
const SND_BOSS := preload("res://sounds/boss_roar.wav")

# true — после перезапуска сразу в бой, без главного меню («Играть снова», «Начать заново»)
static var skip_menu := false

const BREAK_TIME := 15           # пауза между волнами, сек
const CRATE_EVERY := 2           # ящики появляются после каждой 2-й волны
const CRATE_RADIUS := Vector2(2.5, 6.0)   # ящики появляются на таком расстоянии от центра карты
const MAX_CRATES := 6            # больше ящиков на карте не бывает (если их не собирают)
const WAVES_PER_LOCATION := 5    # после стольких волн — переход на следующую локацию
const ARRIVE_BREAK := 8          # пауза после перехода на новую локацию, сек
const LOOT_ON_MAP := 7           # сколько материалов разложено по новой локации
const LOOT_MAX := 14             # больше материалов на карте не бывает
const LOOT_KINDS := ["rag", "rag", "alcohol", "alcohol", "blade", "explosive"]
# Волны с боссами: номер волны -> состав
const BOSS_WAVES := {
	25: ["b_leader", "b_rifle", "b_shotgun", "b_pistol", "b_brute"],                       # Карантинная зона
	35: ["giant_bloater", "clicker", "clicker", "clicker", "clicker", "runner", "runner", "runner", "runner"],   # Метро
	40: ["rat_king", "runner", "runner", "runner", "runner"],                                # Джексон, финал
}
const LOCATION_NAMES := ["Заброшенный город", "Лесное шоссе", "Затопленный квартал", "Торговый центр",
	"Карантинная зона", "Порт", "Станция метро", "Джексон зимой"]
const LOCATIONS := [
	"res://level.gd",            # Заброшенный город
	"res://level_forest.gd",     # Лесное шоссе
	"res://level_flooded.gd",    # Затопленный квартал
	"res://level_mall.gd",       # Торговый центр
	"res://level_qz.gd",         # Карантинная зона
	"res://level_port.gd",       # Порт
	"res://level_subway.gd",     # Станция метро
	"res://level_jackson.gd",    # Джексон зимой
]

var wave := 0
var enemies_alive := 0
var kills := 0
var game_over := false
var announce: Label            # крупная надпись по центру («Топляк!»)
var break_label: Label         # «Волна пройдена… следующая через N»
var location := 0              # номер текущей локации (0..7)
var fade: ColorRect            # затемнение экрана при переходе
var won := false
var started := false           # бой начался (вышли из главного меню)
var menus: CanvasLayer
var menu_cam: Camera3D
var in_break := false          # идёт пауза/переход (N в это время не работает)
var boss: Node3D               # текущий босс (для полоски здоровья)
var boss_max := 1
var boss_bar: ProgressBar
var boss_label: Label
var music_calm: AudioStreamPlayer
var music_combat: AudioStreamPlayer
var combat_mix := 0.0          # 0 — спокойная музыка, 1 — боевая
var combat_hold := 0.0         # боевая играет ещё немного после того, как враги потеряли игрока
var notice_cd := 0.0
var top_wave: Label            # верхний правый блок: волна, локация, враги
var top_loc: Label
var top_info: Label
var top_panel: PanelContainer

@onready var player: Node3D = $Player
@onready var level: Node3D = $Level
@onready var wave_label: Label = $UI/WaveLabel
@onready var kills_label: Label = $UI/KillsLabel
@onready var game_over_screen: Control = $UI/GameOver
@onready var stats_label: Label = $UI/GameOver/Box/StatsLabel
@onready var best_label: Label = $UI/GameOver/Box/BestLabel
@onready var restart_button: Button = $UI/GameOver/Box/RestartButton

func _ready() -> void:
	Settings.load_settings()
	Settings.apply(get_tree())
	player.connect("died", _on_player_died)
	restart_button.pressed.connect(_on_restart_pressed)
	_make_announce()
	_make_break_label()
	_make_fade()
	_make_menus()
	_make_boss_bar()
	_make_top_hud()
	_make_music()
	if skip_menu:
		skip_menu = false
		_begin()
	else:
		_show_main_menu()

func _make_menus() -> void:
	menus = Menus.new()
	add_child(menus)
	menus.can_pause = _can_pause
	menus.best_text = best_text
	menus.start_pressed.connect(_begin)
	menus.resume_pressed.connect(_resume)
	menus.restart_pressed.connect(_on_restart_pressed)
	menus.main_menu_pressed.connect(_to_main_menu)
	# на экране смерти — ещё кнопка «Главное меню»
	var b := Button.new()
	b.text = "Главное меню"
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(_to_main_menu)
	restart_button.get_parent().add_child(b)
	var box: Control = restart_button.get_parent()
	box.offset_top = -260.0
	box.offset_bottom = 260.0
	stats_label.add_theme_font_size_override("font_size", 26)

# Главное меню поверх замершей карты, камера медленно облетает её
func _show_main_menu() -> void:
	menu_cam = Camera3D.new()
	menu_cam.fov = 60.0
	add_child(menu_cam)
	menu_cam.make_current()
	menus.orbit_cam = menu_cam
	player.get_node("HUD").visible = false
	$UI.visible = false
	get_tree().paused = true
	menus.show_main()

func _begin() -> void:
	menus.hide_menu()
	if menu_cam:
		menu_cam.queue_free()
		menu_cam = null
	player.camera.make_current()
	player.get_node("HUD").visible = true
	$UI.visible = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.fire_cooldown = 0.3
	RunStats.reset()
	started = true
	_spawn_map_loot(LOOT_ON_MAP)
	# даём навигационной сетке пару кадров, чтобы подключиться, и только потом пускаем врагов
	await get_tree().physics_frame
	await get_tree().physics_frame
	start_next_wave()

func _process(delta: float) -> void:
	if started and not game_over:
		RunStats.time += delta
	_update_boss_bar()
	_update_music(delta)

# ---------- Пауза (Esc) ----------

func _can_pause() -> bool:
	if not started or game_over:
		return false
	if player.wheel_open:
		player._close_wheel(false)
	return true

func _resume() -> void:
	menus.hide_menu()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.fire_cooldown = maxf(player.fire_cooldown, 0.3)   # клик по кнопке — не выстрел

func _to_main_menu() -> void:
	skip_menu = false
	get_tree().paused = false
	get_tree().reload_current_scene()

func start_next_wave() -> void:
	in_break = false
	wave += 1
	var kinds := wave_composition(wave)
	enemies_alive = kinds.size()
	update_hud()
	if wave > 1:
		Sfx.play(self, SND_WAVE, -6.0, 1.0, 0.0)
	var boss_kind := ""
	for k in kinds:
		if k in ["b_leader", "giant_bloater", "rat_king"]:
			boss_kind = k
	if boss_kind != "":
		Sfx.play(self, SND_BOSS, -2.0, 1.0, 0.0)
		_announce({"b_leader": "Главарь бандитов!", "giant_bloater": "Огромный топляк!", "rat_king": "Крысиный король!"}[boss_kind])
	elif kinds.size() > 0 and not kinds[0].begins_with("b_") and kinds[-1].begins_with("b_"):
		_announce("Бандиты и заражённые!")
	elif kinds.size() > 0 and kinds[0].begins_with("b_"):
		_announce("Бандиты!")
	elif wave == 2:
		_announce("Бегуны!")
	elif kinds.has("bloater"):
		_announce("Топляк!" if kinds.count("bloater") == 1 else "Топляки!")
	for k in kinds:
		spawn_enemy(k)

# Кто приходит в волне N. Всего врагов: 2 + N (как раньше) + топляки сверху.
#   волна 1     — только щелкуны
#   с волны 2   — бегуны, их доля растёт до половины
#   волна 4, 8, 12... — топляки (по одному на каждые 4 волны)
func wave_composition(n: int) -> Array[String]:
	var list: Array[String] = []
	if BOSS_WAVES.has(n):
		list.assign(BOSS_WAVES[n])
		return list
	# 3-я волна каждой локации — бандиты
	if n % WAVES_PER_LOCATION == 3:
		return bandit_squad(n)
	var total := 2 + n
	var runners := 0
	if n >= 2:
		runners = mini(total / 2, n - 1)
	for i in total - runners:
		list.append("clicker")
	for i in runners:
		list.append("runner")
	if n % 4 == 0:
		for i in n / 4:
			list.append("bloater")
	# с 4-й локации в 1-й волне к заражённым присоединяются бандиты
	if n > 15 and n % WAVES_PER_LOCATION == 1:
		var squad := bandit_squad(n)
		for i in mini(squad.size(), 1 + n / 12):
			list.append(squad[i])
	return list

# Отряд бандитов: чем дальше, тем больше и лучше вооружены.
#   локация 1 — пистолеты и громила, 2 — + дробовик, 3+ — + автоматчики
func bandit_squad(n: int) -> Array[String]:
	var loc := (n - 1) / WAVES_PER_LOCATION
	var count := mini(3 + loc, 9)
	var pool: Array[String] = ["b_pistol", "b_pistol", "b_brute"]
	if loc >= 1:
		pool.append_array(["b_shotgun", "b_pistol"])
	if loc >= 2:
		pool.append_array(["b_rifle", "b_rifle", "b_shotgun"])
	if loc >= 5:
		pool.append_array(["b_rifle", "b_brute"])
	var list: Array[String] = []
	list.append("b_pistol")
	if loc >= 2:
		list.append("b_rifle")
	while list.size() < count:
		list.append(pool.pick_random())
	return list

func spawn_enemy(kind := "clicker") -> void:
	var e: Node3D
	if kind.begins_with("b_"):          # бандит: "b_rifle" -> тип "rifle"
		e = Bandit.new()
		e.kind = kind.substr(2)
	else:
		e = ENEMY_SCENE.instantiate()
		e.kind = kind
	# Позицию ставим ДО add_child: иначе враг на миг окажется в точке (0,0,0)
	# и выбросит игрока физикой (Main стоит в нуле, так что position = global_position)
	e.position = level.get_spawn_point(player.global_position)
	add_child(e)
	e.died.connect(_on_enemy_died)
	if e.get("is_boss"):
		boss = e
		boss_max = maxi(1, int(e.health))

# Враг посреди волны (крысиный король зовёт бегунов): сразу знает, где игрок
func spawn_extra(kind: String, pos: Vector3) -> void:
	if game_over:
		return
	var e: Node3D = ENEMY_SCENE.instantiate()
	e.kind = kind
	e.position = pos + Vector3(0, 0.3, 0)
	enemies_alive += 1
	add_child(e)
	e.died.connect(_on_enemy_died)
	e.hear(player.global_position, 1000.0, true)
	update_hud()

func _on_enemy_died() -> void:
	kills += 1
	enemies_alive -= 1
	update_hud()
	if enemies_alive <= 0:
		_wave_break()

# ---------- Передышка между волнами: ящики и обратный отсчёт ----------

func _wave_break() -> void:
	in_break = true
	Sfx.play(self, SND_WAVE_CLEAR, -4.0, 1.0, 0.0)
	await get_tree().create_timer(0.6).timeout
	if game_over or not is_inside_tree():
		return
	if wave % WAVES_PER_LOCATION == 0:
		_next_location()
		return
	var crates := wave % CRATE_EVERY == 0
	_spawn_map_loot(2)
	if crates:
		_spawn_crate("medkit")
		_spawn_crate("ammo")
	await _countdown(BREAK_TIME, "Волна %d пройдена!" % wave, crates)
	if game_over or not is_inside_tree():
		return
	start_next_wave()

func _countdown(seconds: int, header: String, crates: bool) -> void:
	break_label.show()
	for s in range(seconds, 0, -1):
		if crates:
			break_label.text = "%s\nЯщики с припасами в центре карты\nСледующая волна через %d" % [header, s]
		else:
			break_label.text = "%s\nСледующая волна через %d" % [header, s]
		await get_tree().create_timer(1.0).timeout
		if game_over or not is_inside_tree():
			break_label.hide()
			return
	break_label.hide()

# ---------- Переход на следующую локацию ----------

# N — для проверки: сразу перейти на следующую локацию (во время боя)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_N:
		if game_over or in_break or location >= LOCATIONS.size() - 1:
			return
		for e in get_tree().get_nodes_in_group("enemy"):
			e.queue_free()
		enemies_alive = 0
		wave = (location + 1) * WAVES_PER_LOCATION
		update_hud()
		in_break = true
		_next_location()

func _next_location() -> void:
	if location >= LOCATIONS.size() - 1:
		_victory()
		return
	break_label.show()
	for s in range(5, 0, -1):
		break_label.text = "Локация пройдена!\nПереход в следующую локацию через %d" % s
		await get_tree().create_timer(1.0).timeout
		if game_over or not is_inside_tree():
			break_label.hide()
			return
	break_label.hide()
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.7)
	await tw.finished
	load_location(location + 1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_spawn_map_loot(LOOT_ON_MAP)
	tw = create_tween()
	tw.tween_property(fade, "color:a", 0.0, 1.0)
	_announce(str(level.get("location_name")))
	if wave % CRATE_EVERY == 0:
		_spawn_crate("medkit")
		_spawn_crate("ammo")
	await _countdown(ARRIVE_BREAK, "Локация %d из %d: %s" % [location + 1, LOCATIONS.size(), str(level.get("location_name"))], wave % CRATE_EVERY == 0)
	if game_over or not is_inside_tree():
		return
	start_next_wave()

# Убрать старую локацию со всем мусором (ящики, трофеи, кровь, облака) и построить новую
func load_location(i: int) -> void:
	location = i
	for c in get_children():
		if c == player or c == level or c is CanvasLayer or c is AudioStreamPlayer:
			continue
		c.queue_free()
	var old := level
	remove_child(old)
	old.queue_free()
	var nl := Node3D.new()
	nl.set_script(load(LOCATIONS[i]))
	nl.name = "Level"
	add_child(nl)
	move_child(nl, 0)
	Settings.apply_shadows(nl)
	level = nl
	player.global_position = Vector3(0, 1.1, 0)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	update_hud()

# Разложить материалы (тряпки, спирт, лезвия, взрывчатку) по карте — в стороне от игрока
func _spawn_map_loot(n: int) -> void:
	var have := get_tree().get_nodes_in_group("map_loot").size()
	for i in mini(n, LOOT_MAX - have):
		var spot = _find_crate_spot(Vector2(5.0, 26.0))
		if spot == null:
			continue
		var pk := Pickup.new()
		pk.what = LOOT_KINDS.pick_random()
		pk.permanent = true
		pk.position = spot
		pk.add_to_group("map_loot")
		add_child(pk)

func _make_fade() -> void:
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(fade)

func _victory() -> void:
	won = true
	_on_player_died()
	$UI/GameOver/Box/TitleLabel.text = "ВЫ ВЫЖИЛИ"
	best_label.text = "Победа! Все %d локаций пройдены" % LOCATIONS.size()

func _spawn_crate(kind: String) -> void:
	if get_tree().get_nodes_in_group("crate").size() >= MAX_CRATES:
		return
	var p = _find_crate_spot()
	if p == null:
		return
	var c := SupplyCrate.new()
	c.kind = kind
	c.position = p
	c.rotation.y = randf() * TAU
	add_child(c)

# Свободное место недалеко от центра: не в игроке, не в машине, не в другом ящике
func _find_crate_spot(radius := CRATE_RADIUS) -> Variant:
	var space := get_world_3d().direct_space_state
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3, 0.8, 1.3)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = 1 | 2
	for i in 40:
		var a := randf() * TAU
		var r := randf_range(radius.x, radius.y)
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		if Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() < 2.0:
			continue
		q.transform = Transform3D(Basis(), p + Vector3(0, 0.5, 0))
		if space.intersect_shape(q, 1).is_empty():
			return p
	return null

func _make_break_label() -> void:
	break_label = Label.new()
	break_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	break_label.offset_left = -500.0
	break_label.offset_right = 500.0
	break_label.offset_top = 90.0
	break_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	break_label.add_theme_font_size_override("font_size", 22)
	break_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	break_label.add_theme_color_override("font_outline_color", Color.BLACK)
	break_label.add_theme_constant_override("outline_size", 8)
	break_label.hide()
	$UI.add_child(break_label)

# ---------- Полоска здоровья босса ----------

func _make_boss_bar() -> void:
	boss_label = Label.new()
	boss_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_label.offset_left = -300.0
	boss_label.offset_right = 300.0
	boss_label.offset_top = 14.0
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override("font_size", 24)
	boss_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.7))
	boss_label.add_theme_color_override("font_outline_color", Color.BLACK)
	boss_label.add_theme_constant_override("outline_size", 6)
	boss_label.hide()
	$UI.add_child(boss_label)
	boss_bar = ProgressBar.new()
	boss_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_bar.offset_left = -300.0
	boss_bar.offset_right = 300.0
	boss_bar.offset_top = 48.0
	boss_bar.offset_bottom = 66.0
	boss_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.05, 0.05, 0.8)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.75, 0.12, 0.08)
	boss_bar.add_theme_stylebox_override("background", bg)
	boss_bar.add_theme_stylebox_override("fill", fg)
	boss_bar.hide()
	$UI.add_child(boss_bar)

func _update_boss_bar() -> void:
	var alive: bool = is_instance_valid(boss) and not boss.get("is_dead")
	boss_bar.visible = alive
	boss_label.visible = alive
	if alive:
		boss_label.text = str(boss.cfg.get("name", "Босс"))
		boss_bar.max_value = boss_max
		boss_bar.value = maxf(0.0, float(boss.health))

# ---------- Музыка: спокойная гитара / тревожная боевая ----------

func _make_music() -> void:
	var calm: AudioStreamOggVorbis = MUSIC_CALM
	var fight: AudioStreamOggVorbis = MUSIC_COMBAT
	calm.loop = true
	fight.loop = true
	music_calm = AudioStreamPlayer.new()
	music_calm.stream = MUSIC_CALM
	music_combat = AudioStreamPlayer.new()
	music_combat.stream = MUSIC_COMBAT
	for m in [music_calm, music_combat]:
		m.process_mode = Node.PROCESS_MODE_ALWAYS
		m.volume_db = -80.0
		add_child(m)
		m.play()
	_update_music(0.0)

# Есть ли враг, который сейчас гонится за игроком
func any_enemy_aware() -> bool:
	if is_instance_valid(boss) and not boss.get("is_dead"):
		return true
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.get("is_dead") and e.has_method("is_aware") and e.is_aware():
			return true
	return false

func _update_music(delta: float) -> void:
	notice_cd -= delta
	var combat := started and not game_over and not in_break and any_enemy_aware()
	if combat:
		if combat_hold <= 0.0 and combat_mix < 0.2 and notice_cd <= 0.0:
			Sfx.play(self, SND_NOTICE, -6.0, 1.0, 0.0)
			notice_cd = 20.0
		combat_hold = 5.0
	else:
		combat_hold -= delta
	var target := 1.0 if combat_hold > 0.0 else 0.0
	combat_mix = move_toward(combat_mix, target, delta / (1.5 if target > combat_mix else 4.0))
	var base := linear_to_db(maxf(Settings.music, 0.0001)) - 6.0
	music_combat.volume_db = base + linear_to_db(maxf(combat_mix, 0.0001))
	music_calm.volume_db = base + linear_to_db(maxf(1.0 - combat_mix, 0.0001))

func _make_top_hud() -> void:
	wave_label.visible = false
	kills_label.visible = false
	top_panel = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.05, 0.045, 0.38)
	st.border_color = Color(1.0, 0.76, 0.35, 0.4)
	st.border_width_right = 2
	st.set_corner_radius_all(5)
	st.set_content_margin_all(7)
	st.content_margin_left = 12
	st.content_margin_right = 10
	top_panel.add_theme_stylebox_override("panel", st)
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_panel.offset_right = -16
	top_panel.offset_top = 14
	top_panel.offset_left = -16
	top_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(top_panel)
	$UI.move_child(top_panel, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	top_panel.add_child(v)
	top_loc = _hud_label(11, Color(0.62, 0.6, 0.55))
	top_wave = _hud_label(19, Color(1.0, 0.76, 0.35))
	top_info = _hud_label(12, Color(0.94, 0.92, 0.86))
	for l in [top_loc, top_wave, top_info]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.add_child(l)

func _hud_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	return l

func update_hud() -> void:
	wave_label.text = "Волна: " + str(wave)
	kills_label.text = "Убийства: " + str(kills)
	if top_wave:
		top_loc.text = "%s  ·  %d/%d" % [str(level.get("location_name")).to_upper(), location + 1, LOCATIONS.size()]
		var in_loc := (wave - 1) % WAVES_PER_LOCATION + 1 if wave > 0 else 0
		top_wave.text = "ВОЛНА %d  (%d/%d)" % [wave, in_loc, WAVES_PER_LOCATION]
		top_info.text = "Врагов: %d     Убийств: %d" % [maxi(enemies_alive, 0), kills]

# ---------- Надпись по центру экрана ----------

func _make_announce() -> void:
	announce = Label.new()
	announce.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	announce.offset_top = 120.0
	announce.grow_horizontal = Control.GROW_DIRECTION_BOTH
	announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announce.add_theme_font_size_override("font_size", 38)
	announce.add_theme_color_override("font_color", Color(1, 0.35, 0.25))
	announce.add_theme_color_override("font_outline_color", Color.BLACK)
	announce.add_theme_constant_override("outline_size", 7)
	announce.modulate.a = 0.0
	$UI.add_child(announce)

func _announce(text: String) -> void:
	announce.text = text
	var tw := create_tween()
	tw.tween_property(announce, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.0)
	tw.tween_property(announce, "modulate:a", 0.0, 0.6)

# ---------- Смерть игрока и рекорд ----------

func _on_player_died() -> void:
	game_over = true
	var run := {
		"wave": wave, "kills": kills, "location": location + 1,
		"location_name": str(level.get("location_name")),
		"headshots": RunStats.headshots, "accuracy": RunStats.accuracy(),
		"fire_kills": RunStats.fire_kills, "time": RunStats.time,
		"won": won, "date": _today(),
	}
	var best := load_best()
	var new_record := _better(run, best)
	_save_run(run, new_record)
	if new_record:
		best = run

	stats_label.text = "Локация %d/%d · Волна %d\nУбийства: %d    В голову: %d\nТочность: %d%%    Сожжено: %d    Время: %s" % [
		location + 1, LOCATIONS.size(), wave, kills, RunStats.headshots,
		RunStats.accuracy(), RunStats.fire_kills, RunStats.time_text(RunStats.time)]
	if new_record:
		best_label.text = "Новый рекорд!"
	else:
		best_label.text = "Рекорд: волна %d, убийств %d" % [best.wave, best.kills]

	if not won:
		Sfx.play(self, SND_GAME_OVER, -3.0, 1.0, 0.0)
	game_over_screen.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true   # замораживаем врагов и игрока
	restart_button.grab_focus()

func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%02d.%02d.%d" % [d.day, d.month, d.year]

# Лучше ли забег a, чем b: победа > дальше по волнам > больше убийств
func _better(a: Dictionary, b: Dictionary) -> bool:
	if a.get("won", false) != b.get("won", false):
		return a.get("won", false)
	if a.wave != b.wave:
		return a.wave > b.wave
	return a.kills > b.kills

func _on_restart_pressed() -> void:
	skip_menu = true
	get_tree().paused = false
	get_tree().reload_current_scene()

const BEST_KEYS := ["wave", "kills", "location", "location_name", "headshots", "accuracy", "fire_kills", "time", "won", "date"]

func load_best() -> Dictionary:
	var best := {"wave": 0, "kills": 0}
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return best
	for k in BEST_KEYS:
		if cfg.has_section_key("best", k):
			best[k] = cfg.get_value("best", k)
	return best

# Записать забег: общий счётчик и (если рекорд) лучший забег
func _save_run(run: Dictionary, new_record: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	if new_record:
		for k in BEST_KEYS:
			cfg.set_value("best", k, run[k])
	cfg.set_value("total", "runs", cfg.get_value("total", "runs", 0) + 1)
	cfg.set_value("total", "kills", cfg.get_value("total", "kills", 0) + run.kills)
	cfg.set_value("total", "time", cfg.get_value("total", "time", 0.0) + run.time)
	cfg.save(SAVE_PATH)

# Текст для меню «Лучший забег»
func best_text() -> String:
	var b := load_best()
	if b.wave <= 0:
		return "Пока ни одного забега.\nНачните новую игру!"
	var lines: Array[String] = []
	if b.get("won", false):
		lines.append("ВСЕ ЛОКАЦИИ ПРОЙДЕНЫ!")
	if b.has("location"):
		lines.append("Волна: %d  (%s, %d/%d)" % [b.wave, b.get("location_name", ""), b.location, LOCATIONS.size()])
	else:
		lines.append("Волна: %d" % b.wave)
	lines.append("Убийства: %d" % b.kills)
	if b.has("headshots"):
		lines.append("В голову: %d" % b.headshots)
		lines.append("Точность: %d%%" % b.get("accuracy", 0))
		lines.append("Сожжено молотовом: %d" % b.get("fire_kills", 0))
		lines.append("Время: %s" % RunStats.time_text(b.get("time", 0.0)))
		lines.append("Дата: %s" % b.get("date", ""))
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK and cfg.has_section("total"):
		lines.append("")
		lines.append("Всего забегов: %d    Всего убийств: %d" % [cfg.get_value("total", "runs", 0), cfg.get_value("total", "kills", 0)])
		lines.append("Всего в игре: %s" % RunStats.time_text(cfg.get_value("total", "time", 0.0)))
	return "\n".join(lines)
