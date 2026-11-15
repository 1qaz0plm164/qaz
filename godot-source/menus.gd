extends CanvasLayer
# Главное меню, пауза (Esc), настройки и «Лучший забег». Всё рисуется кодом.
# Main подключается к сигналам и сам запускает/останавливает игру.

signal start_pressed
signal resume_pressed
signal restart_pressed
signal main_menu_pressed

const Settings := preload("res://settings.gd")

const ACCENT := Color(0.95, 0.72, 0.35)
const TEXT := Color(0.86, 0.84, 0.78)
const DIM := Color(0.55, 0.54, 0.5)

var mode := "hidden"              # main / pause / hidden
var can_pause: Callable           # Main говорит, можно ли сейчас ставить паузу
var best_text: Callable           # Main отдаёт текст лучшего забега
var orbit_cam: Camera3D           # камера, облетающая карту за главным меню
var orbit_t := 0.0

var root: Control
var shade: ColorRect
var left_panel: ColorRect
var title: Label
var subtitle: Label
var buttons: VBoxContainer
var side: PanelContainer          # правая панель: настройки или рекорд
var side_box: VBoxContainer
var side_open := ""
var fps_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.55)
	root.add_child(shade)

	# тёмная полоса слева с плавным краем
	left_panel = ColorRect.new()
	left_panel.anchor_bottom = 1.0
	left_panel.offset_right = 560.0
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	COLOR = vec4(0.02, 0.02, 0.018, 0.92 * (1.0 - smoothstep(0.55, 1.0, UV.x)));
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	left_panel.material = sm
	root.add_child(left_panel)

	title = _label("", 86, ACCENT)
	title.position = Vector2(70, 70)
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	root.add_child(title)
	subtitle = _label("", 24, DIM)
	subtitle.position = Vector2(76, 180)
	root.add_child(subtitle)

	buttons = VBoxContainer.new()
	buttons.position = Vector2(70, 270)
	buttons.add_theme_constant_override("separation", 6)
	root.add_child(buttons)

	side = PanelContainer.new()
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.anchor_top = 0.5
	side.anchor_bottom = 0.5
	side.offset_left = -600.0
	side.offset_right = -60.0
	side.offset_top = -230.0
	side.offset_bottom = 230.0
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.03, 0.03, 0.03, 0.88)
	ps.border_color = Color(ACCENT, 0.5)
	ps.border_width_left = 3
	ps.content_margin_left = 30
	ps.content_margin_right = 30
	ps.content_margin_top = 24
	ps.content_margin_bottom = 24
	side.add_theme_stylebox_override("panel", ps)
	side_box = VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 14)
	side.add_child(side_box)
	side.visible = false
	root.add_child(side)

	# FPS в углу (по настройке)
	fps_label = _label("", 18, Color(0.7, 1.0, 0.7))
	fps_label.position = Vector2(8, 620)
	fps_label.anchor_top = 1.0
	fps_label.anchor_bottom = 1.0
	fps_label.offset_top = -28
	fps_label.offset_left = 8
	add_child(fps_label)

	root.visible = false

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", Color(1, 0.9, 0.7))
	b.add_theme_color_override("font_hover_pressed_color", Color(1, 0.9, 0.7))
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, empty)
	b.mouse_entered.connect(func() -> void: b.text = "›  " + text)
	b.mouse_exited.connect(func() -> void: b.text = text)
	b.pressed.connect(cb)
	buttons.add_child(b)
	return b

func _clear_buttons() -> void:
	for c in buttons.get_children():
		c.queue_free()

