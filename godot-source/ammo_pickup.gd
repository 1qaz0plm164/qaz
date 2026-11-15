extends Node3D
# Трофей, выпавший из бандита: коробка патронов или аптечка.
# Подбирается сам, когда игрок подходит вплотную (если есть куда положить).
#   what = "shotgun" | "rifle" | "sniper" — патроны к этому оружию, "medkit" — аптечка,
#   "molotov" — коктейль Молотова, "rag"/"alcohol"/"blade"/"explosive" — материал для крафта

const PICK_RANGE := 1.3
const LIFETIME := 45.0

var what := "rifle"
var amount := 10
var age := 0.0
var permanent := false     # true — лежит на карте, пока не подберут
var mesh_root: Node3D
var player: Node3D

const MAT_LOOK := {
	"rag": [Vector3(0.2, 0.05, 0.16), Color(0.75, 0.7, 0.6)],
	"alcohol": [Vector3(0.08, 0.22, 0.08), Color(0.55, 0.7, 0.8)],
	"blade": [Vector3(0.04, 0.02, 0.2), Color(0.8, 0.8, 0.85)],
	"explosive": [Vector3(0.16, 0.1, 0.1), Color(0.7, 0.25, 0.1)],
}

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	mesh_root = Node3D.new()
	add_child(mesh_root)
	var m := StandardMaterial3D.new()
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	if what == "medkit":
		b.size = Vector3(0.26, 0.12, 0.18)
		m.albedo_color = Color(0.85, 0.83, 0.78)
		var cross := StandardMaterial3D.new()
		cross.albedo_color = Color(0.8, 0.1, 0.08)
		for sz in [Vector3(0.1, 0.01, 0.03), Vector3(0.03, 0.01, 0.1)]:
			var c := MeshInstance3D.new()
			var cb := BoxMesh.new()
			cb.size = sz
			c.mesh = cb
			c.material_override = cross
			c.position.y = 0.065
			mesh_root.add_child(c)
	elif what == "molotov":
		b.size = Vector3(0.07, 0.2, 0.07)
		m.albedo_color = Color(0.35, 0.45, 0.25)
		m.roughness = 0.15
		var neck := MeshInstance3D.new()
		var nb := BoxMesh.new()
		nb.size = Vector3(0.03, 0.08, 0.03)
		neck.mesh = nb
		var rag := StandardMaterial3D.new()
		rag.albedo_color = Color(0.6, 0.55, 0.45)
		neck.material_override = rag
		neck.position.y = 0.13
		mesh_root.add_child(neck)
	elif MAT_LOOK.has(what):
		var look: Array = MAT_LOOK[what]
		b.size = look[0]
		m.albedo_color = look[1]
	else:
		b.size = Vector3(0.22, 0.12, 0.14)
		var cols := {"rifle": Color(0.3, 0.34, 0.2), "shotgun": Color(0.55, 0.15, 0.1), "sniper": Color(0.15, 0.2, 0.35)}
		m.albedo_color = cols.get(what, Color(0.5, 0.5, 0.5))
	mi.mesh = b
	mi.material_override = m
	mesh_root.add_child(mi)
	mesh_root.position.y = 0.1
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.6)
	light.light_energy = 0.5
	light.omni_range = 1.8
	light.position.y = 0.5
	add_child(light)

func _process(delta: float) -> void:
	age += delta
	mesh_root.rotation.y += delta * 1.5
	mesh_root.position.y = 0.12 + sin(age * 3.0) * 0.04
	if age > LIFETIME and not permanent:
		queue_free()
		return
	if not is_instance_valid(player) or player.get("is_dead"):
		return
	var d := player.global_position - global_position
	if Vector2(d.x, d.z).length() < PICK_RANGE and absf(d.y) < 2.5:
		var took := false
		if what == "medkit":
			took = player.add_medkit()
		elif what == "molotov":
			took = player.add_molotov()
		elif MAT_LOOK.has(what):
			took = player.add_material(what)
		else:
			took = player.add_ammo(what, amount) > 0
		if took:
			queue_free()
