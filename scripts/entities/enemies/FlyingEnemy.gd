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

	# Fallback Weapon (Ensure Range 6, Overwrite Unit.gd default "Bark")
	if not primary_weapon or (primary_weapon.display_name == "Bark"):
		var bolt = WeaponData.new()
		bolt.display_name = "Ectoplasm Bolt"
		bolt.damage = 1
		bolt.weapon_range = 6
		primary_weapon = bolt
		attack_range = 6

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




func check_los(tile: Vector2, target, gm: GridManager) -> bool:
	const FLIGHT_HEIGHT = 4.0 # 2 Tiles High
	
	# Ray from elevated position
	var my_eye = gm.get_world_position(tile) + Vector3(0, FLIGHT_HEIGHT, 0)
	var target_center = target.position + Vector3(0, 1.0, 0)
	
	var space = get_viewport().world_3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(my_eye, target_center)
	query.exclude = [self.get_rid()] 
	
	var result = space.intersect_ray(query)
	
	if result:
		if result.collider == target:
			return true
		# Helper: Check if hit object is very close to target (sometimes origin differs)
		if result.collider.get_parent() == target:
			return true
			
		return false # Blocked
		
	return true # Clear line if nothing hit
