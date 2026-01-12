extends Node

var grid_manager_script = load("res://scripts/managers/GridManager.gd")
var gm

func _ready():
	print("--- TEST BOOTSTRAP: Grid Height Logic ---")
	gm = grid_manager_script.new()
	add_child(gm)
	
	_test_flat_connectivity()
	_test_step_up_logic()
	_test_ladder_cost()
	
	gm.queue_free()
	await TestUtils.finalize_and_quit(get_tree(), 0)

func _test_flat_connectivity():
	print("\n[TEST] Flat Connectivity (0 -> 0)...")
	gm.grid_data.clear()
	gm.grid_data[Vector2(0,0)] = {"type": 0, "is_walkable": true, "elevation": 0}
	gm.grid_data[Vector2(0,1)] = {"type": 0, "is_walkable": true, "elevation": 0}
	gm._setup_astar()
	
	var path = gm.get_move_path(Vector2(0,0), Vector2(0,1))
	if path.size() > 0:
		print("PASS: Can move on flat ground.")
	else:
		print("FAIL: Cannot move on flat ground.")

func _test_step_up_logic():
	print("\n[TEST] Step Up Logic (0 -> 1)...")
	# Case 1: No Ramp (Block step-up)
	gm.grid_data.clear()
	gm.grid_data[Vector2(0,0)] = {"type": 0, "is_walkable": true, "elevation": 0}
	gm.grid_data[Vector2(0,1)] = {"type": 0, "is_walkable": true, "elevation": 1} # 1 step up
	gm._setup_astar()
	
	var path = gm.get_move_path(Vector2(0,0), Vector2(0,1))
	if path.size() == 0:
		print("INFO: Step Up without Ramp is BLOCKED (Current Behavior).")
	else:
		print("INFO: Step Up without Ramp is ALLOWED.")

	# Case 2: Ramped Step Up
	print("\n[TEST] Ramped Step Up (0 -> 1 with Ramp)...")
	gm.grid_data.clear()
	gm.grid_data[Vector2(0,0)] = {"type": 0, "is_walkable": true, "elevation": 0}
	gm.grid_data[Vector2(0,1)] = {"type": 4, "is_walkable": true, "elevation": 1} # Type 4 = RAMP
	gm._setup_astar()
	
	path = gm.get_move_path(Vector2(0,0), Vector2(0,1))
	if path.size() > 0:
		print("PASS: Can move up ramp.")
	else:
		print("FAIL: Cannot move up ramp.")

func _test_ladder_cost():
	print("\n[TEST] Ladder Movement Rules (Cost & Valid Destination)...")
	gm.grid_data.clear()
	# 0,0 Ground -> 0,1 Ladder -> 0,2 Ground
	gm.grid_data[Vector2(0,0)] = {"type": 0, "is_walkable": true, "elevation": 0}
	gm.grid_data[Vector2(0,1)] = {"type": 5, "is_walkable": true, "elevation": 0} # 5 = LADDER
	gm.grid_data[Vector2(0,2)] = {"type": 0, "is_walkable": true, "elevation": 1} # Connects to upper? 
	# Actually standard ladder logic in GM connects 0 diff and 1 diff if ladder.
	# Let's just test flat cost first for simplicity's sake.
	gm._setup_astar()
	
	# Check 1: Cost
	var path = gm.get_move_path(Vector2(0,0), Vector2(0,1))
	if path.size() > 0:
		var cost = gm.calculate_path_cost(path)
		# Path includes Start? AStar returns [Start, End] usually or [End]? 
		# GridManager.get_move_path returns [Start, ... , End]
		# calculate_path_cost skips index 0 (Start).
		# So path is [0,0 -> 0,1]. Cost should be cost(0,1).
		# Ladder cost was 2, now 1.
		if cost == 1:
			print("PASS: Ladder move cost is 1.")
		else:
			print("FAIL: Ladder move cost is %d (Expected 1)." % cost)
	else:
		print("FAIL: Could not path to ladder.")
		
	# Check 2: Stop Validation
	if gm.is_valid_destination(Vector2(0,1)):
		print("FAIL: Ladder should NOT be a valid destination to stop on.")
	else:
		print("PASS: Ladder correctly rejected as stop destination.")
		
	# Check 3: Traverse Through
	# Move 0,0 -> 0,2 (Through Ladder)
	var path_through = gm.get_move_path(Vector2(0,0), Vector2(0,2))
	if path_through.size() > 0:
		var cost = gm.calculate_path_cost(path_through)
		# Cost: (0,0)->(0,1) [1] + (0,1)->(0,2) [1] = 2
		if cost == 2:
			print("PASS: Traversing ladder cost is 2 (1+1).")
		else:
			print("FAIL: Traversing ladder cost is %d (Expected 2)." % cost)
	else:
		print("FAIL: Could not path through ladder.")
