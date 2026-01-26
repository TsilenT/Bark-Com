extends Node

# verify_passive_visuals.gd
# Verifies that UnitStatusUI correctly ignores cover that is below the unit's feet (Passive Logic).

var grid_manager = null
var unit = null
var high_ground_pos = Vector2(0,0)
var low_ground_pos = Vector2(0,1)

func _ready():
	print("Starting Passive Visuals Verification...")
	await setup()
	test_passive_high_ground()
	test_passive_ground_level()
	cleanup()
	print("Verification Completed.")
	get_tree().quit()

func setup():
	# Mock GridManager
	grid_manager = Node.new()
	grid_manager.set_name("GridManager")
	grid_manager.set_script(load("res://scripts/managers/GridManager.gd"))
	add_child(grid_manager)
	
	grid_manager.grid_data = {}
	
	# High Ground (Elev 2)
	grid_manager.grid_data[high_ground_pos] = {"elevation": 2, "is_walkable": true}
	
	# Low Ground Hydrant (Elev 0, Height 2.0) at (0,1)
	grid_manager.grid_data[low_ground_pos] = {"elevation": 0, "cover_height": 2.0}

	# Unit (Mock)
	unit = Node3D.new()
	unit.set_meta("grid_pos", high_ground_pos)
	
	var mock_script = GDScript.new()
	mock_script.source_code = "extends Node3D\nvar grid_pos = Vector2(0,0)\nvar status_ui = null"
	mock_script.reload()
	unit.set_script(mock_script)
	
	add_child(unit)
	unit.grid_pos = high_ground_pos
	
	# Status UI
	var ui_script = load("res://scripts/ui/UnitStatusUI.gd")
	var ui = Node3D.new()
	ui.set_name("UnitStatusUI")
	ui.set_script(ui_script)
	unit.add_child(ui)
	unit.status_ui = ui
	
	await get_tree().process_frame

func test_passive_high_ground():
	print("TEST: High Ground vs Low Hydrant (Passive)")
	
	# Unit is at Elev 2. Hydrant at Elev 0 (Height 2.0).
	# Effective = (0 + 2.0) - 2.0 = 0.0.
	# Should be NO visual.
	
	unit.status_ui._update_directional_cover_indicators(grid_manager)
	
	var count = unit.status_ui.cover_indicators.size()
	if count == 0:
		print("PASS: No indicators shown for cover below feet.")
	else:
		print("FAILURE: Indicators shown: " + str(count) + ". Expected 0.")

func test_passive_ground_level():
	print("TEST: Ground Level vs Low Hydrant (Passive)")
	
	# Move Unit to Elev 0.
	grid_manager.grid_data[high_ground_pos]["elevation"] = 0
	unit.grid_pos = high_ground_pos # Same pos, just grid data changed
	
	# Effective = (0 + 2.0) - 0.0 = 2.0.
	# Should be Full Cover.
	
	# Force refresh (since we modified grid data directly)
	# Pre-req: ensure grid_data elevation is read correctly by UI logic
	
	unit.status_ui._update_directional_cover_indicators(grid_manager)
	
	var count = unit.status_ui.cover_indicators.size()
	if count > 0:
		print("PASS: Indicators shown for valid cover.")
	else:
		print("FAILURE: No indicators shown for valid cover.")

func cleanup():
	pass
