extends Node

class MockUnit extends Node3D:
	var current_hp = 10

func _ready():
	print("TEST SCENE: Verify Cylindrical AOE Logic")

	# Watchdog
	add_child(load("res://tests/TestSafeGuard.gd").new())

	
	# Setup
	var gm_script = load("res://scripts/managers/GridManager.gd")
	var gm = gm_script.new()
	add_child(gm)
	
	# Create Mock Units
	var u1 = MockUnit.new()
	u1.name = "Unit_Ground"
	u1.add_to_group("Units")
	add_child(u1)
	u1.global_position = Vector3(5, 0, 0)
	
	var u2 = MockUnit.new()
	u2.name = "Unit_High"
	u2.add_to_group("Units")
	add_child(u2)
	u2.global_position = Vector3(5, 2, 0) # Same X/Z, higher Y
	
	var u3 = MockUnit.new()
	u3.name = "Unit_Outside"
	u3.add_to_group("Units")
	add_child(u3)
	u3.global_position = Vector3(10, 0, 0)

	await get_tree().process_frame
	
	# Test
	var center = Vector3(0, 0, 0)
	var radius = 6.0 # Should hit u1 and u2 (Dist 5), miss u3 (Dist 10)
	
	print("Checking Radius 6.0 at (0,0,0)...")
	var hits = gm.get_units_in_radius_cylindrical(center, radius, 3.0)
	
	print("Hits detected: ", hits.size())
	for h in hits:
		print(" - Hit: ", h.name)
		
	if hits.size() != 2:
		_fail("Expected 2 hits.")
		return
		
	if not hits.has(u1) or not hits.has(u2):
		_fail("Missing expected units.")
		return
		
	if hits.has(u3):
		_fail("Hit unit outside radius.")
		return
		
	# Test Vertical Tolerance Limit
	print("Checking Vertical Tolerance 1.0...")
	hits = gm.get_units_in_radius_cylindrical(center, radius, 1.0) # Should miss u2 (Y=2)
	
	if hits.has(u2):
		_fail("Tolerance check failed (High unit hit).")
		return
	
	print("SUCCESS: Cylindrical AOE works as expected.")
	get_tree().quit(0)

func _fail(msg):
	print("FAILED: ", msg)
	get_tree().quit(1)
