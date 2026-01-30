extends Node

func _ready():
	print("--- TEST OBJECTIVE SPAWNER ---")
	
	# Anti-Hang Safeguard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	# 1. Setup GridManager (Integration Style)
	var gm = GridManager.new()
	gm.name = "GridManager"
	add_child(gm)
	
	# Use standard generation to ensure AStar is valid
	gm.generate_tactical_grid()
	
	# 2. Setup Config
	var config = MissionConfig.new()
	config.objective_type = 2 # Loot
	config.objective_target_count = 3
	
	# 3. Test Spawner
	var spawner = load("res://scripts/builders/ObjectiveSpawner.gd").new()
	
	# Test Loot Spawn
	print("Testing Spawn Type 2 (Loot)...")
	var count = spawner.spawn_objectives(2, 3, config, gm)
	
	if count == 3:
		print("SUCCESS: Spawned 3 Loot Crates.")
	else:
		printerr("FAIL: Expected 3, got " + str(count))
		get_tree().quit(1)
		return
		
	# Verify Nodes exist
	var found = 0
	for child in get_children():
		if child.is_in_group("Objectives"):
			found += 1
			
	# Fallback check
	if found < 3:
		found = 0
		for child in get_children():
			if child.name.begins_with("ObjectiveCrate"):
				found += 1
			
	if found == 3:
		print("SUCCESS: Found 3 Crate Nodes in Scene.")
	else:
		printerr("FAIL: Found " + str(found) + " Crate Nodes.")
		get_tree().quit(1)
		return

	# 4. Cleanup
	gm.queue_free()
	
	print("ALL OBJECTIVE SPAWNER TESTS PASSED")
	get_tree().quit(0)
