extends Node3D

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
	add_child(load("res://tests/TestSafeGuard.gd").new())
	print("Starting Status Visuals Verification (Scene Runner)...")
	
	var root = self
	
	# 1. Setup Mock GridManager
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
	var mock_unit = Node3D.new()
	mock_unit.name = "MockUnit"
	
	# Add properties via script
	var u_script = GDScript.new()
	u_script.source_code = "extends Node3D\nvar grid_pos = Vector2(1,1)\nvar active_effects = []\nvar current_panic_state = 0\nfunc get_elevation_offset(): return 0"
	u_script.reload()
	mock_unit.set_script(u_script)
	root.add_child(mock_unit)
	
	# 3. Instantiate UI
	var ui_script = load("res://scripts/ui/UnitStatusUI.gd")
	if not ui_script:
		print("FAIL: Could not load UnitStatusUI.gd")
		get_tree().quit(1)
		return
		
	var ui = Node3D.new()
	ui.set_script(ui_script)
	mock_unit.add_child(ui)
	
	print("Unit Inside Tree: ", mock_unit.is_inside_tree())
	
	# Wait for Deferred Refresh (Timer is safer in headless start-up)
	await get_tree().create_timer(0.2).timeout
	if not ui.has_method("_refresh_full"):
		print("FAIL: UnitStatusUI missing _refresh_full")
		get_tree().quit(1)
		return
		
	# 5. Verify Visuals & Rotation Robustness
	print("--- Checking Rotation Robustness ---")
	
	# Rotate Unit 90 degrees
	mock_unit.rotation_degrees.y = 90
	
	# The indicators should NOT rotate relative to world if they are top_level.
	# But wait, if they are top_level, they won't rotate with parent transform automatically.
	# We just need to ensure they exist and are at the right Global Position.
	
	var hg_found = false
	var cover_targets = []
	
	for child in ui.get_children():
		if child is Sprite3D and child.texture:
			if "high_ground" in child.texture.resource_path:
				print("PASS: High Ground Icon Found.")
				hg_found = true
				
		if child is MeshInstance3D:
			# Check Global Position
			print("Found Indicator at Global: ", child.global_position)
			cover_targets.append(child.global_position)
			
	# Expected: One indicator at (0, 0, -2) (Local North relative to (0,0,0) world, but Unit is at (2, 0, 2))
	# Unit at (1,1) -> (2, 0, 2).
	# North Neighbor (1,0) -> (2, 0, 0).
	# Indicator should be between them, offset towards North.
	# Offset 0.85 North -> (2, 0, 2) + (0,0,-0.85) = (2, 0, 1.15).
	
	var expected_z = 2.0 - 0.85
	var found_valid_cover = false
	
	for pos in cover_targets:
		if abs(pos.x - 2.0) < 0.1 and abs(pos.z - expected_z) < 0.1:
			print("PASS: Indicator correctly aligned North (Global).")
			found_valid_cover = true
			
	if not found_valid_cover:
		print("FAIL: No indicator found at expected North position (2, 0, ", expected_z, ")")
		get_tree().quit(1)
		return
		
	# 6. Simulate Movement Step
	print("--- Simulate Step --")
	# Move Unit to (1,0)
	mock_unit.grid_pos = Vector2(1,0)
	mock_unit.global_position = Vector3(2, 0, 0)
	
	# Emit Signal
	SignalBus.on_unit_step_completed.emit(mock_unit)
	
	# New Setup: Unit at (1,0). 
	# Neighbor (1,1) is South. Elevation 1.
	# Neighbor (0,0) is West? 
	# Let's see what grid has.
	# We didn't define (0,0). We defined (1,1) Elev 1.
	# So moving to (1,0), the South neighbor (1,1) has Elevation 1. 
	# Does it provide Cover? Defaults to 0?
	# In MockGridManager below, (1,1) has cover_height 0.0.
	# So no cover here.
	
	# Add Cover at (2,0) (East)
	gm.grid_data[Vector2(2,0)] = {"elevation": 0, "cover_height": 1.0}
	
	# Re-Emit to catch new data
	SignalBus.on_unit_step_completed.emit(mock_unit)
	
	var found_east = false
	for child in ui.get_children():
		if child is MeshInstance3D:
			# Should be East of (2,0,0) -> (3.7, 0, 0) approx
			if child.global_position.x > 2.5:
				print("PASS: Found new indicator East after move.")
				found_east = true
				
	if found_east:
		print("VERIFICATION SUCCESS")
	else:
		print("FAIL: Did not update cover after move.")
		get_tree().quit(1)
		return

	get_tree().quit()
