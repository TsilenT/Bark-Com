extends Node

# verify_visuals_sync.gd
# Verifies that UnitStatusUI correctly adjusts visuals based on Threat Context

var grid_manager = null
var unit = null
var attacker_pos = Vector2(0,0)
var target_pos = Vector2(0,2)

# Use _ready for Scene-based execution
func _ready():
	print("Starting Visuals Sync Verification...")
	await setup()
	test_normal_cover()
	test_high_ground_negation()
	cleanup()
	print("Verification Completed.")
	get_tree().quit()

func setup():
	var root = self

	# Mock Objects
	grid_manager = Node.new()
	grid_manager.set_name("GridManager")
	grid_manager.set_script(load("res://scripts/managers/GridManager.gd"))
	root.add_child(grid_manager)
	
	# Mock Grid
	# Elev 0 everywhere except attacker
	grid_manager.grid_data = {}
	grid_manager.grid_data[attacker_pos] = {"elevation": 2, "is_walkable": true}
	grid_manager.grid_data[target_pos] = {"elevation": 0, "is_walkable": true}
	
	# Wall at (0, 1) - Between them
	grid_manager.grid_data[Vector2(0,1)] = {"elevation": 0, "cover_height": 2.0} # Full Cover
	
	# Unit (Mock)
	unit = Node3D.new()
	# Add properties expected by UI
	unit.set_meta("grid_pos", target_pos) # Meta or script var?
	# Attach a script to simulate unit
	var mock_script = GDScript.new()
	mock_script.source_code = "extends Node3D\nvar grid_pos = Vector2(0,2)\nvar status_ui = null"
	mock_script.reload()
	unit.set_script(mock_script)
	
	root.add_child(unit)
	unit.grid_pos = target_pos
	
	# Status UI
	var ui_script = load("res://scripts/ui/UnitStatusUI.gd")
	var ui = Node3D.new()
	ui.set_name("UnitStatusUI")
	ui.set_script(ui_script)
	unit.add_child(ui)
	unit.status_ui = ui

	# Add to tree to trigger _ready
	await get_tree().process_frame

func test_normal_cover():
	print("TEST: Normal Cover (No Threat Context)")
	# GridManager setup is static.
	# UnitStatusUI should show Green Shield (Full Cover) towards North (0, -1 from target) -> 0,1
	
	unit.status_ui._update_directional_cover_indicators(grid_manager)
	
	var count = unit.status_ui.cover_indicators.size()
	if count > 0:
		print("PASS: Indicators present: " + str(count))
	else:
		print("FAILURE: No indicators spawned for static cover.")

func test_high_ground_negation():
	print("TEST: High Ground Visual Negation")
	
	# Enable Threat Context (Attacker at Elev 2 vs Target at Elev 0)
	unit.status_ui.set_threat_context(attacker_pos)
	
	# Wall is at (0,1). Target is at (0,2). Attacker at (0,0).
	# Direction from Target to Wall is North.
	# Direction from Target to Attacker is North (0, -2).
	
	# Elevation Advantage = 2.
	# Wall Eff Height = (0 + 2.0) - 0 = 2.0.
	# Penalized Height = 2.0 - 2.0 = 0.0.
	
	# Expectation: The indicator facing North should be GONE or BROKEN.
	# Since my logic removes it if < 0.5, it should be gone.
	
	var found_north_shield = false
	for ind in unit.status_ui.cover_indicators:
		# Check position relative to unit
		var rel = ind.global_position - unit.global_position
		if rel.z < -0.1: # North is -Z
			found_north_shield = true
			
	if not found_north_shield:
		print("PASS: North Shield Removed due to High Ground.")
	else:
		print("FAILURE: North Shield still present despite High Ground.")

func cleanup():
	unit.queue_free()
	grid_manager.queue_free()

