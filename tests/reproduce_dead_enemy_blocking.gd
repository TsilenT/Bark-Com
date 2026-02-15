extends Node

var grid_manager
var player_unit: Unit
var enemy_unit: Unit

func _ready():
	await get_tree().create_timer(1.0).timeout
	var gm = get_node("/root/GameManager")
	gm.settings["debug_logging"] = true
	gm.log("TEST_REPRO", "Reproducing Dead Enemy Blocking Bug...")
	print("RAW PRINT: Starting Test...")
	_setup_test_environment()
	
	# Add TestSafeGuard
	var guard = load("res://tests/TestSafeGuard.gd").new()
	guard.name = "TestSafeGuard"
	add_child(guard)
	
	await get_tree().process_frame
	_run_test()

func _setup_test_environment():
	var gm = get_node("/root/GameManager")
	# 1. Setup GridManager
	grid_manager = get_tree().get_first_node_in_group("GridManager")
	if not grid_manager:
		var gm_script = load("res://scripts/managers/GridManager.gd")
		grid_manager = gm_script.new()
		grid_manager.name = "GridManager"
		add_child(grid_manager)
		grid_manager.generate_tactical_grid(-1) # Default
	
	# 2. Mock TurnManager (needed for units if they access it)
	var tm_mock = Node.new()
	tm_mock.name = "TurnManager"
	var tm_script = GDScript.new()
	tm_script.source_code = "extends Node\nvar units = []"
	tm_script.reload()
	tm_mock.set_script(tm_script)
	tm_mock.add_to_group("TurnManager")
	add_child(tm_mock)
	
	# 3. Spawn Player Unit at (0, 0)
	var unit_script = load("res://scripts/entities/Unit.gd")
	player_unit = unit_script.new()
	player_unit.name = "PlayerUnit"
	player_unit.faction = "Player"
	add_child(player_unit)
	player_unit.initialize(Vector2(0, 0), grid_manager)
	
	# 4. Spawn Enemy Unit at (1, 0)
	# Use Unit script directly if EnemyUnit causes issues in test env
	enemy_unit = unit_script.new()
	if not enemy_unit:
		gm.log("TEST_REPRO", "CRITICAL: Failed to instantiate enemy_unit!")
	enemy_unit.name = "EnemyUnit"
	enemy_unit.faction = "Enemy"
	add_child(enemy_unit)
	enemy_unit.initialize(Vector2(1, 0), grid_manager)
	
	# 5. Refresh Grid
	grid_manager.refresh_pathfinding([player_unit, enemy_unit])
	
	gm.log("TEST_REPRO", "Setup Complete.")
	gm.log("TEST_REPRO", " - Player at: " + str(player_unit.grid_pos))
	gm.log("TEST_REPRO", " - Enemy at: " + str(enemy_unit.grid_pos))
	gm.log("TEST_REPRO", " - (1,0) Blocked? " + str(grid_manager.is_tile_blocked(Vector2(1, 0))))

func _run_test():
	var gm = get_node("/root/GameManager")
	var enemy_pos = Vector2(1, 0)
	
	# Verify Enemy Blocks Tile Initial State
	var blocked_initial = grid_manager.is_tile_blocked(enemy_pos)
	if not blocked_initial:
		gm.log("TEST_REPRO", "ERROR: Enemy should block tile (1,0) initially, but didn't.")
	else:
		gm.log("TEST_REPRO", "SUCCESS: Enemy initially blocks tile.")

	# 1. Kill Enemy
	gm.log("TEST_REPRO", "Killing Enemy...")
	if not is_instance_valid(enemy_unit):
		gm.log("TEST_REPRO", "CRITICAL ERROR: enemy_unit is invalid/null before taking damage!")
		return

	# Use take_damage_from to avoid deprecation warning
	enemy_unit.take_damage_from(100, null, "Generic") 
	
	gm.log("TEST_REPRO", "Enemy HP: " + str(enemy_unit.current_hp))
	gm.log("TEST_REPRO", "Enemy is_dead: " + str(enemy_unit.is_dead))
	
	# 2. Trigger Grid Refresh (Now explicitly via MissionManager fix logic is tested implicitly?)
	# NO, we are manually testing the *logic*.
	# If we just corrected MissionManager, we need to simulate MissionManager calling it?
	# Or do we want to check if the BUG IS GONE by simulating the game flow?
	# Since this test mimics the GAME state, we must manually call refresh IF we want to prove it works when refreshed.
	# But the bug was that MissionManager DIDN'T call refresh.
	# So this test script was verifying that *dead enemies don't block IF refreshed*.
	# If they DO block even if refreshed, then GridManager is broken.
	# If they don't block if refreshed, then the fix in MissionManager handles the "game loop".
	
	# So for this UNIT TEST, we must call refresh manually to verify GridManager behavior.
	grid_manager.refresh_pathfinding([player_unit, enemy_unit])
	
	# 3. Check if tile is free
	var blocked_after_death = grid_manager.is_tile_blocked(enemy_pos)
	
	gm.log("TEST_REPRO", "After Death (and refresh):")
	gm.log("TEST_REPRO", " - Is Blocked? " + str(blocked_after_death))
	
	if blocked_after_death:
		gm.log("TEST_REPRO", "FAILURE: Dead enemy still blocks movement!")
	else:
		gm.log("TEST_REPRO", "SUCCESS: Dead enemy no longer blocks movement.")
		
	_cleanup()
	get_tree().quit()

func _cleanup():
	if player_unit: player_unit.free()
	if enemy_unit: enemy_unit.free()
	if grid_manager: grid_manager.free()
