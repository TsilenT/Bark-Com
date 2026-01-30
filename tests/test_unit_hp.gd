extends Node

func _ready():
	_run_tests()
	get_tree().quit()

func _run_tests():
	# Watchdog
	add_child(load("res://tests/TestSafeGuard.gd").new())

	print("--- Starting Unit HP Tests ---")
	
	test_level_up_healing()
	test_snapshot_clamp()
	
	print("--- All Unit HP Tests Passed ---")

func test_level_up_healing():
	print("Test: Level Up Healing (Max HP Growth)")
	
	var unit = load("res://scripts/entities/Unit.gd").new()
	# Setup mock data requiring level up (e.g. Recruit)
	unit.unit_name = "TestSubject"
	unit.unit_class = "Recruit"
	# Force base stats
	unit.max_hp = 10
	unit.current_hp = 10
	unit.rank_level = 1
	unit.current_xp = 0
	
	# Verify Start
	assert(unit.max_hp == 10, "Initial Max HP should be 10")
	assert(unit.current_hp == 10, "Initial Current HP should be 10")
	
	# Trigger Level Up (Threshold for Lvl 2 is 100)
	unit.gain_xp(100)
	
	# Verify Level Up happened
	assert(unit.rank_level == 2, "Unit should be Level 2. Actual: " + str(unit.rank_level))
	
	# Verify Growth (+2 HP usually)
	# Logic in Unit.gd adds +2 per level for Recruitment if not using ClassData, 
	# OR recalculate_stats logic.
	# Let's verify it grew at all first.
	assert(unit.max_hp > 10, "Max HP should increase. Got: " + str(unit.max_hp))
	
	# Verify Healing
	# Current HP should equal Max HP (12/12) because we started full.
	# The bug was 10/12. We want 12/12.
	assert(unit.current_hp == unit.max_hp, "Current HP should match Max HP after level up if full. Got: %d/%d" % [unit.current_hp, unit.max_hp])
	
	print("✅ PASS: Level Up Healing")
	unit.free()

func test_snapshot_clamp():
	print("Test: Snapshot HP Clamp")
	
	var unit = load("res://scripts/entities/Unit.gd").new()
	unit.max_hp = 10 # True Max
	
	# Mock Snapshot with corrupted/overhealed data
	var corrupted_data = {
		"name": "Cheater",
		"class": "Recruit",
		"level": 1,
		"xp": 0,
		"max_hp": 10,  # Snapshot says 10
		"hp": 20,      # Snapshot says 20 (Way over max)
		"sanity": 100,
		"fallen": false,
		"cosmetics": {}
	}
	
	unit.restore_from_snapshot(corrupted_data)
	
	# Expectation: current_hp should be clamped to max_hp (10)
	assert(unit.current_hp == 10, "Current HP should be clamped to Max HP (10). Got: " + str(unit.current_hp))
	
	print("✅ PASS: Snapshot Clamp")
	unit.free()
