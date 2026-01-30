extends Node

func _ready():
	print("--- VERIFY MAIN DECOUPLED START ---")
	
	# Anti-Hang Safeguard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	await get_tree().process_frame

	# 1. Instantiate Main
	var main_script = load("res://scripts/core/Main.gd")
	var main = main_script.new()
	main.is_test_mode = true
	main.name = "Main"
	
	# 2. Add to Tree (Triggers _ready)
	add_child(main)
	
	# 3. Validate Components
	var failures = []
	
	if not main.grid_manager:
		failures.append("GridManager is missing")
	elif main.grid_manager.name != "GridManager":
		failures.append("GridManager naming incorrect")
		
	if not main.mission_manager:
		failures.append("MissionManager is missing")
		
	if not main.turn_manager:
		failures.append("TurnManager is missing")
		
	if not main.game_ui:
		failures.append("GameUI is missing")

	# Check Mission Config
	# In scene mode, GameManager should be active?
	if GameManager:
		print("GameManager is active.")
	else:
		failures.append("GameManager Autoload missing")

	if not main.active_mission_data:
		# Main generates default mission if none active.
		pass
	else:
		print("Mission Data loaded: " + str(main.active_mission_data))
		
	# 4. Cleanup
	main.queue_free()
	
	if failures.size() > 0:
		printerr("FAIL: " + str(failures))
		# TestUtils.finalize_and_quit(get_tree(), 1)
		# Or just quit manually
		get_tree().quit(1)
	else:
		print("SUCCESS: Main decoupled initialization verified.")
		get_tree().quit(0)
