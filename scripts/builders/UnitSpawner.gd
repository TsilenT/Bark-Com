extends RefCounted
class_name UnitSpawner

const LOG_PREFIX = "UnitSpawner: "

const ENEMY_SCRIPTS = {
	"Rusher": "res://scripts/entities/RusherEnemy.gd",
	"Sniper": "res://scripts/entities/SniperEnemy.gd",
	"Spitter": "res://scripts/entities/SpitterUnit.gd",
	"Whisperer": "res://scripts/entities/WhispererUnit.gd",
	"Exploder": "res://scripts/entities/enemies/ExploderEnemy.gd",
	"Tank": "res://scripts/entities/enemies/TankEnemy.gd",
	"Flying": "res://scripts/entities/enemies/FlyingEnemy.gd",
	"Infiltrator": "res://scripts/entities/enemies/InfiltratorEnemy.gd",
	"Boss": "res://scripts/entities/enemies/DogthulhuBoss.gd",
	"Nemesis": "res://scripts/entities/EnemyUnit.gd" # Placeholder
}

# Returns the spawned unit (or null if failed)
func spawn_enemy(type_name: String, grid_manager: GridManager, turn_manager: Node) -> Node3D:
	if not grid_manager:
		GameManager.log(LOG_PREFIX, "Error: GridManager missing.")
		return null

	var script_path = ENEMY_SCRIPTS.get(type_name)
	if not script_path or not ResourceLoader.exists(script_path):
		GameManager.log(LOG_PREFIX, "Error: Unknown enemy script for ", type_name)
		return null

	# 1. Instantiate
	var resource = load(script_path)
	var enemy = null
	
	if resource is PackedScene:
		enemy = resource.instantiate()
	else:
		enemy = resource.new()
		
	# 2. Find Position
	var spawn_pos = _find_spawn_position(grid_manager, type_name)
	
	enemy.position = grid_manager.get_world_position(spawn_pos)
	enemy.grid_pos = spawn_pos
	
	# Register in Grid
	if grid_manager.grid_data.has(spawn_pos):
		grid_manager.grid_data[spawn_pos]["unit"] = enemy

	enemy.visible = false
	
	# Add to Scene
	grid_manager.get_parent().add_child(enemy)
	enemy.add_to_group("Units")
	enemy.add_to_group("Enemies")
	
	# Register with TurnManager
	if turn_manager:
		if turn_manager.has_method("register_unit"):
			turn_manager.register_unit(enemy)
		elif "units" in turn_manager:
			turn_manager.units.append(enemy)

	# 3. Configure
	_configure_enemy(enemy, type_name)

	# 4. Initialize
	if enemy.has_method("initialize"):
		enemy.initialize(spawn_pos)

	GameManager.log(LOG_PREFIX, "Spawned ", type_name, " at ", spawn_pos)
	return enemy


func spawn_nemesis(invader_data: Dictionary, grid_manager: GridManager, turn_manager: Node) -> Node3D:
	if not grid_manager: return null
	
	var type_name = "Nemesis"
	var enemy = load(ENEMY_SCRIPTS["Nemesis"]).new()
	
	# Nemesis-specific override logic would go here, 
	# but traditionally they reuse EnemyUnit.gd logic but hydrated with Nemesis data.
	
	var spawn_pos = _find_spawn_position(grid_manager, "Nemesis")
	enemy.position = grid_manager.get_world_position(spawn_pos)
	enemy.grid_pos = spawn_pos
	
	if grid_manager.grid_data.has(spawn_pos):
		grid_manager.grid_data[spawn_pos]["unit"] = enemy
		
	grid_manager.get_parent().add_child(enemy)
	enemy.add_to_group("Units")
	enemy.add_to_group("Enemies")
	enemy.add_to_group("Nemesis")
	
	if turn_manager and turn_manager.has_method("register_unit"):
		turn_manager.register_unit(enemy)
		
	# Hydrate from Data
	if enemy.has_method("initialize_from_data"):
		enemy.initialize_from_data(invader_data)
		
	# Also initialize regular flow
	if enemy.has_method("initialize"):
		enemy.initialize(spawn_pos)
		
	GameManager.log(LOG_PREFIX, "Spawned NEMESIS: ", invader_data.display_name)
	return enemy


func _find_spawn_position(grid_manager: GridManager, type_name: String) -> Vector2:
	var spawn_pos = Vector2(-1, -1)
	for i in range(20): 
		var candidate = grid_manager.get_random_valid_position()
		
		# Check Reachability from Player Start Zone (Approx 1,1)
		var path = grid_manager.get_move_path(Vector2(1, 1), candidate)
		if not path.is_empty():
			spawn_pos = candidate
			break
			
	if spawn_pos == Vector2(-1, -1):
		GameManager.log(LOG_PREFIX, "Could not find reachable spawn for ", type_name)
		spawn_pos = grid_manager.get_random_valid_position() 
		
	return spawn_pos


func _configure_enemy(enemy, type_name: String):
	# Factory Logic
	var gm_global = null
	if enemy.has_node("/root/GameManager"):
		gm_global = enemy.get_node("/root/GameManager")
	
	# Or pass GameManager via static if possible, but Autoloads are available globally
	# However, RefCounted scripts don't have get_node unless passed a node context.
	# But GameManager IS an autoload. we can access it directly as 'GameManager'
	
	if not EnemyFactory:
		GameManager.log(LOG_PREFIX, "Error: EnemyFactory missing?")
		return

	var data = EnemyFactory.create_enemy_data(type_name, GameManager)
	if data:
		enemy.initialize_from_data(data)
