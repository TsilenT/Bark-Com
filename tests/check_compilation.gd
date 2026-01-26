extends Node

func _ready():
	print("Checking compilation of modified scripts...")
	
	var scripts = [
		"res://scripts/managers/GridManager.gd",
		"res://scripts/ui/GridVisualizer.gd",
		"res://scripts/controllers/PlayerMissionController.gd",
		"res://scripts/managers/TurnManager.gd"
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
