extends Node

var grid_manager
var combat_resolver

func _ready():
	# Watchdog
	add_child(load("res://tests/TestSafeGuard.gd").new())

	print("Starting Cover Logic Tests...")
	setup()
	test_hydrant_default_cover()
	test_high_ground_negation()
	print("All Tests Completed.")
	get_tree().quit()

func _exit_tree():
	if grid_manager:
		grid_manager.free()

func setup():
	grid_manager = GridManager.new()
	# Mimic Grid Data initialization
	grid_manager.grid_data = {}
	combat_resolver = load("res://scripts/managers/CombatResolver.gd")

func test_hydrant_default_cover():
	print("TEST: Hydrant Cover Height")
	
	# Pre-initialize grid data (Required for update_tile_state)
	grid_manager.grid_data[Vector2(0,0)] = {
		"type": 0, 
		"is_walkable": true, 
		"elevation": 0,
		"cover_height": 0.0
	}
	
	var hydrant = load("res://scripts/entities/DestructibleCover.gd").new()
	hydrant.initialize(Vector2(0,0), grid_manager, "Street", hydrant.Variant.HYDRANT)
	
	# Check what it wrote to GridManager
	if grid_manager.grid_data.has(Vector2(0,0)):
		var data = grid_manager.grid_data[Vector2(0,0)]
		var height = data.get("cover_height", 0.0)
		if height >= 2.0:
			print("PASS: Hydrant registered as Full Cover (Height: " + str(height) + ").")
		else:
			print("FAILURE: Hydrant registered as " + str(height) + ". Expected >= 2.0 (Full Cover).")
	else:
		print("FAILURE: Hydrant failed to register in grid.")
	hydrant.free()

func test_high_ground_negation():
	print("TEST: High Ground Negation")
	# Scenario:
	# Attacker: (0, 0, Elev 2)
	# Target: (0, 3, Elev 0)
	# Wall: (0, 2, Elev 0, Height 2.0)
	
	# Setup Grid Data
	grid_manager.grid_data.clear()
	
	# Attacker (No cover needed, just elevation)
	grid_manager.grid_data[Vector2(0,0)] = {"elevation": 2}
	
	# Obstacle
	grid_manager.grid_data[Vector2(0,2)] = {"elevation": 0, "cover_height": 2.0}
	
	# Target
	grid_manager.grid_data[Vector2(0,3)] = {"elevation": 0}
	
	var cover_val = combat_resolver.get_cover_height_at_pos(
		Vector2(0,3), # Target
		Vector2(0,0), # Attacker
		grid_manager
	)
	
	# Expectation: 
	# Elevation Diff = 2. Cover Height = 2.
	# Effective Cover = 0.
	
	if cover_val < 1.0:
		print("PASS: High Ground successfully negated cover. Result: " + str(cover_val))
	else:
		print("FAILURE: High Ground failed to negate cover. Result: " + str(cover_val) + " (Expected < 1.0)")

