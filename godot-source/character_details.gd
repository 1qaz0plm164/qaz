extends RefCounted
# Layered, asymmetric fungal shelves with a pale growing edge.
static func fungus(parent: Node3D, pos: Vector3, radius: float, phase: float) -> Node3D:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 7:
		for segment in 32:
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var t: float = (ring+corner.y)/7.0
				var a: float = TAU*(segment+corner.x)/32.0
				var r := radius*t*(1.0+0.14*sin(a*5.0+phase)+0.07*sin(a*11.0))
				var col := Color(0.25,0.15,0.085).lerp(Color(0.66,0.52,0.31),t)
				if t > 0.85:
					col = col.lerp(Color(0.85,0.76,0.56),0.8)
				col *= 0.8+0.2*sin(t*40.0+a*2.0)
				mesh.set_color(col)
				mesh.set_uv(Vector2(a/TAU,t))
				mesh.add_vertex(Vector3(cos(a)*r, radius*(0.35*(1.0-t*t)+0.08*sin(a*7.0)*t),sin(a)*r*0.75))
	mesh.index()
	mesh.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.85
	var instance := MeshInstance3D.new()
	instance.mesh = mesh.commit()
	instance.material_override = mat
	instance.position = pos
	parent.add_child(instance)
	return instance

static func pouch(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = pos
	n.material_override = material
	parent.add_child(n)
	return n
