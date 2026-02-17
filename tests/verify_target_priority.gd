extends Node

func _ready():
	print("--- Verifying Target Priority ---")
	await get_tree().process_frame
	_run_test()
	
func _run_test():
	var main_script = load("res://scripts/core/Main.gd")
	var main_node = main_script.new()
	add_child(main_node)
	# Add TestSafeGuard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	main_node.grid_manager.generate_tactical_grid(1)
	
	await get_tree().process_frame
	
	# ----------------------------------------------------
	# TEST 1: Hydrant vs Player (Equal Distance)
	# ----------------------------------------------------
	print("\nRunning Test 1: Hydrant vs Player (Equal/Close Dist)")
	var enemy = load("res://scripts/entities/EnemyUnit.gd").new()
	enemy.grid_pos = Vector2(0,0)
	main_node.grid_manager.get_parent().add_child(enemy)
	
	var player = load("res://scripts/entities/Unit.gd").new()
	player.grid_pos = Vector2(5,0)
	player.name = "Player"
	player.faction = "Player"
	main_node.grid_manager.get_parent().add_child(player)
	
	var hydrant = load("res://scripts/entities/GoldenHydrant.gd").new()
	hydrant.initialize(Vector2(0,5), main_node.grid_manager) # Same dist (5)
	main_node.grid_manager.get_parent().add_child(hydrant)
	
	# Pass Player list
	enemy._acquire_target([player], main_node.grid_manager)
	
	if enemy.target_unit == player:
		print("SUCCESS: Prefers Player over Hydrant at equal distance.")
	else:
		print("FAILURE: Targeted ", enemy.target_unit, " instead of Player.")
		
	# ----------------------------------------------------
	# TEST 2: Rescue Target vs Player
	# ----------------------------------------------------
	print("\nRunning Test 2: Rescue vs Player")
	var rescue = load("res://scripts/entities/CorgiUnit.gd").new()
	rescue.name = "LostCorgi"
	rescue.unit_name = "LostCorgi" # For safety
	rescue.add_to_group("Objectives")
	rescue.add_to_group("RescueTargets")
	rescue.faction = "Neutral"
	rescue.grid_pos = Vector2(0,5) # Same pos as hydrant was
	main_node.grid_manager.get_parent().add_child(rescue)
	
	# Re-run acquire
	enemy._acquire_target([player, rescue], main_node.grid_manager) # Rescue is a Unit too
	
	if enemy.target_unit == player:
		print("SUCCESS: Prefers Player over Rescue Target.")
	else:
		print("FAILURE: Targeted ", enemy.target_unit, " instead of Player.")
		
	# ----------------------------------------------------
	# TEST 3: Rescue Target Exists (No Player)
	# ----------------------------------------------------
	print("\nRunning Test 3: Only Rescue Target")
	enemy._acquire_target([rescue], main_node.grid_manager) # Only Rescue available in list (assuming TurnManager passed it)
	
	if enemy.target_unit == rescue:
		print("SUCCESS: Targeted Rescue Target when no player available.")
	else:
		print("FAILURE: Ignored Rescue Target completely.")

	main_node.queue_free()
	get_tree().quit()
