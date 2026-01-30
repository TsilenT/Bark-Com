extends Node

# Mock ObjectiveManager Spy
class MockObjectiveManager extends "res://scripts/managers/ObjectiveManager.gd":
	var last_interaction_target = null
	var generic_interaction_called = false
	
	func handle_interaction(interactor, target):
		print("MockOM: handle_interaction called for ", target.name)
		last_interaction_target = target
		# Call super to verify logic if needed, or just track call
		# For this verification, we just want to know Main delegated to us.
		generic_interaction_called = true

var main_node
var spy_om
var player
var rescue_target
var treat_bag
var rt_script
var tb_script

func _ready():
	print("--- VERIFY OBJECTIVE INTERACTION --")

	# Watchdog
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	await get_tree().process_frame
	
	# 1. Setup Environment
	var main_script = load("res://scripts/core/Main.gd")
	main_node = main_script.new()
	main_node.is_test_mode = true
	add_child(main_node)
	
	# Autoloads (local instances)
	var gm = load("res://scripts/managers/GridManager.gd").new()
	main_node.grid_manager = gm
	main_node.add_child(gm)
	
	# Mock Player
	var unit_script = load("res://tests/MockPlayerUnit.gd")
	player = unit_script.new()
	player.name = "Player"
	player.grid_pos = Vector2(5, 5)
	player.current_ap = 2
	main_node.selected_unit = player
	main_node.add_child(player)
	
	# Spy OM
	spy_om = MockObjectiveManager.new()
	spy_om.name = "ObjectiveManager"
	main_node.objective_manager = spy_om
	main_node.add_child(spy_om)
	
	# Test 1: Rescue Target
	print("Test 1: Rescue Target Interaction...")
	
	rt_script = GDScript.new()
	rt_script.source_code = "extends Node3D\nvar grid_pos = Vector2(5, 6)"
	rt_script.reload()
	
	rescue_target = rt_script.new()
	rescue_target.name = "RescueTarget"
	rescue_target.add_to_group("RescueTargets")
	main_node.add_child(rescue_target)
	
	# Execute
	main_node._try_interact()
	
	if spy_om.last_interaction_target == rescue_target:
		print("  > PASS: RescueTarget delegated to ObjectiveManager.")
	else:
		print("  > FAIL: RescueTarget NOT passed to ObjectiveManager.")
		_fail()
		return
		
	# Reset
	spy_om.last_interaction_target = null
	rescue_target.queue_free()
	await get_tree().process_frame
	
	# Test 2: Treat Bag
	print("Test 2: Treat Bag Interaction...")
	
	tb_script = GDScript.new()
	tb_script.source_code = "extends Node3D\nvar grid_pos = Vector2(6, 5)"
	tb_script.reload()
	
	treat_bag = tb_script.new()
	treat_bag.name = "TreatBag"
	treat_bag.add_to_group("TreatBags")
	main_node.add_child(treat_bag)
	
	# Execute
	main_node._try_interact()
	
	if spy_om.last_interaction_target == treat_bag:
		print("  > PASS: TreatBag delegated to ObjectiveManager.")
	else:
		print("  > FAIL: TreatBag NOT passed to ObjectiveManager.")
		_fail()
		return

	print("--- VERIFICATION PASSED ---")
	_cleanup()
	await get_tree().process_frame
	get_tree().quit(0)

func _fail():
	print("TEST FAILED")
	_cleanup()
	get_tree().quit(1)

func _cleanup():
	if main_node and is_instance_valid(main_node):
		# Clean children immediately
		main_node.free()
	
	# Clear refs
	main_node = null
	spy_om = null
	player = null
	rescue_target = null
	treat_bag = null
	rt_script = null
	tb_script = null

