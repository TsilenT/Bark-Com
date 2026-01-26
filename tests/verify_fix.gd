extends Node

func _ready():
	add_child(load("res://tests/TestSafeGuard.gd").new())
	print("--- SCENE INTEGRITY CHECK START ---")
	
	# Check GameManager availability
	if GameManager:
		print("GameManager found: ", GameManager.name)
	else:
		print("CRITICAL: GameManager Autoload missing!")
		
	# Check TurnManager
	print("Loading TurnManager...")
	var tm_res = load("res://scripts/managers/TurnManager.gd")
	if tm_res:
		var tm = tm_res.new()
		print("TurnManager instantiated OK.")
		tm.queue_free()
	else:
		print("FAILED to load TurnManager.")
		
	# Check PlayerMissionController
	print("Loading PlayerMissionController...")
	var pmc_res = load("res://scripts/controllers/PlayerMissionController.gd")
	if pmc_res:
		var pmc = pmc_res.new()
		print("PlayerMissionController instantiated OK.")
		pmc.queue_free()
	else:
		print("FAILED to load PlayerMissionController.")
		
	print("--- SCENE INTEGRITY CHECK END ---")
	get_tree().quit()
