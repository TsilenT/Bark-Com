extends Node

# verify_floating_text_scene.gd
# Runs within a Scene context so Autoloads are guaranteed.

var game_ui
var mock_unit_a
var mock_unit_b

func _ready():
	print("TEST SCENE: Starting Floating Text Verification")
	
	# Wait for Autoloads? They should be ready in _ready for scene.
	# Instantiate GameUI manually
	var ui_script = load("res://scripts/ui/GameUI.gd")
	game_ui = ui_script.new()
	add_child(game_ui)

	# --- Watchdog ---
	var watchdog = load("res://tests/TestSafeGuard.gd").new()
	add_child(watchdog)

	
	# Mock Units
	mock_unit_a = Node3D.new()
	mock_unit_a.name = "UnitA"
	add_child(mock_unit_a)
	
	mock_unit_b = Node3D.new()
	mock_unit_b.name = "UnitB"
	add_child(mock_unit_b)
	mock_unit_b.position = Vector3(10, 0, 0)
	
	# Wait a physics frame to ensure ready?
	await get_tree().process_frame
	
	_run_test()

func _run_test():
	print("Step 1: Emit parallel requests")
	# Unit A Request
	game_ui._queue_floating_text(mock_unit_a, "A1", Color.WHITE)
	# Unit B Request
	game_ui._queue_floating_text(mock_unit_b, "B1", Color.RED)
	# Unit A Second Request
	game_ui._queue_floating_text(mock_unit_a, "A2", Color.WHITE)
	
	var queues = game_ui.active_text_queues
	if queues.size() != 2:
		_fail("Expected 2 active queues, found " + str(queues.size()))
		return
		
	if queues[mock_unit_a]["queue"].size() != 2:
		_fail("Unit A should have 2 messages queued")
		return
		
	print("Step 1 Passed: Queues initialized correctly.")
	
	print("Step 2: Simulate Process (Frame 1)")
	
	game_ui._process(0.1)
	
	# After 1 frame, both A1 and B1 should be spawned (removed from queue)
	if queues[mock_unit_a]["queue"].size() != 1:
		_fail("Unit A queue did not advance. Size: " + str(queues[mock_unit_a]["queue"].size()))
		return
		
	if queues[mock_unit_b]["queue"].size() != 0:
		_fail("Unit B queue did not advance. Size: " + str(queues[mock_unit_b]["queue"].size()))
		return
		
	print("Step 2 Passed: Parallel processing confirmed.")
	print("TEST PASSED: Floating Text Queues are parallel.")
	get_tree().quit(0)

func _fail(msg):
	print("TEST FAILED: ", msg)
	get_tree().quit(1)
