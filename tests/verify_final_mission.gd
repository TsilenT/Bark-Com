extends Node

func _ready():
	print("TEST STARTED: Verify Final Mission (Scene Mode)")

	# Add TestSafeGuard (Standard Compliance)
	var safeguard = load("res://tests/TestSafeGuard.gd").new()
	add_child(safeguard)
	
	# 1. Setup Mock Main
	var main_script = load("res://scripts/core/Main.gd")
	if not main_script:
		print("ERROR: Could not load Main.gd")
		await get_tree().create_timer(0.1).timeout
		get_tree().quit(1)
		return

	var main_node = main_script.new()
	main_node.name = "Main"
	add_child(main_node)
	
	# 3. Configure Mission Data (Mock MissionConfig)
	var mission_config = load("res://scripts/resources/MissionConfig.gd").new()
	mission_config.mission_name = "BASE DEFENSE"
	mission_config.is_final_defense = true
	mission_config.objective_type = 4 # DEFENSE
	mission_config.objective_target_count = 1
	
	# SETUP WAVES MANUALLY (Since we bypass Main._setup_mission_data)
	var wave1 = load("res://scripts/resources/WaveDefinition.gd").new()
	wave1.budget_points = 5
	wave1.allowed_archetypes.assign(["Rusher", "Sniper", "Spitter"])
	wave1.wave_message = "TEST WAVE 1"
	wave1.guaranteed_spawns["Boss"] = 1 # THIS IS CRITICAL
	mission_config.waves.append(wave1)
	
	main_node.active_mission_data = mission_config
	# main_node.is_test_mode = true # TestSafeGuard handles this!
	
	# MANUALLY TRIGGER SPAWN (Since is_test_mode=true disables automatic spawn_test_scenario)
	# 1. Generate Grid
	main_node.grid_manager.generate_tactical_grid(1) # Force biome
	# 2. Start Mission (Spawns Objectives + Wave 1)
	main_node.mission_manager.start_mission(mission_config, main_node.grid_manager)
	
	# Wait for Main to initialize and spawn (approx 2s)
	await get_tree().create_timer(2.0).timeout
	
	print("Checking results...")
	var passed = true
	
	# TEST: Check for Golden Hydrant
	var hydrant = main_node.find_child("GoldenHydrant", true, false)
	if hydrant:
		print("PASSED: Golden Hydrant found.")
		if hydrant.faction == "Player":
			print("PASSED: Golden Hydrant has 'Player' faction.")
		else:
			print("FAILED: Golden Hydrant faction is ", hydrant.faction)
			passed = false
	else:
		print("FAILED: Golden Hydrant NOT found.")
		passed = false

	# TEST: Check for Boss (Dogthulhu)
	var boss_found = false
	var units_to_check = []
	units_to_check.append_array(main_node.spawned_units)
	if main_node.mission_manager:
		units_to_check.append_array(main_node.mission_manager.spawned_units)
		
	# DEBUG: Print all units
	print("DEBUG: All Spawned Units:")
	for u in units_to_check:
		if is_instance_valid(u):
			var n = u.name
			if "unit_name" in u: n = u.unit_name
			print(" - ", n, " (", u.name, ") Type: ", u.get_class())
			
	for u in units_to_check:
		if not is_instance_valid(u): continue
		
		var u_name = u.name
		if "unit_name" in u:
			u_name = u.unit_name
			
		if u_name == "Dogthulhu":
			boss_found = true
			print("PASSED: Boss (Dogthulhu) Spawned.")
			
			var hp = u.get("max_hp")
			var arm = u.get("armor")
			
			if hp == 70 and arm == 1:
				print("PASSED: Boss Stats verified (70 HP, 1 Armor).")
			else:
				print("FAILED: Boss Stats Mismatch! HP:", hp, " Armor:", arm)
				passed = false
			break

	if not boss_found:
		print("FAILED: Boss NOT found in spawned lists.")
		passed = false

	main_node.queue_free()
	
	# Force Flush?
	await get_tree().create_timer(0.1).timeout
	
	if passed:
		print("TEST VERIFY_FINAL_MISSION: SUCCESS")
		get_tree().quit(0)
	else:
		print("TEST VERIFY_FINAL_MISSION: FAILED")
		get_tree().quit(1)
