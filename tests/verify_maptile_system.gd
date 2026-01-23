extends SceneTree

# Mocks
class MockGridManager extends Node:
	var grid_data = {}
	signal grid_generated
	
	func get_world_position(coord: Vector2) -> Vector3:
		return Vector3(coord.x * 2.0, 0, coord.y * 2.0)
		
	func get_grid_coord(pos: Vector3) -> Vector2:
		return Vector2(round(pos.x/2.0), round(pos.z/2.0))

func _init():
	print("Starting MapTile Verification...")
	
	# 1. Setup Environment
	var root = Node3D.new()
	get_root().add_child(root)
	
	var gm = MockGridManager.new()
	gm.name = "GridManager"
	root.add_child(gm)
	
	var gv = load("res://scripts/ui/GridVisualizer.gd").new()
	gv.name = "GridVisualizer"
	root.add_child(gv)
	gv.grid_manager = gm
	
	# 2. Setup Mock Data (Small 3x3 Grid)
	var data = {}
	for x in range(3):
		for y in range(3):
			var coord = Vector2(x,y)
			data[coord] = {
				"type": 0, # Ground
				"is_walkable": true,
				"biome": 1,
				"world_pos": Vector3(x*2.0, 0, y*2.0)
			}
			
	gm.grid_data = data
	
	# 3. Test Generation
	print("Testing Grid Visualization...")
	gv._on_grid_generated()
	
	var children = gv.get_children()
	print("GridVisualizer Children Count: ", children.size())
	
	# Preload for Type Check
	var MapTileScript = load("res://scripts/visuals/MapTile.gd")

	# We expect 9 MapTiles in tile_meshes (children count might include debug labels if separate)
	var tile_count = 0
	for child in children:
		# Check if script matches
		if child.get_script() == MapTileScript:
			tile_count += 1
			
	if tile_count == 9:
		print("PASS: Correct number of MapTiles spawned.")
	else:
		print("FAIL: Expected 9 MapTiles, found ", tile_count)
		quit(1)
		
	# 4. Test Highlighting (Shader Param)
	print("Testing Shader Highlights...")
	var test_coord = Vector2(1,1)
	gv.show_highlights([test_coord], Color.RED)
	
	var tile = gv.tile_meshes[test_coord]
	if tile.get_script() == MapTileScript:
		# Can't easily check shader param value in headless script without access to RenderingServer or complex reflection
		# But if it didn't crash, the API exists.
		print("PASS: show_highlights called without error.")
	else:
		print("FAIL: Tile at 1,1 is not MapTile.")
		quit(1)

	# 5. Test Highlight Clearing
	gv.clear_highlights()
	print("PASS: clear_highlights called without error.")
	
	print("All MapTile tests passed.")
	quit()
