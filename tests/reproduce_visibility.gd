extends SceneTree

# Extending the global GridManager class to satisfy type checks
class ReproVisMockGridManager extends GridManager:
	func _ready():
		pass
		
	func get_world_position(grid_pos: Vector2) -> Vector3:
		return Vector3(grid_pos.x * 2.0, 0, grid_pos.y * 2.0)
		
	func is_walkable(grid_pos: Vector2) -> bool:
		return true
		
	func is_tile_blocked(coord: Vector2) -> bool:
		return false

# Must extend Node to be passed to VisionManager.initialize(gm, gv: Node)
class ReproVisMockGridVisualizer extends Node:
	func reset_vision(): pass
	func reveal_fogged(coord): pass
	func reveal_visible(coord): pass
	func set_cell_color(coord, color): pass 

func _init():
	print("Init: Scheduling test run...")
	call_deferred("_run_test_deferred")

func _run_test_deferred():
	print("Starting Visibility Reproduction Test (Deferred)...")
	
	# Watchdog
	var watchdog = load("res://tests/TestSafeGuard.gd").new()
	root.add_child(watchdog)
	
	await process_frame
	
	# 1. Setup SignalBus
	var sb = root.get_node_or_null("SignalBus")
	if not sb:
		print("SignalBus not found in root, creating...")
		sb = load("res://scripts/core/SignalBus.gd").new()
		sb.name = "SignalBus"
		root.add_child(sb)
	else:
		print("SignalBus found.")

	# 2. Setup Managers
	if root.has_node("UnitsNode"):
		root.get_node("UnitsNode").free()
	var units_node = Node3D.new()
	units_node.name = "UnitsNode"
	root.add_child(units_node)
	
	var gm = ReproVisMockGridManager.new()
	gm.name = "GridManager" 
	root.add_child(gm) 
	
	# Populate grid data (20x20)
	for x in range(0, 20):
		for y in range(0, 20):
			gm.grid_data[Vector2(x,y)] = {"is_walkable": true, "type": 0}
			
	var gv = ReproVisMockGridVisualizer.new()
	root.add_child(gv) # Add to tree since it's a Node
	
	print("Loading VisionManager...")
	var vm_script = load("res://scripts/managers/VisionManager.gd")
	if not vm_script:
		print("ERROR: Could not load VisionManager.gd")
		quit()
		return
		
	var vm = vm_script.new()
	vm.name = "VisionManager"
	root.add_child(vm)
	
	vm.initialize(gm, gv)
	
	# 3. Setup Units
	print("Creating Units...")
	var player = load("res://scripts/entities/Unit.gd").new()
	player.name = "PlayerUnitRepro"
	player.faction = "Player"
	player.grid_pos = Vector2(5, 5)
	player.vision_range = 4
	player.smell_range = 10
	player.position = gm.get_world_position(player.grid_pos)
	units_node.add_child(player)
	
	# Add collider to Player manually if Unit.gd doesn't? 
	# Unit.gd usually relies on scene.
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	col.shape = shape
	player.add_child(col)

	var enemy = load("res://scripts/entities/EnemyUnit.gd").new()
	enemy.name = "EnemyUnitRepro"
	enemy.faction = "Enemy"
	enemy.grid_pos = Vector2(15, 15) # Far away
	enemy.position = gm.get_world_position(enemy.grid_pos)
	units_node.add_child(enemy)
	
	await process_frame
	await process_frame # Physics frame
	
	# Initial Vision Update (Simulating Fix: Both units passed)
	print("Initial Update Vision (Simulated Fix)...")
	vm.update_vision([player, enemy])
	
	# Assert Enemy Invisible
	if enemy.visible:
		print("FAILURE: Enemy should be invisible at start (Dist 14, Vision 4).")
	else:
		print("SUCCESS: Enemy invisible at start.")
		
	# 4. Move Enemy into Vision
	print("Moving Enemy to (6, 5) [Visible]...")
	enemy.grid_pos = Vector2(6, 5)
	enemy.position = gm.get_world_position(enemy.grid_pos)
	
	# Emit Signal
	print("Emitting step completed signal...")
	sb.on_unit_step_completed.emit(enemy)
	
	# Wait for signal processing
	await process_frame
	await process_frame
	
	# Assert Enemy Visible
	if enemy.visible:
		print("SUCCESS: Enemy became visible after moving.")
	else:
		print("FAILURE: Enemy did NOT become visible after moving!")
		print("Player Pos: ", player.grid_pos)
		print("Enemy Pos: ", enemy.grid_pos)
		print("Player Vision Range: ", player.vision_range)
		print("Known Enemies: ", vm.known_enemies.keys())
		print("Enemy visible property: ", enemy.visible)
		
	# 5. Move Enemy Out of Vision
	print("Moving Enemy to (15, 15) [Hidden]...")
	enemy.grid_pos = Vector2(15, 15)
	enemy.position = gm.get_world_position(enemy.grid_pos)
	sb.on_unit_step_completed.emit(enemy)
	
	await process_frame
	await process_frame
	
	if not enemy.visible:
		print("SUCCESS: Enemy became invisible after leaving.")
	else:
		print("FAILURE: Enemy is still visible after leaving!")
		
	print("Test Finished.")
	quit()
