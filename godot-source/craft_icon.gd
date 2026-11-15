extends Control
# Иконка, нарисованная кодом: материалы и то, что из них крафтится

var kind := "medkit"
var dim := false

func _init(k := "medkit", sz := 64.0) -> void:
	kind = k
	custom_minimum_size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var s := size.x / 64.0
	var a := 0.35 if dim else 1.0
	var c := func(col: Color) -> Color: return Color(col.r, col.g, col.b, col.a * a)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	match kind:
		"medkit":
			draw_rect(Rect2(10, 18, 44, 34), c.call(Color(0.92, 0.9, 0.85)))
			draw_rect(Rect2(24, 12, 16, 8), c.call(Color(0.6, 0.58, 0.55)))
			draw_rect(Rect2(28, 24, 8, 22), c.call(Color(0.85, 0.12, 0.1)))
			draw_rect(Rect2(21, 31, 22, 8), c.call(Color(0.85, 0.12, 0.1)))
		"molotov":
			_bottle(c, Color(0.35, 0.5, 0.28))
			draw_rect(Rect2(28, 4, 8, 10), c.call(Color(0.75, 0.68, 0.55)))
			draw_colored_polygon(PackedVector2Array([Vector2(32, -6), Vector2(38, 4), Vector2(32, 8), Vector2(26, 4)]), c.call(Color(1.0, 0.6, 0.15)))
		"nailbomb":
			draw_rect(Rect2(16, 20, 32, 34), c.call(Color(0.55, 0.57, 0.6)))
			draw_rect(Rect2(16, 20, 32, 5), c.call(Color(0.4, 0.42, 0.45)))
			for i in 5:
				var x := 18.0 + i * 7.0
				draw_line(Vector2(x, 30 + (i % 2) * 8), Vector2(x - 6, 26 + (i % 2) * 8), c.call(Color(0.85, 0.85, 0.9)), 2.0)
			draw_line(Vector2(32, 20), Vector2(40, 8), c.call(Color(0.7, 0.55, 0.3)), 2.5)
			draw_circle(Vector2(41, 7), 3.0, c.call(Color(1.0, 0.7, 0.2)))
		"rag":
			var pts := PackedVector2Array()
			for i in 9:
				pts.append(Vector2(10 + i * 5.5, 22 + sin(i * 1.3) * 4))
			for i in 9:
				pts.append(Vector2(54 - i * 5.5, 44 + sin(i * 1.1 + 1.0) * 4))
			draw_colored_polygon(pts, c.call(Color(0.78, 0.72, 0.6)))
			draw_line(Vector2(14, 33), Vector2(50, 31), c.call(Color(0.6, 0.55, 0.45)), 2.0)
		"alcohol":
			_bottle(c, Color(0.55, 0.72, 0.85))
			draw_rect(Rect2(27, 6, 10, 6), c.call(Color(0.3, 0.3, 0.35)))
			draw_rect(Rect2(22, 36, 20, 10), c.call(Color(0.95, 0.95, 0.9)))
		"blade":
			draw_colored_polygon(PackedVector2Array([Vector2(8, 40), Vector2(48, 20), Vector2(56, 22), Vector2(14, 46)]), c.call(Color(0.82, 0.84, 0.88)))
			draw_line(Vector2(10, 42), Vector2(52, 21), c.call(Color(1, 1, 1)), 1.5)
		"explosive":
			draw_rect(Rect2(12, 26, 40, 16), c.call(Color(0.75, 0.22, 0.1)))
			draw_rect(Rect2(12, 30, 40, 4), c.call(Color(0.55, 0.15, 0.08)))
			draw_line(Vector2(52, 34), Vector2(58, 22), c.call(Color(0.7, 0.6, 0.4)), 2.0)
			draw_circle(Vector2(58, 21), 3.0, c.call(Color(1.0, 0.75, 0.2)))

func _bottle(c: Callable, col: Color) -> void:
	draw_rect(Rect2(20, 26, 24, 32), c.call(col))
	draw_colored_polygon(PackedVector2Array([Vector2(20, 26), Vector2(28, 16), Vector2(36, 16), Vector2(44, 26)]), c.call(col))
	draw_rect(Rect2(28, 10, 8, 8), c.call(col.darkened(0.15)))
	draw_rect(Rect2(23, 30, 4, 22), c.call(Color(1, 1, 1, 0.35)))