# ============================================================
#  Режимы
# ============================================================
func show_main() -> void:
	mode = "main"
	root.visible = true
	shade.color = Color(0, 0, 0, 0.15)
	title.text = "ЗОМБАКИ"
	subtitle.text = "Выживи. Любой ценой."
	_clear_buttons()
	_button("Новая игра", func() -> void: start_pressed.emit())
	_button("Лучший забег", func() -> void: _toggle_side("best"))
	_button("Настройки", func() -> void: _toggle_side("settings"))
	_button("Выход", func() -> void: get_tree().quit())
	_close_side()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_pause() -> void:
	mode = "pause"
	root.visible = true
	shade.color = Color(0, 0, 0, 0.55)
	title.text = "ПАУЗА"
	subtitle.text = ""
	_clear_buttons()
	_button("Продолжить", func() -> void: resume_pressed.emit())
	_button("Настройки", func() -> void: _toggle_side("settings"))
	_button("Начать заново", func() -> void: restart_pressed.emit())
	_button("Главное меню", func() -> void: main_menu_pressed.emit())
	_button("Выход из игры", func() -> void: get_tree().quit())
	_close_side()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_menu() -> void:
	mode = "hidden"
	root.visible = false
	_close_side()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
		return
	get_viewport().set_input_as_handled()
	if side_open != "":
		_close_side()
	elif mode == "pause":
		resume_pressed.emit()
	elif mode == "hidden" and can_pause.is_valid() and can_pause.call():
		show_pause()
		get_tree().paused = true

func _process(delta: float) -> void:
	if Settings.show_fps:
		fps_label.visible = true
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	else:
		fps_label.visible = false
	# за главным меню камера медленно облетает карту
	if mode == "main" and orbit_cam and is_instance_valid(orbit_cam):
		orbit_t += delta * 0.05
		var p := Vector3(cos(orbit_t) * 22.0, 7.0 + sin(orbit_t * 2.0), sin(orbit_t) * 22.0)
		orbit_cam.global_position = p
		orbit_cam.look_at(Vector3(0, 1.5, 0))

# ============================================================
#  Правая панель: настройки и рекорд
# ============================================================
func _toggle_side(what: String) -> void:
	if side_open == what:
		_close_side()
		return
	side_open = what
	for c in side_box.get_children():
		c.queue_free()
	side.visible = true
	if what == "best":
		side_box.add_child(_label("Лучший забег", 36, ACCENT))
		var t := _label(best_text.call() if best_text.is_valid() else "Пока нет", 24, TEXT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD
		side_box.add_child(t)
	else:
		side_box.add_child(_label("Настройки", 36, ACCENT))
		_slider("Чувствительность мыши", 0.2, 3.0, 0.05, Settings.sens, func(v: float) -> void: Settings.sens = v, "%.2f")
		_slider("Громкость", 0.0, 1.0, 0.01, Settings.volume, func(v: float) -> void: Settings.volume = v, "%d%%", 100.0)
		_slider("Музыка", 0.0, 1.0, 0.01, Settings.music, func(v: float) -> void: Settings.music = v, "%d%%", 100.0)
		_check("Полный экран", Settings.fullscreen, func(on: bool) -> void: Settings.fullscreen = on)
		_check("Тени (выключить — быстрее)", Settings.shadows, func(on: bool) -> void: Settings.shadows = on)
		_check("Показывать FPS", Settings.show_fps, func(on: bool) -> void: Settings.show_fps = on)
	var back := Button.new()
	back.text = "Назад"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(_close_side)
	side_box.add_child(back)

func _close_side() -> void:
	side_open = ""
	side.visible = false

func _changed() -> void:
	Settings.save_settings()
	Settings.apply(get_tree())

func _slider(text: String, lo: float, hi: float, step: float, value: float, setter: Callable, fmt: String, show_mult := 1.0) -> void:
	var row := VBoxContainer.new()
	var top := HBoxContainer.new()
	var l := _label(text, 22, TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := _label(fmt % (value * show_mult), 22, ACCENT)
	top.add_child(l)
	top.add_child(v)
	row.add_child(top)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(0, 24)
	s.value_changed.connect(func(x: float) -> void:
		setter.call(x)
		v.text = fmt % (x * show_mult)
		_changed())
	row.add_child(s)
	side_box.add_child(row)

func _check(text: String, value: bool, setter: Callable) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 22)
	c.toggled.connect(func(on: bool) -> void:
		setter.call(on)
		_changed())
	side_box.add_child(c)
