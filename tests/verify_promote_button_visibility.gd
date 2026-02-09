extends Node

func _ready():
	await _run_tests()
	get_tree().quit()

func _run_tests():
	print("--- Starting Promote Button Visibility Test ---")
	
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
	
	# Setup Roster with two units:
	# 1. Eligible for promotion
	# 2. Ineligible (Not enough XP)
	var eligible_unit = {
		"name": "PromotableDog",
		"class": "Recruit",
		"level": 1,
		"xp": 100, # Eligible
		"max_hp": 10,
		"hp": 10
	}
	
	var ineligible_unit = {
		"name": "NewbieDog",
		"class": "Recruit",
		"level": 1,
		"xp": 0, # Ineligible
		"max_hp": 10,
		"hp": 10
	}
	
	gm.roster.clear()
	gm.roster.append(eligible_unit)
	gm.roster.append(ineligible_unit)
	gm.kibble = 1000
	gm.session_initialized = true
	
	# 2. Instantiate BaseScene
	var BaseSceneScript = load("res://scripts/ui/BaseScene.gd")
	var scene = BaseSceneScript.new()
	add_child(scene)
	
	# Wait for UI build
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 3. Navigate to Roster
	scene._show_roster()
	await get_tree().process_frame # Allow UI to update
	
	# 4. Verify Buttons
	print("Verifying Promote Buttons...")
	
	# We need to find the specific buttons for each unit.
	# The roster list is built in order.
	# Helper to find button in a node tree.
	
	# Container structure in BaseScene:_show_roster
	# Scroll -> Grid -> VBoxWrapper -> Actions(HBox) -> Promote(Button)
	
	var scroll = scene.find_child("RosterScroll", true, false)
	if not scroll:
		print("❌ FAIL: RosterScroll not found")
		return
		
	var grid = scroll.get_child(0) # GridContainer
	if grid.get_child_count() < 2:
		print("❌ FAIL: Grid has fewer children than roster size")
		return
		
	# Unit 1: Eligible
	var row1 = grid.get_child(0) # VBoxWrapper
	var actions1 = row1.get_child(1) # Actions HBox
	var promo1 = _find_promote_button_in_actions(actions1)
	
	if promo1:
		if promo1.disabled:
			print("❌ FAIL: Eligible unit has DISABLED promote button.")
		else:
			print("✅ PASS: Eligible unit has ENABLED promote button.")
	else:
		print("❌ FAIL: Eligible unit MISSING promote button.")

	# Unit 2: Ineligible
	var row2 = grid.get_child(1) # VBoxWrapper
	var actions2 = row2.get_child(1) # Actions HBox
	var promo2 = _find_promote_button_in_actions(actions2)
	
	if promo2:
		if promo2.disabled:
			print("✅ PASS: Ineligible unit has DISABLED promote button.")
		else:
			print("❌ FAIL: Ineligible unit has ENABLED promote button (should be disabled).")
	else:
		print("❌ FAIL: Ineligible unit MISSING promote button (should be visible but disabled).")


	# Cleanup
	if is_instance_valid(scene):
		scene.queue_free()
	
	# Audio cleanup
	if gm.audio_manager:
		if gm.audio_manager.has_method("stop_all"):
			gm.audio_manager.stop_all()
	
func _find_promote_button_in_actions(node: Node) -> Button:
	for child in node.get_children():
		if child is Button and child.text == "PROMOTE!":
			return child
	return null
