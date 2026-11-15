extends Control
# Красивый HUD игрока: здоровье и аптечки (слева внизу), оружие и патроны (справа внизу),
# прицел по центру. Сам читает состояние игрока каждый кадр — player.gd только создаёт его.

const CraftIcon := preload("res://craft_icon.gd")

const ACCENT := Color(1.0, 0.76, 0.35)
const TEXT := Color(0.94, 0.92, 0.86)
const MUTED := Color(0.62, 0.6, 0.55)
const PANEL := Color(0.05, 0.05, 0.045, 0.38)

var player: Node
var hp_panel: PanelContainer
var hp_bar_bg: Control
var hp_value: Label
var med_icons: Array = []
var crouch_tag: Label
var ammo_panel: PanelContainer
var weapon_name: Label
var mag_label: Label
var reserve_label: Label
var throw_icon: Control
var pips: Control
var reload_label: Label
var cross: Control

var shown_hp := 100.0          # плавная полоска
var ghost_hp := 100.0          # «след» урона — светлая часть, догоняющая полоску
var last_hp := 100
var hurt_t := 0.0
var t := 0.0
var last_idx := -1
var last_weapon_id := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_health()
	_build_ammo()
	cross = Control.new()
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.draw.connect(_draw_cross)
	add_child(cross)
	last_hp = player.health
	shown_hp = player.health
	ghost_hp = player.health

# ---------- Здоровье ----------
func _build_health() -> void:
	hp_panel = _panel()
	hp_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hp_panel.offset_left = 16
	hp_panel.offset_bottom = -16
	hp_panel.offset_top = -16
	hp_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(hp_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	hp_panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)
	var heart := Control.new()
	heart.custom_minimum_size = Vector2(16, 16)
	heart.draw.connect(func() -> void: _draw_heart(heart))
	heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(heart)
	hp_value = _label("100", 19, TEXT)
	top.add_child(hp_value)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	crouch_tag = _label("ПРИСЕД", 11, Color(0.75, 0.82, 1.0))
	crouch_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(crouch_tag)
	hp_bar_bg = Control.new()
	hp_bar_bg.custom_minimum_size = Vector2(170, 7)
	hp_bar_bg.draw.connect(_draw_hp_bar)
	v.add_child(hp_bar_bg)
	var meds := HBoxContainer.new()
	meds.add_theme_constant_override("separation", 4)
	v.add_child(meds)
	for i in player.MEDKIT_MAX:
		var ic := CraftIcon.new("medkit", 20.0)
		meds.add_child(ic)
		med_icons.append(ic)

func _draw_heart(c: Control) -> void:
	var low: bool = player.health <= 30
	var pulse := 1.0 + (0.12 * sin(t * 8.0) if low else 0.0)
	var col := Color(0.9, 0.2, 0.18)
	var cx := c.size.x * 0.5
	var cy := c.size.y * 0.5
	var r := 3.8 * pulse
	c.draw_circle(Vector2(cx - r * 0.85, cy - r * 0.4), r, col)
	c.draw_circle(Vector2(cx + r * 0.85, cy - r * 0.4), r, col)
	c.draw_colored_polygon(PackedVector2Array([Vector2(cx - r * 1.8, cy - r * 0.1), Vector2(cx + r * 1.8, cy - r * 0.1), Vector2(cx, cy + r * 1.9)]), col)

func _draw_hp_bar() -> void:
	var c := hp_bar_bg
	var w := c.size.x
	var h := c.size.y
	var maxh: float = player.MAX_HEALTH
	c.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55))
	var f := clampf(shown_hp / maxh, 0.0, 1.0)
	var g := clampf(ghost_hp / maxh, 0.0, 1.0)
	if g > f:
		c.draw_rect(Rect2(w * f, 0, w * (g - f), h), Color(1.0, 0.85, 0.6, 0.8))
	var col := Color(0.35, 0.8, 0.35).lerp(Color(0.95, 0.75, 0.2), clampf((0.7 - f) / 0.35, 0.0, 1.0))
	if f < 0.35:
		col = Color(0.9, 0.2, 0.15).lerp(Color(1.0, 0.45, 0.35), 0.5 + 0.5 * sin(t * 8.0))
	c.draw_rect(Rect2(0, 0, w * f, h), col)
	c.draw_rect(Rect2(0, 0, w * f, h * 0.35), Color(1, 1, 1, 0.15))
	for k in range(1, 10):             # деления по 10 единиц
		c.draw_line(Vector2(w * k / 10.0, 0), Vector2(w * k / 10.0, h), Color(0, 0, 0, 0.35), 1.0)
	if hurt_t > 0.0:
		c.draw_rect(Rect2(0, 0, w, h), Color(1, 0.2, 0.1, hurt_t * 0.5), false, 1.0)

