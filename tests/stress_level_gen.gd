
extends SceneTree

const LOG_PREFIX = "StressLevelGen: "

func _init():
	var lg_script = load("res://scripts/core/LevelGenerator.gd")
	var lg = lg_script.new()
	lg.name = "LevelGenerator"
	root.add_child(lg)
	
	# Watchdog
	var watchdog = load("res://tests/TestSafeGuard.gd").new()
	root.add_child(watchdog)
	
	print(LOG_PREFIX, "Starting Stress Test (100 Iterations)...")
	var failures = 0
	
	for i in range(100):
		var map = lg.generate_level()
		
		# Check if Fallback Map
		# Fallback map has NO obstacles.
		var has_obstacles = false
		for k in map:
			var t = map[k].get("type", 0)
			if t != 0: # 0 is GROUND
				has_obstacles = true
				break
				
		if not has_obstacles:
			print(LOG_PREFIX, "Iteration ", i, ": FAILED (Fallback Map detected)")
			failures += 1
		else:
			# print(LOG_PREFIX, "Iteration ", i, ": SUCCESS")
			pass
			
	print(LOG_PREFIX, "Test Completed. Failures: ", failures, "/100")
	
	if failures > 0:
		print(LOG_PREFIX, "Result: FAILURE")
		quit(1)
	else:
		print(LOG_PREFIX, "Result: SUCCESS")
		quit(0)
