extends Node3D
# Споровая бомба топляка: летит по дуге, при ударе лопается облаком спор.
# Прямое попадание по игроку бьёт сразу, облако потом травит.

const SporeCloud := preload("res://spore_cloud.gd")
const Sfx := preload("res://sfx.gd")
const SND_SPLAT := preload("res://sounds/spore_splat.wav")

const DIRECT_DAMAGE := 15
const CLOUD_RADIUS := 3.0
const CLOUD_LIFE := 5.0
const MAX_LIFE := 5.0

var velocity := Vector3.ZERO
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var life := 0.0
var exclude: Array[RID] = []
var mesh: MeshInstance3D

# Считаем стартовую скорость так, чтобы бомба упала в точку target
func setup(from: Vector3, target: Vector3, thrower: CollisionObject3D) -> void:
	position = from
	var flat := Vector2(target.x - from.x, target.z - from.z).length()
	var t := clampf(flat / 11.0, 0.55, 1.5)                 # время полёта
	velocity = (target - from) / t + Vector3(0, 0.5 * gravity * t, 0)
	if thrower:
		exclude.append(thrower.get_rid())

func _ready() -> void:
	mesh = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.14
	s.height = 0.28
	s.radial_segments = 10
	s.rings = 5
	mesh.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.58, 0.3)
	m.emission_enabled = true
	m.emission = Color(0.35, 0.32, 0.1)
	m.roughness = 0.4
	mesh.material_override = m
	add_child(mesh)

func _physics_process(delta: float) -> void:
	life += delta
	velocity.y -= gravity * delta
	var from := global_position
	var to := from + velocity * delta
	mesh.rotation += Vector3(7.0, 4.0, 0.0) * delta

	# Луч по отрезку полёта: стены/земля (слой 1) и игрок (слой 2). Враги не мешают.
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, exclude)
	var hit := space.intersect_ray(q)
	while not hit.is_empty() and hit.collider is Node and (hit.collider as Node).is_in_group("enemy"):
		exclude.append(hit.rid)
		q.exclude = exclude
		hit = space.intersect_ray(q)

	if not hit.is_empty():
		var c: Object = hit.collider
		if c is Node and (c as Node).is_in_group("player") and c.has_method("take_damage"):
			c.take_damage(DIRECT_DAMAGE)
		_burst(hit.position)
		return
	global_position = to
	if life > MAX_LIFE or to.y < -20.0:
		queue_free()

func _burst(pos: Vector3) -> void:
	Sfx.play_3d(self, SND_SPLAT, pos, 3.0)
	var cloud := SporeCloud.new()
	cloud.radius = CLOUD_RADIUS
	cloud.lifetime = CLOUD_LIFE
	# облако встаёт на землю, даже если бомба ударилась в стену или в игрока
	var space := get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.3, 0), pos + Vector3(0, -10, 0), 1, exclude)
	var g := space.intersect_ray(down)
	cloud.position = g.position if not g.is_empty() else pos
	get_parent().add_child(cloud)
	queue_free()
