extends Node

# Mock Unit that acts INSTANTLY (Synchronous signal emission)
class InstantMockUnit extends Node:
	signal action_complete
	var name_ = "InstantUnit"
	
	func decide_action(_units, _gm):
		print("MockUnit: Deciding action... (Instant)")
		# Simulate Idle behavior: Spend AP?
		# Emit immediately!
		print("MockUnit: Emitting action_complete NOW.")
		action_complete.emit()
		print("MockUnit: action_complete emitted.")

# Expose the logic we want to test from TurnManager
# (Or we can load the real script and call a helper if we make it static? No, it uses add_child)
# We will create a partial mock of TurnManager or just use the logic directly to verify the PATTERN.
# Ideally we test the REAL TurnManager script functions.

func _ready():
	print("TEST START: Verify Turn Manager Signal Race Condition")
	
	# Watchdog
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	await test_race_condition()
	
	# Cleanup handled by tree exit
	get_tree().quit(0)

func test_race_condition():
	print("\n--- TEST: Synchronous Signal Capture ---")
	
	# 1. Setup
	var tm_script = load("res://scripts/managers/TurnManager.gd")
	var tm = tm_script.new()
	add_child(tm) # Add to self
	
	var unit = InstantMockUnit.new()
	add_child(unit)
	
	# 2. Replicate the Fix Pattern
	# var waiter = _wait_for_unit_action_start(unit, 2.0)
	# We access the method via the instance. 
	# Note: _wait_for_unit_action_start is likely not public (starting with _), but GDScript allows access.
	
	print("Step 1: Calling _wait_for_unit_action_start...")
	var waiter = tm._wait_for_unit_action_start(unit, 2.0) # Short timeout for test
	
	if waiter == null:
		print("FAILURE: Waiter is null? (Signal missing?)")
		get_tree().quit(1)
		return

	# 3. Trigger Instant Action
	print("Step 2: Calling decide_action (Synchronous)...")
	var start_time = Time.get_ticks_msec()
	unit.decide_action([], null)
	
	# 4. Await Result
	print("Step 3: Checking waiter.result or awaiting...")
	
	var result
	if waiter.result:
		print(" - Result available immediately (Synchronous)")
		result = waiter.result
	else:
		print(" - Awaiting signal (Async)...")
		result = await waiter.completed
	var elapsed = Time.get_ticks_msec() - start_time
	
	print("Step 4: Result received: ", result)
	print("Elapsed Time: ", elapsed, "ms")
	
	if result == "done":
		print("SUCCESS: Signal captured instantly!")
		if elapsed > 100: # Should be ~0-20ms
			print("WARNING: Taken longer than expected? (", elapsed, "ms)")
	elif result == "timeout":
		print("FAILURE: Waiter timed out! Race condition exists.")
		get_tree().quit(1)
	else:
		print("FAILURE: Unknown result: ", result)
		get_tree().quit(1)
		
	# Cleanup
	tm.free()
	unit.free()
