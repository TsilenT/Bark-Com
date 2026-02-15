extends Node

var turn_manager_script = load("res://scripts/managers/TurnManager.gd")
var mock_unit_script = load("res://tests/MockPlayerUnit.gd")

var tm
var unit

func _ready():
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)
	
	setup()
	run_test()

func setup():
	# Mock Game State
	var gm_mock = Node.new()
	gm_mock.name = "GameManager"
	# Mock log to avoid errors
	var gm_script = GDScript.new()
	gm_script.source_code = "extends Node\nfunc log(prefix, msg, a=null, b=null, c=null): print(prefix, msg)"
	gm_script.reload()
	gm_mock.set_script(gm_script)
	# Autoloads are tricky in tests, so we rely on TM using GameManager global or we patch it if dependency injection was used.
	# TurnManager uses GameManager.log which is global. In test runner, GameManager is autoloaded.
	# So we don't need to add it if running via runner.
	gm_mock.free()

	# 1. Setup TurnManager
	tm = turn_manager_script.new()
	tm.name = "TurnManager"
	add_child(tm)
	
	# 2. Setup Unit
	unit = mock_unit_script.new()
	unit.name = "SuicidalUnit"
	unit.faction = "Enemy"
	unit.current_hp = 10
	
	# Mock decide_action to kill itself
	var u_script = GDScript.new()
	u_script.source_code = """
extends "res://tests/MockPlayerUnit.gd"
func decide_action(units, gm):
	# Simulate async action
	await get_tree().create_timer(0.1).timeout
	# COMMIT SUDOKU (Free itself)
	print("Unit committing seppuku...")
	self.free()
"""
	u_script.reload()
	unit.set_script(u_script)
	
	add_child(unit)
	
	# Mock GridManager for unit to find
	var gm = Node.new()
	gm.name = "GridManager"
	var gm_script2 = GDScript.new()
	gm_script2.source_code = "extends Node\nfunc refresh_pathfinding(u, i=null, f=''): pass"
	gm_script2.reload()
	gm.set_script(gm_script2)
	add_child(gm)

func run_test():
	print("TEST: Starting Turn Manager Crash Test...")
	
	tm.units = [unit]
	
	# Start Enemy Turn
	# This is async
	tm.start_enemy_turn()
	
	print("TEST: Enemy turn started. Waiting for crash or completion...")
	
	# Wait enough time for the suicide to happen and TM to resume
	await get_tree().create_timer(2.0).timeout
	
	print("SUCCESS: Test finished without crashing.")
	_cleanup()
	get_tree().quit(0)

func _cleanup():
	if is_instance_valid(tm): tm.free()
	if is_instance_valid(unit): unit.free()
