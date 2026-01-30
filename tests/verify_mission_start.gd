extends Node

var main_node
var mission_manager

func _ready():
	print("--- VERIFY MISSION START INTEGRATION ---")
	
	# Watchdog
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	await get_tree().process_frame
	
	test_mission_flow()
	
	print("MISSION START VERIFIED")
	_cleanup()
	
func test_mission_flow():
	# 1. Initialize Main (and dependencies)
	# Main._ready calls MissionInitializer
	main_node = load("res://scripts/core/Main.gd").new()
	main_node.is_test_mode = true # Prevents camera/input capture issues
	add_child(main_node)
	
	# Wait for _ready? It happens immediately on add_child
	mission_manager = main_node.mission_manager
	
	if not mission_manager:
		fail_test("MissionManager not initialized in Main.")
		return
		
	# 2. Generate Config (Uses MissionGenerator)
	var config = mission_manager.generate_mission_config(1)
	if not config:
		fail_test("Config Generation Failed.")
		return
		
	print("  > Config: ", config.mission_name)
	
	# 3. Start Mission
	main_node.grid_manager.generate_tactical_grid() # Ensure Grid exists
	mission_manager.start_mission(config, main_node.grid_manager)
	
	# 4. Verify Wave Started
	if mission_manager.current_wave_index == 1:
		print("  > Wave 1 Started OK.")
	else:
		fail_test("Wave Index expected 1, got " + str(mission_manager.current_wave_index))
		
	# 5. Verify Units Spawned (UnitSpawner)
	# MissionManager.spawned_units should have enemies
	var units = mission_manager.spawned_units
	print("  > Spawned Units Count: ", units.size())
	
	if units.size() > 0:
		print("  > First Unit: ", units[0].name)
	else:
		# Maybe Wave 1 budget was too low? 
		# Level 1 Budget 5. Rusher cost 1. Should have at least 1.
		fail_test("No units spawned!")
		
	# 6. Verify TurnManager Registration
	var tm = main_node.turn_manager
	if tm:
		# Check if units are in TM
		var registered_count = tm.units.size()
		print("  > TurnManager Units: ", registered_count)
		if registered_count >= units.size():
			print("  > TurnManager Registration OK.")
		else:
			fail_test("TurnManager has fewer units than spawned!")
	else:
		fail_test("TurnManager missing.")


func _cleanup():
	if main_node:
		main_node.free()
	await get_tree().process_frame
	get_tree().quit(0)

func fail_test(msg):
	printerr("FAIL: " + msg)
	_cleanup()
	get_tree().quit(1)
