extends Node

func _ready():
	_run_tests()
	get_tree().quit()

func _run_tests():
	# Watchdog
	add_child(load("res://tests/TestSafeGuard.gd").new())

	print("--- Starting Promotion Tests ---")
	test_unit_promotion_method()
	print("--- All Promotion Tests Passed ---")

func test_unit_promotion_method():
	print("Test: Unit.apply_promotion()")
	
	var unit = load("res://scripts/entities/Unit.gd").new()
	add_child(unit) # Mimic BaseScene
	
	# Simulate BaseScene workflow: Restore from damaged snapshot
	var mock_data = {
		"name": "Waffles",
		"class": "Recruit",
		"level": 1,
		"xp": 100,
		"max_hp": 10,
		"hp": 1 # DAMAGED 1/10
	}
	unit.restore_from_snapshot(mock_data)
	
	# Verify Restoration
	assert(unit.max_hp == 10, "Base Max HP 10")
	assert(unit.current_hp == 1, "Base Cur HP 1")
	
	# Trigger Promotion
	unit.apply_promotion()
	
	# Verify Level
	assert(unit.rank_level == 2, "Level should be 2. Got: " + str(unit.rank_level))
	
	# Verify Stats (Recruit gets +2)
	assert(unit.max_hp > 10, "Max HP Should Increase. Got: " + str(unit.max_hp))
		
	# Verify Healing
	# Should be 1 + 1 = 2 (Recruit growth is 1).
	assert(unit.current_hp == 2, "Current HP should increase by growth (1), start(1) -> 2. Got: " + str(unit.current_hp) + "/" + str(unit.max_hp))
	if unit.current_hp == unit.max_hp:
		print("❌ FAIL: Unit was fully healed during promotion!")
	
	# Verify Snapshot Export
	var snap = unit.get_data_snapshot()
	assert(snap.has("hp"), "Snapshot MUST contain 'hp'")
	assert(snap["hp"] == unit.current_hp, "Snapshot 'hp' must match unit state.")
	assert(snap.has("max_hp"), "Snapshot MUST contain 'max_hp'")
	assert(snap["max_hp"] == unit.max_hp, "Snapshot 'max_hp' must match unit state.")
	
	print("✅ PASS: apply_promotion logic")
	unit.free()
	
	# Test 2: Fallback key logic
	print("Test 2: Fallback Key Logic")
	var unit2 = load("res://scripts/entities/Unit.gd").new()
	add_child(unit2)
	var legacy_data = {
		"name": "Legacy",
		"class": "Recruit",
		"level": 1,
		"xp": 100,
		"max_hp": 10,
		"current_hp": 5 # FALLBACK KEY
	}
	unit2.restore_from_snapshot(legacy_data)
	assert(unit2.current_hp == 5, "Should restore from 'current_hp' fallback. Got: " + str(unit2.current_hp))
	unit2.free()
	print("✅ PASS: Fallback Logic")
