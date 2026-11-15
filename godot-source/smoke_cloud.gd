extends Node3D
# Дымовая шашка: густое облако. Враги внутри оглушены (можно добить или задушить),
# сквозь дым никто не видит игрока.

const Sfx := preload("res://sfx.gd")
const Sound := preload("res://noise.gd")
const SND := preload("res://sounds/smoke_hiss.wav")

const RADIUS := 5.0
const DURATION := 9.0
const STUN := 3.0             # на сколько оглушает при первом попадании в дым

var age := 0.0
var tick := 0.0
var stunned := {}             # кого уже оглушили этим облаком
var smoke: CPUParticles3D

func _ready() -> void:
	add_to_group("smoke")
	Sfx.play_3d(self, SND, global_position, 2.0)
	Sound.make(get_tree(), global_position, 10.0)
	smoke = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3.2, 3.2)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	q.material = m
	smoke.mesh = q
	smoke.amount = 45
	smoke.lifetime = 3.5
	smoke.preprocess = 0.6
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = RADIUS * 0.75
	smoke.position.y = 1.2
	smoke.scale = Vector3(1, 0.45, 1)
	smoke.direction = Vector3.UP
	smoke.spread = 90.0
	smoke.gravity = Vector3(0, 0.15, 0)
	smoke.initial_velocity_min = 0.1
	smoke.initial_velocity_max = 0.5
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 1.4
	var g := Gradient.new()
	g.set_color(0, Color(0.72, 0.74, 0.74, 0.0))
	g.add_point(0.2, Color(0.72, 0.74, 0.74, 0.75))
	g.add_point(0.8, Color(0.65, 0.66, 0.66, 0.65))
	g.set_color(1, Color(0.6, 0.6, 0.6, 0.0))
	smoke.color_ramp = g
	add_child(smoke)

func covers(p: Vector3) -> bool:
	if age > DURATION:
		return false
	var d := p - global_position
	return Vector2(d.x, d.z).length() < RADIUS and d.y < 4.0

func _process(delta: float) -> void:
	age += delta
	if age > DURATION and smoke.emitting:
		smoke.emitting = false
	if age > DURATION + smoke.lifetime:
		queue_free()
		return
	tick -= delta
	if tick > 0.0 or age > DURATION:
		return
	tick = 0.25
	for e in get_tree().get_nodes_in_group("enemy"):
		if not covers(e.global_position):
			continue
		if e.has_method("blind"):
			e.blind(0.6)
		if not stunned.has(e) and e.has_method("stun"):
			stunned[e] = true
			e.stun(STUN)
