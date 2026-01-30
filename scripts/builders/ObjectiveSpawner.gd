class_name ObjectiveSpawner
extends RefCounted

const LOG_PREFIX = "ObjSpawner: "

# Objective Types (Matching MissionConfig/Legacy)
const OBJ_TYPE_EXTERMINATION = 0
const OBJ_TYPE_RESCUE = 1
const OBJ_TYPE_LOOT = 2
const OBJ_TYPE_DEFENSE = 4

## Main Entry Point
## Returns the count of successfully spawned objectives
func spawn_objectives(type: int, count: int, config: MissionConfig, grid_manager: GridManager) -> int:
	GameManager.log(LOG_PREFIX, "Spawning ", count, " Objectives (Type ", type, ")...")
	var successful_spawns = 0
	
	for i in range(count):
		# 1. Find Position
		var pos = _find_valid_objective_pos(type, grid_manager)
		if pos == Vector2(-1, -1):
			GameManager.log(LOG_PREFIX, "Could not find spot for objective ", i)
			continue
			
		var obj_node = null
		
		# 2. Instantiate Based on Type
		match type:
			OBJ_TYPE_LOOT: # Loot Crates
				obj_node = load("res://scripts/entities/LootCrate.gd").new()
				obj_node.name = "ObjectiveCrate_" + str(i)
				
				# Loot Tables
				var item = _get_random_consumable()
				if item:
					obj_node.loot_table.append(item)

			OBJ_TYPE_RESCUE: # Rescue Unit
				var recruit_data = config.reward_recruit_data
				if recruit_data.is_empty():
					# Fallback
					recruit_data = {
						"name": "Lost Corgi", 
						"class": "Recruit",
						"level": 1
					}
				
				obj_node = load("res://scripts/entities/CorgiUnit.gd").new()
				obj_node.name = recruit_data.get("name", "RescueTarget")
				obj_node.unit_name = obj_node.name
				obj_node.apply_class_stats(recruit_data.get("class", "Recruit"))
				obj_node.is_rescue_target = true
				obj_node.faction = "Neutral" # Passive until rescued
				
				# Unique: Beacon Attachment needed after add_child usually, 
				# For now, we return the node, caller/helper handles scene tree add.
				
				obj_node.add_to_group("RescueTargets")
				obj_node.add_to_group("Objectives") # Required for GameUI context check

			OBJ_TYPE_DEFENSE: # Golden Hydrant
				var gh_script = load("res://scripts/entities/GoldenHydrant.gd")
				if gh_script:
					obj_node = gh_script.new()
					obj_node.name = "GoldenHydrant"
					
					# Special Case: Hydrant forces wall destruction in MissionManager.
					# We handle that in _find_pos logic or post-spawn?
					# The finding logic for Hydrant was specific (Center Spiral).
					# We should move that logic to _find_valid_objective_pos with type check.
		
		# 3. Finalize Spawn
		if obj_node:
			# Wall clearing logic for Hydrant moved here/handled by position finder result?
			# Actually, if type == DEFENSE, we might need to clear the wall at 'pos'.
			if type == OBJ_TYPE_DEFENSE:
				_clear_walls_at(pos, grid_manager)

			_add_to_scene(obj_node, pos, grid_manager)
			
			# Post-Add Logic (Beacons)
			if type == OBJ_TYPE_RESCUE:
				_attach_rescue_beacon(obj_node)
				
			successful_spawns += 1
			GameManager.log(LOG_PREFIX, "Spawned Objective (Type ", type, ") at ", pos)
			
	return successful_spawns

func spawn_loot(grid_manager: GridManager) -> void:
    # Single random loot spawn (10% chance logic usually in Manager, but method here)
	var pos = _find_valid_objective_pos(OBJ_TYPE_LOOT, grid_manager)
	if pos != Vector2(-1, -1):
		var crate = load("res://scripts/entities/LootCrate.gd").new()
		crate.name = "RandomLootCrate"
		# Add random item via helper
		var item = _get_random_consumable()
		if item:
			crate.loot_table.append(item)
		_add_to_scene(crate, pos, grid_manager)
		GameManager.log(LOG_PREFIX, "Random field loot spawned at ", pos)

# --- Private Helpers ---

func _add_to_scene(node: Node3D, grid_pos: Vector2, gm: GridManager):
	# Add to GM's parent (Main/SceneRoot) or GM itself? 
	# MissionManager used: grid_manager.get_parent().add_child(obj_node)
	if gm.get_parent():
		gm.get_parent().add_child(node)
	else:
		gm.add_child(node) # Fallback
		
	node.position = gm.get_world_position(grid_pos)
	if "grid_pos" in node:
		node.grid_pos = grid_pos
	
	if node.has_method("initialize"):
		node.initialize(grid_pos, gm)
	elif node.has_method("setup_visuals"): # Fallback for units if initialize differs
		pass
		
	# Update Grid Data
	if gm.grid_data.has(grid_pos):
		gm.grid_data[grid_pos]["unit"] = node


