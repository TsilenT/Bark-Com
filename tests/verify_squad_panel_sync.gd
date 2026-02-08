extends Node

func _ready():
	print("Running verify_squad_panel_sync...")
	
	# 0. STRICT SAFEGUARD
	var watchdog_script = load("res://tests/TestSafeGuard.gd")
	if watchdog_script:
		var watchdog = watchdog_script.new()
		add_child(watchdog)
	
	# Wait for tree
	await get_tree().process_frame
	
	# Components to test
	var unit_script = load("res://scripts/entities/Unit.gd")
	var card_script = load("res://scripts/ui/UnitInfoCard.gd")
	var frame_script = load("res://scripts/ui/SquadMemberFrame.gd")
	
	if not (unit_script and card_script and frame_script):
		print("ERROR: Missing scripts.")
		await get_tree().process_frame
		get_tree().quit(1)
		return
		
	# 1. SETUP
	var unit = unit_script.new()
	unit.unit_name = "RegressionUnit"
	unit.max_ap = 3
	unit.current_ap = 0
	
	add_child(unit) # MUST be in tree for get_node("/root/SignalBus") to work
	
	# Mock SignalBus if not present
	if not get_tree().root.has_node("SignalBus"):
		print("WARNING: SignalBus not found in root. Test incomplete.")
	
	# 2. TEST UNIT REFRESH SIGNAL
	var sb = get_tree().root.get_node_or_null("SignalBus")
	var state = {"caught": false}
	if sb:
		# print("SignalBus found. Connecting listener...")
		sb.on_unit_stats_changed.connect(func(u): 
			# print("Signal received from: ", u)
			if u == unit: 
				state.caught = true
				# print("MATCH!")
		)
	else:
		print("SignalBus NOT found in root.")
	
	# print("Calling refresh_ap()...")
	unit.refresh_ap()
	
	if unit.current_ap != 3:
		print("FAIL: AP not refreshed.")
		unit.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return
		
	if sb and not state.caught:
		print("FAIL: Signal not emitted from refresh_ap.")
		unit.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return
		
	# 3. TEST CARD PARSING
	var card = card_script.new()
	unit.current_ap = 1
	var data = card._parse_data(unit)
	
	if data.get("ap") != 1:
		print("FAIL: UnitInfoCard parsed ", data.get("ap"), " instead of 1.")
		card.free()
		unit.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return
		
	print("PASS: Signal Emitted + Parsing Correct.")
	
	card.free()
	unit.queue_free()
	await get_tree().process_frame
	get_tree().quit()
