extends Node3D
# Бомба с гвоздями: лежит миной и взрывается, когда рядом враг (или сама через 25 с).
# Взрыв бьёт всех вокруг, в том числе игрока, если он слишком близко.

const Sfx := preload("res://sfx.gd")
const Sound := preload("res://noise.gd")
const SND_BEEP := preload("res://sounds/mine_beep.wav")
const SND_BOOM := preload("res://sounds/explosion.wav")

const ARM_TIME := 0.8         # через сколько взводится
const TRIGGER := 2.6          # враг ближе — взрыв
const RADIUS := 6.0           # радиус поражения
const DAMAGE := Vector2(190, 30)        # урон в центре / на краю
const PLAYER_DAMAGE := Vector2(45, 5)
const FUSE := 25.0

var age := 0.0
var beep := 0.0
var blink: OmniLight3D
var blink_mesh: MeshInstance3D
var exploded := false

func _ready() -> void:
	var can := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.06
	cm.height = 0.12
	can.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.4, 0.4, 0.38)
	m.metallic = 0.6
	m.roughness = 0.4
	can.material_override = m
	can.position.y = 0.06
	add_child(can)
	# торчащие гвозди
	var nm := StandardMaterial3D.new()
	nm.albedo_color = Color(0.6, 0.6, 0.58)
	nm.metallic = 0.8
	for i in 8:
		var n := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.006, 0.006, 0.07)
		n.mesh = b
		n.material_override = nm
		var a := TAU * i / 8.0
		n.position = Vector3(cos(a) * 0.06, 0.06 + (i % 2) * 0.03, sin(a) * 0.06)
		n.rotation.y = -a
		add_child(n)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1, 0.1, 0.05)
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blink_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.015
	sm.height = 0.03
	blink_mesh.mesh = sm
	blink_mesh.material_override = lm
	blink_mesh.position.y = 0.13
	add_child(blink_mesh)
	blink = OmniLight3D.new()
	blink.light_color = Color(1, 0.1, 0.05)
	blink.light_energy = 0.0
	blink.omni_range = 2.0
	blink.position.y = 0.2
	add_child(blink)

func _process(delta: float) -> void:
	if exploded:
		return
	age += delta
	if age < ARM_TIME:
		return
	beep -= delta
	var on := beep > 0.75
	blink_mesh.visible = on
	blink.light_energy = 1.5 if on else 0.0
	if beep <= 0.0:
		beep = 0.9
		Sfx.play_3d(self, SND_BEEP, global_position, -8.0)
	if age > FUSE:
		explode()
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		var d: Vector3 = e.global_position - global_position
		if Vector2(d.x, d.z).length() < TRIGGER and absf(d.y) < 2.5:
			explode()
			return

func explode() -> void:
	if exploded:
		return
	exploded = true
	var center := global_position + Vector3(0, 0.4, 0)
	Sfx.play_3d(self, SND_BOOM, center, 8.0)
	Sound.make(get_tree(), center, 35.0)
	var space := get_world_3d().direct_space_state
	for e in get_tree().get_nodes_in_group("enemy"):
		var to: Vector3 = e.global_position - center
		var d := to.length()
		if d > RADIUS:
			continue
		# за стеной осколки не достают
		var q := PhysicsRayQueryParameters3D.create(center, e.global_position, 1, [e.get_rid()])
		var h := space.intersect_ray(q)
		if not h.is_empty() and not (h.collider is CharacterBody3D):
			continue
		var dmg := roundi(lerpf(DAMAGE.x, DAMAGE.y, d / RADIUS))
		e.take_damage(dmg, to.normalized() * 3.0, e.global_position, false)
	var p := get_tree().get_first_node_in_group("player")
	if p:
		var dp: float = p.global_position.distance_to(center)
		if dp < RADIUS * 0.85:
			p.take_damage(roundi(lerpf(PLAYER_DAMAGE.x, PLAYER_DAMAGE.y, dp / (RADIUS * 0.85))))
	_fx()

func _fx() -> void:
	for c in get_children():
		c.queue_free()
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.35)
	l.light_energy = 8.0
	l.omni_range = 14.0
	l.position.y = 0.8
	add_child(l)
	var sparks := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1.0, 0.7, 0.3)
	q.material = m
	sparks.mesh = q
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 60
	sparks.lifetime = 0.7
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 6.0
	sparks.initial_velocity_max = 14.0
	sparks.gravity = Vector3(0, -9.8, 0)
	sparks.position.y = 0.4
	sparks.emitting = true
	add_child(sparks)
	var fire := CPUParticles3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(1.6, 1.6)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.vertex_color_use_as_albedo = true
	fq.material = fm
	fire.mesh = fq
	fire.one_shot = true
	fire.explosiveness = 0.9
	fire.amount = 24
	fire.lifetime = 1.6
	fire.direction = Vector3.UP
	fire.spread = 70.0
	fire.initial_velocity_min = 1.0
	fire.initial_velocity_max = 4.0
	fire.gravity = Vector3(0, 1.0, 0)
	fire.position.y = 0.5
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.8, 0.4, 1.0))
	g.add_point(0.15, Color(1.0, 0.4, 0.1, 0.9))
	g.set_color(1, Color(0.15, 0.13, 0.12, 0.0))
	fire.color_ramp = g
	fire.emitting = true
	add_child(fire)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.5)
	tw.tween_interval(1.8)
	tw.tween_callback(queue_free)
