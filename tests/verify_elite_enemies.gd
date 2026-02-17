extends Node

const LOG_PREFIX = "TestVerifyElite: "

# CORRECT PATH: Scripts, not Scene
var main_script = load("res://scripts/core/Main.gd")
var main_node = null

func _ready():
	_run_test()

func _run_test():
	print(LOG_PREFIX + "Starting Test...")
	
	# Add TestSafeGuard
	var safeguard = load("res://tests/TestSafeGuard.gd").new()
	add_child(safeguard)

	# 1. Setup Main
	if not main_script:
		print("ERROR: Could not load Main.gd")
		get_tree().quit(1)
		return

	main_node = main_script.new()
	main_node.name = "Main"
	
	# 2. Mock Mission with Elite Enemies
	var config = load("res://scripts/resources/MissionConfig.gd").new()
	config.mission_name = "Elite Verify Mission"
	config.objective_type = 0 # Deathmatch
	
	var w = load("res://scripts/resources/WaveDefinition.gd").new()
	w.budget_points = 20
	w.allowed_archetypes.assign(["Whisperer", "Infiltrator"])
	w.wave_message = "Testing Elites"
	config.waves.append(w)
	
	# Inject into GameManager (Main reads this)
	GameManager.active_mission = config
	GameManager.is_test_mode = true # Skip camera/UI
	
	add_child(main_node) # _ready() runs here, safely reading GameManager
	
	# Allow Main._ready() to process
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 3. Wait for Spawn
	var mm = main_node.mission_manager
	if not mm:
		print("FAIL: MissionManager not found.")
		get_tree().quit(1)
		return
		
	# Wait for spawns (async safe)
	var max_wait = 200
	while mm.spawned_units.is_empty() and max_wait > 0:
		await get_tree().process_frame
		max_wait -= 1
		
	# 4. Assertions
	var found_whisperer = false
	var found_infiltrator = false
	
	print(LOG_PREFIX + "Spawned Units: " + str(mm.spawned_units.size()))
	
	for u in mm.spawned_units:
		var script_path = ""
		if u.get_script():
			script_path = u.get_script().resource_path
			
		print(LOG_PREFIX + "Checking Unit: " + u.name + " | Script: " + script_path)
		
		# Check for Whisperer
		if "Whisperer" in script_path or "Whisperer" in u.name:
			found_whisperer = true
			
		# Check for Infiltrator
		if "Infiltrator" in script_path or "Infiltrator" in u.name:
			found_infiltrator = true
			
	if found_whisperer and found_infiltrator:
		print("PASSED: Both Whisperer and Infiltrator spawned successfully.")
		get_tree().quit(0)
	else:
		print("FAIL: Missing Elite. Whisperer: " + str(found_whisperer) + ", Infiltrator: " + str(found_infiltrator))
		get_tree().quit(1)
