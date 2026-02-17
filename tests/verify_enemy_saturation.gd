extends Node

# verify_enemy_saturation.gd
# Stress Test: Fills a small map with units and verifies graceful failure on overflow.

var _iterations = 0
var _max_iterations = 1000 # Safety Break

func _ready():
	print("--- Verify Enemy Saturation Stress Test ---")
	
	# Add TestSafeGuard (Watchdog)
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)
	
	_run_test()

func _run_test():
	# 1. Setup Minimal Dependencies
	var gm_script = load("res://scripts/managers/GridManager.gd")
	var gm = gm_script.new()
	gm.name = "GridManager"
	# We can add gm directly to self since we are a Node in the tree now
	add_child(gm)
	
	# Generate Small Grid (e.g. 5x5) to reach saturation quickly
	# GridManager uses LevelGenerator which defaults to 20x20 usually.
	# We can't easily change LevelGenerator size (const), but we can fill a 20x20.
	# 20x20 = 400 Tiles. 
	# Spawning 400 units is heavy but doable for a stress test.
	
	print("Generating 20x20 Grid...")
	gm.generate_tactical_grid(2) # Street
	
	var valid_tiles = []
	for pos in gm.grid_data:
		if gm.is_tile_walkable(pos):
			valid_tiles.append(pos)
			
	print("Valid Walkable Tiles Found: ", valid_tiles.size())
	
	# 2. Spawn Units until full
	var unit_scene = load("res://scenes/entities/CorgiUnit.tscn") # Or script
	var spawned_count = 0
	var dummy_units = []
	
	print("Attempting to saturate grid...")
	
	var start_time = Time.get_ticks_msec()
	
	for tile in valid_tiles:
		# Simulate Main.gd logic: Check occupancy
		# GridManager.grid_data.unit is usually set by Unit.initialize -> set_unit_at_grid
		
		var u = unit_scene.instantiate()
		add_child(u)
		u.initialize(tile)
		u.set_unit_at_grid(tile) # Should register itself in GM
		
		dummy_units.append(u)
		spawned_count += 1
		
		# Validation
		if not gm.is_tile_occupied(tile):
			print("ERROR: Tile ", tile, " reported empty after spawn!")
			_fail("Occupancy Logic Broken")
			return
			
	print("Saturation Complete. Spawned: ", spawned_count)
	print("Time Taken: ", Time.get_ticks_msec() - start_time, "ms")
	
	# 3. Attempt Overflow Spawn
	print("Attempting to spawn ONE MORE unit (Should fail gracefully)...")
	
	# Find a tile (any tile is now occupied)
	var test_tile = valid_tiles[0] 
	
	if not gm.is_tile_occupied(test_tile):
		_fail("Test tile mysteriously empty!")
		return
		
	# Logic Under Test: Main.gd spawning loop (Simulated)
	# Main.gd checks `grid_manager.get_nearest_walkable_tile` then checks occupancy.
	
	var result_tile = gm.get_nearest_walkable_tile(test_tile)
	# Since ALL are occupied, get_nearest_walkable_tile might return the tile itself (it checks walkability, not occupancy).
	# Occupancy check is separate in Main.gd.
	
	if not gm.grid_data.has(result_tile):
		_fail("get_nearest_walkable_tile returned invalid tile")
		return
		
	# Check Occupancy
	var is_occupied = gm.is_tile_occupied(result_tile)
	print("Nearest Walkable Tile to ", test_tile, " is ", result_tile, " | Occupied: ", is_occupied)
	
	if is_occupied:
		print("SUCCESS: Spawner would correctly reject this tile.")
	else:
		print("FAILURE: Spawner sees tile as empty!")
		_fail("Overflow check failed")
		return

	# Cleanup
	for u in dummy_units:
		u.queue_free()
	# root.queue_free() # Self is root
	
	print("--- Verify Enemy Saturation Stress Test: PASS ---")
	get_tree().quit(0)

func _fail(msg):
	print("--- FAILURE: ", msg, " ---")
	get_tree().quit(1)
