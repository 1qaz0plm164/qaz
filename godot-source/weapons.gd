extends RefCounted
# Таблица оружия. Хочешь поменять баланс — правь числа здесь, код трогать не нужно.
#
#  damage        урон одной пули/дробинки
#  pellets       сколько пуль вылетает за выстрел (у дробовика — 8)
#  spread        разброс в градусах (конус вокруг прицела)
#  interval      пауза между выстрелами, сек
#  auto          true — стреляет, пока зажата кнопка мыши
#  mag           размер магазина
#  reload_time   время перезарядки, сек (для shell_reload — не используется)
#  shell_reload  true — заряжает по одному патрону (дробовик), можно прервать выстрелом
#  falloff_*     падение урона с расстоянием: до falloff_start полный урон,
#                к falloff_end урон падает до min_factor от полного
#  knockback     на сколько отбрасывает врага каждая пуля
#  kick          отдача камеры (подбрасывает прицел вверх)
#  reserve       патронов в запасе на старте (-1 — бесконечно)
#  reserve_max   сколько патронов можно носить в запасе (-1 — бесконечно)
#  crate_ammo    сколько патронов даёт ящик: [от, до] — каждый раз случайно
#  aim_fov       (необязательно) поле зрения при прицеливании, по умолчанию 55
#  aim_sens      (необязательно) чувствительность мыши при прицеливании, по умолчанию 0.6
#  aim_spread    (необязательно) доля разброса при прицеливании, по умолчанию 0.35
#  scope         (необязательно) true — при прицеливании экран оптики, оружие скрыто
#  noise         насколько далеко слышен выстрел/бросок (м) — заражённые и бандиты идут на звук
#  projectile    у бросаемых: "molotov" | "nail"
#  throwable     (необязательно) true — бросаемое (Молотов): mag = сколько носим, start — сколько на старте

const PistolView := preload("res://pistol.gd")
const ShotgunView := preload("res://shotgun_view.gd")
const RifleView := preload("res://rifle_view.gd")
const SniperView := preload("res://sniper_view.gd")
const MolotovView := preload("res://molotov_view.gd")
const NailBombView := preload("res://nailbomb_view.gd")

const LIST := [
	{
		"id": "pistol", "name": "Пистолет", "view": PistolView, "noise": 28.0,
		"damage": 25, "pellets": 1, "spread": 0.0, "interval": 0.22, "auto": false,
		"mag": 15, "reload_time": 1.5, "shell_reload": false, "shell_time": 0.0,
		"falloff_start": 1000.0, "falloff_end": 1001.0, "min_factor": 1.0,
		"knockback": 0.4, "kick": 0.012, "volume": -4.0,
		"reserve": -1, "reserve_max": -1, "crate_ammo": [0, 0],
		"snd_shot": preload("res://sounds/shoot.wav"),
		"snd_reload": preload("res://sounds/reload.wav"),
		"snd_after": null, "after_delay": 0.0,
	},
	{
		"id": "shotgun", "name": "Дробовик", "view": ShotgunView, "noise": 36.0,
		"damage": 14, "pellets": 8, "spread": 5.0, "interval": 0.95, "auto": false,
		"mag": 6, "reload_time": 0.0, "shell_reload": true, "shell_time": 0.55,
		"falloff_start": 5.0, "falloff_end": 25.0, "min_factor": 0.25,
		"knockback": 1.1, "kick": 0.05, "volume": 0.0,
		"reserve": 12, "reserve_max": 30, "crate_ammo": [4, 10],
		"snd_shot": preload("res://sounds/shotgun_shot.wav"),
		"snd_reload": preload("res://sounds/shell_insert.wav"),
		"snd_after": preload("res://sounds/shotgun_pump.wav"), "after_delay": 0.3,
	},
	{
		"id": "rifle", "name": "Винтовка", "view": RifleView, "noise": 32.0,
		"damage": 20, "pellets": 1, "spread": 0.7, "interval": 0.09, "auto": true,
		"mag": 30, "reload_time": 2.2, "shell_reload": false, "shell_time": 0.0,
		"falloff_start": 1000.0, "falloff_end": 1001.0, "min_factor": 1.0,
		"knockback": 0.35, "kick": 0.012, "volume": -3.0,
		"reserve": 60, "reserve_max": 180, "crate_ammo": [20, 50],
		"snd_shot": preload("res://sounds/rifle_shot.wav"),
		"snd_reload": preload("res://sounds/rifle_reload.wav"),
		"snd_after": null, "after_delay": 0.0,
	},
	{
		"id": "sniper", "name": "Снайперка", "view": SniperView, "noise": 45.0,
		"damage": 120, "pellets": 1, "spread": 4.0, "interval": 1.3, "auto": false,
		"mag": 5, "reload_time": 3.0, "shell_reload": false, "shell_time": 0.0,
		"falloff_start": 1000.0, "falloff_end": 1001.0, "min_factor": 1.0,
		"knockback": 1.6, "kick": 0.07, "volume": 1.0,
		"reserve": 10, "reserve_max": 25, "crate_ammo": [3, 6],
		"aim_fov": 20.0, "aim_sens": 0.3, "aim_spread": 0.0, "scope": true,
		"snd_shot": preload("res://sounds/sniper_shot.wav"),
		"snd_reload": preload("res://sounds/sniper_reload.wav"),
		"snd_after": preload("res://sounds/sniper_bolt.wav"), "after_delay": 0.35,
	},
	{
		"id": "molotov", "name": "Молотов", "view": MolotovView, "throwable": true, "projectile": "molotov", "noise": 4.0,
		"damage": 0, "pellets": 0, "spread": 0.0, "interval": 1.0, "auto": false,
		"mag": 3, "start": 1, "reload_time": 0.0, "shell_reload": false, "shell_time": 0.0,
		"falloff_start": 1000.0, "falloff_end": 1001.0, "min_factor": 1.0,
		"knockback": 0.0, "kick": 0.0, "volume": -2.0,
		"reserve": -1, "reserve_max": -1, "crate_ammo": [0, 0],
		"throw_speed": 17.0,
		"snd_shot": preload("res://sounds/molotov_throw.wav"),
		"snd_reload": null, "snd_after": null, "after_delay": 0.0,
	},
	{
		"id": "nailbomb", "name": "Бомба", "view": NailBombView, "throwable": true, "projectile": "nail", "noise": 4.0,
		"damage": 0, "pellets": 0, "spread": 0.0, "interval": 1.0, "auto": false,
		"mag": 3, "start": 0, "reload_time": 0.0, "shell_reload": false, "shell_time": 0.0,
		"falloff_start": 1000.0, "falloff_end": 1001.0, "min_factor": 1.0,
		"knockback": 0.0, "kick": 0.0, "volume": -2.0,
		"reserve": -1, "reserve_max": -1, "crate_ammo": [0, 0],
		"throw_speed": 13.0,
		"snd_shot": preload("res://sounds/swing.wav"),
		"snd_reload": null, "snd_after": null, "after_delay": 0.0,
	},
]

# Крафт: что из чего собирается (как в TLOU). makes — во что: id оружия, или "medkit"
const MATERIAL_NAMES := {"rag": "Тряпка", "alcohol": "Спирт", "blade": "Лезвие", "explosive": "Взрывчатка"}
const MATERIAL_MAX := 3
const RECIPES := [
	{"makes": "medkit", "name": "Аптечка", "needs": ["rag", "alcohol"]},
	{"makes": "molotov", "name": "Коктейль Молотова", "needs": ["rag", "alcohol"]},
	{"makes": "nailbomb", "name": "Бомба с гвоздями", "needs": ["explosive", "blade"]},
]
