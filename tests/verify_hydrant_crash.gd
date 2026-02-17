extends Node

func _ready():
	print("--- Verifying Golden Hydrant Crash Fix ---")
	await get_tree().process_frame
	_run_test()
	
func _run_test():
	var main_script = load("res://scripts/core/Main.gd")
	var main_node = main_script.new()
	add_child(main_node)
	
	# Add TestSafeGuard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	main_node.grid_manager.generate_tactical_grid(1)
	
	# 1. Setup Enemy (Attacker)
	var enemy = load("res://scripts/entities/EnemyUnit.gd").new()
	enemy.grid_pos = Vector2(0,0)
	enemy.faction = "Enemy"
	enemy.name = "Attacker"
	main_node.grid_manager.get_parent().add_child(enemy)
	
	# 2. Setup Hydrant (Target - Faction: Player)
	var hydrant = load("res://scripts/entities/GoldenHydrant.gd").new()
	hydrant.initialize(Vector2(0,1), main_node.grid_manager)
	main_node.grid_manager.get_parent().add_child(hydrant)
	
	# Verify Faction
	print("Hydrant Faction: ", hydrant.faction)
	if hydrant.faction != "Player":
		print("WARNING: Hydrant faction is not Player (Crash might not trigger if not Player)")
		hydrant.faction = "Player"
		
	await get_tree().process_frame
	
	print("Triggering Attack on Hydrant...")
	
	# 3. Call CombatResolver directly
	var resolver = load("res://scripts/managers/CombatResolver.gd")
	var result = resolver.execute_attack(enemy, hydrant, main_node.grid_manager)
	
	print("Attack Result: ", result)
	print("Hydrant HP: ", hydrant.current_hp)
	
	# If we reach here, Success
	print("SUCCESS: Attack executed without crash.")
	
	main_node.queue_free()
	get_tree().quit(0)
