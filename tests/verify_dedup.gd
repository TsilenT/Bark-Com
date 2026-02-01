extends Node

const LOG_PREFIX = "VerifyDedup: "

func _ready():
	print(LOG_PREFIX, "Starting Ability Deduplication Test...")
	
	var root = Node3D.new()
	add_child(root)
	var guard = load("res://tests/TestSafeGuard.gd").new()
	root.add_child(guard)
	
	await get_tree().process_frame # Let Autoloads settle if needed
	
	# 1. Setup EnemyUnit
	var enemy = load("res://scripts/entities/EnemyUnit.gd").new()
	root.add_child(enemy)
	
	# 2. Add Dummy Ability Manually (Simulate _ready)
	var acid_script = load("res://scripts/abilities/AcidSpitAbility.gd")
	enemy.abilities.append(acid_script.new())
	print(LOG_PREFIX, "Initial Abilities: ", enemy.abilities.size())
	
	# 3. Create Mock Data
	# We can't easily instantiate a Resource script with properties in code without defining a class, 
	# but EnemyData is a Resource.
	# We'll just mock the object structure if EnemyData is complex.
	# Actually, EnemyData is a global class name.
	var data = load("res://scripts/resources/EnemyData.gd").new()
	data.display_name = "Mock Spitter"
	data.abilities.append(acid_script)
	
	# 4. Initialize
	print(LOG_PREFIX, "Initializing from Data (contains duplicate ability)...")
	enemy.initialize_from_data(data)
	
	# 5. Assert
	print(LOG_PREFIX, "Final Abilities: ", enemy.abilities.size())
	
	var acid_count = 0
	for a in enemy.abilities:
		if a.get_script() == acid_script:
			acid_count += 1
			
	if acid_count == 1:
		print(LOG_PREFIX, "PASS: Ability was deduplicated.")
	else:
		print(LOG_PREFIX, "FAIL: Duplicate abilities found (Count: ", acid_count, ")")
		get_tree().quit(1)
	
	print(LOG_PREFIX, "All Tests Passed.")
	get_tree().quit()
