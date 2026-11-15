extends Node3D
# Лужа огня от коктейля Молотова. Поджигает всех, кто в ней: заражённых, бандитов и самого игрока.
# Подожжённый враг горит ещё немного после того, как выбежал из огня.

const Sfx := preload("res://sfx.gd")
const SND_FIRE := preload("res://sounds/fire_loop.wav")
const RunStats := preload("res://run_stats.gd")

const RADIUS := 3.0           # радиус огня, м
const DURATION := 7.0         # сколько горит, сек
const TICK := 0.25            # как часто проверяем, кто в огне
const ENEMY_DPS := 34.0       # урон врагам в секунду
const PLAYER_DPS := 14.0      # урон игроку в секунду
const AFTERBURN := 2.0        # сколько ещё горит враг, выбежавший из огня

var age := 0.0
var tick := 0.0
var flames: CPUParticles3D
var smoke: CPUParticles3D
var light: OmniLight3D
var sound: AudioStreamPlayer3D
var scorch: MeshInstance3D
var burning := {}             # враг -> оставшееся время горения
var dmg_acc := {}             # враг -> накопленный дробный урон
var player_acc := 0.0

func _ready() -> void:
	flames = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	flames.mesh = q
	flames.amount = 70
	flames.lifetime = 0.7
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = RADIUS * 0.85
	flames.scale = Vector3(1, 0.05, 1)       # плоское облако частиц по земле
	flames.local_coords = false
	flames.direction = Vector3.UP
	flames.spread = 15.0
	flames.gravity = Vector3(0, 2.5, 0)
	flames.initial_velocity_min = 0.6
	flames.initial_velocity_max = 1.6
	flames.scale_amount_min = 0.6
	flames.scale_amount_max = 1.4
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	g.set_color(1, Color(0.6, 0.08, 0.0, 0.0))
	g.add_point(0.45, Color(1.0, 0.4, 0.08, 0.8))
	flames.color_ramp = g
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.6))
	sc.add_point(Vector2(0.3, 1.0))
	sc.add_point(Vector2(1, 0.2))
	flames.scale_amount_curve = sc
	add_child(flames)

	smoke = CPUParticles3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(1.4, 1.4)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.vertex_color_use_as_albedo = true
	sq.material = sm
	smoke.mesh = sq
	smoke.amount = 14
	smoke.lifetime = 2.5
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = RADIUS * 0.6
	smoke.local_coords = false
	smoke.position.y = 1.0
	smoke.direction = Vector3.UP
	smoke.gravity = Vector3(0.2, 1.2, 0)
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 1.0
	var sg := Gradient.new()
	sg.set_color(0, Color(0.1, 0.09, 0.08, 0.5))
	sg.set_color(1, Color(0.2, 0.2, 0.2, 0.0))
	smoke.color_ramp = sg
	add_child(smoke)

	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.position.y = 0.8
	add_child(light)

	# обгоревшее пятно (остаётся после огня и тает)
	scorch = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = RADIUS
	cm.bottom_radius = RADIUS
	cm.height = 0.01
	cm.radial_segments = 16
	scorch.mesh = cm
	var scm := StandardMaterial3D.new()
	scm.albedo_color = Color(0.03, 0.025, 0.02, 0.8)
	scm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	scm.roughness = 1.0
	scorch.material_override = scm
	scorch.position.y = 0.01
	scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(scorch)

	sound = AudioStreamPlayer3D.new()
	sound.stream = SND_FIRE
	sound.unit_size = 6.0
	sound.volume_db = 2.0
	add_child(sound)
	sound.finished.connect(func() -> void:
		if age < DURATION: sound.play())
	sound.play()

func _process(delta: float) -> void:
	age += delta
	var left := DURATION - age
	light.light_energy = (2.6 + sin(age * 17.0) * 0.4 + randf() * 0.6) * clampf(left, 0.0, 1.0)
	if left < 1.0:
		sound.volume_db = 2.0 + linear_to_db(maxf(left, 0.01))
	if left <= 0.0 and flames.emitting:
		flames.emitting = false
		smoke.emitting = false
		sound.stop()
	if left < -12.0:
		var a := clampf(1.0 + (left + 12.0) / 3.0, 0.0, 1.0)
		scorch.material_override.albedo_color.a = 0.8 * a
		if a <= 0.0 and burning.is_empty():
			queue_free()
			return

	tick -= delta
	if tick > 0.0:
		return
	tick = TICK
	if left > 0.0:
		for e in get_tree().get_nodes_in_group("enemy"):
			if _inside(e):
				burning[e] = AFTERBURN
		var p := get_tree().get_first_node_in_group("player")
		if p and not p.get("is_dead") and _inside(p):
			player_acc += PLAYER_DPS * TICK
			if player_acc >= 1.0:
				var d := int(player_acc)
				player_acc -= d
				p.take_damage(d)
	# горящие враги получают урон, даже выбежав из огня
	for e in burning.keys():
		if not is_instance_valid(e) or e.get("is_dead"):
			burning.erase(e)
			dmg_acc.erase(e)
			continue
		burning[e] -= TICK
		dmg_acc[e] = dmg_acc.get(e, 0.0) + ENEMY_DPS * TICK
		if dmg_acc[e] >= 4.0:      # урон порциями, чтобы не спамить звуком
			var d := int(dmg_acc[e])
			dmg_acc[e] -= d
			e.take_damage(d)
			if is_instance_valid(e) and not e.get("is_dead"):
				_flame_on(e)
			elif is_instance_valid(e):
				RunStats.fire_kills += 1
		if burning.has(e) and burning[e] <= 0.0:
			burning.erase(e)
			dmg_acc.erase(e)

func _inside(n: Node3D) -> bool:
	var d := n.global_position - global_position
	return Vector2(d.x, d.z).length() < RADIUS + 0.3 and d.y > -1.0 and d.y < 2.5

# Маленький огонь на горящем враге (живёт, пока враг горит)
func _flame_on(e: Node3D) -> void:
	var f := e.get_node_or_null("BurnFx")
	if f == null:
		f = CPUParticles3D.new()
		f.name = "BurnFx"
		var q := QuadMesh.new()
		q.size = Vector2(0.4, 0.5)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.vertex_color_use_as_albedo = true
		q.material = m
		f.mesh = q
		f.amount = 24
		f.lifetime = 0.5
		f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		f.emission_box_extents = Vector3(0.25, 0.7, 0.25)
		f.local_coords = false
		f.direction = Vector3.UP
		f.gravity = Vector3(0, 3.0, 0)
		f.initial_velocity_min = 0.3
		f.initial_velocity_max = 1.0
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.8, 0.35, 1.0))
		g.set_color(1, Color(0.6, 0.08, 0.0, 0.0))
		f.color_ramp = g
		e.add_child(f)
	f.set_meta("until", Time.get_ticks_msec() + int(AFTERBURN * 1000.0) + 300)
	if not f.has_meta("timer_on"):
		f.set_meta("timer_on", true)
		_watch_flame(f)

func _watch_flame(f: CPUParticles3D) -> void:
	while is_instance_valid(f) and Time.get_ticks_msec() < int(f.get_meta("until")):
		await get_tree().create_timer(0.3).timeout
		if not is_inside_tree():
			break
	if is_instance_valid(f):
		f.queue_free()
