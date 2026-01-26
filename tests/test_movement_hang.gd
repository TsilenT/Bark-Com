extends Node

# --- TEST: Movement Hang Regression ---
# Verifies that EnemyUnit correctly awaits movement completion
# and doesn't hang the turn if movement is instant or fails.

var grid_manager
var enemy
var mock_tm

func _ready():
	print("--- TEST START: Movement Hang ---")
	var guard = load("res://tests/TestSafeGuard.gd").new()
	guard.name = "TestSafeGuard"
	add_child(guard)
	
	setup_env()
	run_test()

func setup_env():
	grid_manager = load("res://scripts/managers/GridManager.gd").new()
	add_child(grid_manager)
	
	# SAFETY CHECK
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.TEST_MOCK_ENABLED = true
		gm.save_file_path = "user://test_savegame.dat"
	
	# Open Grid
	for x in range(5):
		for y in range(5):
			grid_manager.grid_data[Vector2(x,y)] = {
				"type": 0, "is_walkable": true, "world_pos": Vector3(x * 2.0, 0, y * 2.0)
			}
	grid_manager._setup_astar()

var signal_received = false

func run_test():
	print("Test: Verify Enemy Waits for Movement Signal...")
	
	enemy = load("res://scripts/entities/EnemyUnit.gd").new()
	enemy.name = "TestEnemy"
	add_child(enemy)
	enemy.initialize(Vector2(0,0))
	enemy.mobility = 3
	enemy.current_ap = 2
	
	print("Triggering _perform_move...")
	
	# Spy on signal
	enemy.movement_finished.connect(func(): 
		print("Signal movement_finished received!")
		signal_received = true
	)
	
	# Force move to (2,0)
	var target_tile = Vector2(2,0)
	var path = grid_manager.get_move_path(Vector2(0,0), target_tile)
	
	var world_path: Array[Vector3] = []
	var grid_subset: Array[Vector2] = []
	for i in range(1, path.size()):
		world_path.append(grid_manager.get_world_position(path[i]))
		grid_subset.append(path[i])
	
	# Testing move_along_path directly as that's what _perform_move calls
	# and where the await happens.
	enemy.move_along_path(world_path, grid_subset)
	
	print("Movement started. Waiting for completion...")
	
	# Wait enough time for movement (0.25s per tile * 2 = 0.5s)
	await get_tree().create_timer(1.0).timeout
	
	if signal_received:
		print("✅ PASS: Movement finished signal emitted.")
		# Also verify position
		if enemy.grid_pos == target_tile:
			print("✅ PASS: Position updated.")
			await _finalize(0)
		else:
			print("❌ FAIL: Position not updated. Got: ", enemy.grid_pos)
			await _finalize(1)
	else:
		print("❌ FAIL: Signal NOT emitted! Turn would hang.")
		await _finalize(1)

func _finalize(code):
	if code == 0:
		print("✅ ALL TESTS PASSED")
	else:
		print("❌ FAILED")
	
	# Cleanup
	TestUtils.free_children(self)
	
	if enemy and is_instance_valid(enemy):
		enemy.queue_free()
	if grid_manager and is_instance_valid(grid_manager):
		grid_manager.queue_free()
	
	# Clear Factory Cache
	var Factory = load("res://scripts/utils/EnemyModelFactory.gd")
	if Factory and "mat_cache" in Factory:
		Factory.mat_cache.clear()

	await TestUtils.finalize_and_quit(get_tree(), code)
