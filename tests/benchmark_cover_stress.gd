extends Node

# Benchmark: Cover Stress Test
# Spawns a large number of DestructibleCovers and measures setup time.
# Then destroys a subset to measure update time.

const COVER_SCRIPT = "res://scripts/entities/DestructibleCover.gd"
const COUNT = 2000
const DESTROY_COUNT = 100

func _ready():
	print("--- BENCHMARK STARTED: DestructibleCover Stress Test ---")
	
	# Add TestSafeGuard for Watchdog Compliance is handled by the runner usually?
	# No, we need to add it manually if the scene doesn't have it.
	# But wait, run_tests.ps1 checks for it in the SCRIPT or Scene.
	# Adding it here is fine.
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)
	
	var root = Node3D.new()
	root.name = "BenchmarkRoot"
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)
	
	# 1. Measure Spawn Time
	var start_time = Time.get_ticks_msec()
	
	var covers = []
	var variants = ["Crate", "Hydrant", "Trash Can", "Planter", "Server Rack", "Wall"]
	
	print("Spawning ", COUNT, " covers...")
	
	for i in range(COUNT):
		var cover = load(COVER_SCRIPT).new()
		root.add_child(cover)
		
		# Random Position
		var pos = Vector2(i % 50, i / 50) 
		var variant = i % variants.size()
		
		# Now that we are in MainLoop (via Runner), SignalBus and others exist.
		cover.set_variant(DestructibleCover.get_variant_from_string(variants[variant]))
		cover.position = Vector3(pos.x, 0, pos.y)
		
		covers.append(cover)
		
	var spawn_duration = Time.get_ticks_msec() - start_time
	print("Spawn Time: ", spawn_duration, "ms")
	print("Average per unit: ", float(spawn_duration) / COUNT, "ms")
	
	# 2. Measure Memory/State Check
	print("Destroying ", DESTROY_COUNT, " covers...")
	var destroy_start = Time.get_ticks_msec()
	
	for i in range(DESTROY_COUNT):
		var c = covers[i]
		c.queue_free()
		
	var destroy_duration = Time.get_ticks_msec() - destroy_start
	print("Destroy Time: ", destroy_duration, "ms")
	
	# Cleanup
	root.queue_free()
	print("--- BENCHMARK COMPLETE ---")
	
	# Important: Flush cache to avoid leaks in strict mode!
	load(COVER_SCRIPT).flush_cache()
	
	get_tree().quit()
