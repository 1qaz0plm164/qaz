extends RefCounted
# Шум и дым — общие помощники для стелса.
#   Sound.make(get_tree(), где, радиус)  — все враги в радиусе слышат шум
#   Sound.in_smoke(get_tree(), точка)    — точка внутри дымовой завесы (сквозь дым не видно)

static func make(tree: SceneTree, pos: Vector3, radius: float, by_player := true) -> void:
	for e in tree.get_nodes_in_group("enemy"):
		if e.has_method("hear"):
			e.hear(pos, radius, by_player)

static func in_smoke(tree: SceneTree, pos: Vector3) -> bool:
	for s in tree.get_nodes_in_group("smoke"):
		if s.covers(pos):
			return true
	return false
