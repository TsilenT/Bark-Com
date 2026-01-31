extends Node

func _ready():
	# Watchdog
	var monitor = load("res://tests/TestSafeGuard.gd").new()
	add_child(monitor)
	
	print("=== VERIFYING ABORT CONNECTION ===")
	
	# Load Scripts
	var main_script = load("res://scripts/core/Main.gd")
	var gui_script = load("res://scripts/ui/GameUI.gd")
	
	if not main_script or not gui_script:
		print("[FAIL] Could not load scripts.")
		get_tree().quit(1)
		return

	# Instantiate Main
	var main = main_script.new()
	main.is_test_mode = true 
	
	print("Instantiating Main and adding to Tree...")
	add_child(main)
	
	# Wait for _ready? add_child triggers _ready immediately? 
	# Verification
	
	print("Checking children for GameUI...")
	var found_gui = null
	for child in main.get_children():
		if child.name == "GameUI":
			found_gui = child
			break
			
	if not found_gui:
		print("[FAIL] GameUI child NOT found in Main.")
		if main.game_ui:
			print("[INFO] main.game_ui reference exists but not in children?")
			found_gui = main.game_ui
		else:
			print("[FAIL] main.game_ui reference is NULL.")
			get_tree().quit(1)
			return
	else:
		print("[PASS] GameUI child found.")

	# Verify Connection
	print("Checking signal connections...")
	var signal_name = "action_requested"
	var method_name = "_on_action_requested"
	
	if not found_gui.has_signal(signal_name):
		print("[FAIL] GameUI missing signal 'action_requested'.")
		get_tree().quit(1)
		return
		
	var connections = found_gui.action_requested.get_connections()
	var is_connected = false
	for conn in connections:
		var target = conn["callable"].get_object()
		var method = conn["callable"].get_method()
		
		if target == main and method == method_name:
			is_connected = true
			break
			
	if is_connected:
		print("[PASS] GameUI.action_requested IS connected to Main._on_action_requested.")
	else:
		print("[FAIL] GameUI.action_requested is NOT connected to Main._on_action_requested.")
		print("       Found ", connections.size(), " connections.")
		for c in connections:
			print("       - Target: ", c["callable"].get_object(), " Method: ", c["callable"].get_method())

	if is_connected:
		print("Simulating Signal Emission 'Abort'...")
		main._mission_end_processed = false
		found_gui.action_requested.emit("Abort")
		
		if main._mission_end_processed:
			print("[PASS] 'Abort' signal triggered _on_mission_ended_handler.")
		else:
			print("[FAIL] 'Abort' signal DID NOT trigger mission end logic.")
			
	get_tree().quit(0)
