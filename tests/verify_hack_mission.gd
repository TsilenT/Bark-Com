extends Node

var main_node
var gm
var ui
var mission
var unit
var terminals = []

func _ready():
	print("--- VERIFYING HACK MISSION FIXES ---")
	
	# Watchdog
	# add_child(load("res://tests/TestSafeGuard.gd").new()) 
	
	await get_tree().process_frame
	
	# 1. SETUP MOCK ENVIRONMENT
	if not GameManager:
		printerr("FATAL: GameManager Autoload missing.")
		_fail_test()
		return

	# 1. SETUP MOCK ENVIRONMENT
	if not GameManager:
		printerr("FATAL: GameManager Autoload missing.")
		_fail_test()
		return

	if "is_test_mode" in GameManager:
		GameManager.is_test_mode = true

	main_node = load("res://scripts/core/Main.gd").new()
	main_node.is_test_mode = true
	add_child(main_node)
	
	# Mock GridManager & GameUI
	gm = load("res://scripts/managers/GridManager.gd").new()
	main_node.grid_manager = gm
	main_node.add_child(gm)
	
	ui = load("res://scripts/ui/GameUI.gd").new()
	main_node.game_ui = ui
	main_node.add_child(ui)
	
	# 2. TEST TERMINAL SPAWNING
	mission = load("res://scripts/resources/MissionData.gd").new()
	mission.objective_type = 3 # HACKER
	mission.objective_target_count = 3
	
	# Manual Spawn Logic
	print("  > Spawning 3 Terminals manually...")
	
	for i in range(3):
		var term
		# Use direct load to avoid var holding
		var t_path = "res://scenes/entities/Terminal.tscn"
		var t_scene = null
		if FileAccess.file_exists(t_path):
			t_scene = load(t_path)
			
		if t_scene:
			term = t_scene.instantiate()
		else:
			term = Node3D.new()
			# Don't hold script ref in local var if possible
			term.set_script(load("res://scripts/entities/Terminal.gd"))
			term.name = "Terminal_" + str(i)
		
		# Setup properties
		term.add_to_group("Objectives")
		term.add_to_group("Terminals")
		if "grid_pos" in term:
			term.grid_pos = Vector2(5 + i, 5)
		
		main_node.add_child(term)
		
		if gm.has_method("register_item"):
			gm.register_item(term.grid_pos, term)
			
		if gm.has_method("update_tile_state"):
			gm.update_tile_state(term.grid_pos, false, 1.0, 1)
		
	terminals = utils_get_nodes_in_group(main_node, "Objectives")
	var term_count = 0
	var valid_term = null
	for t in terminals:
		if t.is_in_group("Terminals") or t.has_method("is_hacked"):
			term_count += 1
			valid_term = t
			
	if term_count >= 3:
		print("  > Success. Spawned ", term_count, " Terminals.")
	else:
		print("  > FAILURE. Expected 3 Terminals, found ", term_count)
		_fail_test()
		return

	# 3. TEST UI CONTEXT ACTION
	print("Test 2: Hack Button Context...")
	
	if not valid_term:
		print("  > FAILURE. No valid terminal found to test context.")
		_fail_test()
		return
	
	# Mock Unit
	unit = load("res://scripts/entities/CorgiUnit.gd").new()
	unit.grid_pos = valid_term.grid_pos + Vector2(1, 0) # Adjacent
	unit.faction = "Player"
	unit.current_ap = 2
	
	ui.grid_manager = gm
	
	# UI Container Mock
	var container = HBoxContainer.new()
	ui.action_bar_container = container
	ui.add_child(container)
	
	ui._check_context_actions(unit)
	
	var found_hack = false
	for btn in container.get_children():
		if "Hack" in btn.text:
			found_hack = true
			print("  > Found Button: ", btn.text)
			
	if found_hack:
		print("  > Success. UI generated Hack button.")
	else:
		print("  > FAILURE. No Hack button generated.")
		_fail_test()
		return
		
		return
		
	# 4. TEST HACK SUCCESS (High Tech)
	print("Test 3: Hack Success (Tech 100)")
	unit.tech_score = 100 # Guarantee 100%
	var result_success = valid_term.hack(unit)
	
	if result_success and valid_term.is_hacked:
		print("  > Success. Hack Succeeded with High Tech.")
	else:
		print("  > FAILURE. Hack Failed despite 200% chance.")
		_fail_test()
		return
		
	# Reset Terminal for next test (Manually)
	valid_term.is_hacked = false
	
	# 5. TEST HACK FAILURE (Low Tech)
	print("Test 4: Hack Failure (Tech -100)")
	unit.tech_score = -100 # Guarantee 0%
	var result_fail = valid_term.hack(unit)
	
	if not result_fail and not valid_term.is_hacked:
		print("  > Success. Hack Failed with Low Tech.")
	else:
		print("  > FAILURE. Hack Succeeded despite 0% chance.")
		_fail_test()
		return

	# 6. TEST DYNAMIC RANGE
	print("Test 6: Dynamic Range (Range 3)...")
	# Clean previous buttons
	for child in container.get_children(): child.free()
	
	# Move Unit Far away (3 tiles)
	unit.grid_pos = valid_term.grid_pos + Vector2(3, 0)
	
	# Case A: Low Tech (Should Fail)
	# Tech 0 -> Range 1.5. Target Dist 3.0.
	unit.tech_score = 0
	ui._check_context_actions(unit)
	var found_range_fail = false
	for btn in container.get_children():
		if "Hack" in btn.text: found_range_fail = true
	
	if not found_range_fail:
		print("  > Success. No Hack button at Range 3 with Tech 0.")
	else:
		print("  > FAILURE. Hack button appeared at Range 3 with Tech 0 (Limit 1.5).")
		_fail_test()
		return

	# Case B: Medium Tech (Should Fail)
	# Tech 5 -> Range 1.5 + 1.0 = 2.5. Target Dist 3.0.
	# Clean
	for child in container.get_children(): child.free()
	
	unit.tech_score = 5
	ui._check_context_actions(unit)
	var found_mid_fail = false
	for btn in container.get_children():
		if "Hack" in btn.text: found_mid_fail = true
		
	if not found_mid_fail:
		print("  > Success. No Hack button at Range 3 with Tech 5 (Limit 2.5).")
	else:
		print("  > FAILURE. Hack button appeared at Range 3 with Tech 5.")
		_fail_test()
		return

	# Case C: High Tech (Should Pass)
	# Tech 10 -> Range 1.5 + 2.0 = 3.5. Target Dist 3.0.
	# Clean
	for child in container.get_children(): child.free()
	
	unit.tech_score = 10
	ui._check_context_actions(unit)
	var found_range_pass = false
	for btn in container.get_children():
		if "Hack" in btn.text: found_range_pass = true
		
	if found_range_pass:
		print("  > Success. Hack button appeared at Range 3 with Tech 10 (Limit 3.5).")
	else:
		print("  > FAILURE. No Hack button at Range 3 with Tech 10.")
		_fail_test()
		return

	# 7. TEST DEDUPLICATION (HackAbility vs Context)
	print("Test 7: Deduplication (Suppress Context if Ability exists)...")
	# Clean
	for child in container.get_children(): child.free()
	
	# Add Mock Hack Ability
	var ability = load("res://scripts/abilities/HackAbility.gd").new()
	# Access property directly (Dynamic GDScript)
	if "abilities" in unit:
		unit.abilities.append(ability)
	else:
		print("  > WARNING: unit.abilities not found!")
	
	print("  > Unit Abilities Size: ", unit.abilities.size())
	
	# Reset Position to Adjacent
	unit.grid_pos = valid_term.grid_pos + Vector2(1, 0)
	
	# Context Check should now SKIP adding the button
	ui._check_context_actions(unit)
	
	var found_dedup = false
	for btn in container.get_children():
		if "Hack" in btn.text: found_dedup = true
		
	if not found_dedup:
		print("  > Success. Context Button suppressed because Ability exists.")
	else:
		print("  > FAILURE. Context Button appeared despite HackAbility existing.")
		_fail_test()
		return

	print("--- HACK FIXES VERIFIED ---")
	_cleanup()
	# Wait multiple frames for Engine Renderer cleanup (Headless Dummy Rasterizer is slow to release RIDs)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	quit(0)

func _cleanup():
	# Clear Unit (Orphan)
	if unit and is_instance_valid(unit):
		unit.free()
	
	# Clear Hierarchy
	if main_node and is_instance_valid(main_node):
		# Use free() to ensure immediate cleanup before quit check
		main_node.free()
		
	# Clear Refs to prevent leaks
	main_node = null
	gm = null
	ui = null
	mission = null
	unit = null
	terminals.clear()

func _fail_test():
	printerr("TEST FAILED")
	_cleanup()
	quit(1)

func quit(code):
	get_tree().quit(code)

func utils_get_nodes_in_group(root, group):
	var res = []
	_recurse_group(root, group, res)
	return res

func _recurse_group(node, group, res):
	if node.is_in_group(group):
		res.append(node)
	for c in node.get_children():
		_recurse_group(c, group, res)
