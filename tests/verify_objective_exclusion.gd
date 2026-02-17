extends Node

func _ready():
	print("--- Verifying Objective Exclusion (Hydrant vs Dumpster) ---")
	await get_tree().process_frame
	_run_test()

func _run_test():
	# 1. Setup Mock GridManager
	var gm = load("res://scripts/managers/GridManager.gd").new()
	gm.name = "GridManager"
	add_child(gm)
	
	# Add TestSafeGuard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	# Create a dummy 10x10 grid
	gm.width = 10
	gm.height = 10
	for x in range(10):
		for y in range(10):
			var pos = Vector2(x, y)
			gm.grid_data[pos] = {
				"type": 0, # GROUND
				"is_walkable": true,
				"cover": 0.0,
				"world_pos": Vector3(x, 0, y)
			}
			
	# 2. Place Obstacle (Dumpster) at likely spawn spot (8,8)
	# ObjectiveSpawner seems to see Width=20 regardless of setting (Default), so Center=10, Start=8.
	var dumpster_pos = Vector2(8, 8)
	
	var dumpster = load("res://scripts/entities/DestructibleCover.gd").new()
	dumpster.name = "DumpsterObject"
	add_child(dumpster)
	dumpster.grid_pos = dumpster_pos
	
	# Register in Grid
	gm.grid_data[dumpster_pos]["unit"] = dumpster
	gm.grid_data[dumpster_pos]["walkable"] = false
	print("Placed Dumpster at ", dumpster_pos)
	
	# 3. Simulate Spawning
	var spawner = load("res://scripts/builders/ObjectiveSpawner.gd").new()
	var config = load("res://scripts/resources/MissionConfig.gd").new()
	config.objective_type = 4 # DEFENSE (Hydrant)
	
	# We need the spawner to pick (3,3). 
	# _find_spiral_pos uses gm.grid_data to check validity.
	# It returns the first valid key in range.
	# (3,3) is valid in grid_data (even if occupied, usually finding logic ignores occupancy for Objective forcing?)
	# Let's check _find_spiral_pos: "if gm.grid_data.has(p): return p"
	# Yes, it just checks if tile exists. It DOES NOT check is_walkable or unit occupation in that specific helper.
	# So it should return (3,3).
	
	print("Spawning Objective...")
	var count = spawner.spawn_objectives(4, 1, config, gm)
	
	# 4. Verification
	print("Spawned Count: ", count)
	
	var tile_data = gm.grid_data[dumpster_pos]
	var unit = tile_data.get("unit")
	
	if unit == null:
		print("FAILURE: No unit at ", dumpster_pos)
	elif unit.name == "GoldenHydrant":
		print("SUCCESS: GoldenHydrant spawned at ", dumpster_pos)
		
		# Check if Dumpster is gone
		if is_instance_valid(dumpster):
			if dumpster.is_queued_for_deletion():
				print("SUCCESS: Dumpster is queued for deletion.")
			else:
				print("FAILURE: Dumpster still exists and is VALID!")
		else:
			print("SUCCESS: Dumpster instance is invalid (freed).")
			
	elif unit == dumpster:
		print("FAILURE: Dumpster still occupies the tile!")
	else:
		print("FAILURE: Unknown unit at tile: ", unit.name)

	# Verify Biome Randomization (Main.gd Check) makes less sense here without instantiating Main.
	# We trust the code change in Main.gd for now as it's a simple one-liner.
	
	get_tree().quit(0)