# ---------- Оружие и патроны ----------
func _build_ammo() -> void:
	ammo_panel = _panel()
	ammo_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_panel.offset_right = -16
	ammo_panel.offset_bottom = -16
	ammo_panel.offset_left = -16
	ammo_panel.offset_top = -16
	ammo_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ammo_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(ammo_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	ammo_panel.add_child(v)
	weapon_name = _label("ПИСТОЛЕТ", 12, ACCENT)
	weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(weapon_name)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	throw_icon = CraftIcon.new("molotov", 26.0)
	throw_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(throw_icon)
	mag_label = _label("15", 26, TEXT)
	row.add_child(mag_label)
	reserve_label = _label("/ ∞", 15, MUTED)
	reserve_label.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(reserve_label)
	pips = Control.new()
	pips.custom_minimum_size = Vector2(120, 4)
	pips.draw.connect(_draw_pips)
	v.add_child(pips)
	reload_label = _label("ПЕРЕЗАРЯДКА", 11, ACCENT)
	reload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(reload_label)

func _draw_pips() -> void:
	var w: Dictionary = player.weapons[player.idx]
	if w.get("throwable", false):
		return
	var cap: int = w.mag
	var n: int = player.mags[player.idx]
	var full_w := pips.size.x
	var gap := 1.0
	var pw := maxf(2.0, (full_w - gap * (cap - 1)) / cap)
	var low := n <= ceili(cap * 0.25)
	for k in cap:
		var x := full_w - (k + 1) * (pw + gap) + gap
		var on := k < n
		var col := (Color(1.0, 0.45, 0.35) if low else TEXT) if on else Color(1, 1, 1, 0.12)
		pips.draw_rect(Rect2(x, 0, pw, pips.size.y), col)

# ---------- Прицел ----------
func _draw_cross() -> void:
	var ch: Label = player.crosshair
	if not ch.visible:
		return
	var c := cross.size * 0.5
	var col := ch.modulate
	var outline := Color(0, 0, 0, 0.7 * col.a)
	if ch.text == "X":                 # попадание в голову
		for s in [Vector2(1, 1), Vector2(-1, 1)]:
			cross.draw_line(c - s * 11, c + s * 11, outline, 4.0)
			cross.draw_line(c - s * 10, c + s * 10, col, 2.0)
		return
	var sp := Vector2(player.velocity.x, player.velocity.z).length()
	var gap := 5.0 + minf(sp, 8.0) * 1.1
	if player.aiming:
		gap *= 0.5
	var radius := gap + 6.0
	cross.draw_arc(c, radius, 0.0, TAU, 64, outline, 3.5, true)
	cross.draw_arc(c, radius, 0.0, TAU, 64, Color(col.r,col.g,col.b,0.85*col.a), 1.5, true)
	cross.draw_circle(c, 2.0, outline, true, -1.0, true)
	cross.draw_circle(c, 0.9, col, true, -1.0, true)

# ---------- Обновление ----------
func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	t += delta
	var hp: int = player.health
	if hp < last_hp:
		hurt_t = 1.0
	last_hp = hp
	hurt_t = maxf(0.0, hurt_t - delta * 2.0)
	shown_hp = move_toward(shown_hp, hp, delta * 160.0)
	if ghost_hp < shown_hp:
		ghost_hp = shown_hp
	else:
		ghost_hp = move_toward(ghost_hp, shown_hp, delta * (0.0 if hurt_t > 0.5 else 45.0))
	hp_value.text = str(hp)
	hp_value.add_theme_color_override("font_color", TEXT.lerp(Color(1.0, 0.35, 0.3), 1.0 if hp <= 30 else hurt_t))
	hp_panel.position.x = 16 + (sin(t * 70.0) * 3.0 * hurt_t)
	for i in med_icons.size():
		var ic: Control = med_icons[i]
		if ic.dim != (i >= player.medkits):
			ic.dim = i >= player.medkits
			ic.queue_redraw()
	crouch_tag.visible = player.crouching

	var idx: int = player.idx
	var w: Dictionary = player.weapons[idx]
	var throwable: bool = w.get("throwable", false)
	weapon_name.text = str(w.name).to_upper()
	throw_icon.visible = throwable
	if throwable and last_weapon_id != w.id:
		throw_icon.kind = w.id
		throw_icon.queue_redraw()
	last_weapon_id = w.id
	var n: int = player.mags[idx]
	mag_label.text = ("×%d" % n) if throwable else str(n)
	var low: bool = (n == 0) if throwable else n <= ceili(w.mag * 0.25)
	mag_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35) if low else TEXT)
	reserve_label.visible = not throwable
	var res: int = player.reserve[idx]
	reserve_label.text = "/ ∞" if res < 0 else "/ %d" % res
	pips.visible = not throwable
	reload_label.visible = player.reloading
	reload_label.modulate.a = 0.55 + 0.45 * sin(t * 9.0)
	if idx != last_idx:
		last_idx = idx
		ammo_panel.modulate = Color(1.4, 1.3, 1.1)
		create_tween().tween_property(ammo_panel, "modulate", Color.WHITE, 0.3)
	hp_bar_bg.queue_redraw()
	pips.queue_redraw()
	cross.queue_redraw()
	(hp_value.get_parent().get_child(0) as Control).queue_redraw()

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.border_width_left = 2
	s.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.4)
	s.set_corner_radius_all(5)
	s.set_content_margin_all(8)
	s.content_margin_left = 10
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
