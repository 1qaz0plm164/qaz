extends CanvasLayer
# Убежище между локациями: верстак (улучшения оружия за детали) и торговец.
# main.gd: var h := Hideout.new(); h.player = player; h.next_name = "..."; add_child(h); await h.done

signal done

const Weapons := preload("res://weapons.gd")
const Sfx := preload("res://sfx.gd")
const SND_CRAFT := preload("res://sounds/craft.wav")
const SND_EMPTY := preload("res://sounds/empty.wav")

const ACCENT := Color(1.0, 0.78, 0.4)
const TEXT := Color(0.92, 0.9, 0.85)
const MAX_LEVEL := 2
const UPGRADE_COST := [30, 60]           # цена 1-го и 2-го уровня
# Улучшения верстака: что меняется в таблице оружия на каждом уровне
const UPGRADES := [
	{"id": "mag", "name": "Магазин", "desc": "+25% патронов"},
	{"id": "reload", "name": "Перезарядка", "desc": "на 20% быстрее"},
	{"id": "spread", "name": "Точность", "desc": "разброс −30%"},
	{"id": "damage", "name": "Урон", "desc": "+15%"},
]
const UPGRADABLE := ["pistol", "shotgun", "rifle", "sniper"]
# Торговец: [что, название, цена, сколько]
const TRADES := [
	["ammo_shotgun", "Патроны для дробовика ×8", 15, 8],
	["ammo_rifle", "Патроны для винтовки ×30", 15, 30],
	["ammo_sniper", "Патроны для снайперки ×5", 20, 5],
	["medkit", "Аптечка", 25, 1],
	["molotov", "Коктейль Молотова", 25, 1],
	["shiv", "Заточка", 20, 1],
	["plank", "Доска с гвоздями", 15, 1],
	["rag", "Тряпка", 10, 1],
	["alcohol", "Спирт", 10, 1],
	["blade", "Лезвие", 10, 1],
	["tape", "Лента", 10, 1],
	["explosive", "Взрывчатка", 15, 1],
]

var player: Node
var next_name := ""
var parts_label: Label
var bench_box: VBoxContainer
var trade_box: VBoxContainer
var status_label: Label

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.health = player.MAX_HEALTH
	player.heal(0)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.05, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 40
	root.offset_right = -40
	root.offset_top = 24
	root.offset_bottom = -24
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	root.add_child(_label("Убежище", 46, ACCENT))
	var sub := _label("Передышка. Здоровье восстановлено. Дальше: %s" % next_name, 22, TEXT)
	root.add_child(sub)
	parts_label = _label("", 28, ACCENT)
	root.add_child(parts_label)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 40)
	root.add_child(cols)
	bench_box = _column(cols, "Верстак — улучшения оружия")
	trade_box = _column(cols, "Торговец")
	status_label = _label("", 22, Color(0.7, 1.0, 0.7))
	root.add_child(status_label)
	var go := Button.new()
	go.text = "Отправиться в путь"
	go.add_theme_font_size_override("font_size", 30)
	go.custom_minimum_size = Vector2(380, 56)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(_leave)
	root.add_child(go)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()

func _column(parent: Control, title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_label(title, 28, ACCENT))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	sc.add_child(box)
	parent.add_child(col)
	return box

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, enabled: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b

func _refresh() -> void:
	parts_label.text = "Детали: %d" % player.parts
	for c in bench_box.get_children():
		c.queue_free()
	for c in trade_box.get_children():
		c.queue_free()
	for i in player.weapons.size():
		var w: Dictionary = player.weapons[i]
		if not UPGRADABLE.has(w.id):
			continue
		bench_box.add_child(_label(w.name, 22, TEXT))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bench_box.add_child(grid)
		for u in UPGRADES:
			if u.id == "spread" and float(w.spread) <= 0.0:
				continue
			var lvl := upgrade_level(w.id, u.id)
			var t: String
			if lvl >= MAX_LEVEL:
				t = "%s — макс." % u.name
			else:
				t = "%s %s (%s) — %d дет." % [u.name, "I".repeat(lvl + 1), u.desc, UPGRADE_COST[lvl]]
			grid.add_child(_button(t, lvl < MAX_LEVEL and player.parts >= UPGRADE_COST[mini(lvl, MAX_LEVEL - 1)],
				buy_upgrade.bind(w.id, u.id)))
	for tr in TRADES:
		var have := _trade_possible(tr[0])
		var t2 := "%s — %d дет." % [tr[1], tr[2]]
		if not have:
			t2 += "  (некуда)"
		trade_box.add_child(_button(t2, have and player.parts >= tr[2], buy.bind(tr[0])))

func upgrade_level(wid: String, uid: String) -> int:
	return int(player.upgrades.get("%s:%s" % [wid, uid], 0))

# Улучшить оружие: меняем свою (игрока) копию таблицы оружия
func buy_upgrade(wid: String, uid: String) -> bool:
	var lvl := upgrade_level(wid, uid)
	if lvl >= MAX_LEVEL or player.parts < UPGRADE_COST[lvl]:
		_fail()
		return false
	for i in player.weapons.size():
		var w: Dictionary = player.weapons[i]
		if w.id != wid:
			continue
		match uid:
			"mag":
				var nm := int(ceil(w.mag * 1.25))
				w.mag = nm
			"reload":
				w.reload_time = float(w.reload_time) * 0.8
				w.shell_time = float(w.shell_time) * 0.8
			"spread":
				w.spread = float(w.spread) * 0.7
			"damage":
				w.damage = int(round(w.damage * 1.15))
	player.parts -= UPGRADE_COST[lvl]
	player.upgrades["%s:%s" % [wid, uid]] = lvl + 1
	_ok("Улучшено!")
	return true

func _weapon_index(wid: String) -> int:
	for i in player.weapons.size():
		if player.weapons[i].id == wid:
			return i
	return -1

func _trade_possible(what: String) -> bool:
	if what.begins_with("ammo_"):
		var i := _weapon_index(what.substr(5))
		return i >= 0 and player.reserve[i] < player.weapons[i].reserve_max
	match what:
		"medkit":
			return player.medkits < player.MEDKIT_MAX
		"molotov":
			var i := _weapon_index("molotov")
			return i >= 0 and player.mags[i] < player.weapons[i].mag
		"shiv":
			return player.shivs < player.SHIV_MAX
		"plank":
			return player.plank_hp < player.PLANK_HITS
	return player.materials.has(what) and player.materials[what] < Weapons.MATERIAL_MAX

func buy(what: String) -> bool:
	var tr: Array = []
	for t in TRADES:
		if t[0] == what:
			tr = t
	if tr.is_empty() or player.parts < tr[2] or not _trade_possible(what):
		_fail()
		return false
	if what.begins_with("ammo_"):
		player.add_ammo(what.substr(5), tr[3])
	elif what == "medkit":
		player.add_medkit()
	elif what == "molotov":
		player.add_molotov()
	elif what == "shiv":
		player.shivs += 1
	else:
		player.add_material(what)
	player.parts -= tr[2]
	_ok("Куплено: %s" % tr[1])
	return true

func _ok(text: String) -> void:
	Sfx.play(self, SND_CRAFT, -4.0, 1.0, 0.0)
	status_label.text = text
	player._update_hud()
	_refresh()

func _fail() -> void:
	Sfx.play(self, SND_EMPTY, -6.0, 1.0, 0.0)

func _leave() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player._update_hud()
	done.emit()
	queue_free()
