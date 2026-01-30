extends Node

func _ready():
	await _run_tests()
	get_tree().quit()

func _run_tests():
	print("--- Starting BaseScene Promotion Integration Test (Scene Mode) ---")
	
	# 1. Setup Mock GameManager State
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		print("❌ FAIL: GameManager not found (Autoload missing?)")
		return

	# Watchdog
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	# SAFETY: Prevent overwriting real save
	gm.TEST_MOCK_ENABLED = true
	gm.save_file_path = "user://test_savegame.dat"
	print("TEST SAFETY: TEST_MOCK_ENABLED set to TRUE. Path: " + gm.save_file_path)
		
	# Create a Damaged Unit ready for promotion
	var unit_data = {
		"name": "IntegrationTestDog",
		"class": "Recruit",
		"level": 1,
		"xp": 100, # Enough for Lvl 2
		"max_hp": 31,
		"hp": 1 # Damaged (1/31)
	}
	
	# Manually inject into roster
	# Check if gm has settings for save data
	gm.roster.clear()
	gm.roster.append(unit_data)
	gm.kibble = 1000
	gm.inventory = [] 
	gm.session_initialized = true
	
	# 2. Instantiate BaseScene
	var BaseSceneScript = load("res://scripts/ui/BaseScene.gd")
	var scene = BaseSceneScript.new()
	# scene.name = "BaseScene"
	
	# Add to tree to trigger _ready and UI build
	# We added this script to root or similar, so add scene as child of root
	add_child(scene)
	
	# Wait for _ready and UI generation
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 3. Navigate to Barracks (Roster)
	print("Navigating to Roster...")
	scene._show_roster()
	
	# 4. Find Promote Button
	var promote_btn = _find_promote_button(scene)
	
	if not promote_btn:
		print("❌ FAIL: 'PROMOTE!' button not found in UI.")
		_print_tree(scene)
		return
		
	print("Found Promote Button. Clicking...")
	promote_btn.pressed.emit()
	
	# 5. Handle Potential Popup
	var updated_data = gm.roster[0]
	if updated_data["level"] == 1:
		print("Promotion not applied immediately. Checking for Popup...")
		var popup = scene.find_child("PromotionPopup", true, false)
		if popup and popup.visible:
			print("Popup detected. Selecting first choice.")
			# Popup logic simulation
			# popup.perk_selected.emit(first_perk_id)
			# Assume we can verify layout or manually trigger emit
			# Let's inspect popup children
			var choices = popup.find_children("", "Button", true, false) 
			# This might return all buttons. Usually choices are in a container.
			if choices.size() > 0:
				choices[0].pressed.emit()
			else:
				print("❌ Popup found but no buttons?")

	# 6. Verify Results
	updated_data = gm.roster[0]
	print("Roster Data After Promotion: ", updated_data)
	
	# Validation 1: Level Increased
	if updated_data["level"] != 2:
		print("❌ FAIL: Level did not increase. Still " + str(updated_data["level"]))
	else:
		print("✅ PASS: Level Increased to 2")
		
	# Validation 2: HP Logic (Damage Preservation)
	var new_max = updated_data["max_hp"]
	var new_cur = updated_data["hp"]
	
	print("HP Result: " + str(new_cur) + "/" + str(new_max))
	
	if new_cur == new_max:
		print("❌ FAIL: Unit was FULLY HEALED!")
	elif new_cur > 1 and new_cur < new_max and new_cur < 10: 
		# Expect 3/33 ish.
		print("✅ PASS: Damage Preserved check.")
	else:
		print("❓ INFO: Value is " + str(new_cur) + ". Verify if correct.")
		
	if gm.audio_manager:
		# Stop all audio to release resource references (Crucial for OggVorbis)
		if gm.audio_manager.has_method("stop_all"):
			gm.audio_manager.stop_all()
			
		# Use queue_free for safer cleanup
		gm.audio_manager.queue_free()
		gm.audio_manager = null
		
	ClassIconManager.clear_cache()
	
	if is_instance_valid(scene):
		scene.queue_free()
		
	# Allow deletion queue to flush (Extended for safety)
	for i in range(10):
		await get_tree().process_frame
	
	get_tree().quit()

func _find_promote_button(node: Node) -> Button:
	if node is Button and node.text == "PROMOTE!":
		return node
	
	for child in node.get_children():
		var res = _find_promote_button(child)
		if res: return res
	return null

func _print_tree(node: Node, depth: int = 0):
	var prefix = ""
	for i in range(depth): prefix += "  "
	print(prefix + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_print_tree(child, depth + 1)
