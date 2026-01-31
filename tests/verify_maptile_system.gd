extends Node3D

# verify_maptile_system_runner.gd
# Tests basic MapTile generation and highlighting
# Converted to Node3D + TestSafeGuard to prevent hangs.

class MapTileMockGridManager extends Node:
	signal grid_generated
	var grid_data = {}
	
	func get_grid_coord(pos): return Vector2(round(pos.x/2), round(pos.z/2))
	func get_world_position(coord): return Vector3(coord.x*2, 0, coord.y*2)

func _ready():
	print("Starting MapTile Verification...")
	
	# Add Watchdog
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)
	
	_run_test()

func _run_test():
	# 1. Mock GridManager
	var gm = MapTileMockGridManager.new()
	gm.name = "GridManager"
	gm.add_to_group("GridManager") 
	add_child(gm)
	
	# Populate Mock Data (10 tiles)
	for x in range(2):
		for y in range(5):
			gm.grid_data[Vector2(x,y)] = {
				"type": 0, "is_walkable": true, "elevation": 0, "biome": 1
			}
			
	# 2. Instantiate Visualizer
	var viz_script = load("res://scripts/ui/GridVisualizer.gd")
	var viz = Node3D.new()
	viz.set_script(viz_script)
	viz.grid_manager = gm # Explicitly assign mock
	add_child(viz)
	
	await get_tree().process_frame
	
	# Trigger Generation
	print("Testing Grid Visualization...")
	viz._on_grid_generated()
	
	await get_tree().process_frame # Yield to allow updates
	
	# Check Children
	var tile_count = 0
	for child in viz.get_children():
		if child is Node3D and child.has_method("initialize"): # MapTile
			tile_count += 1
			
	print("GridVisualizer Children Count: ", tile_count)
	if tile_count == 10:
		print("PASS: Correct number of MapTiles spawned.")
	else:
		print("FAIL: Expected 10 tiles, found ", tile_count)
		get_tree().quit(1)
		return
		
	# Test Highlights
	print("Testing Shader Highlights...")
	if viz.has_method("show_highlights"):
		viz.show_highlights([Vector2(0,0)], viz.VisualType.MOVE)
		print("PASS: show_highlights called without error.")
	else:
		print("FAIL: show_highlights method missing.")
		get_tree().quit(1)
		return
	
	await get_tree().process_frame

	if viz.has_method("clear_highlights"):
		viz.clear_highlights()
		print("PASS: clear_highlights called without error.")

	print("All MapTile tests passed.")
	
	# Cleanup
	viz.queue_free()
	gm.queue_free()
	
	await get_tree().process_frame
	get_tree().quit(0)
