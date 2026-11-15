extends RefCounted
# Помощник для звуков: проигрывает звук и сам удаляет плеер, когда он закончится

# Обычный (2D) звук: выстрел, перезарядка, интерфейс
static func play(ctx: Node, stream: AudioStream, volume_db := 0.0, pitch := 1.0, pitch_var := 0.05) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.process_mode = Node.PROCESS_MODE_ALWAYS   # чтобы звучал и на паузе
	_scene_root(ctx).add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

# Звук из точки в мире: попадание и смерть врага (слышно, с какой стороны)
static func play_3d(ctx: Node, stream: AudioStream, pos: Vector3, volume_db := 0.0, pitch := 1.0, pitch_var := 0.08) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.unit_size = 8.0
	_scene_root(ctx).add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()

static func _scene_root(ctx: Node) -> Node:
	var tree := ctx.get_tree()
	return tree.current_scene if tree.current_scene else tree.root
