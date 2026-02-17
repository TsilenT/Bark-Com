extends Node

const EnemyUnitScript = preload("res://scripts/entities/EnemyUnit.gd")
const GridManagerScript = preload("res://scripts/managers/GridManager.gd")
const UnitScript = preload("res://scripts/entities/Unit.gd")

var gm
var enemy
var player

func _ready():
	await get_tree().process_frame
	_setup_test()
	await _run_test()
	_cleanup()
	get_tree().quit()

func _setup_test():
	print("--- Setup Walled Navigation Test ---")
	gm = GridManagerScript.new()
	add_child(gm)

	# Add TestSafeGuard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	# Mock Grid Data manually for control
	gm.grid_data = {}
	for x in range(10):
		for y in range(10):
			var tile = Vector2(x,y)
			gm.grid_data[tile] = {
				"is_walkable": true,
				"top_height": 0,
				"type": 0, # Ground
				"elevation": 0
			}
			
	# Init AStar
	gm.setup_astar()
	
	# Create Wall at (4,5) blocking the way to (5,5)?
	# Actually, to block completely we need a ring or line.
	# Let's simple block (5,5) from all sides? Or just put Player at (8,8) and block (5,0) to (5,9).
	# Let's build a wall at x=5.
	for y in range(10):
		var wall = Vector2(5, y)
		gm.grid_data[wall]["is_walkable"] = false
		gm.grid_data[wall]["type"] = 1 # Obstacle
		# Disable in AStar
		var id = gm._get_point_id(wall)
		if gm.astar.has_point(id):
			gm.astar.set_point_disabled(id, true)
			
	# Spawn Units
	player = UnitScript.new()
	player.name = "PlayerTarget"
	player.faction = "Player"
	player.grid_pos = Vector2(8, 5) # Behind Wall
	add_child(player)
	
	enemy = EnemyUnitScript.new()
	enemy.name = "Boss"
	enemy.faction = "Enemy"
	enemy.grid_pos = Vector2(1, 5) # Far side
	enemy.mobility = 4 # Can reach wall (dist 3)
	enemy.attack_range = 1
	# enemy.behavior_resource = load("res://scripts/ai/DogthulhuBehavior.gd").new() # Use generic or boss
	# We want to test _perform_move logic specifically, which overrides behavior if unreachable.
	add_child(enemy)
	
	# Inject into scene tree concepts
	# GridManager needs to know about them? No, we pass list.
	
func _run_test():
	print("--- Running Test ---")
	
	# 1. Verify Unreachable
	var path = gm.get_move_path(enemy.grid_pos, player.grid_pos)
	print("Path from ", enemy.grid_pos, " to ", player.grid_pos, ": ", path)
	if path.size() > 0:
		print("FAIL: Path should be blocked! Test Setup Error.")
		return
	else:
		print("PASS: Path is blocked/empty as expected.")
		
	# 2. Execute Move
	print("Executing _perform_move...")
	enemy.target_unit = player
	
	# Mock "all_units"
	var all_units = [player, enemy]
	
	await enemy._perform_move(gm, all_units)
	
	print("New Enemy Pos: ", enemy.grid_pos)
	
	# 3. Assert Position
	# Wall is at x=5. Enemy start x=1.
	# Closest reachable tile to (8,5) is (4,5) (The wall itself? No, Wall is blocked).
	# Closest *Walkable* tile is (4,5) if wall is walk=false?
	# Wait, if wall is walk=false, get_reachable_tiles WON'T include (4,5).
	# It will include (4,5) ONLY if the wall is at (5,5).
	# I set wall at x=5. So (5,y) is blocked.
	# Closest reachable tile is (4,5).
	# Distance from (4,5) to (8,5) is 4.
	# Enemy Mobility 4. Start (1,5). Can reach (4,5)? Dist is 3. Yes.
	
	if enemy.grid_pos == Vector2(4, 5):
		print("SUCCESS: Enemy moved to (4,5), hugging the wall.")
	else:
		print("FAILURE: Enemy moved to ", enemy.grid_pos, ". Expected (4,5).")
		
func _cleanup():
	enemy.queue_free()
	player.queue_free()
	gm.queue_free()
