extends Node

func _ready():
	print("--- Verifying Periodic Wave Spawning ---")
	await get_tree().process_frame
	_run_test()
	
func _run_test():
	# 1. Setup Mock Main & Grid
	var main_script = load("res://scripts/core/Main.gd")
	var main_node = main_script.new()
	add_child(main_node)
	
	# Add TestSafeGuard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	await get_tree().process_frame
	
	# 2. Config Mission (Final Defense)
	var config = load("res://scripts/resources/MissionConfig.gd").new()
	config.mission_name = "TEST DEFENSE"
	config.is_final_defense = true
	
	var wave1 = load("res://scripts/resources/WaveDefinition.gd").new()
	wave1.budget_points = 5
	wave1.allowed_archetypes.assign(["Rusher"]) # Only Rushers for simplicity
	config.waves.append(wave1)
	
	main_node.active_mission_data = config
	
	# 3. Start Mission
	main_node.grid_manager.generate_tactical_grid(1)
	main_node.mission_manager.start_mission(config, main_node.grid_manager)
	
	await get_tree().create_timer(1.0).timeout
	
	var initial_count = main_node.mission_manager.spawned_units.size()
	print("Initial Unit Count: ", initial_count)
	
	# 4. Simulate Turn 4
	print("Simulating Turn 4...")
	# Simulate TurnManager event
	main_node.mission_manager._on_turn_changed(0, 4)
	
	await get_tree().create_timer(1.0).timeout
	
	var new_count = main_node.mission_manager.spawned_units.size()
	print("New Unit Count: ", new_count)
	
	if new_count == initial_count + 2:
		print("SUCCESS: 2 Reinforcements Spawned.")
		get_tree().quit(0)
	else:
		print("FAILURE: Expected ", initial_count + 2, " units, got ", new_count)
		get_tree().quit(1)
		
	# Cleanup
	main_node.queue_free()
