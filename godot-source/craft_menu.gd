extends Control
# Меню крафта (зажать Tab): материалы сверху, карточки рецептов с клавишами 1, 2, 3...
# player.gd вызывает open(player) / close() / refresh(player)

const Weapons := preload("res://weapons.gd")
const CraftIcon := preload("res://craft_icon.gd")

const ACCENT := Color(1.0, 0.76, 0.35)
const OK := Color(0.55, 0.95, 0.5)
const BAD := Color(1.0, 0.45, 0.38)
const TEXT := Color(0.92, 0.9, 0.85)
const MUTED := Color(0.6, 0.58, 0.54)

var panel: PanelContainer
var mat_box: HBoxContainer
var card_box: HBoxContainer
var tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.45)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.09, 0.08, 0.07, 0.94), ACCENT.darkened(0.35), 2, 14, 22))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	# заголовок
	var head := HBoxContainer.new()
	var title := _label("КРАФТ", 34, ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var hint := _label("держите Tab  ·  нажмите цифру", 18, MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hint)
	v.add_child(head)
	var line := ColorRect.new()
	line.color = ACCENT.darkened(0.5)
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	# материалы
	v.add_child(_label("Материалы", 18, MUTED))
	mat_box = HBoxContainer.new()
	mat_box.add_theme_constant_override("separation", 10)
	v.add_child(mat_box)
	# рецепты
	v.add_child(_label("Рецепты", 18, MUTED))
	card_box = HBoxContainer.new()
	card_box.add_theme_constant_override("separation", 14)
	v.add_child(card_box)

func open(p: Node) -> void:
	refresh(p)
	if visible:
		return
	visible = true
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.94, 0.94)
	modulate.a = 0.0
	if tween:
		tween.kill()
	tween = create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	visible = false

func refresh(p: Node) -> void:
	for c in mat_box.get_children():
		mat_box.remove_child(c)
		c.queue_free()
	for c in card_box.get_children():
		card_box.remove_child(c)
		c.queue_free()
	for m in p.materials:
		mat_box.add_child(_material_chip(m, p.materials[m]))
	for i in Weapons.RECIPES.size():
		card_box.add_child(_recipe_card(i, Weapons.RECIPES[i], p))

func _material_chip(id: String, n: int) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.12), 1, 8, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	chip.add_child(h)
	var icon := CraftIcon.new(id, 40.0)
	icon.dim = n <= 0
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(_label(Weapons.MATERIAL_NAMES[id], 18, TEXT if n > 0 else MUTED))
	var pips := ""
	for k in Weapons.MATERIAL_MAX:
		pips += "●" if k < n else "○"
	v.add_child(_label(pips, 16, ACCENT if n > 0 else MUTED))
	h.add_child(v)
	return chip

func _recipe_card(i: int, r: Dictionary, p: Node) -> Control:
	var can: bool = p._can_craft(r)
	var full: bool = p._craft_target_full(r)
	var ready := can and not full
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(230, 0)
	card.add_theme_stylebox_override("panel", _box(
		Color(0.16, 0.2, 0.13, 0.9) if ready else Color(0.13, 0.12, 0.11, 0.9),
		OK.darkened(0.25) if ready else Color(1, 1, 1, 0.1), 2, 10, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	# клавиша + иконка
	var top := HBoxContainer.new()
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", _box(ACCENT if ready else Color(0.35, 0.33, 0.3), Color(0, 0, 0, 0), 0, 6, 0))
	badge.custom_minimum_size = Vector2(34, 34)
	var num := _label(str(i + 1), 22, Color(0.1, 0.08, 0.05))
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(num)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(badge)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var icon := CraftIcon.new(r.makes, 72.0)
	icon.dim = not ready
	top.add_child(icon)
	v.add_child(top)
	v.add_child(_label(r.name, 22, TEXT if ready else Color(0.75, 0.73, 0.7)))
	# ингредиенты: зелёные — есть, красные — нет
	var ing := HBoxContainer.new()
	ing.add_theme_constant_override("separation", 4)
	for k in r.needs.size():
		var m: String = r.needs[k]
		if k > 0:
			ing.add_child(_label("+", 17, MUTED))
		ing.add_child(_label(Weapons.MATERIAL_NAMES[m], 17, OK if p.materials[m] > 0 else BAD))
	v.add_child(ing)
	var have: Array = _have_text(r, p)
	v.add_child(_label("В запасе: %d / %d" % have, 16, MUTED))
	var status := "Готово — нажмите %d" % (i + 1)
	var col := OK
	if full:
		status = "Полный запас"
		col = MUTED
	elif not can:
		status = "Не хватает материалов"
		col = BAD
	v.add_child(_label(status, 17, col))
	return card

func _have_text(r: Dictionary, p: Node) -> Array:
	if r.makes == "medkit":
		return [p.medkits, p.MEDKIT_MAX]
	for k in p.weapons.size():
		if p.weapons[k].id == r.makes:
			return [p.mags[k], p.weapons[k].mag]
	return [0, 0]

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _box(bg: Color, border: Color, bw: int, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s
