extends Node
	
const LOG_PREFIX = "VerifyFlying: "
	
func _ready():
	# Watchdog
	var watchdog = load("res://tests/TestSafeGuard.gd").new()
	add_child(watchdog)
	
	_run_test()

func _run_test():
	print(LOG_PREFIX, "Starting Flying Enemy Test")
	# In Runner Scene, Autoloads are Global.
	# In Runner Scene, Autoloads are Global (SignalBus).
	var gm = load("res://scripts/managers/GridManager.gd").new()
	gm.name = "GridManager"
	add_child(gm)
	
	# Mock Grid for Pathfinding
	for x in range(12):
		for y in range(5):
			var tile = Vector2(x, y)
			gm.grid_data[tile] = {
				"type": 0, # TileType.GROUND
				"elevation": 0,
				"cover": 0,
				"is_destructible": false,
				"items": []
			}
	gm._setup_astar() # Initialize AStar with mock data
	
	var sb = get_node("/root/SignalBus")   # Autoload Instance

	# Mock Combat Action Signal to detect attacks
	sb.on_combat_action_started.connect(_on_combat_action)

	var flyer = load("res://scripts/entities/enemies/FlyingEnemy.gd").new()
	flyer.name = "Flyer"
	add_child(flyer)
	flyer.grid_pos = Vector2(0, 0)
	flyer.global_position = Vector3(0, 0, 0)
	flyer.current_ap = 2
	
	# Check Range
	print(LOG_PREFIX, "Flyer Attack Range: ", flyer.attack_range) # Expect 4
	
	var target = load("res://scripts/entities/Unit.gd").new()
	target.faction = "Player"
	target.name = "Duck"
	add_child(target)
	target.grid_pos = Vector2(5, 0) # Range 5
	target.global_position = Vector3(10, 0, 0) # 2.0 per tile * 5 = 10.0
	
	await get_tree().process_frame
	
	print(LOG_PREFIX, "Target Distance: ", flyer.grid_pos.distance_to(target.grid_pos)) # 5.0
	
	# Evaluate Position Score at current spot (Range 5)
	var behavior = flyer.behavior_resource
	var score = behavior.evaluate_position(flyer, flyer.grid_pos, target, gm)
	print(LOG_PREFIX, "Score at Range 5: ", score)
	
	# Evaluate Position Score at Range 4
	var closer_score = behavior.evaluate_position(flyer, Vector2(1, 0), target, gm)
	print(LOG_PREFIX, "Score at Range 4: ", closer_score)
	
	print(LOG_PREFIX, "Deciding Action...")
	await flyer.decide_action([target], gm)
	
	await get_tree().process_frame
	await get_tree().process_frame # Wait for action callback
	
	print(LOG_PREFIX, "Test Completed.")
	get_tree().quit()

func _on_combat_action(user, target, type, pos):
	print(LOG_PREFIX, "Action Detected! User: ", user.name, " Type: ", type)
