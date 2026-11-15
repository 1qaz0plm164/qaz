extends Control
# Колесо выбора оружия, как в The Last of Us: зажал E — появилось колесо,
# двигаешь мышь в сторону нужного оружия, отпустил E — оружие выбрано.
# Рисуется кодом, никаких картинок не нужно.

const R_IN := 75.0
const R_OUT := 200.0

var names: Array = []
var ammo_texts: Array = []
var ids: Array = []
var selected := 0
var current := 0
var cursor := Vector2.ZERO

# Силуэты оружия (дуло смотрит вправо), координаты в пикселях от центра иконки
const ICONS := {
	"pistol": [
		[Vector2(-30, -10), Vector2(34, -10), Vector2(34, 4), Vector2(-30, 4)],
		[Vector2(-30, 4), Vector2(-10, 4), Vector2(-15, 34), Vector2(-33, 34)],
		[Vector2(-8, 4), Vector2(8, 4), Vector2(8, 14), Vector2(-8, 14)],
	],
	"shotgun": [
		[Vector2(-34, -10), Vector2(-10, -10), Vector2(-10, 8), Vector2(-34, 8)],
		[Vector2(-10, -8), Vector2(78, -8), Vector2(78, -2), Vector2(-10, -2)],
		[Vector2(-10, 0), Vector2(70, 0), Vector2(70, 5), Vector2(-10, 5)],
		[Vector2(14, 5), Vector2(46, 5), Vector2(46, 13), Vector2(14, 13)],
		[Vector2(-34, -6), Vector2(-76, 4), Vector2(-76, 20), Vector2(-34, 8)],
		[Vector2(-30, 8), Vector2(-16, 8), Vector2(-20, 28), Vector2(-34, 28)],
	],
	"rifle": [
		[Vector2(-26, -11), Vector2(34, -11), Vector2(34, 4), Vector2(-26, 4)],
		[Vector2(34, -8), Vector2(60, -8), Vector2(60, 2), Vector2(34, 2)],
		[Vector2(60, -5), Vector2(84, -5), Vector2(84, -1), Vector2(60, -1)],
		[Vector2(-26, -8), Vector2(-76, 0), Vector2(-76, 16), Vector2(-26, 6)],
		[Vector2(2, 4), Vector2(16, 4), Vector2(10, 32), Vector2(-4, 32)],
		[Vector2(-24, 4), Vector2(-12, 4), Vector2(-16, 22), Vector2(-28, 22)],
		[Vector2(-10, -17), Vector2(14, -17), Vector2(14, -11), Vector2(-10, -11)],
	],
	"sniper": [
		[Vector2(-30, -6), Vector2(30, -6), Vector2(30, 4), Vector2(-30, 4)],
		[Vector2(30, -4), Vector2(96, -4), Vector2(96, 1), Vector2(30, 1)],
		[Vector2(-30, -4), Vector2(-84, 2), Vector2(-84, 18), Vector2(-30, 6)],
		[Vector2(-24, -20), Vector2(26, -20), Vector2(26, -12), Vector2(-24, -12)],
		[Vector2(-32, -22), Vector2(-24, -22), Vector2(-24, -10), Vector2(-32, -10)],
		[Vector2(26, -23), Vector2(36, -23), Vector2(36, -9), Vector2(26, -9)],
		[Vector2(-14, 4), Vector2(-2, 4), Vector2(-6, 22), Vector2(-18, 22)],
		[Vector2(-4, -12), Vector2(4, -12), Vector2(4, -6), Vector2(-4, -6)],
	],
	"nailbomb": [
		[Vector2(-20, -14), Vector2(20, -14), Vector2(20, 26), Vector2(-20, 26)],
		[Vector2(-26, -6), Vector2(-20, -6), Vector2(-20, -3), Vector2(-26, -3)],
		[Vector2(20, 4), Vector2(28, 4), Vector2(28, 7), Vector2(20, 7)],
		[Vector2(-26, 14), Vector2(-20, 14), Vector2(-20, 17), Vector2(-26, 17)],
		[Vector2(20, 18), Vector2(27, 18), Vector2(27, 21), Vector2(20, 21)],
		[Vector2(-4, -22), Vector2(4, -22), Vector2(4, -14), Vector2(-4, -14)],
	],
	"smoke": [
		[Vector2(-13, -16), Vector2(13, -16), Vector2(13, 32), Vector2(-13, 32)],
		[Vector2(-8, -26), Vector2(8, -26), Vector2(8, -16), Vector2(-8, -16)],
		[Vector2(13, -14), Vector2(18, -14), Vector2(18, 8), Vector2(13, 8)],
	],
	"molotov": [
		[Vector2(-14, -6), Vector2(14, -6), Vector2(16, 34), Vector2(-16, 34)],
		[Vector2(-6, -24), Vector2(6, -24), Vector2(6, -6), Vector2(-6, -6)],
		[Vector2(-5, -36), Vector2(7, -38), Vector2(4, -24), Vector2(-6, -24)],
	],
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func set_data(p_names: Array, p_ids: Array, p_ammo: Array) -> void:
	names = p_names
	ids = p_ids
	ammo_texts = p_ammo
	queue_redraw()

func open(current_index: int) -> void:
	current = current_index
	selected = current_index
	cursor = Vector2.ZERO
	visible = true
	queue_redraw()

func close() -> int:
	visible = false
	return selected

# Двигаем «курсор» колеса мышью
func move_cursor(relative: Vector2) -> bool:
	cursor += relative
	cursor = cursor.limit_length(R_OUT * 0.85)
	var old := selected
	if cursor.length() > 30.0 and names.size() > 0:
		selected = _slot_at(cursor)
	queue_redraw()
	return selected != old

func select_slot(i: int) -> void:
	selected = clampi(i, 0, maxi(names.size() - 1, 0))
	queue_redraw()

func _slot_at(v: Vector2) -> int:
	var n := names.size()
	var step := TAU / n
	var a := wrapf(v.angle() + PI * 0.5 + step * 0.5, 0.0, TAU)   # 0 — сверху
	return int(a / step) % n

func _slot_angle(i: int) -> float:
	return -PI * 0.5 + TAU * i / maxi(names.size(), 1)

func _sector(c: Vector2, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 18
	for s in steps + 1:
		var a := lerpf(a0, a1, float(s) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * R_OUT)
	for s in steps + 1:
		var a := lerpf(a1, a0, float(s) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * R_IN)
	return pts

# Аптечка: белая коробка с красным крестом
func _draw_medkit(at: Vector2, sel: bool) -> void:
	var a := 1.0 if sel else 0.85
	draw_rect(Rect2(at + Vector2(-26, -18), Vector2(52, 36)), Color(0.92, 0.9, 0.85, a))
	draw_rect(Rect2(at + Vector2(-9, -24), Vector2(18, 7)), Color(0.92, 0.9, 0.85, a))   # ручка
	draw_rect(Rect2(at + Vector2(-5, -13), Vector2(10, 26)), Color(0.8, 0.12, 0.1, a))
	draw_rect(Rect2(at + Vector2(-13, -5), Vector2(26, 10)), Color(0.8, 0.12, 0.1, a))

func _draw() -> void:
	var n := names.size()
	if n == 0:
		return
	var c := size * 0.5
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var step := TAU / n

	for i in n:
		var ang := _slot_angle(i)
		var sel := i == selected
		var pts := _sector(c, ang - step * 0.5 + 0.03, ang + step * 0.5 - 0.03)
		draw_colored_polygon(pts, Color(0.95, 0.95, 0.9, 0.22) if sel else Color(0.05, 0.05, 0.05, 0.6))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(1, 1, 1, 0.95) if sel else Color(1, 1, 1, 0.25), 3.0 if sel else 1.5)

		# силуэт оружия
		var mid := c + Vector2(cos(ang), sin(ang)) * (R_IN + R_OUT) * 0.5
		var col := Color(1, 1, 1, 1.0) if sel else Color(0.75, 0.75, 0.72, 0.9)
		if ids[i] == "medkit":
			_draw_medkit(mid + Vector2(0, -8), sel)
		if ids[i] == "molotov":    # огонёк на тряпке
			draw_circle(mid + Vector2(1, -36) * 0.72 + Vector2(0, -8), 6.0, Color(1.0, 0.55, 0.15, 1.0 if sel else 0.8))
		var shapes: Array = ICONS.get(ids[i], [])
		for poly in shapes:
			var moved := PackedVector2Array()
			for p in poly:
				moved.append(mid + p * (0.72 if n <= 6 else 0.55) + Vector2(0, -8))
			draw_colored_polygon(moved, col)
		# номер, название и патроны
		draw_string(font, mid + Vector2(-R_OUT * 0.2, -46), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.8))
		draw_string(font, mid + Vector2(-60, 52), ammo_texts[i], HORIZONTAL_ALIGNMENT_CENTER, 120, 22, col)

	# центр: название выбранного
	draw_circle(c, R_IN - 8.0, Color(0, 0, 0, 0.55))
	draw_string(font, c + Vector2(-R_IN + 8.0, 8), names[selected], HORIZONTAL_ALIGNMENT_CENTER, (R_IN - 8.0) * 2.0, 24, Color(1, 1, 1, 1))
	# «курсор» выбора
	draw_circle(c + cursor, 6.0, Color(1, 1, 1, 0.9))
