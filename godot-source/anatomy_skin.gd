extends Node3D
# CC0 MakeHuman anatomy, retargeted to the game's existing animation pivots.
var skeleton: Skeleton3D
var drivers: Array[Node3D] = []
var model_root: Node3D
static var data: Dictionary = {}
static var mesh_cache: Dictionary = {}

static func local_to_root(node: Node3D, stop: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	while node != stop:
		result = node.transform * result
		node = node.get_parent()
	return result

func setup(root: Node3D, parts: Dictionary, kind: String, materials: Array) -> void:
	model_root = root
	if data.is_empty():
		data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/anatomy.json"))
	# MakeHuman L is character +X; legacy animation array is -X then +X.
	drivers = [parts.torso,parts.head,parts.arms[1],parts.elbows[1],parts.legs[1],parts.knees[1],parts.ankles[1],parts.arms[0],parts.elbows[0],parts.legs[0],parts.knees[0],parts.ankles[0]]
	skeleton = Skeleton3D.new()
	add_child(skeleton)
	var bind := Skin.new()
	var rests: Array[Transform3D] = []
	var sources: Array[Vector3] = []
	var rotations: Array[Basis] = []
	for i in drivers.size():
		var key: String = data.names[i]
		skeleton.add_bone(key)
		var origin: Array = data.origins[key]
		sources.append(Vector3(origin[0],origin[1],-origin[2]))
		var rest := local_to_root(drivers[i],root)
		# Bake the current rest pose into vertices, then follow each live pivot.
		rests.append(rest)
		skeleton.set_bone_rest(i,rest)
		bind.add_bind(i,rest.affine_inverse())
		var direction := Vector3.DOWN
		if key.begins_with("arm"):
			var end: Array = data.origins["elbow"+key.right(1)]
			direction = Vector3(end[0],end[1],-end[2])-sources[i]
		elif key.begins_with("elbow"):
			direction = Vector3(1.183 if key.ends_with("L") else -1.183,-1.041,-1.625)
		elif key.begins_with("leg"):
			var end: Array = data.origins["knee"+key.right(1)]
			direction = Vector3(end[0],end[1],-end[2])-sources[i]
		elif key.begins_with("knee"):
			var end: Array = data.origins["foot"+key.right(1)]
			direction = Vector3(end[0],end[1],-end[2])-sources[i]
		rotations.append(Basis(Quaternion(direction.normalized(),Vector3.DOWN)))
	if mesh_cache.has(kind):
		mount(mesh_cache[kind], bind, materials)
		return
	var transformed: Array[Vector3] = []
	var bone_ids: Array[PackedInt32Array] = []
	var bone_weights: Array[PackedFloat32Array] = []
	for vi in data.vertices.size():
		var source: Array = data.vertices[vi]
		var point := Vector3(source[0],source[1],-source[2])
		var ids := PackedInt32Array([0,0,0,0])
		var values := PackedFloat32Array([0,0,0,0])
		var sum := 0.0
		var target := Vector3.ZERO
		for j in data.weights[vi].size():
			var entry: Array = data.weights[vi][j]
			var index: int = data.names.find(entry[0])
			var weight: float = entry[1]
			var offset := rotations[index] * (point-sources[index]) * 0.105
			if index == 0:
				offset *= Vector3(1.25,1.33,1.1)
			elif index in [2,3,7,8]:
				offset.y *= 1.28
			if kind == "bandit" and index in [3,8] and offset.y < -0.30:
				var curl := clampf((-offset.y-0.30)/0.14,0.0,1.0)
				offset.y = -0.30-minf(0.065,-offset.y-0.30)
				offset.x *= 1.0-curl*0.35
				offset.z += sin(curl*PI)*0.04
			if kind == "bloater":
				offset *= Vector3(2.3 if index == 0 else 1.8,1.2,1.9)
			target += (rests[index] * offset) * weight
			ids[j] = index
			values[j] = weight
			sum += weight
		transformed.append(target/maxf(sum,0.0001))
		for j in 4:
			values[j] /= maxf(sum,0.0001)
		bone_ids.append(ids)
		bone_weights.append(values)
	var mesh := ArrayMesh.new()
	# Cloth, trousers and exposed skin are separate surfaces of a continuous mesh.
	for region in 3:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in data.faces:
			var center := Vector3.ZERO
			for corner in face:
				var raw: Array = data.vertices[int(corner[0])]
				center += Vector3(raw[0],raw[1],raw[2])/3.0
			var face_region := 0 if center.y < 0.8 else (1 if center.y < 5.8 and absf(center.x)<3.3 else 2)
			if face_region != region:
				continue
			# Z reflection reverses source winding; Godot uses clockwise faces.
			for corner in face:
				var vi := int(corner[0])
				var tex: Array = data.uv[int(corner[1])]
				st.set_uv(Vector2(tex[0],1.0-tex[1]))
				st.set_bones(bone_ids[vi])
				st.set_weights(bone_weights[vi])
				st.add_vertex(transformed[vi])
		st.index()
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(region,materials[region])
	mesh_cache[kind] = mesh
	mount(mesh, bind, materials)

func mount(mesh: ArrayMesh, bind: Skin, materials: Array) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.skin = bind
	for i in materials.size():
		instance.set_surface_override_material(i,materials[i])
	skeleton.add_child(instance)
	instance.skeleton = NodePath("..")
	_process(0.0)

func _process(_delta: float) -> void:
	for i in drivers.size():
		var pose := local_to_root(drivers[i],model_root)
		# Bones are independent roots; skin bind matrices preserve continuity.
		var delta := pose
		skeleton.set_bone_pose_position(i,delta.origin)
		skeleton.set_bone_pose_rotation(i,delta.basis.get_rotation_quaternion())
