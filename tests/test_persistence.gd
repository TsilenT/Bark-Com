extends Node

var game_manager_script = load("res://scripts/core/GameManager.gd")
var gm

func _ready():
	print("--- TEST BOOTSTRAP: Persistence & Roster Integrity ---")
	
	# Anti-Ghosting Safeguard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	# Clean up previous runs
	var dir = DirAccess.open("user://")
	
	# ONLY delete the test save file. NEVER touch the real savegame.dat.
	if dir.file_exists("test_savegame.dat"):
		dir.remove("test_savegame.dat")
		
	# Setup fake user directory logic by checking if we are in tmp dir?
	# We rely on CLI --user-data-dir. 
	
	await _run_tests()
	
	if failures > 0:
		print("❌ FAILED: ", failures, " tests failed.")
		await TestUtils.finalize_and_quit(get_tree(), 1)
	else:
		print("✅ PASS: All tests passed.")
		await TestUtils.finalize_and_quit(get_tree(), 0)

var failures = 0
func fail(msg):
	print(msg)
	failures += 1
	
func pass_test(msg):
	print(msg)

func _run_tests():
	print("--- Starting Persistence Tests ---")
	await _test_save_load_cycle()
	_test_mission_completion_roster_integrity()
	_test_inventory_persistence_with_items()
	_test_squad_selection_persistence()
	_test_iron_dog_logic()
	print("--- Finished Persistence Tests ---")

	if failures > 0:
		print("❌ FAILED: " + str(failures) + " tests failed.")
		await TestUtils.finalize_and_quit(get_tree(), 1)
	else:
		print("✅ ALL TASKS PASSED.")
		await TestUtils.finalize_and_quit(get_tree(), 0)

func _test_save_load_cycle():
	print("\n[TEST] Save/Load Cycle...")
	
	var test_path = "user://test_savegame.dat"
	
	# Ensure clean slate
	var dir = DirAccess.open("user://")
	if dir.file_exists("test_savegame.dat"):
		dir.remove("test_savegame.dat")

	gm = game_manager_script.new()
	gm.save_file_path = test_path # ISOLATION
	add_child(gm)
	
	gm.kibble = 500
	gm.missions_completed = 3
	gm.roster.clear()
	gm._add_recruit("TestDog_A", 2, "Scout")
	
	gm.save_game()
	
	# Wait for IO?
	await get_tree().process_frame
	
	if not FileAccess.file_exists(test_path):
		fail("FAIL: Save file not created at " + test_path)
	else:
		gm.kibble = 0
		gm.roster.clear()
		gm.load_game()
		
		# Validation
		if gm.kibble == 500 and gm.roster.size() == 1:
			pass_test("PASS: Save/Load Cycle Integrity Confirmed.")
		else:
			fail("FAIL: Data mismatch. Kibble: " + str(gm.kibble) + " Roster: " + str(gm.roster.size()))
			
	gm.queue_free()
	await get_tree().process_frame

func _test_mission_completion_roster_integrity():
	print("\n[TEST] Mission Completion & Roster Safety...")
	gm = game_manager_script.new()
	gm.save_file_path = "user://test_savegame.dat" # CRITICAL: Isolation
	add_child(gm)
	
	gm.roster.clear()
	gm._add_recruit("Alpha", 1, "Scout")
	gm._add_recruit("Beta", 1, "Heavy")
	
	# Mock Deployment
	gm.deploying_squad = [gm.roster[0], gm.roster[1]]
	
	# Beta dies (Survivor only Alpha)
	var survivors = [{"name": "Alpha", "hp": 8, "inventory": []}]
	gm.register_fallen_hero(gm.roster[1], "Test Death")
	
	gm.complete_mission(survivors, true, [], 100)
	
	if _find_in_roster("Beta"):
		fail("FAIL: Beta should be purged.")
	else:
		pass_test("PASS: Dead unit purged correctly.")
		
	if not _find_in_roster("Alpha"):
		fail("FAIL: Alpha should survive.")
	else:
		pass_test("PASS: Survivor intact.")
	
	# Fail Safe
	gm.roster.clear()
	gm._add_recruit("LoneWolf", 1, "Scout")
	gm.deploying_squad = [gm.roster[0]]
	gm.complete_mission([], true, [], 100)
	
	if gm.roster.size() == 1:
		pass_test("PASS: Fail-Safe triggered for empty survivors on win.")
	else:
		fail("FAIL: Fail-Safe failed.")
		
	gm.queue_free()

func _test_iron_dog_logic():
	print("\n[TEST] Iron Dog Wipe...")
	gm = game_manager_script.new()
	gm.save_file_path = "user://test_savegame.dat"
	add_child(gm)
	gm.iron_dog_mode = true
	gm.roster.clear()
	gm._add_recruit("IronPup", 1)
	gm.deploying_squad = [gm.roster[0]]
	
	# Create dummy save
	var f = FileAccess.open("user://test_savegame.dat", FileAccess.WRITE)
	f.store_string("test")
	f.close()
	await get_tree().process_frame # Flush IO
	
	# Register death to ensure roster purge triggers
	gm.register_fallen_hero(gm.roster[0], "Wiped")
	
	gm.complete_mission([], false, [], 0)
	
	if FileAccess.file_exists("user://test_savegame.dat"):
		fail("FAIL: Save not deleted on wipe.")
	else:
		pass_test("PASS: Save deleted.")
		
	gm.queue_free()

