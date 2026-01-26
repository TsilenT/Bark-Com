extends Node

# Test Script
# Using real GridManager to satisfy type constraints
func _ready():
	add_child(load("res://tests/TestSafeGuard.gd").new())
	print("Starting Elevation Cover Verification...")
	
	var gm = GridManager.new()
	var combat_resolver = load("res://scripts/managers/CombatResolver.gd")
	
	# Setup Scenario 1: Low Wall (Half Cover)
	# Target at (5,5), Elev 0
	# Wall at (5,6), Elev 0, Height 1.0
	# Attacker at (5,10)
	
	gm.grid_data[Vector2(5,5)] = {"elevation": 0, "cover_height": 0.0}
	gm.grid_data[Vector2(5,6)] = {"elevation": 0, "cover_height": 1.0}
	
	var cover1 = combat_resolver.get_cover_height_at_pos(Vector2(5,5), Vector2(5,10), gm)
	if cover1 == 1.0:
		print("PASS: Normal Low Wall provides Half Cover.")
	else:
		print("FAIL: Normal Low Wall gave ", cover1)
		
	# Setup Scenario 2: High Ground Negation
	# Target at (5,5), Elev 2 (High Ground)
	# Wall at (5,6), Elev 0, Height 1.0 (Below feet)
	
	gm.grid_data[Vector2(5,5)] = {"elevation": 2, "cover_height": 0.0}
	
	var cover2 = combat_resolver.get_cover_height_at_pos(Vector2(5,5), Vector2(5,10), gm)
	if cover2 == 0.0:
		print("PASS: High Ground negates Low Wall cover.")
	else:
		print("FAIL: High Ground failed to negate cover. Got ", cover2)
		
	# Setup Scenario 3: Tall Wall Valid for High Ground
	# Wall at (5,6), Elev 0, Height 4.0 (Tall)
	# Target at Elev 2.
	# Effective height = 4 - 2 = 2.0 (Full Cover)
	
	gm.grid_data[Vector2(5,6)] = {"elevation": 0, "cover_height": 4.0}
	var cover3 = combat_resolver.get_cover_height_at_pos(Vector2(5,5), Vector2(5,10), gm)
	if cover3 == 2.0:
		print("PASS: Tall Wall covers High Ground unit.")
	else:
		print("FAIL: Tall Wall logic failed. Got ", cover3)

	gm.free()
	get_tree().quit()
