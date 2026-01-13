extends "res://scripts/entities/EnemyUnit.gd"

func _ready():
	super._ready()
	mobility = 8 # High mobility
	# Set Behavior
	_load_behavior(7) # FLYING

	# Visuals (Blue-ish?)
	var mesh = get_node_or_null("Mesh")
	if mesh:
		if not mesh.material_override:
			mesh.material_override = StandardMaterial3D.new()
		mesh.material_override.albedo_color = Color.LIGHT_SKY_BLUE

func get_reachable_tiles(gm: GridManager) -> Array:
	var reachable = []
	var queue = []
	var visited = {}

	queue.append({"pos": grid_pos, "dist": 0})
	visited[grid_pos] = true
	reachable.append(grid_pos)

	while queue.size() > 0:
		var current = queue.pop_front()
		var c_pos = current["pos"]
		var c_dist = current["dist"]

		if c_dist >= mobility:
			continue

		var neighbors = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]
		for n in neighbors:
			var next_pos = c_pos + n
			
			# Flying Check: Just needs to be within grid bounds
			if not visited.has(next_pos) and gm.grid_data.has(next_pos):
				# Flying ignores 'is_walkable' and 'is_tile_blocked' (unless wall height?)
				# For now, totally free movement (Ghost-like)
				visited[next_pos] = true
				reachable.append(next_pos)
				queue.append({"pos": next_pos, "dist": c_dist + 1})

	return reachable
