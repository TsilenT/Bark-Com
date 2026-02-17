extends Node

func _ready():
	print("--- Verifying Whisperer AI Crash Fix ---")
	await get_tree().process_frame
	_run_test()
	
func _run_test():
	var main_script = load("res://scripts/core/Main.gd")
	var main_node = main_script.new()
	add_child(main_node)
	
	# Add TestSafeGuard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	main_node.grid_manager.generate_tactical_grid(1)
	
	# 1. Setup Whisperer
	var whisperer = load("res://scripts/entities/WhispererUnit.gd").new()
	whisperer.grid_pos = Vector2(0,0)
	whisperer.faction = "Enemy"
	main_node.grid_manager.get_parent().add_child(whisperer)
	
	# 2. Setup Victim (Low Sanity -> High Appeal for Mind Fracture)
	var player = load("res://scripts/entities/Unit.gd").new()
	player.grid_pos = Vector2(3,0) # Range 3 (Valid for Mind Fracture)
	player.faction = "Player"
	player.name = "Victim"
	player.current_sanity = 30 # Vulnerable
	main_node.grid_manager.get_parent().add_child(player)
	
	await get_tree().process_frame
	
	print("Triggering Whisperer Action...")
	
	# Mock units list
	var units = [player]
	
	# 3. Trigger Decide Action
	# This will call _acquire_target then evaluate abilities
	whisperer.decide_action(units, main_node.grid_manager)
	
	# If we reach here without crash, SUCCESS.
	# We can also check if it chose the ability.
	
	await get_tree().create_timer(1.0).timeout 
	
	print("Action completed without crash.")
	print("Verify logs manually for 'Mind Shattered!' or 'Resisted'.")
	
	main_node.queue_free()
	get_tree().quit(0)
