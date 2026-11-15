extends RefCounted
const Surface := preload("res://character_surface.gd")
static func build(root: Node3D, seed_value := 0) -> Dictionary:
	return Surface.build(root,"clicker",seed_value)
