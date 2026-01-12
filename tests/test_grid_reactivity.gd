extends Node

# Usage: Run via tests/test_grid_reactivity_runner.tscn

var root

func _ready():
	print("--- Starting Grid Reactivity Tests ---")
	root = self
	
	test_reactivity()
	
	print("--- All Grid Tests Passed ---")
	await TestUtils.finalize_and_quit(get_tree(), 0)

func test_reactivity():
	print("Test 1: Signal Connection and Visualization")
	
	# 1. Setup
	var gm_script = load("res://scripts/managers/GridManager.gd")
	var gv_script = load("res://scripts/ui/GridVisualizer.gd")
	
	var gm = gm_script.new()
	var gv = gv_script.new()
	
	# Mimic Main.gd setup
	gv.grid_manager = gm
	
	# Add to tree to trigger _ready (and connection)
	root.add_child(gm)
	root.add_child(gv)
	
	# Verify Initial State
	# GM should NOT auto-generate (Refactor step 1)
	assert_check(gm.grid_data.size() == 0, "GridManager should not auto-generate")
	assert_check(gv.tile_meshes.size() == 0, "GridVisualizer should be empty initially")
	
	# 2. Trigger Generation
	print("  -> Triggering generate_grid()...")
	gm.generate_grid()
	
	# 3. Assert Reactivity
	assert_check(gm.grid_data.size() > 0, "GridManager should have data")
	assert_check(gv.tile_meshes.size() > 0, "GridVisualizer should have reacted and created meshes")
	assert_check(gv.tile_meshes.size() == gm.grid_data.size(), "Visualizer mesh count should match grid data")
	
	print("  -> Reactivity Confirmed: Visualizer updated via signal.")

	# Aggressive Cleanup
	if is_instance_valid(gv): 
		gv.grid_manager = null
		gv.clear_visuals()
	
	if is_instance_valid(gm):
		if gm.astar: gm.astar = null
		gm.grid_data.clear()
	
	TestUtils.free_children(self)
	
	gm_script = null
	gv_script = null

func assert_check(condition, msg):
	if not condition:
		print("FAILED: " + msg)
		await TestUtils.finalize_and_quit(get_tree(), 1)
