extends Node

func _ready():
	# Watchdog
	var monitor = load("res://tests/TestSafeGuard.gd").new()
	add_child(monitor)

	print("\n=== VERIFYING SPAWNER ===")
	
	await get_tree().process_frame
	
	_test_hacker_spawn()
	
	print("\nSpawner Check Complete. Quitting...")
	get_tree().quit()

func _test_hacker_spawn():
	print("\nTEST: Hacker Mission Spawning (Type 3)")
	
	var spawner_script = load("res://scripts/builders/ObjectiveSpawner.gd")
	var spawner = spawner_script.new()
	
	# Mock Managers
	# We need a GridManager mock that returns valid positions
	var gm = load("res://tests/mocks/MockGridManager.gd").new()
	gm.width = 10
	gm.height = 10
	
	# Mock Config
	var config = load("res://scripts/resources/MissionConfig.gd").new()
	
	# EXECUTE
	# 3 = HACKER
	var count = spawner.spawn_objectives(3, 2, config, gm)
	
	print("  Spawner returned count: ", count)
	if count == 2:
		print("  [PASS] Spawned 2 objectives.")
	else:
		print("  [FAIL] Expected 2, got ", count)
		
	# Check Scene via GM parent (Mock GM needs to simulate parent or we inspect it)
	# But wait, spawn_objectives calls _add_to_scene which calls gm.get_parent().add_child OR gm.add_child
	# Our MockGM needs to handle this.
	
	for child in gm.get_children():
		print("  Found child: ", child.name)
		if child.name.begins_with("Terminal"):
			print("  [PASS] Found Terminal Node: ", child.name)
			if child.is_in_group("Terminals"):
				print("    [PASS] Group 'Terminals' OK")
			else:
				print("    [FAIL] Missing 'Terminals' group")
				
			if child.is_in_group("Objectives"):
				print("    [PASS] Group 'Objectives' OK")
			
	gm.free()
