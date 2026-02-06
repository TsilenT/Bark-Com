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
	
	# Container for easy cleanup (Spawner adds to gm.get_parent())
	var container = Node3D.new()
	add_child(container)
	
	# Mock Managers
	# We need a GridManager mock that returns valid positions
	var gm = load("res://tests/mocks/MockGridManager.gd").new()
	gm.width = 10
	gm.height = 10
	container.add_child(gm) # Spawner will add Terminals to 'container'
	
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
		
	# Check Scene
	for child in container.get_children():
		print("  Found child: ", child.name)
		if child.name.begins_with("Terminal"):
			print("  [PASS] Found Terminal Node: ", child.name)
			if child.is_in_group("Terminals"):
				print("    [PASS] Group 'Terminals' OK")
			else:
				print("    [FAIL] Missing 'Terminals' group")
				
			if child.is_in_group("Objectives"):
				print("    [PASS] Group 'Objectives' OK")
			
	container.queue_free()
