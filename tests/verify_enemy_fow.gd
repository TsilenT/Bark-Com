extends Node

const LOG_PREFIX = "TestFOW"

var gm
var tm
var player
var enemy
var root

# Mock Classes
class FOWMockGridManager extends GridManager:
	func _init():
		name = "GridManager"
		astar = AStar3D.new() 
		# Minimal 20x20 Grid
		for x in range(20):
			for y in range(20):
				var coord = Vector2(x, y)
				grid_data[coord] = {
					"type": 0, "walkable": true, "cover": 0
				}
				astar.add_point(id(coord), Vector3(x*2, 0, y*2))
		# Simplified connections
		for x in range(19):
			for y in range(19):
				astar.connect_points(id(Vector2(x, y)), id(Vector2(x+1, y)))
				astar.connect_points(id(Vector2(x, y)), id(Vector2(x, y+1)))

	func id(v: Vector2) -> int:
		return int(v.y * 20 + v.x)

	func get_world_position(coord: Vector2) -> Vector3:
		return Vector3(coord.x * 2.0, 0, coord.y * 2.0)
		
	func is_walkable(coord: Vector2) -> bool: # Virtual Override
		return true

class FOWMockTurnManager extends Node:
	var turn_count = 1

func _ready():
	print("--- Starting Enemy FOW Test (Robust Clean) ---")
	
	# Prevent Audio Leaks
	if GameManager:
		GameManager.is_test_mode = true
		if GameManager.audio_manager:
			GameManager.audio_manager.stop_all()
			
	var watchdog = load("res://tests/TestSafeGuard.gd").new()
	add_child(watchdog)
	
	await _run_test()
	
	watchdog.queue_free()
	_cleanup()
	
	# Extended Flush for Safety
	for i in range(10):
		await get_tree().process_frame

	print("Test Finished Successfully.")
	get_tree().quit(0)

func _run_test():
	# 1. Setup Environment
	root = Node3D.new()
	add_child(root) # Add to self (Node)
	
	gm = FOWMockGridManager.new()
	root.add_child(gm)
	
	tm = FOWMockTurnManager.new()
	tm.name = "TurnManager"
	root.add_child(tm)

	# 2. Setup Units
	player = load("res://scripts/entities/CorgiUnit.gd").new()
	player.name = "Player"
	player.faction = "Player"
	root.add_child(player)
	player.initialize(Vector2(0, 0)) 
	player.current_hp = 10
	
	enemy = load("res://scripts/entities/EnemyUnit.gd").new()
	enemy.name = "Enemy"
	enemy.faction = "Enemy"
	enemy.detection_range = 8
	enemy.hearing_range = 5
	root.add_child(enemy)
	enemy.initialize(Vector2(15, 15)) 
	enemy.grid_pos = Vector2(15, 15) # Force
	
	await get_tree().process_frame
	
	# TEST 1: Player Far Away
	print("\n--- TEST 1: Player Far Away (Dist ~21) ---")
	
	enemy.current_ap = 2
	await enemy.decide_action([player], gm)
	
	# await get_tree().create_timer(0.5).timeout

	if enemy.target_unit != null:
		print("FAILURE: Enemy picked target from across map!")
		get_tree().quit(1)
		
	if enemy.state != 0: # IDLE
		print("FAILURE: Enemy state is NOT Idle! State: ", enemy.state)
		get_tree().quit(1)
	else:
		print("SUCCESS: Enemy state correctly set to IDLE.")

	if enemy.grid_pos != Vector2(15, 15):
		print("FAILURE: Enemy moved unexpectedly!")
		get_tree().quit(1)

	# TEST 2: Player enters Hearing Range
	print("\n--- TEST 2: Player enters Hearing Range (Dist 3) ---")
	player.grid_pos = Vector2(15, 12)
	player.position = gm.get_world_position(player.grid_pos)
	
	enemy.current_ap = 2
	enemy.target_unit = null 
	
	await enemy.decide_action([player], gm)
	
	# await get_tree().create_timer(1.0).timeout 
	
	if enemy.target_unit == player:
		print("SUCCESS: Enemy detected player via Hearing!")
	else:
		print("FAILURE: Enemy ignored player at close range.")
		get_tree().quit(1)

func _cleanup():
	if GameManager and GameManager.audio_manager:
		GameManager.audio_manager.stop_all()

	# 1. Clear References (Break cycles)
	if enemy and is_instance_valid(enemy):
		enemy.target_unit = null
		enemy.behavior_resource = null
		enemy.enemy_data = null
		enemy.primary_weapon = null
		if enemy.inventory: enemy.inventory.clear()
		if enemy.abilities: enemy.abilities.clear()
	
	if player and is_instance_valid(player):
		if "target_unit" in player: player.target_unit = null
		if player.inventory: player.inventory.clear()
		if player.abilities: player.abilities.clear()
		
	if gm and is_instance_valid(gm):
		if gm.astar: gm.astar.clear(); gm.astar = null

	# 2. Queue Free
	if root and is_instance_valid(root):
		root.queue_free()
		
	# Clear static caches
	var Factory = load("res://scripts/utils/EnemyModelFactory.gd")
	if Factory: Factory.clear_cache()
