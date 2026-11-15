extends Node3D
# Брошенный предмет: летит по дуге и срабатывает при ударе.
#   kind = "molotov" — разливает огонь, "nail" — бомба с гвоздями (ставится миной)

const FireZone := preload("res://fire_zone.gd")
const NailBomb := preload("res://nail_bomb.gd")
const Sound := preload("res://noise.gd")
const Sfx := preload("res://sfx.gd")
const SND_BURST := preload("res://sounds/molotov_burst.wav")
const GRAVITY := 14.0

var kind := "molotov"
var velocity := Vector3.ZERO
var exclude: Array[RID] = []      # игрок, который бросил
var age := 0.0
var spin := Vector3.ZERO

func _ready() -> void:
	spin = Vector3(randf_range(6, 10), randf_range(-3, 3), randf_range(-2, 2))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = {"molotov": Color(0.35, 0.45, 0.25), "nail": Color(0.4, 0.4, 0.38)}[kind]
	glass.roughness = 0.15
	glass.metallic = 0.0 if kind == "molotov" else 0.5
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035 if kind == "molotov" else 0.045
	cm.bottom_radius = cm.top_radius
	cm.height = 0.2 if kind == "molotov" else 0.13
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = glass
	add_child(mi)
	if kind != "molotov":
		return
	var fl := StandardMaterial3D.new()
	fl.albedo_color = Color(1.0, 0.55, 0.15)
	fl.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fl.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fl.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var f := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.16)
	f.mesh = q
	f.material_override = fl
	f.position.y = 0.14
	mi.add_child(f)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 1.5
	l.omni_range = 5.0
	add_child(l)

func _physics_process(delta: float) -> void:
	age += delta
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_burst(hit.position, hit.normal)
		return
	global_position = to
	rotation += spin * delta
	if age > 6.0 or global_position.y < -20.0:
		queue_free()

func _burst(pos: Vector3, normal: Vector3) -> void:
	if kind == "molotov":
		Sfx.play_3d(self, SND_BURST, pos, 4.0)
		Sound.make(get_tree(), pos, 18.0)
	# огонь всегда разливается по земле: ищем пол под точкой удара
	var ground := pos
	var q := PhysicsRayQueryParameters3D.create(pos + normal * 0.3 + Vector3.UP * 0.2, pos + normal * 0.3 + Vector3.DOWN * 8.0, 1, exclude)
	q.collide_with_areas = false
	var space := get_world_3d().direct_space_state
	var excl := exclude.duplicate()
	for i in 4:   # пропускаем врагов: огонь под ними, а не на их головах
		q.exclude = excl
		var h := space.intersect_ray(q)
		if h.is_empty():
			break
		if h.collider is CharacterBody3D:
			excl.append(h.rid)
			continue
		ground = h.position
		break
	var z: Node3D
	match kind:
		"nail": z = NailBomb.new()
		_: z = FireZone.new()
	get_parent().add_child(z)
	z.global_position = ground + Vector3(0, 0.02, 0)
	queue_free()
