extends RefCounted
# Статистика текущего забега (сбрасывается при старте). Пишут игрок, огонь и Main.

static var shots := 0          # выстрелов (выстрел дробовика = 1)
static var hits := 0           # выстрелов, попавших во врага
static var headshots := 0
static var fire_kills := 0     # сожжено молотовом
static var molotovs := 0       # брошено коктейлей
static var medkits := 0        # использовано аптечек
static var time := 0.0         # секунд в бою

static func reset() -> void:
	shots = 0
	hits = 0
	headshots = 0
	fire_kills = 0
	molotovs = 0
	medkits = 0
	time = 0.0

static func accuracy() -> int:
	return roundi(100.0 * hits / shots) if shots > 0 else 0

static func time_text(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60] if s < 3600 else "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
