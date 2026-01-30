extends Node

func _ready():
	print("--- TEST MISSION GENERATOR ---")
	
	# Anti-Hang Safeguard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	test_generation(1)
	test_generation(2)
	test_generation(5)
	
	# Verify Scaling
	var c_low = load("res://scripts/builders/MissionGenerator.gd").new().generate_mission_config(5)
	var c_high = load("res://scripts/builders/MissionGenerator.gd").new().generate_mission_config(20)
	
	print("Scaling Check: Lvl 5 vs Lvl 20")
	var b_low = c_low.waves[2].budget_points
	var b_high = c_high.waves[2].budget_points
	print("  > Lvl 5 budget: ", b_low)
	print("  > Lvl 20 budget: ", b_high)
	
	if b_high <= b_low:
		fail_test("Difficulty did not scale up! (Lvl 20 budget same or lower than Lvl 5)")
	
	print("ALL MISSION GENERATOR TESTS PASSED")
	_cleanup()
	
func test_generation(level):
	print("Testing Level ", level, " Generation...")
	var gen = load("res://scripts/builders/MissionGenerator.gd").new()
	var config = gen.generate_mission_config(level)
	
	if not config:
		fail_test("Config is null")
		return
		
	if "Sector Sweep" in config.mission_name or "Supply Run" in config.mission_name or "Network Breach" in config.mission_name:
		print("  > Name: ", config.mission_name)
	else:
		fail_test("Invalid Mission Name: " + config.mission_name)
		
	if config.waves.size() > 0:
		print("  > Waves: ", config.waves.size())
		for w in config.waves:
			print("    - Budget: ", w.budget_points, " Allowed: ", w.allowed_archetypes)
	else:
		fail_test("No waves generated!")
		
	# Verify Pick
	if config.waves.size() > 0:
		var w = config.waves[0]
		var type = gen.pick_random_archetype(w)
		print("  > Picked Random Type: ", type)
		if type == "" and w.allowed_archetypes.size() > 0:
			fail_test("Failed to pick archetype from allowed list.")

	print("PASS: Level ", level)


func _cleanup():
	await get_tree().process_frame
	get_tree().quit(0)

func fail_test(msg):
	print("FAIL: " + msg)
	get_tree().quit(1)
