extends Node

# --- TEST: Freed Unit Crash Regression ---
# Verifies that EnemyUnit._perform_move defaults gracefully when encountering
# a freed unit in the 'all_units' array, instead of crashing on 'grid_pos' access.

var grid_manager
var enemy
var freed_unit

func _ready():
	print("--- TEST START: Freed Unit Crash Regression ---")
	var guard = load("res://tests/TestSafeGuard.gd").new()
	guard.name = "TestSafeGuard"
	add_child(guard)
	
	setup_env()
	run_test()

func setup_env():
	grid_manager = load("res://scripts/managers/GridManager.gd").new()
	add_child(grid_manager)
	
	# Open Grid
	for x in range(5):
		for y in range(5):
			grid_manager.grid_data[Vector2(x,y)] = {
				"type": 0, "is_walkable": true, "world_pos": Vector3(x*2.0, 0, y*2.0)
			}
	grid_manager.setup_astar()

func run_test():
	print("Test: Verify _perform_move handles freed units...")
	
	enemy = load("res://scripts/entities/EnemyUnit.gd").new()
	enemy.name = "TestEnemy"
	add_child(enemy)
	enemy.initialize(Vector2(0,0))
	enemy.mobility = 3
	enemy.behavior_resource = load("res://tests/MockBehavior.gd").new()
	
	# Create a dummy unit and FREE IT immediately
	freed_unit = load("res://scripts/entities/Unit.gd").new()
	freed_unit.name = "FreedUnit"
	add_child(freed_unit)
	freed_unit.queue_free()
	
	print("Freeing dummy unit and waiting 1 frame...")
	await get_tree().process_frame # Let queue_free happen
	
	if is_instance_valid(freed_unit):
		print("WARNING: Unit still valid after 1 frame. Waiting another...")
		await get_tree().process_frame
		
	print("Is FreedUnit valid? ", is_instance_valid(freed_unit))
	
	# Prepare list with the freed reference
	# Note: In Godot, the reference might still exist in the array even if invalid
	var all_units = [enemy, freed_unit]
	
	print("Calling _perform_move with freed unit in list...")
	
	# This call causes the crash without the fix
	# We need to target something to trigger logic? 
	# _perform_move calls get_reachable_tiles, then iterates units for occupancy
	
	# Mock target to ensure logic flows
	enemy.target_unit = enemy # Self target just to have something not null if checked
	
	# Run logic
	# If this crashes, the test runner fails.
	await enemy._perform_move(grid_manager, all_units)
	
	print("✅ PASS: _perform_move completed without crash.")
	
	# Clear local refs before finalize
	all_units.clear()
	var debugger = get_node_or_null("/root/AIDebugger")
	if debugger:
		debugger.decision_history.clear()
		
	_finalize(0)

func _finalize(code):
	if code == 0:
		print("✅ ALL TESTS PASSED")
	else:
		print("❌ FAILED")
	
	if enemy: 
		enemy.target_unit = null
		if "behavior_resource" in enemy: enemy.behavior_resource = null
		if "abilities" in enemy: enemy.abilities.clear()
		enemy.queue_free()
	if grid_manager: grid_manager.queue_free()
	
	# Cleanup safeguard
	for c in get_children():
		if c.name == "TestSafeGuard":
			c.queue_free()
			
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(code)
