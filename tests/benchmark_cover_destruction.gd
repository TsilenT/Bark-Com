extends Node

# Benchmark: Real Cover Destruction (Logic + VFX)
# Measures the cost of calling destroy() which triggers particles and visual updates.

const COVER_SCRIPT = "res://scripts/entities/DestructibleCover.gd"
const COUNT = 500
const DESTROY_COUNT = 50

func _ready():
	print("--- BENCHMARK STARTED: Real Destruction ---")
	
	# Add TestSafeGuard
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)
	
	var root = Node3D.new()
	root.name = "BenchmarkRoot"
	add_child(root)
	
	# 1. Spawn
	var covers = []
	print("Spawning ", COUNT, " covers...")
	for i in range(COUNT):
		# Create plain DestructibleCover (not Volatile for this test, or maybe mix?)
		# Let's test standard DestructibleCover first, as it also has VFX.
		var cover = load(COVER_SCRIPT).new()
		root.add_child(cover)
		
		var pos = Vector2(i % 50, i / 50) 
		cover.initialize(pos, GameManager) # Sets up grid data
		cover.position = Vector3(pos.x, 0, pos.y)
		covers.append(cover)
	
	# Wait a frame to settle
	await get_tree().process_frame
	
	# 2. Destroy Loop
	print("Destroying ", DESTROY_COUNT, " covers (calling destroy())...")
	var start_time = Time.get_ticks_msec()
	
	for i in range(DESTROY_COUNT):
		if i < covers.size():
			covers[i].destroy() # This spawns VFX
			
	var duration = Time.get_ticks_msec() - start_time
	print("Destruction Logic Time: ", duration, "ms")
	print("Avg per unit: ", float(duration) / DESTROY_COUNT, "ms")
	
	# 3. Wait for particles to simulate a bit (check for FPS drops?)
	# Hard to check FPS in headless, but expensive logic shows in duration.
	
	print("--- BENCHMARK COMPLETE ---")
	get_tree().quit()
