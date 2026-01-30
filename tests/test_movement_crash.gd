extends Node

var unit
var state_machine
var move_state
var crash_detected = false

func _ready():
	print("--- TEST MOVEMENT RACE CONDITION ---")
	
	# Watchdog
	add_child(load("res://tests/TestSafeGuard.gd").new()) 

	# 1. Setup Unit & State Machine
	unit = Node3D.new()
	unit.name = "TestUnit"
	unit.set("current_hp", 10)
	unit.set("grid_pos", Vector2(0,0))
	add_child(unit)
	
	# Mock TurnManager
	var tm = MockTM.new()
	tm.name = "MockTM"
	tm.add_to_group("TurnManager")
	add_child(tm)

	state_machine = load("res://scripts/fsm/StateMachine.gd").new()
	unit.add_child(state_machine)
	
	move_state = load("res://scripts/fsm/units/UnitMoveState.gd").new()
	move_state.name = "Move"
	state_machine.add_child(move_state)
	
	# Mock Idle State
	var idle = load("res://scripts/fsm/State.gd").new()
	idle.name = "Idle"
	state_machine.add_child(idle)
	
	# Init
	state_machine.initial_state = NodePath("Idle")
	state_machine._ready() # Initialize
	
	# 2. Trigger Move 1 (Long Path)
	print(" > Triggering Move 1 (Size 5)")
	var path1 = [Vector3(0,0,0), Vector3(1,0,0), Vector3(2,0,0), Vector3(3,0,0), Vector3(4,0,0)]
	var grid1 = [Vector2(0,0), Vector2(1,0), Vector2(2,0), Vector2(3,0), Vector2(4,0)]
	
	state_machine.transition_to("Move", {"world_path": path1, "grid_path": grid1})
	
	# 3. Wait minimal time (Let loop start and yield)
	# _start_movement awaits process_frame immediately
	await get_tree().process_frame
	await get_tree().process_frame 
	
	# 4. Trigger Move 2 (Short Path) - This overwrites path_points
	print(" > Triggering Move 2 (Size 1)")
	var path2 = [Vector3(0,0,0)]
	var grid2 = [Vector2(0,0)]
	
	state_machine.transition_to("Move", {"world_path": path2, "grid_path": grid2})
	
	# 5. Wait for crash
	# If logic is broken, the first loop continues, sees 'is_moving' is true, 
	# and tries to access path_points[1] (which doesn't exist in path2).
	
	print(" > Waiting...")
	await get_tree().create_timer(1.0).timeout
	
	print("--- TEST SURVIVED ---")
	quit(0)

class MockTM extends Node:
	func handle_reaction_fire(unit, pos):
		# Simulate Async Delay
		await get_tree().create_timer(0.1).timeout

func quit(code):
	get_tree().quit(code)
