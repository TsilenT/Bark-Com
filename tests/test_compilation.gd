extends Node

func _ready():
	print("--- TEST START: Script Compilation & Instantiation ---")
	
	print("Attempting to instantiate Unit...")
	var u = load("res://scripts/entities/Unit.gd").new()
	if u:
		print("PASS: Unit instantiated successfully.")
		u.queue_free()
	else:
		print("FAIL: Unit failed to instantiate.")
		get_tree().quit(1)
		return

	print("Attempting to instantiate EnemyUnit...")
	var e = load("res://scripts/entities/EnemyUnit.gd").new()
	if e:
		print("PASS: EnemyUnit instantiated successfully.")
		e.queue_free()
	else:
		print("FAIL: EnemyUnit failed to instantiate.")
		get_tree().quit(1)
		return

	print("--- ALL COMPILATION TESTS PASSED ---")
	get_tree().quit(0)
