extends RefCounted
# Кровь при попадании: брызги-частицы и лужицы на земле. Всё рисуется кодом.
#   BloodFx.spawn(где_создать, точка_попадания, направление_пули, сильно?, враг)
# «Сильно» — попадание в голову или смертельный выстрел: брызг больше, плюс брызги навылет.

const BLOOD := Color(0.32, 0.02, 0.02)     # кровь заражённых тёмная, почти чёрная
const MAX_SPLATS := 50                     # больше лужиц на карте не держим (старые исчезают)
const SPLAT_LIFE := 14.0                   # через сколько секунд лужица растворяется

static func spawn(parent: Node, pos: Vector3, dir: Vector3, strong: bool, victim: CollisionObject3D = null, color := BLOOD) -> void:
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	# брызги назад к стрелку и немного вверх
	_burst(parent, pos, (-dir * 0.7 + Vector3.UP * 0.5).normalized(), 54 if strong else 28, 3.2 if strong else 2.4, 40.0, color)
	if strong:
		# навылет — по ходу пули
		_burst(parent, pos, (dir + Vector3.UP * 0.2).normalized(), 38, 4.5, 25.0, color)
	_splat(parent, pos, dir, 1.65 if strong else 1.05, victim, color)

static func _mat(alpha := 1.0, color := BLOOD) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.roughness = 0.25            # мокрый блеск
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

static func _burst(parent: Node, pos: Vector3, dir: Vector3, amount: int, speed: float, spread: float, color := BLOOD) -> void:
	# Bound simultaneous emitters during automatic fire and large waves.
	if parent.get_tree().get_nodes_in_group("blood_burst").size() >= 32:
		return
	var p := CPUParticles3D.new()
	p.add_to_group("blood_burst")
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.95
	p.explosiveness = 0.95
	p.local_coords = false
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.8, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	var curve := Curve.new()          # капли уменьшаются к концу жизни
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = 0.022
	m.height = 0.044
	m.radial_segments = 6
	m.rings = 3
	m.material = _mat(1.0, color)
	p.mesh = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)

# Лужица на земле под местом попадания (чуть дальше по ходу пули)
static func _splat(parent: Node, pos: Vector3, dir: Vector3, size: float, victim: CollisionObject3D, color := BLOOD) -> void:
	var world := parent.get_viewport().world_3d
	if world == null:
		return
	var from := pos + Vector3(dir.x, 0, dir.z) * randf_range(0.2, 0.7)
	var ex: Array[RID] = []
	if victim:
		ex.append(victim.get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -4, 0), 1, ex)
	var hit := world.direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit.normal.y < 0.7:
		return
	var tree := parent.get_tree()
	var old := tree.get_nodes_in_group("blood_splat")
	if old.size() >= MAX_SPLATS:
		old[0].queue_free()

	var root := Node3D.new()
	root.add_to_group("blood_splat")
	parent.add_child(root)
	# над асфальтом дорог (они чуть выше земли), чтобы не мерцало
	root.global_position = hit.position + Vector3(0, 0.05, 0)
	root.rotation.y = randf() * TAU
	var mat := _mat(0.92, color)
	# несколько плоских кружков разного размера складываются в неровное пятно
	for i in randi_range(3, 6):
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		var r := randf_range(0.06, 0.18) * size
		c.top_radius = r
		c.bottom_radius = r
		c.height = 0.004
		c.radial_segments = 12
		c.rings = 1
		mi.mesh = c
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(randf_range(-0.2, 0.2), i * 0.001, randf_range(-0.2, 0.2)) * size
		mi.scale = Vector3(randf_range(0.7, 1.4), 1, randf_range(0.7, 1.4))
		root.add_child(mi)
	# лужица «растекается», потом медленно растворяется
	root.scale = Vector3(0.3, 1, 0.3)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_interval(SPLAT_LIFE)
	tw.tween_property(mat, "albedo_color:a", 0.0, 3.0)
	tw.tween_callback(root.queue_free)
