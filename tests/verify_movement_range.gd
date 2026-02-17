extends Node3D

# verify_movement_range.gd (Refactored)
const GridManager = preload("res://scripts/managers/GridManager.gd")

func _ready():
	print("--- TEST START: Verify Movement Range ---")
	
	# Watchdog
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)

	_run_test()

func _run_test():
	var gm = GridManager.new()
	add_child(gm)
	
	# Override LevelGenerator to produce a FLAT EMPTY GRID
	print("--- SETTING UP FLAT GRID 20x20 ---")
	gm.grid_data.clear()
	for x in range(20):
		for y in range(20):
			var coord = Vector2(x, y)
			gm.grid_data[coord] = {
				"type": GridManager.TileType.GROUND,
				"elevation": 0,
				"is_walkable": true,
				"world_pos": Vector3(x*2, 0, y*2)
			}
			
	gm.setup_astar()
	print("AStar initialized with ", gm.grid_data.size(), " points.")
	
	# TEST 1: Basic Movement from (10, 10), Mobility 6
	# Expectation: Square shape (Chebyshev) due to cost=1 diagonals
	var start = Vector2(10, 10)
	var mobility = 6
	
	await get_tree().process_frame # Yield
	
	print("\n--- TEST 1: Mobility ", mobility, " from ", start, " ---")
	var tiles = gm.get_reachable_tiles(start, mobility)
	
	# Verify Extents
	var min_x = 999; var max_x = -999
	var min_y = 999; var max_y = -999
	var count = 0
	
	var reachable_set = {}
	
	for t in tiles:
		reachable_set[t] = true
		min_x = min(min_x, t.x)
		max_x = max(max_x, t.x)
		min_y = min(min_y, t.y)
		max_y = max(max_y, t.y)
		count += 1
		
	print("Reachable Tiles Count: ", count)
	print("Bounds: X[", min_x, "..", max_x, "] Y[", min_y, "..", max_y, "]")
	
	var expected_min_x = start.x - mobility
	var expected_max_x = start.x + mobility
	
	if min_x == expected_min_x and max_x == expected_max_x:
		print("SUCCESS: X-Range matches mobility (", expected_min_x, "..", expected_max_x, ")")
	else:
		print("FAILURE: X-Range mismatch! Expected ", expected_min_x, "..", expected_max_x)
		get_tree().quit(1)
		return
		
	# Check Corners (Diagonal reach)
	var corner = start + Vector2(mobility, mobility)
	if reachable_set.has(corner):
		print("SUCCESS: Corner ", corner, " is reachable (Diagonal Cost = 1).")
	else:
		print("FAILURE: Corner ", corner, " is NOT reachable. (Maybe Cost > 1?)")
		get_tree().quit(1)
		return
		
	# Visualize (ASCII)
	print("\n--- GRID VISUALIZATION ---")
	for y in range(min_y, max_y + 1):
		var line = ""
		for x in range(min_x, max_x + 1):
			if reachable_set.has(Vector2(x, y)):
				line += "[X]"
			else:
				if x == start.x and y == start.y:
					line += "[O]"
				else:
					line += " . "
		print(line)
		
	gm.queue_free()
	
	await get_tree().process_frame
	get_tree().quit(0)
