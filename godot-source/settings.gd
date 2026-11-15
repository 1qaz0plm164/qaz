extends RefCounted
# Настройки игры: хранятся в user://settings.cfg и действуют сразу.
# Использование: Settings.load_settings(), Settings.sens, Settings.apply(get_tree())

const PATH := "user://settings.cfg"

static var sens := 1.0           # множитель чувствительности мыши
static var volume := 0.8         # общая громкость 0..1
static var music := 0.6          # громкость музыки 0..1
static var fullscreen := false
static var shadows := true       # тени от солнца (выключить — быстрее на слабом ПК)
static var show_fps := false
static var loaded := false

static func load_settings() -> void:
	if loaded:
		return
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	sens = cfg.get_value("settings", "sens", sens)
	volume = cfg.get_value("settings", "volume", volume)
	music = cfg.get_value("settings", "music", music)
	fullscreen = cfg.get_value("settings", "fullscreen", fullscreen)
	shadows = cfg.get_value("settings", "shadows", shadows)
	show_fps = cfg.get_value("settings", "show_fps", show_fps)

static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "sens", sens)
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "music", music)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "shadows", shadows)
	cfg.set_value("settings", "show_fps", show_fps)
	cfg.save(PATH)

static func apply(tree: SceneTree) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != want:
		if not (want == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(want)
	apply_shadows(tree.root)

static func apply_shadows(root: Node) -> void:
	for l in root.find_children("*", "DirectionalLight3D", true, false):
		l.shadow_enabled = shadows
	for l in root.find_children("*", "SpotLight3D", true, false):   # фонарик
		l.shadow_enabled = shadows
