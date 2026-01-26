extends Node3D

# verify_level_gen.gd (Refactored)
# Verifies LevelGenerator functionality with Watchdog protection.

func _ready():
	print("Starting Level Generator Verification...")
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)
	
	_run_test()

func _run_test():
	var lg = load("res://scripts/core/LevelGenerator.gd").new()
	
	var success_count = 0
	var total_runs = 50
	var w_found = false
	
	var start_time = Time.get_ticks_msec()
	
	for i in range(total_runs):
		# Yield occasionally to keep Main Loop alive for Watchdog
		if i % 5 == 0:
			await get_tree().process_frame
			
		if Time.get_ticks_msec() - start_time > 30000: # 30s Timeout
			print("FAIL: Timeout during level generation loop!")
			get_tree().quit(1)
			return
			
		var grid = lg.generate_level()
		
		# Validate Check
		var obstacles = 0
		for k in grid:
			if not grid[k].get("is_walkable"):
				obstacles += 1
			# Check for Wall Variant
			if grid[k].get("variant") == "Wall":
				w_found = true
		
		# If obstacles > 0, it's not a fallback flat map
		if obstacles > 0:
			success_count += 1
			
	print("Level Generation Success Rate: ", success_count, "/", total_runs)
	if success_count < total_runs * 0.8:
		print("FAIL: Too many map rejections.")
		get_tree().quit(1)
		return
		
	if w_found:
		print("PASS: Destructible Walls (W) found in generated maps.")
	else:
		print("FAIL: No Destructible Walls generated.")
		get_tree().quit(1)
		return
		
	print("PASS: Level Generator Audit Complete.")
	lg.free()
	
	# Small delay before quit
	await get_tree().process_frame
	get_tree().quit(0)
