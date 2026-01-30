extends Node
 
var main_node
var player_unit
var door
var grid_manager
 
func _ready():
	print("--- TEST START: Interaction Regression Verify ---")
	# Watchdog
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	await test_interaction_detects_door()
	
	# Cleanup
	_cleanup()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)

func test_interaction_detects_door():
	# 1. Setup
	print("Context: Interaction System Regression Test")
	
	main_node = load("res://scripts/core/Main.gd").new()
	main_node.is_test_mode = true
	add_child(main_node)
	
	grid_manager = GridManager.new()
	add_child(grid_manager)
	
	# Initializing Mock Components
	main_node.grid_manager = grid_manager
	main_node.turn_manager = Node.new() # Mock
	main_node.turn_manager.name = "TurnManager"
	add_child(main_node.turn_manager)
	
	# Mock ObjectiveManager
	var obj_man_script = load("res://scripts/managers/ObjectiveManager.gd")
	var om = obj_man_script.new()
	om.name = "ObjectiveManager"
	main_node.objective_manager = om
	main_node.add_child(om)

	# 2. Spawn Player
	# 2. Spawn Player
	# Use static mock script to avoid resource leaks
	var unit_script = load("res://tests/MockPlayerUnit.gd")
	player_unit = unit_script.new()
	player_unit.name = "PlayerUnit"
	
	main_node.selected_unit = player_unit
	if "spawned_units" in main_node:
		main_node.spawned_units.append(player_unit)
	main_node.add_child(player_unit)
	
	# 3. Spawn Door (Group: Interactive)
	var door_script = load("res://scripts/entities/Door.gd")
	door = door_script.new()
	door.name = "TestDoor"
	door.grid_pos = Vector2(1, 2) # Adjacent
	main_node.add_child(door)
	door.initialize(Vector2(1, 2), grid_manager)
	
	# 4. Attempt Interaction
	await get_tree().create_timer(0.1).timeout
	
	# Spy on log/signal?
	assert_eq(door.is_open, false, "Door should start closed")
	
	print("Triggering _try_interact()...")
	main_node._try_interact()
	
	# 5. Asset
	if door.is_open:
		pass_test("Door opened successfully!")
	else:
		fail_test("Door failed to open via _try_interact()")

func _cleanup():
	# Stop Audio to release stream refs
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("stop_all"):
		am.stop_all()

	if main_node and is_instance_valid(main_node):
		# Break internal cycles if possible
		if "player_controller" in main_node and is_instance_valid(main_node.player_controller):
			main_node.player_controller.queue_free()
		
		if "spawned_units" in main_node: main_node.spawned_units.clear()
		main_node.queue_free()
		
	# Explicitly handle player unit
	if player_unit and is_instance_valid(player_unit):
		# If it was added to tree, queue_free is enough.
		# If it wasn't (standalone), free() is needed.
		# Safer to use queue_free if we think it's in tree, but free() if guaranteed orphan.
		# In this test, we did main_node.add_child(player_unit).
		# BUT main_node.queue_free() might not have processed yet.
		# Let's unlink it first.
		if player_unit.get_parent():
			player_unit.get_parent().remove_child(player_unit)
		player_unit.free() 
		player_unit = null

	if grid_manager and is_instance_valid(grid_manager):
		grid_manager.free()
		
	# Clear refs
	main_node = null
	player_unit = null
	door = null
	grid_manager = null
	
	# Force garbage collection cycle (best effort)
	await get_tree().process_frame

func assert_eq(a, b, msg):
	if a != b:
		print("FAIL: " + msg + " [Expected: " + str(b) + ", Got: " + str(a) + "]")
		get_tree().quit(1)

func pass_test(msg):
	print("PASS: " + msg)

func fail_test(msg):
	print("FAIL: " + msg)
	get_tree().quit(1)

