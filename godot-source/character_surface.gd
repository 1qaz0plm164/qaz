extends RefCounted
const Details := preload("res://character_details.gd")
# Authored procedural character surfaces. Rig anchors preserve gameplay contracts.
static func mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	var noise := FastNoiseLite.new()
	noise.frequency = 0.07
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.noise = noise
	texture.as_normal_map = true
	texture.bump_strength = 1.2
	m.normal_enabled = true
	m.normal_texture = texture
	m.normal_scale = 0.35
	var albedo := NoiseTexture2D.new()
	albedo.width = 256
	albedo.height = 256
	albedo.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0,Color(0.22,0.20,0.18))
	ramp.set_color(1,Color(1.0,0.93,0.83))
	albedo.color_ramp = ramp
	m.albedo_texture = albedo
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(4,4,4)
	return m

static func ell(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 24
	m.rings = 12
	var n := MeshInstance3D.new()
	n.mesh = m
	n.material_override = material
	n.position = pos
	n.scale = size
	parent.add_child(n)
	return n

static func pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

static func build(root: Node3D, kind: String, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var human := kind == "bandit"
	var heavy := kind == "bloater"
	var click := kind == "clicker"
	var w := 2.25 if heavy else 1.0
	var hip := 1.05 if heavy else 0.95
	var skin := mat(Color(0.64,0.46,0.34) if human else Color(0.39,0.37,0.29))
	var cloth := mat(Color(0.18 + rng.randf()*0.1,0.20,0.16))
	var pants := mat(Color(0.12,0.13,0.14))
	var leather := mat(Color(0.055,0.043,0.035))
	var wound := mat(Color(0.24,0.065,0.045),0.5)
	var bone := mat(Color(0.59,0.47,0.30))
	var legs: Array[Node3D] = []
	var arms: Array[Node3D] = []
	var knees: Array[Node3D] = []
	var elbows: Array[Node3D] = []
	var ankles: Array[Node3D] = []
	for side in [-1.0,1.0]:
		var leg := pivot(root,Vector3(side*0.115*w,hip,0))
		var knee := pivot(leg,Vector3(0,-0.43,0))
		var ankle := pivot(knee,Vector3(0,-0.40,0))
		legs.append(leg)
		knees.append(knee)
		ankles.append(ankle)
	var torso := pivot(root,Vector3(0,hip,0))
	torso.rotation.x = 0.0 if human else (-0.55 if click else (-0.3 if heavy else -0.22))
	for side in [-1.0,1.0]:
		var arm := pivot(torso,Vector3(side*(0.62 if heavy else (0.28 if click else 0.26)),0.95 if heavy else (0.7 if click else 0.66),-0.05 if heavy else 0.0))
		arm.rotation.x = 0.0 if human else (0.5 if heavy else (0.95 if click else 1.25))
		var elbow := pivot(arm,Vector3(0,-0.5 if heavy else -0.32,0))
		arms.append(arm)
		elbows.append(elbow)
	var head := pivot(torso,Vector3(0,1.15 if heavy else (0.98 if click else 0.86),-0.25 if heavy else (-0.1 if click else 0.0)))
	head.rotation.x = 0.25 if heavy else (0.35 if click else 0.0)
	for ankle in ankles:
		ell(ankle,Vector3(0,-0.065,-0.07),Vector3(0.07*w,0.072,0.15),leather)
	# Jacket front, collar, belt and stitched cargo pockets follow the torso.
	if not heavy:
		for side in [-1.0,1.0]:
			Details.pouch(torso,Vector3(side*0.09,0.34,-0.145),Vector3(0.16,0.46,0.035),cloth)
			Details.pouch(torso,Vector3(side*0.11,0.44,-0.18),Vector3(0.105,0.14,0.045),cloth)
			Details.pouch(torso,Vector3(side*0.11,0.50,-0.207),Vector3(0.11,0.025,0.012),leather)
			var collar := Details.pouch(torso,Vector3(side*0.07,0.68,-0.08),Vector3(0.06,0.11,0.025),cloth)
			collar.rotation.z = side*0.35
		Details.pouch(torso,Vector3(0,0.1,-0.14),Vector3(0.32,0.038,0.03),leather)
		Details.pouch(torso,Vector3(0,0.1,-0.16),Vector3(0.04,0.035,0.012),bone)
		for i in 7:
			ell(torso,Vector3(0,0.19+i*0.06,-0.17),Vector3(0.006,0.007,0.006),leather)
	if human:
		ell(head,Vector3(0,0.13,0.015),Vector3(0.108,0.075,0.104),leather)
		Details.pouch(torso,Vector3(0,0.42,0.17),Vector3(0.27,0.37,0.13),leather)
		for side in [-1.0,1.0]:
			Details.pouch(torso,Vector3(side*0.15,0.42,-0.20),Vector3(0.04,0.42,0.02),leather)
			Details.pouch(legs[0 if side<0 else 1],Vector3(side*0.09,-0.17,0),Vector3(0.045,0.17,0.12),cloth)
	else:
		for i in (32 if heavy else (18 if click else 5)):
			var a := rng.randf()*TAU
			var target := head if click or i < 8 else torso
			var pos := Vector3(cos(a)*0.13,sin(a)*0.12,-0.06) if target == head else Vector3(cos(a)*0.23*w,rng.randf_range(0.2,0.7),sin(a)*0.18*w)
			var r := rng.randf_range(0.045,0.11) * (1.5 if heavy else 1.0)
			var plate := Details.fungus(target,pos,r*1.4,a)
			plate.rotation = Vector3(rng.randf_range(-0.5,0.5),a,rng.randf_range(-0.5,0.5))
			Details.fungus(plate,Vector3(0,0.018,0),r,a+1.0)
	var parts := {"legs":legs,"arms":arms,"torso":torso,"head":head,"knees":knees,"elbows":elbows,"ankles":ankles}
	var anatomy := preload("res://anatomy_skin.gd").new()
	root.add_child(anatomy)
	anatomy.setup(root,parts,kind,[pants,cloth if not heavy else skin,skin])
	return parts

static func gait(parts: Dictionary, phase: float, amount: float, delta: float, armed := false) -> void:
	var k := 1.0-exp(-12.0*delta)
	for i in 2:
		var cycle := phase + i*PI
		parts.knees[i].rotation.x = lerp_angle(parts.knees[i].rotation.x,-maxf(0.0,sin(cycle))*0.85*amount,k)
		parts.ankles[i].rotation.x = lerp_angle(parts.ankles[i].rotation.x,maxf(0.0,sin(cycle))*0.35*amount,k)
		parts.elbows[i].rotation.x = lerp_angle(parts.elbows[i].rotation.x,0.0 if armed else 0.12+maxf(0.0,-sin(cycle))*0.35*amount,k)
