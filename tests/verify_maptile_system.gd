extends SceneTree

# Reconstructed verify_maptile_system.gd
# Tests basic MapTile generation and highlighting

class MockGridManager extends Node:
	signal grid_generated
	var grid_data = {}
	
	func get_grid_coord(pos): return Vector2(round(pos.x/2), round(pos.z/2))
	func get_world_position(coord): return Vector3(coord.x*2, 0, coord.y*2)

func _init():
	print("Starting MapTile Verification...")
	var root = get_root()
	
	# 1. Mock GridManager
	var gm = MockGridManager.new()
	gm.name = "GridManager"
	gm.add_to_group("GridManager") # Just in case
	root.add_child(gm)
	
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
	root.add_child(viz)
	
	# Trigger Generation
	print("Testing Grid Visualization...")
	viz._on_grid_generated()
	
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
		quit(1)
		return
		
	# Test Highlights
	print("Testing Shader Highlights...")
	if viz.has_method("show_highlights"):
		viz.show_highlights([Vector2(0,0)], Color.RED)
		print("PASS: show_highlights called without error.")
	else:
		print("FAIL: show_highlights method missing.")
		quit(1)
		return

	if viz.has_method("clear_highlights"):
		viz.clear_highlights()
		print("PASS: clear_highlights called without error.")

	print("All MapTile tests passed.")
	viz.free()
	gm.free()
	quit()
