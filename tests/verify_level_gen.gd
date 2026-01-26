extends SceneTree

func _init():
	print("Starting Level Generator Verification...")
	var lg = load("res://scripts/core/LevelGenerator.gd").new()
	
	var success_count = 0
	var total_runs = 50
	var w_found = false
	
	var start_time = Time.get_ticks_msec()
	
	for i in range(total_runs):
		if Time.get_ticks_msec() - start_time > 30000: # 30s Timeout
			print("FAIL: Timeout during level generation!")
			quit(1)
			
		var grid = lg.generate_level()
		# check if valid (if invalid, it generates safe map or returns partial?)
		# LG prints "Map Validated" or "CRITICAL FAIL".
		# We can check connectivity ourself or trust the result.
		
		# But wait, lg.generate_level() returns a dictionary.
		# If it failed 10 times, it calls _generate_safe_map (Flat ground).
		# We want to know if it SUCCEEDED natively.
		
		# Let's inspect the grid for Walls ('W' -> destructible=true, variant=Wall)
		for k in grid:
			if grid[k].get("variant") == "Wall":
				w_found = true
				
		# We can't easily read internal 'attempts' or 'valid_map' state from outside.
		# But we can check if it looks like a SAFE MAP (flat 20x20 ground).
		# Safe map has no Obstacles.
		var obstacles = 0
		for k in grid:
			if not grid[k].get("is_walkable"):
				obstacles += 1
		
		if obstacles > 0:
			success_count += 1
			
	print("Level Generation Success Rate: ", success_count, "/", total_runs)
	if success_count < total_runs * 0.8:
		print("FAIL: Too many map rejections.")
		quit(1)
		
	if w_found:
		print("PASS: Destructible Walls (W) found in generated maps.")
	else:
		print("FAIL: No Destructible Walls generated.")
		quit(1)
		
	print("PASS: Level Generator Audit Complete.")
	lg.free()
	quit(0)
