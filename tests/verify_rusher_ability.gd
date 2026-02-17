extends Node

func _ready():
	print("--- Verifying Rusher AI: Go For Ankles ---")
	await get_tree().process_frame
	_run_test()
	
func _run_test():
	var main_script = load("res://scripts/core/Main.gd")
	var main_node = main_script.new()
	add_child(main_node)
	
	# Add TestSafeGuard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	main_node.grid_manager.generate_tactical_grid(1)
	
	# 1. Setup Rusher (2 AP)
	# Use Factory to ensure Ability is loaded
	var ef = load("res://scripts/factories/EnemyFactory.gd")
	var rusher_data = ef.create_enemy_data("Rusher")
	var rusher = load("res://scripts/entities/EnemyUnit.gd").new()
	rusher.enemy_data = rusher_data # Correct property name 
	# Actual initialization usually copies data in _ready or via setup_from_data
	# EnemyUnit.gd doesn't have a clean "setup_from_data" exposed for testing easily, 
	# but _ready loads from 'data' variable if set? No, usually spawner does it.
	# Let's check EnemyUnit.gd ... it usually uses 'enemy_data' export or loads from archetype?
	# Let's just manually set it up to be safe.
	
	rusher.name = "RusherTester"
	rusher.faction = "Enemy"
	rusher.grid_pos = Vector2(0,0)
	rusher.max_ap = 2 # Correct property name
	rusher.current_ap = 2
	rusher.primary_weapon = rusher_data.primary_weapon
	
	rusher.abilities.clear()
	for abil_script in rusher_data.abilities:
		rusher.abilities.append(abil_script.new())
		
	main_node.grid_manager.get_parent().add_child(rusher)
	
	# 2. Setup Victim (Player)
	var player = load("res://scripts/entities/Unit.gd").new()
	player.name = "Victim"
	player.faction = "Player"
	player.grid_pos = Vector2(0,1) # Adjacent
	player.max_hp = 20
	player.current_hp = 20
	main_node.grid_manager.get_parent().add_child(player)
	
	await get_tree().process_frame
	
	print("Starting Rusher Turn (AP: ", rusher.current_ap, ")...")
	print("Target Distance: ", rusher.grid_pos.distance_to(player.grid_pos))
	
	# Detect check logic might fail if not fully initialized map, so let's force list
	var units = [player]
	
	# Execute AI
	await rusher.decide_action(units, main_node.grid_manager)
	
	await get_tree().process_frame
	
	# Check Result
	print("Action Complete.")
	
	# Verify Effect
	if player.has_effect("Vulnerable"):
		print("SUCCESS: Player is Vulnerable! Rusher used Go For Ankles.")
	else:
		print("FAILURE: Player is NOT Vulnerable. Rusher probably just attacked.")
		# Check HP to confirm attack
		print("Player HP: ", player.current_hp)
	
	main_node.queue_free()
	get_tree().quit(0)