func _test_inventory_persistence_with_items():
	print("\n[TEST] Inventory Persistence (Real Items & Null Filtering)...")
	gm = game_manager_script.new()
	gm.save_file_path = "user://test_savegame.dat"
	add_child(gm)
	
	gm.roster.clear()
	
	# Load Real Resources to simulate actual game behavior
	var medkit = load("res://scripts/resources/items/Medkit.gd").new()
	var grenade = load("res://scripts/resources/items/GrenadeItem.gd").new()
	
	# Initial State: [Medkit, Grenade]
	# We mock the roster entry manually to avoid needing a full Unit instance
	var recruit_data = {
		"name": "Lt. Items",
		"level": 1, 
		"class": "Scout",
		"hp": 10,
		"max_hp": 10,
		"inventory": [medkit, grenade]
	}
	gm.roster.append(recruit_data)
	gm.deploying_squad = [gm.roster[0]]
	
	# Simulate Mission: Medkit Used (Slot 0 -> null), Grenade Kept (Slot 1)
	# Main.gd captures this as [null, Grenade] (GameManager should filter nulls)
	# OR [Grenade] if Main pre-filtered. 
	# GameManager.complete_mission handles the filtering if raw array passed.
	var survivor_data = [{
		"name": "Lt. Items", 
		"hp": 10, 
		"inventory": [null, grenade]
	}]
	
	gm.complete_mission(survivor_data, true, [], 0)
	
	var unit = gm.roster[0]
	
	# 1. Check Size (Should be 1, null removed)
	if unit["inventory"].size() != 1:
		fail("FAIL: Inventory filtering failed. Expected size 1. Got: " + str(unit["inventory"].size()))
	# 2. Check Item Identity
	elif unit["inventory"][0].display_name != "Tennis Ball Grenade":
		fail("FAIL: Wrong item persisted. Expected Grenade. Got: " + unit["inventory"][0].display_name)
	else:
		pass_test("PASS: Inventory persistence handled used items correctly.")
		
	gm.queue_free()

func _test_squad_selection_persistence():
	print("\n[TEST] Squad Selection Persistence...")
	var test_path = "user://test_savegame.dat"
	
	# Phase 1: Setup & Saving
	gm = game_manager_script.new()
	gm.save_file_path = test_path
	add_child(gm)
	
	gm.roster.clear()
	gm._add_recruit("SquadLeader", 1, "Scout")
	gm._add_recruit("SquadMember", 1, "Heavy")
	gm._add_recruit("BenchWarmer", 1, "Sniper")
	
	# Mock Mission Start (Deployment)
	# MissionSelectUI calls start_mission(mission, squad_data)
	var mission = load("res://scripts/resources/MissionData.gd").new()
	mission.mission_name = "Test Mission"
	var custom_squad = [gm.roster[0], gm.roster[1]] # Leader & Member
	
	gm.start_mission(mission, custom_squad)
	
	# Verify Initial State
	if gm.last_squad_ids.size() != 2:
		fail("FAIL: last_squad_ids not populated on start_mission.")
	if not gm.last_squad_ids.has("SquadLeader") or not gm.last_squad_ids.has("SquadMember"):
		fail("FAIL: last_squad_ids missing correct names.")
		
	gm.save_game()
	gm.queue_free()
	
	await get_tree().process_frame
	
	# Phase 2: Loading & Validation
	gm = game_manager_script.new()
	gm.save_file_path = test_path
	add_child(gm)
	
	# Ensure clean state before load
	gm.roster.clear()
	gm.last_squad_ids.clear()
	
	gm.load_game()
	
	# Check Persistence
	if gm.last_squad_ids.size() != 2:
		fail("FAIL: last_squad_ids did not load correctly. Got: " + str(gm.last_squad_ids))
	elif not gm.last_squad_ids.has("SquadLeader"):
		fail("FAIL: SquadLeader missing from persisted selection.")
	else:
		pass_test("PASS: Squad Selection persisted correctly.")
		
	# Check UI Selection Logic (Simulation)
	# MissionSelectUI Step 1: Restore Previous Squad
	var selected_names = []
	var ready_units = gm.get_ready_corgis()
	
	for name in gm.last_squad_ids:
		for unit in ready_units:
			if unit["name"] == name:
				selected_names.append(name)
				break
				
	if selected_names.size() == 2 and selected_names.has("SquadLeader"):
		pass_test("PASS: UI Selection Logic restores squad correctly.")
	else:
		fail("FAIL: UI Logic verification failed. Selections: " + str(selected_names))
		
	gm.queue_free()


func _find_in_roster(name):
	for u in gm.roster:
		if u["name"] == name: return u
	return null