func _find_valid_objective_pos(type: int, gm: GridManager) -> Vector2:
	if type == OBJ_TYPE_DEFENSE:
		# Spiral from Center Logic
		var center = Vector2(gm.width / 2, gm.height / 2)
		var max_dist = min(gm.width, gm.height) / 2
		
		# Simplification: specific logic for Hydrant 
		# We need a reachable tile, creating one if needed (breaking walls).
		return _find_spiral_pos(center, max_dist, gm)
		
	else:
		# Random Valid Logic
		for i in range(20):
			var p = gm.get_random_valid_position()
			if p != Vector2(-1, -1):
				# Ensure distance from player spawn (1,1)
				if p.distance_to(Vector2(1,1)) > 5:
					return p
		return Vector2(-1, -1)

func _find_spiral_pos(center: Vector2, range_limit: int, gm: GridManager) -> Vector2:
	# Simplified spiral or proximity search
	# For Hydrant, we prefer center, even if wall (we break it).
	# But checking reachability is hard without pathfinding from spawn.
	# We'll trust the original logic's intent: try center area.
	
	var best_pos = Vector2(-1, -1)
	
	# Check center 3x3
	for x in range(center.x - 2, center.x + 3):
		for y in range(center.y - 2, center.y + 3):
			var p = Vector2(x, y)
			if gm.is_valid_tile(p):
				return p # Just take the first valid coordinate near center
				
	return center # Fallback

func _clear_walls_at(pos: Vector2, gm: GridManager):
	# Raycast or Grid Data check to remove walls
	var world_pos = gm.get_world_position(pos)
	var space = gm.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(world_pos + Vector3(0, 10, 0), world_pos - Vector3(0, 10, 0))
	var result = space.intersect_ray(query)
	
	if result and result.collider:
		if result.collider.is_class("StaticBody3D") or result.collider.is_in_group("Destructible"):
			result.collider.queue_free()
			# Update Grid Data to remove "Wall" type?
			# LevelGenerator uses Type 1 for Wall.
			if gm.grid_data.has(pos):
				gm.grid_data[pos]["type"] = 0 # FLOOR
				gm.grid_data[pos]["walkable"] = true


func _attach_rescue_beacon(unit: Node):
	# Procedural Beacon (Ported from MissionManager)
	var beacon_pivot = Node3D.new()
	beacon_pivot.name = "RescueBeacon"
	beacon_pivot.position = Vector3(0, 3.5, 0) # High above head
	unit.add_child(beacon_pivot)
	
	# Arrow Mesh (Prism pointing down)
	var mesh_inst = MeshInstance3D.new()
	var mesh = PrismMesh.new()
	mesh.size = Vector3(0.8, 1.2, 0.2) # Flat arrow
	mesh_inst.mesh = mesh
	mesh_inst.rotation_degrees.z = 180 # Point down
	
	# Material (Gaudy Gold)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.84, 0.0) # Gold
	mat.metallic = 1.0
	mat.roughness = 0.2
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.84, 0.0)
	mat.emission_energy_multiplier = 2.0
	mesh_inst.material_override = mat
	
	beacon_pivot.add_child(mesh_inst)
	
	# Animation (Tween)
	var tween = beacon_pivot.create_tween().set_loops()
	
	# Bounce
	tween.tween_property(mesh_inst, "position:y", 0.5, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mesh_inst, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	
	# Spin (Separate Tween)
	var spin_tween = beacon_pivot.create_tween().set_loops()
	spin_tween.tween_property(mesh_inst, "rotation_degrees:y", 360.0, 2.0).as_relative()


func _get_random_consumable():
	var valid_items = []
	
	# 1. Try GameManager Shop Stock
	var gm = get_node_or_null("/root/GameManager")
	if gm and "shop_stock" in gm:
		for item in gm.shop_stock:
			if item is ConsumableData:
				valid_items.append(item)
				
	# 2. Fallback (If GM missing or stock empty)
	if valid_items.is_empty():
		var pool = [
			"res://scripts/resources/items/Medkit.gd",
			"res://scripts/resources/items/GrenadeItem.gd",
			"res://scripts/resources/items/SanityTreat.gd"
		]
		var picked_path = pool.pick_random()
		var script = load(picked_path)
		if script:
			return script.new()
		return null
		
	# 3. Pick Random from Valid Items
	var choice = valid_items.pick_random()
	# Duplicate to ensure unique instance ownership
	return choice.duplicate()

# Helper for RefCounted to get tree/nodes safely
func get_node_or_null(path: String) -> Node:
	if Engine.get_main_loop() and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null(path)
	return null
