extends Node

# Mocks
class MockGridManager extends Node:
	enum TileType { GROUND, OBSTACLE, COVER_HALF, COVER_FULL, RAMP, LADDER }
	var grid_data = {}
	signal grid_generated
	
	func get_world_position(coord: Vector2) -> Vector3:
		return Vector3(coord.x * 2, 0, coord.y * 2)

class MockVisionManager extends Node3D:
	var explored_tiles = {}
	func is_tile_explored(coord): return explored_tiles.has(coord)

func _ready():
	print("Starting Tactical Visuals Verification...")
	
	var root = self
	
	var gm = MockGridManager.new()
	gm.name = "GridManager"
	add_child(gm)
	
	var vm = MockVisionManager.new()
	vm.name = "VisionManager"
	add_child(vm)
	
	# Load actual GridVisualizer
	var gv_script = load("res://scripts/ui/GridVisualizer.gd")
	var gv = Node3D.new()
	gv.set_script(gv_script)
	gv.name = "GridVisualizer"
	# gv.grid_manager dependency will be injected via node search or prop
	gv.grid_manager = gm
	add_child(gv)
	
	# TEST 1: LOF
	print("Testing LOF Drawing...")
	if gv.has_method("draw_lof"):
		gv.draw_lof(Vector3(0,0,0), Vector3(10,0,10), Color.RED)
		print("PASS: draw_lof executed.")
	else:
		print("FAIL: draw_lof missing.")
		
	# TEST 2: Cover Icons
	print("Testing Cover Icons...")
	if gv.has_method("update_cover_icons"):
		# Setup data
		gm.grid_data[Vector2(0,0)] = { "type": MockGridManager.TileType.COVER_FULL }
		gm.grid_data[Vector2(0,1)] = { "type": MockGridManager.TileType.COVER_HALF }
		
		# Create fake cover data (normally filtered by Controller)
		var cover_data = {
			Vector2(0,0): MockGridManager.TileType.COVER_FULL,
			Vector2(0,1): MockGridManager.TileType.COVER_HALF
		}
		
		gv.update_cover_icons(cover_data)
		print("PASS: update_cover_icons executed.")
		
		# Check if children created (Icons)
		# gv has map tiles (none yet) and lof_mesh and Icons
		# Icons children of gv?
		var icon_count = 0
		for child in gv.get_children():
			if child is MeshInstance3D and child.mesh is QuadMesh:
				icon_count += 1
		
		if icon_count >= 2:
			print("PASS: Cover Icons spawned (Count: ", icon_count, ")")
		else:
			print("FAIL: Cover Icons not found (Count: ", icon_count, ")")
			
	else:
		print("FAIL: update_cover_icons missing.")
		
	get_tree().quit()
