extends Node

func _ready():
	print("--- Verifying Boss Upgrade (HP 70 & Abilities) ---")
	await get_tree().process_frame
	_run_test()
	
func _run_test():
	var ef = load("res://scripts/factories/EnemyFactory.gd")
	# Add TestSafeGuard
	add_child(load("res://tests/TestSafeGuard.gd").new())

	var boss_data = ef.create_enemy_data("Boss")
	
	print("Boss Name: ", boss_data.display_name)
	print("Boss HP: ", boss_data.max_hp)
	print("Boss AP: ", boss_data.action_points)
	
	if boss_data.max_hp != 70:
		print("FAILURE: Boss HP is not 70! Found: ", boss_data.max_hp)
	else:
		print("SUCCESS: Boss HP is 70.")
		
	print("Boss Abilities:")
	var found_ankles = false
	var found_fracture = false
	
	for abil in boss_data.abilities:
		# abil is a GDScript (preload), so we need to instantiate or check script path?
		# Actually factories append `preload("...")`.
		# So `abil` IS a GDScript resource.
		# checking resource path.
		var path = abil.resource_path
		print(" - ", path)
		if "GoForAnklesAbility" in path:
			found_ankles = true
		if "MindFractureAbility" in path:
			found_fracture = true
			
	if found_ankles and found_fracture:
		print("SUCCESS: Boss has both new abilities.")
	else:
		print("FAILURE: Boss is missing abilities.")
		
	get_tree().quit(0)
