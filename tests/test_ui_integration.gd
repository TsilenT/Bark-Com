extends Node

# Usage: godot -s tests/test_ui_integration.gd

var GameUI_Script
var SquadMemberFrame_Script
var SignalBus_Script

class MockGridManager:
	func is_walkable(pos): return true

class MockTurnManager:
	var units = []

class MockUnit:
	var name = "TestUnit"
	var current_hp = 10
	var max_hp = 10
	var faction = "Player"
	var inventory = []
	var abilities = []
	var max_sanity = 100
	var current_sanity = 100
	var max_ap = 5
	var current_ap = 2


func _ready():
	print("--- STARTING UI INTEGRATION TESTS ---")
	add_child(load("res://tests/TestSafeGuard.gd").new())
	await get_tree().process_frame
	
	GameUI_Script = load("res://scripts/ui/GameUI.gd")
	SquadMemberFrame_Script = load("res://scripts/ui/SquadMemberFrame.gd")
	if not GameUI_Script or not SquadMemberFrame_Script:
		printerr("CRITICAL FAIL: Could not load UI scripts!")
		await TestUtils.finalize_and_quit(get_tree(), 1)
		return

		return

	await test_signal_connection_and_processing()
	await test_squad_sync()
	


func test_signal_connection_and_processing():
	var gui = GameUI_Script.new()
	var mock_tm = MockTurnManager.new()
	var mock_gm = MockGridManager.new()
	
	# Initialize (Dependency Injection)
	gui.initialize(mock_tm, mock_gm)
	
	# Simulate _ready (Manually call since we aren't adding to tree usually, 
	# but GameUI connects in _ready. We must add to tree to trigger _ready or call it.
	# Adding to root to trigger lifecycle.)
	get_tree().root.add_child(gui)
	
	var failed = false

	# 1. Test Squad Init Signal
	var units = [MockUnit.new(), MockUnit.new()]
	print("Emitting on_squad_list_initialized...")
	SignalBus.on_squad_list_initialized.emit(units)
	await get_tree().process_frame # Wait for UI update
	
	# Verification: Check if gui.squad_list_container has children
	# accessing private vars for test is okay
	if gui.squad_container.get_child_count() == 2:
		print("PASS [Squad List Init]: Created 2 frames.")
	else:
		printerr("FAIL [Squad List Init]: Expected 2 frames, got ", gui.squad_container.get_child_count())
		failed = true

	# 2. Test Log Signal
	print("Emitting on_combat_log_event...")
	SignalBus.on_combat_log_event.emit("Test Message", Color.WHITE)
	# No crash = Good.
	# If we could check log history, we would.
	print("PASS [Combat Log]: Signal handled without crash.")
	
	# 3. Test Pause Signal
	print("Emitting on_request_pause...")
	SignalBus.on_request_pause.emit()
	if gui.pause_menu and gui.pause_menu.visible:
		print("PASS [Pause Menu]: Menu became visible.")
	else:
		printerr("FAIL [Pause Menu]: Menu did not open.")
		failed = true
		
	# 4. Test Select Unit Signal
	print("Emitting on_ui_select_unit...")
	var ref_unit = MockUnit.new()
	ref_unit.name = "SelectionTest"
	SignalBus.on_ui_select_unit.emit(ref_unit)
	
	if gui.selected_unit == ref_unit:
		print("PASS [Selection]: Unit selected correctly.")
	else:
		printerr("FAIL [Selection]: Expected unit selection not applied.")
		failed = true

	gui.queue_free()
	await get_tree().process_frame # Flush old GUI

	if failed:
		print("--- UI TESTS FAILED ---")
		await TestUtils.finalize_and_quit(get_tree(), 1)
	else:
		print("--- UI CONNECTIVITY PASS ---")

func test_squad_sync():
	print("--- TEST: SQUAD SYNC ---")
	var gui = GameUI_Script.new()
	var squad_frame = SquadMemberFrame_Script.new()
	var mock_unit = MockUnit.new()
	mock_unit.name = "SyncUnit"
	
	# Setup
	get_tree().root.add_child(gui)
	get_tree().root.add_child(squad_frame)
	
	# Initialize Frame
	squad_frame.initialize(mock_unit)
	
	# Initialize GameUI
	# GameUI creates its own internal elements, we need to inspect them.
	# We select the unit to show it in Bottom Panel
	gui.update_unit_info(mock_unit)
	
	# 1. Verify Initial State
	await get_tree().process_frame
	var frame_ap = squad_frame.ap_label.text
	var bottom_ap = gui.ap_label.text # "AP 2/2"
	
	if "2" in frame_ap and "2" in bottom_ap:
		print("PASS: Initial AP matches (2).")
	else:
		print("FAIL: Initial Sync Mismatch. Frame: ", frame_ap, " Bottom: ", bottom_ap)
		await TestUtils.finalize_and_quit(get_tree(), 1)
		return

	# 2. Simulate Turn Change (AP Refresh)
	# Modifying Mock Data
	mock_unit.current_ap = 3 
	# The real system might emit stats_changed or turn_changed.
	# We test the FIX: SquadFrame listening to Turn Changed.
	
	print("Emitting on_turn_changed...")
	SignalBus.on_turn_changed.emit("PLAYER PHASE", 2)
	await get_tree().process_frame
	
	# 3. Verify Sync
	frame_ap = squad_frame.ap_label.text
	# Note: GameUI might NOT update bottom panel on turn change automatically if it relies on stats_changed
	# But we want to ensure SQUAD FRAME updated.
	
	if "3" in frame_ap:
		print("PASS: SquadFrame updated AP to 3 on Turn Change.")
	else:
		printerr("FAIL: SquadFrame STALE! Expected 3, got ", frame_ap)
		await TestUtils.finalize_and_quit(get_tree(), 1)
		return

	# 4. Verify Bottom Panel (Optional, user said it was correct)
	# If Bottom Panel listens to stats_changed, we need to emit that too for full simulation
	SignalBus.on_unit_stats_changed.emit(mock_unit)
	await get_tree().process_frame
	bottom_ap = gui.ap_label.text
	
	if "3" in bottom_ap:
		print("PASS: Bottom Panel updated AP to 3.")
	else:
		printerr("FAIL: Bottom Panel STALE! Expected 3, got ", bottom_ap)
		await TestUtils.finalize_and_quit(get_tree(), 1)
		return
	
	gui.queue_free()
	squad_frame.queue_free()
	print("--- ALL UI TESTS PASSED ---")
	await TestUtils.finalize_and_quit(get_tree(), 0)
