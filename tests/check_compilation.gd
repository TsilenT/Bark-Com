extends Node

func _ready():
	# Watchdog
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	print("Checking compilation of modified scripts...")
	
	var scripts = [
		"res://scripts/managers/GridManager.gd",
		"res://scripts/ui/GridVisualizer.gd",
		"res://scripts/controllers/PlayerMissionController.gd",
		"res://scripts/managers/TurnManager.gd",
		"res://scripts/core/Main.gd",
		"res://scripts/core/LevelGenerator.gd"
	]
	
	for s_path in scripts:
		print("Preloading ", s_path, "...")
		var res = load(s_path)
		if res:
			print("OK: ", s_path)
		else:
			print("FAILED: ", s_path)
			
	print("Compilation check complete.")
	get_tree().quit()
