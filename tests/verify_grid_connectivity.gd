extends SceneTree

func _init():
	_run_test()

func _run_test():
	print("--- Verifying GridManager Connectivity ---")
	
	var gm = load("res://scripts/managers/GridManager.gd").new()
	gm.name = "GridManager"
	root.add_child(gm)
	
	# Add TestSafeGuard
	root.add_child(load("res://tests/TestSafeGuard.gd").new())
	
	# Generate 3x3 Grid
	var grid = {}
	for x in range(3):
		for y in range(3):
			grid[Vector2(x, y)] = {
				"type": 0,
				"is_walkable": true,
				"elevation": 0,
				"height": 0.0
			}
			
	gm.grid_data = grid
	gm.setup_astar()
	
	# Check Neighbors of (1,1)
	var start = Vector2(1,1)
	var reach = gm.get_reachable_tiles(start, 2)
	
	print("Start: ", start)
	print("Reachable Count: ", reach.size())
	print("Reachable: ", reach)
	
	var expected_size = 9
	if reach.size() != expected_size:
		print("FAILURE: Expected 9 tiles, got ", reach.size())
	else:
		print("SUCCESS: Full connectivity.")
		
	# Check specific neighbor (1,0)
	if not reach.has(Vector2(1,0)):
		print("FAILURE: Missing (1,0)!")
	
	# Check point IDs
	var id = gm._get_point_id(start)
	print("ID(1,1): ", id)
	var id_up = gm._get_point_id(Vector2(1,0))
	print("ID(1,0): ", id_up)
	
	if gm.astar.are_points_connected(id, id_up):
		print("SUCCESS: (1,1) connected to (1,0)")
	else:
		print("FAILURE: Connection missing!")
		
	# FORCE QUIT
	quit()
