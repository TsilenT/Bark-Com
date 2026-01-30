extends Node

func _ready():
	print("--- VERIFY MEDKIT CRASH FIX ---")
	
	# Anti-Hang Safeguard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	# Mock Grid
	var gm = load("res://scripts/managers/GridManager.gd").new()
	# Manually setup fake grid data
	gm.grid_data = {
		Vector2(0,0): {"type": 0, "is_walkable": true},
		Vector2(0,1): {"type": 0, "is_walkable": true},
		Vector2(1,1): {"type": 0, "is_walkable": true},
		Vector2(2,2): {"type": 0, "is_walkable": true}
	}
	
	# Test get_tiles_in_range
	if not gm.has_method("get_tiles_in_range"):
		fail("GridManager missing get_tiles_in_range!")
		return
		
	var center = Vector2(0,0)
	var tiles = gm.get_tiles_in_range(center, 1.5)
	
	print("Tiles in range 1.5 of (0,0): ", tiles)
	
	# Expected: (0,0), (0,1), (1,0) if exists, (1,1) dist is 1.414 <= 1.5
	# My mock only has (0,0), (0,1), (1,1). (1,0) missing.
	# So expected size: 3
	
	if tiles.size() == 3:
		print("PASS: Correct tile count returned.")
	else:
		fail("Returned " + str(tiles.size()) + " tiles. Expected 3.")
		
	gm.free()
	
	print("ALL TESTS PASSED")
	get_tree().quit(0)

func fail(msg):
	print("FAIL: ", msg)
	get_tree().quit(1)
