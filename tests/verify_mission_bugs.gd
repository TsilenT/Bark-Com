extends Node

# Test Suite for Mission Logic bugs
# 1. Instant Win on Hack Mission
# 2. Abort Button failure

func _ready():
	# Watchdog
	var monitor = load("res://tests/TestSafeGuard.gd").new()
	add_child(monitor)

	print("\n=== VERIFYING MISSION BUGS (SCENE MODE) ===\n")
	
	# Wait one frame to ensure Autoloads are fully ready? Usually _ready is fine.
	await get_tree().process_frame
	
	_test_hack_mission_instant_win()
	_test_abort_button_signal()
	
	print("\nDouble Check Complete. Quitting...")
	get_tree().quit()

func _test_hack_mission_instant_win():
	print("\nTEST: Hack Mission Instant Win")
	
	# Setup Managers
	var om = load("res://scripts/managers/ObjectiveManager.gd").new()
	var tm = load("res://scripts/managers/TurnManager.gd").new()
	
	# Mock Mission Type: HACKER (3)
	# Case 1: Initialize with explicit count
	om.initialize(3, tm, 3) 
	
	print("  Status after Init(3 hacks required): ", om.check_status([], 1))
	if om.check_status([], 1) == "WIN":
		print("  [FAIL] Instant Win detected immediately after init!")
	else:
		print("  [PASS] No instant win on proper init.")

	# Case 2: Initialize with 0 count (Spawning Failure Scenario)
	print("  Testing Spawning Failure (Count 0)...")
	om.initialize(3, tm, 0)
	
	# Simulate override from spawner returning 0
	om.target_count = 0
	
	var status = om.check_status([], 1) 
	print("  Status with target_count=0: ", status)
	
	if status == "WIN":
		print("  [FAIL] Instant Win triggered when target_count is 0!")
	else:
		print("  [PASS] Zero targets handled gracefully.")
		
	om.free()
	tm.free()


func _test_abort_button_signal():
	print("\nTEST: Abort Button Signal")
	
	var main_script = load("res://scripts/core/Main.gd")
	if not main_script:
		print("  [ERROR] Could not load Main.gd (Load Failed)")
		return

	# Try to instantiate
	# Note: Main.gd _ready() relies on Dependencies. 
	# We just want to check method existence, so strictly we don't need to add it to tree.
	# But .new() might trigger init logic? Main.gd doesn't have _init, only _ready.
	
	var main = main_script.new()
	if not main:
		print("  [ERROR] Could not instantiate Main.gd")
		return
	
	# Check if method exists
	if main.has_method("_on_action_requested"):
		print("  [PASS] Main.gd has _on_action_requested method.")
		# DEBUG GHOST
		var src = main_script.source_code
		if src.find("func _on_action_requested") == -1:
			print("  [WTF] Method found via reflection, but NOT in source code?!")
		else:
			print("  [INFO] Method FOUND in source code via script resource.")
	else:
		print("  [FAIL] Main.gd is MISSING _on_action_requested method!")
		
	main.free()
