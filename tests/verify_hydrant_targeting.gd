extends Node

func _ready():
	print("--- Verifying Hydrant Targeting ---")
	await get_tree().process_frame
	_run_test()
	
func _run_test():
	# 1. Setup Mock Main & Grid
	var main_script = load("res://scripts/core/Main.gd")
	var main_node = main_script.new()
	add_child(main_node)
	
	# Add TestSafeGuard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	main_node.grid_manager.generate_tactical_grid(1)
	
	# 2. Add Entities
	# Enemy at (0,0)
	var enemy = load("res://scripts/entities/EnemyUnit.gd").new()
	enemy.grid_pos = Vector2(0,0)
	enemy.name = "TestEnemy"
	enemy.faction = "Enemy"
	main_node.grid_manager.get_parent().add_child(enemy)
	
	# Player at (30,30) (Very Far - Should be ignored in favor of close Hydrant)
	var player = load("res://scripts/entities/Unit.gd").new()
	player.grid_pos = Vector2(30,30)
	player.name = "PlayerParams"
	player.faction = "Player"
	main_node.grid_manager.get_parent().add_child(player)
	
	# Hydrant at (2,0) (Close, High Value)
	var hydrant = load("res://scripts/entities/GoldenHydrant.gd").new()
	hydrant.initialize(Vector2(2,0), main_node.grid_manager)
	main_node.grid_manager.get_parent().add_child(hydrant)
	
	# Wait for physics/ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 3. Simulate Target Acquisition
	print("Enemy triggering acquire_target...")
	# Pass players list (std behavior)
	# But Hydrant is NOT in this list usually.
	var known_units = [player] 
	
	# We manually call _acquire_target
	enemy._acquire_target(known_units, main_node.grid_manager)
	
	print("Selected Target: ", enemy.target_unit)
	
	var passed = false
	if enemy.target_unit == hydrant:
		print("SUCCESS: Enemy targeted the Hydrant!")
		passed = true
	elif enemy.target_unit == player:
		print("FAILURE: Enemy targeted the Player (ignored Hydrant).")
	else:
		print("FAILURE: Enemy targeted NOTHING.")
		
	# Cleanup
	main_node.queue_free()
	
	if passed:
		get_tree().quit(0)
	else:
		get_tree().quit(1)
