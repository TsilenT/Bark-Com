extends Node

var turn_manager
var enemy
var grid_manager

func _ready():
	# Watchdog
	add_child(load("res://tests/TestSafeGuard.gd").new())

	print("--- TEST START: Turn Manager Hang ---")
	
	# 1. Setup Managers as children of SELF (TestRunner)
	
	grid_manager = Node.new()
	grid_manager.name = "GridManager"
	grid_manager.set_script(load("res://scripts/managers/GridManager.gd"))
	add_child(grid_manager)
	
	turn_manager = Node.new()
	turn_manager.name = "TurnManager"
	turn_manager.set_script(load("res://scripts/managers/TurnManager.gd"))
	add_child(turn_manager)
	
	# 2a. Setup Enemy 1
	enemy = load("res://scripts/entities/EnemyUnit.gd").new()
	enemy.name = "TestEnemy1"
	enemy.max_ap = 2
	enemy.current_ap = 2
	enemy.grid_pos = Vector2(5, 5)
	enemy.position = Vector3(5, 0, 5)
	enemy.faction = "Enemy"
	add_child(enemy)
	enemy.add_to_group("Units")
	
	# 2b. Setup Enemy 2 (The one that "never acts"?)
	var enemy2 = load("res://scripts/entities/EnemyUnit.gd").new()
	enemy2.name = "TestEnemy2"
	enemy2.max_ap = 2
	enemy2.current_ap = 2
	enemy2.grid_pos = Vector2(7, 7)
	enemy2.position = Vector3(7, 0, 7)
	enemy2.faction = "Enemy"
	add_child(enemy2)
	enemy2.add_to_group("Units")
	
	# 3. Simulate Turn
	print("Starting Enemy Turn with 2 Enemies...")
	
	# Setup TurnManager units list (Explicit order)
	turn_manager.units = [enemy, enemy2]
	
	# Add dummy player targets
	var player = load("res://scripts/entities/Unit.gd").new()
	player.name = "PlayerTarget1"
	player.grid_pos = Vector2(12, 5)
	player.position = Vector3(12, 0, 5)
	player.faction = "Player"
	player.current_hp = 10
	add_child(player)
	player.add_to_group("Units")
	turn_manager.units.append(player)
	
	var player2 = load("res://scripts/entities/Unit.gd").new()
	player2.name = "PlayerTarget2"
	player2.grid_pos = Vector2(12, 7)
	player2.position = Vector3(12, 0, 7)
	player2.faction = "Player"
	player2.current_hp = 10
	add_child(player2)
	player2.add_to_group("Units")
	turn_manager.units.append(player2)
	
	# Mock Grid Data
	grid_manager.grid_data = {}
	for x in range(0, 10):
		for y in range(0, 10):
			var vec = Vector2(x, y)
			grid_manager.grid_data[vec] = {
				"type": 0, # TileType.GROUND (Enum is int)
				"walkable": true,
				"occupied_by": null,
				"world_pos": Vector3(x, 0, y)
			}
			
	# Initialize AStar for test
	grid_manager.astar = AStar3D.new()
	# Basic mock setup for AStar if GridManager methods rely on it
	# Assuming GridManager._setup_astar() does this, but we can just mock it if private.
	# Actually, since we are mocking grid_data, we should populate astar too or GridManager fails.
	# Let's call a minimal setup loop here.
	for vec in grid_manager.grid_data:
		var id = grid_manager._get_point_id(vec)
		grid_manager.astar.add_point(id, grid_manager.grid_data[vec].world_pos)
		
	# Connect them simply
	for x in range(9):
		for y in range(9):
			var u = grid_manager._get_point_id(Vector2(x, y))
			var v = grid_manager._get_point_id(Vector2(x+1, y))
			if grid_manager.astar.has_point(u) and grid_manager.astar.has_point(v):
				grid_manager.astar.connect_points(u, v)
			v = grid_manager._get_point_id(Vector2(x, y+1))
			if grid_manager.astar.has_point(u) and grid_manager.astar.has_point(v):
				grid_manager.astar.connect_points(u, v)
			
	# Start!
	run_test()

func run_test():
	await get_tree().process_frame
	
	# Force Enemy Turn
	turn_manager.start_enemy_turn()
	
	# Watchdog: Wait 10 seconds. If turn not changed back to Environment/Player, FAIL.
	var timer = 0.0
	while turn_manager.current_turn == 1: # ENEMY_TURN
		await get_tree().process_frame
		timer += get_process_delta_time()
		if timer > 30.0:
			print("❌ FAIL: TurnManager stuck in ENEMY_TURN for 30s!")
			get_tree().quit(1)
			return
			
	print("✅ PASS: TurnManager exited ENEMY_TURN successfully.")
	print("Current Turn State: ", turn_manager.current_turn)
	get_tree().quit(0)
