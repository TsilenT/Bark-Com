extends Node3D

var _guard
var _spawned_nodes = []
var _main_mock_node
var _pmc
var _corgi
var _enemy

const LOG_PREFIX = "ReproduceCornerAttack: "

func _ready():
	print("--- Reproduce Corner Attack Bug ---")
	_guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(_guard)
	call_deferred("_run_test")

func _track(node):
	if node.get_parent() == null:
		add_child(node)
	_spawned_nodes.append(node)
	return node

func _run_test():
	# 1. Setup GridManager
	var gm_script = load("res://scripts/managers/GridManager.gd")
	var gm = gm_script.new()
	gm.name = "GridManager"
	_track(gm)
	gm.astar = AStar3D.new()
	
	# Mock Grid Data (Simple 5x5)
	for x in range(5):
		for y in range(5):
			gm.grid_data[Vector2(x, y)] = {
				"type": 0, # GROUND
				"is_walkable": true,
				"elevation": 0,
				"world_pos": Vector3(x*2, 0, y*2)
			}
	
	# 2. Spawn Units
	# Corgi at (1,1)
	var unit_script = load("res://scripts/entities/CorgiUnit.gd")
	_corgi = unit_script.new()
	_corgi.name = "TestCorgi"
	_track(_corgi) # Add to tree first
	
	_corgi.faction = "Player"
	_corgi.grid_pos = Vector2(1,1)
	_corgi.current_ap = 2
	_corgi.add_to_group("Units")
	
	# Enemy at (0,0) - The Corner
	var enemy_script = load("res://scripts/entities/EnemyUnit.gd")
	_enemy = enemy_script.new()
	_enemy.name = "TestEnemy"
	_track(_enemy)
	
	_enemy.faction = "Enemy"
	_enemy.grid_pos = Vector2(0,0)
	_enemy.current_hp = 10
	_enemy.add_to_group("Units")
	
	# 3. Mock Main
	var mock_script = GDScript.new()
	mock_script.source_code = "extends Node\nvar executed = false\nvar last_target = null\n\nfunc _execute_ability(ability, source, target, grid_pos):\n\tprint('MockMain: _execute_ability called!')\n\tprint('Target: ', target)\n\texecuted = true\n\tlast_target = target\n\nfunc _clear_targeting_visuals():\n\tpass"
	
	if mock_script.reload() != OK:
		print("FAILED TO RELOAD MOCK SCRIPT")
		return
		
	_main_mock_node = Node.new()
	_main_mock_node.set_script(mock_script)
	_main_mock_node.name = "MainMock"
	_track(_main_mock_node)

	# 4. Setup PlayerMissionController
	var pmc_script = load("res://scripts/controllers/PlayerMissionController.gd")
	_pmc = pmc_script.new()
	_track(_pmc)
	
	# Dependencies
	var tm_mock = Node.new() 
	var tm_script = GDScript.new()
	tm_script.source_code = "extends Node\nvar units = []"
	if tm_script.reload() != OK:
		print("FAILED TO RELOAD TURN MANAGER MOCK SCRIPT")
		return
	tm_mock.set_script(tm_script)
	
	tm_mock.units = [_corgi, _enemy]
	_track(tm_mock)

	var ui_mock = Node.new()
	_track(ui_mock)
	var sb_mock = load("res://scripts/managers/SignalBus.gd").new() # Use real SB or mock? Real is fine for tracking
	_track(sb_mock)
	
	_pmc.initialize(_main_mock_node, gm, tm_mock, ui_mock, sb_mock)
	
	# 5. Execute Test
	print("Selecting Corgi...")
	_pmc.select_unit(_corgi)
	
	print("Setting Input State to TARGETING...")
	_pmc.set_input_state(2) # TARGETING
	
	# Verify PMC state
	if _pmc.current_input_state != 2:
		print("FAILURE: PMC failed to enter TARGETING state")
		_fail()
		return
		
	# DEBUG: Check groups
	var units = get_tree().get_nodes_in_group("Units")
	print("DEBUG: Units in group: ", units.size())
	for u in units:
		print("DEBUG: Unit: ", u.name, " Faction: ", u.get("faction"), " HP: ", u.get("current_hp"), " Pos: ", u.get("grid_pos"))
		
	# DEBUG: Valid Tiles check manually
	var da = load("res://scripts/abilities/StandardAttack.gd").new()
	var valid = da.get_valid_tiles(_main_mock_node, _corgi) # mock passed as grid_manager, but valid_tiles logic doesn't use grid_manager for standard attack (uses tree)
	# Wait, standard attack doesn't use grid_manager in get_valid_tiles mostly, except for maybe custom LineOfSight?
	# StandardAttack.gd checks distance only? 
	# Let's check StandardAttack.gd content again.
	# It takes (grid_manager, user).
	# It calls `u.grid_pos.distance_to(user.grid_pos)`.
	# It does NOT use grid_manager.
	print("DEBUG: Manual get_valid_tiles count: ", valid.size())
	if valid.size() > 0:
		print("DEBUG: Valid Tile 0: ", valid[0])

	print("Simulating Click at (0,0)...")
	# Using MOUSE_BUTTON_LEFT (1)
	_pmc.handle_tile_clicked(Vector2(0,0), 1)
	
	# 6. Check Results
	if _main_mock_node.executed:
		print("SUCCESS: Attack executed on target: ", _main_mock_node.last_target)
		if _main_mock_node.last_target == _enemy:
			print("Target verified as Enemy.")
		else:
			print("WARNING: Target was not the enemy object!")
		_pass()
	else:
		print("FAILURE: Attack failed to execute! PMC swallowed the input.")
		_fail()

func _pass():
	print("test_reproduce_corner_attack PASSED")
	call_deferred("_cleanup_and_quit", 0)

func _fail():
	print("test_reproduce_corner_attack FAILED")
	call_deferred("_cleanup_and_quit", 1)

func _cleanup_and_quit(code):
	for n in _spawned_nodes:
		if is_instance_valid(n):
			n.queue_free()
	if is_instance_valid(_guard):
		_guard.queue_free()
	
	# Wait a frame
	await get_tree().process_frame
	get_tree().quit(code)
