extends Node

var grid_manager
var unit

func _ready():
	print("Reproducing Movement Backtrack Bug...")
	_setup_test_environment()
	print("DEBUG: Backtrack Reproduction Started...")
	
	var guard = load("res://tests/TestSafeGuard.gd").new()
	guard.name = "TestSafeGuard"
	add_child(guard)
	
	# Check if we need to wait for frame
	await get_tree().process_frame
	_run_test()

func _setup_test_environment():
	# GridManager (Singleton Logic or Mock)
	# Since we run as scene, Autoloads 'GameManager', 'SignalBus' should be present.
	# But GridManager might not be auto-instantiated if it's not an Autoload (it is managed by GameManager usually or Scene).
	
	# Check if GridManager exists, if not create it
	grid_manager = get_tree().get_first_node_in_group("GridManager")
	if not grid_manager:
		var gm_script = load("res://scripts/managers/GridManager.gd")
		grid_manager = gm_script.new()
		grid_manager.name = "GridManager"
		add_child(grid_manager)
	
	# Generate simple grid
	grid_manager.generate_tactical_grid(-1) # Default
	
	# Mock Unit
	var unit_script = load("res://scripts/entities/Unit.gd")
	unit = unit_script.new()
	unit.name = "TestUnit"
	add_child(unit)
	
	# Place Unit at (0, 0)
	unit.initialize(Vector2(0, 0), grid_manager)
	grid_manager.refresh_pathfinding([unit]) # Register unit on grid




func _run_test():
	var start_pos = Vector2(0, 0)
	var target_pos = Vector2(1, 0)
	
	print("Initial Pos: ", unit.grid_pos)
	
	# 1. Move Unit to (1, 0)
	print("Attempting Move: (0, 0) -> (1, 0)")
	
	# Assume movement success for reproduction (we can manually update grid_pos to simulate "moved")
	# In real game, UnitMoveState handles this. We will simulate the STATE CHANGE.
	
	# Emulate "Move Finished" logic:
	unit.grid_pos = target_pos
	grid_manager.refresh_pathfinding([unit])
	
	print("Moved to: ", unit.grid_pos)
	
	# 2. Check if (0, 0) is now valid
	var is_start_free = not grid_manager.is_tile_blocked(start_pos)
	var is_start_valid_dest = grid_manager.is_valid_destination(start_pos)
	
	print("Checking old position (0, 0):")
	print(" - Is Blocked? ", not is_start_free)
	print(" - Is Valid Dest? ", is_start_valid_dest)
	
	if not is_start_valid_dest:
		print("FAILURE: Old position (0, 0) is NOT a valid destination!")
		print(" - Occupancy Dump: ", grid_manager._unit_occupancy)
	else:
		print("SUCCESS: Old position (0, 0) is free.")
		
	_cleanup()
	get_tree().quit()

func _cleanup():
	if unit: unit.free()
	if grid_manager: grid_manager.free()
	unit = null
	grid_manager = null
	# Wait for any deferred calls
	await get_tree().process_frame

