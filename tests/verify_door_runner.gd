extends Node3D

# verify_door_runner.gd
# Validates Door functionality

const GridManager = preload("res://scripts/managers/GridManager.gd")
const Door = preload("res://scripts/entities/Door.gd")

func _ready():
	add_child(load("res://tests/TestSafeGuard.gd").new())
	print("--- Starting Door Verification ---")
	
	# 1. Setup Mock GM
	var gm = GridManager.new()
	gm.name = "GridManager"
	add_child(gm)
	
	# Mock data for (1,1)
	var pos = Vector2(1,1)
	gm.grid_data = {
		pos: {
			"type": 0,
			"is_walkable": true,
			"world_pos": Vector3(2,0,2)
		}
	}
	
	# 2. Spawn Door
	var door = Door.new()
	add_child(door)
	door.initialize(pos, gm, "Indoors")
	
	# CHECK 1: Initial State
	var tile_data = gm.grid_data[pos]
	if tile_data.type == GridManager.TileType.OBSTACLE and not tile_data.is_walkable:
		print("PASS: Door initialized as OBSTACLE (Unwalkable).")
	else:
		print("FAIL: Door did not set grid to OBSTACLE.")
		get_tree().quit(1)
		return
		
	# CHECK 2: Interaction (Open)
	print("Testing Interaction (Open)...")
	door.interact(null) # Mock unit
	
	# Wait for Tween? Or just check logic immediately?
	# Tween is visual. Logic should be instant.
	tile_data = gm.grid_data[pos]
	if tile_data.type == GridManager.TileType.GROUND and tile_data.is_walkable:
		# CHECK SUPER CRITICAL: Occupancy must be cleared
		if tile_data.get("unit") == null:
			print("PASS: Interaction opened door and CLEARED occupancy.")
		else:
			print("FAIL: Interaction opened door but occupancy ('unit') is still set!")
			get_tree().quit(1)
			return
	else:
		print("FAIL: Door interaction did not clear grid.")
		get_tree().quit(1)
		return
		
	if door.is_open:
		print("PASS: Door.is_open is true.")
		
	# CHECK 3: Destruction
	print("Testing Destruction...")
	# Reset state first to ensure destroy works from Closed OR Open.
	# Let's respawn or re-close.
	door.queue_free()
	await get_tree().process_frame
	
	var door2 = Door.new()
	add_child(door2)
	door2.initialize(pos, gm)
	
	# Verify it's blocked again
	if gm.grid_data[pos].type == GridManager.TileType.OBSTACLE:
		print("PASS: Respawned Door blocked grid.")
	
	door2.take_damage_from(100, null, "Generic") # Should call destroy()
	
	tile_data = gm.grid_data[pos]
	if tile_data.type == GridManager.TileType.GROUND and tile_data.is_walkable:
		print("PASS: Destroyed door cleared grid.")
	else:
		print("FAIL: Destroyed door did not clear grid.")
		get_tree().quit(1)
		return
		
	print("ALL DOOR TESTS PASSED")
	get_tree().quit()
