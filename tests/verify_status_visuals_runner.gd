extends Node

# verify_status_visuals_runner.gd
# Runs in Full Engine Context (Autoloads Available)

class MockGridManager extends Node:
	var grid_data = {}
	
	func get_tile_data(pos): 
		return grid_data.get(pos, {})
		
	func get_world_position(pos): 
		return Vector3(pos.x * 2.0, 0, pos.y * 2.0)
		
	func get_best_cover_at(coord: Vector2) -> float:
		# Return mock data
		var d = grid_data.get(coord, {})
		return d.get("cover_height", 0.0)

func _ready():
	print("Starting Status Visuals Verification (Scene Runner)...")
	
	var root = self
	
	# 1. Setup Mock GridManager
	# Note: Real GridManager is autoloaded? Or typically a child of Main?
	# In tests we often add it to root.
	# UnitStatusUI looks for group "GridManager".
	var gm = MockGridManager.new()
	gm.name = "GridManager"
	gm.add_to_group("GridManager")
	root.add_child(gm)
	
	# Setup Data: Unit at (1,1). High Ground (Elev 1). Cover at (1,0) (North).
	gm.grid_data = {
		Vector2(1,1): {"elevation": 1, "cover_height": 0.0},
		Vector2(1,0): {"elevation": 0, "cover_height": 1.0} # Half Cover North
	}
	
	# 2. Setup Unit
	# We can use a Node3D mock that quacks like a unit
	var mock_unit = Node3D.new()
	mock_unit.name = "MockUnit"
	
	# Add properties via script
	var u_script = GDScript.new()
	u_script.source_code = "extends Node3D\nvar grid_pos = Vector2(1,1)\nvar active_effects = []\nvar current_panic_state = 0\nfunc get_elevation_offset(): return 0"
	u_script.reload()
	mock_unit.set_script(u_script)
	root.add_child(mock_unit)
	
	# 3. Instantiate UI
	# UnitStatusUI expects to be child of Unit
	var ui_script = load("res://scripts/ui/UnitStatusUI.gd")
	if not ui_script:
		print("FAIL: Could not load UnitStatusUI.gd")
		get_tree().quit(1)
		return
		
	var ui = Node3D.new()
	ui.set_script(ui_script)
	mock_unit.add_child(ui)
	
	# Force Layout/Update
	# _ready called on add_child
	# Call _refresh_full explicitly to be sure
	if ui.has_method("_refresh_full"):
		ui._refresh_full()
	else:
		print("FAIL: UnitStatusUI missing _refresh_full")
		get_tree().quit(1)
		return
		
	# 4. Verify Visuals
	var hg_found = false
	var display_list = []
	
	for child in ui.get_children():
		if child is Sprite3D and child.texture:
			if "high_ground" in child.texture.resource_path:
				print("PASS: High Ground Icon Found.")
				hg_found = true
			display_list.append("Sprite: " + child.texture.resource_path)
			
	# Check Holographic Cover
	var cover_count = 0
	for child in ui.get_children():
		if child is MeshInstance3D:
			# Should be one north
			print("PASS: Holographic Shield Found at ", child.position)
			cover_count += 1
			display_list.append("Mesh: " + str(child.position))
			
	if hg_found and cover_count > 0:
		print("VERIFICATION SUCCESS: All Visuals Present")
	else:
		print("FAIL: HG=", hg_found, " MeshCount=", cover_count)
		print("Children found: ", display_list)
		print("Grid Data: ", gm.grid_data)
		print("Unit Pos: ", mock_unit.grid_pos)
		
		get_tree().quit(1) # Fail code
		return
		
	get_tree().quit()
