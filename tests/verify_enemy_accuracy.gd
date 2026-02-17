extends Node

func _ready():
	# Wait for Autoloads
	add_child(load("res://tests/TestSafeGuard.gd").new())
	await get_tree().process_frame
	_run_test()
	get_tree().quit()

func _run_test():
	print("--- Verifying Enemy Accuracy ---")
	
	var archetypes = {
		"Rusher": 75,
		"Sniper": 90,
		"Spitter": 70,
		"Exploder": 60,
		"Flying": 75,
		"Tank": 60,
		"Infiltrator": 85,
		"Whisperer": 80,
		"Boss": 90
	}
	
	var passed = true
	var Factory = load("res://scripts/factories/EnemyFactory.gd")
	var EnemyScript = load("res://scripts/entities/EnemyUnit.gd")
	
	for arch in archetypes:
		var expected = archetypes[arch]
		
		# Create Data
		var data = Factory.create_enemy_data(arch)
		
		# Validate Data Accuracy
		if data.accuracy != expected:
			print("FAIL: [Data] ", arch, " Accuracy mismatch. Expected: ", expected, " Got: ", data.accuracy)
			passed = false
		else:
			print("PASS: [Data] ", arch, " Accuracy: ", data.accuracy)
			
		# Validate Unit Initialization
		var unit = EnemyScript.new()
		unit.initialize_from_data(data)
		
		if unit.accuracy != expected:
			print("FAIL: [Unit] ", arch, " Accuracy mismatch. Expected: ", expected, " Got: ", unit.accuracy)
			passed = false
		
		unit.free()
		
	if passed:
		print("SUCCESS: All Enemy Archetypes generally accurate.")
	else:
		print("FAILURE: Some accuracy values mismatch.")
