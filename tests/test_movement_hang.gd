extends Node

# --- TEST: Movement Hang Regression ---
# Verifies that EnemyUnit correctly awaits movement completion
# and doesn't hang the turn if movement is instant or fails.

var grid_manager
var enemy
var mock_tm
var test_conn

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
	
	# Disable Audio to prevent leaks
	if gm and gm.audio_manager:
		if is_instance_valid(gm.audio_manager):
			gm.audio_manager.queue_free()
		gm.audio_manager = null

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
	test_conn = enemy.movement_finished.connect(func(): 
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
	
	# Polling Wait (Max 1.0s) rather than hard sleep
	var max_wait = 1.0
	var waited = 0.0
	while not signal_received and waited < max_wait:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	
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
		
	# Disconnect Signal
	if test_conn and test_conn.is_valid():
		test_conn.disconnect()
	
	# Explicitly remove children first (Queue Free)
	if enemy and is_instance_valid(enemy):
		# Manual Resource Cleanup to prevent leak
		if enemy.get("abilities"): enemy.abilities.clear()
		if enemy.get("behavior_resource"): enemy.behavior_resource = null
		if enemy.get("enemy_data"): enemy.enemy_data = null
		
		enemy.queue_free()
		enemy = null
		
	if grid_manager and is_instance_valid(grid_manager):
		if grid_manager.astar:
			grid_manager.astar.clear()
			grid_manager.astar = null # Release Ref
		grid_manager.queue_free()
		grid_manager = null
		
	# Clean up any remaining children (Guards etc)
	for c in get_children():
		c.queue_free()
	
	# Clear Factory Cache
	var Factory = load("res://scripts/utils/EnemyModelFactory.gd")
	if Factory and "mat_cache" in Factory:
		Factory.mat_cache.clear()

	# Stop Audio to release stream refs
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("stop_all"):
		am.stop_all()

	await TestUtils.finalize_and_quit(get_tree(), code)

func _exit_tree():
	# Redundant safety - Disconnect
	if test_conn and test_conn.is_valid(): test_conn.disconnect() 
	# Redundant safety
	if grid_manager and is_instance_valid(grid_manager): grid_manager.queue_free()
	if enemy and is_instance_valid(enemy): enemy.queue_free()
