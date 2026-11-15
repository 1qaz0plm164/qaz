extends Node3D
# Облако спор: висит на месте несколько секунд и травит игрока, пока он внутри.
# Ставится с position = точка на земле; radius и lifetime задаёт тот, кто создаёт.

const TICK := 0.6          # как часто бьёт, сек
const TICK_DAMAGE := 4

var radius := 3.0
var lifetime := 5.0
var age := 0.0
var tick_timer := 0.0
var puffs: Array[MeshInstance3D] = []
var mat: StandardMaterial3D
var player: Node3D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.66, 0.35, 0.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	for i in 9:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		var r := radius * randf_range(0.35, 0.6)
		s.radius = r
		s.height = r * 1.4
		s.radial_segments = 12
		s.rings = 6
		mi.mesh = s
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := randf() * TAU
		var d := randf() * radius * 0.55
		mi.position = Vector3(cos(a) * d, randf_range(0.3, 1.3), sin(a) * d)
		mi.scale = Vector3.ONE * 0.3
		add_child(mi)
		puffs.append(mi)

func _process(delta: float) -> void:
	age += delta
	# быстро разрастается, потом медленно рассеивается
	var grow := minf(1.0, age / 0.4)
	var fade := clampf((lifetime - age) / 1.5, 0.0, 1.0)
	mat.albedo_color.a = 0.32 * grow * fade
	for i in puffs.size():
		var p := puffs[i]
		p.scale = Vector3.ONE * lerpf(0.3, 1.0 + age * 0.04, grow)
		p.rotation.y += delta * (0.2 + i * 0.03)
		p.position.y += delta * 0.05
	if age >= lifetime:
		queue_free()

func _physics_process(delta: float) -> void:
	if age > lifetime - 0.8 or not is_instance_valid(player):
		return
	tick_timer -= delta
	var d := player.global_position - global_position
	var inside := Vector2(d.x, d.z).length() < radius and d.y > -1.0 and d.y < 3.0
	if inside and tick_timer <= 0.0 and player.has_method("take_damage"):
		player.take_damage(TICK_DAMAGE)
		tick_timer = TICK
