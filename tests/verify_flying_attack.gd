extends Node3D

const LOG_PREFIX = "VerifyFlyingAttack: "
var test_failed = false

var _guard
var _spawned_nodes = []

func _ready():
	print(LOG_PREFIX, "--- Starting Test ---")
	
	# Watchdog (Required for Strict Analysis)
	var guard_script = load("res://tests/TestSafeGuard.gd")
	if guard_script:
		_guard = guard_script.new()
		add_child(_guard)
	
	call_deferred("_run_test")

func _track(node):
	add_child(node)
	_spawned_nodes.append(node)
	return node

func _cleanup_and_quit(code):
	# Cleanup tracked nodes
	for node in _spawned_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_spawned_nodes.clear()
	
	# Wait for cleanup
	await get_tree().process_frame
	await get_tree().process_frame
	
	if is_instance_valid(_guard):
		_guard.queue_free()
		
	get_tree().quit(code)

func _run_test():
	print(LOG_PREFIX, "Running Test Logic")
	
	# 1. Setup Environment
	var gm_script = load("res://scripts/managers/GridManager.gd")
	if not gm_script:
		print("ERROR: GridManager script not found!")
		_cleanup_and_quit(1)
		return

	var gm = gm_script.new()
	gm.name = "GridManager"
	_track(gm)
	
	print(LOG_PREFIX, "GridManager Created")
	
	# Mock Grid: 5x5 Flat Ground
	for x in range(5):
		for y in range(5):
			var tile = Vector2(x, y)
			gm.grid_data[tile] = {
				"type": 0,
				"elevation": 0,
				"is_destructible": false,
				"items": []
			}
	gm._setup_astar()
	print(LOG_PREFIX, "Grid Initialized")
	
	# 2. Setup SignalBus Spy
	var sb = get_node_or_null("/root/SignalBus")
	var state = { "combat_triggered": false }
	
	if not sb:
		print("ERROR: SignalBus Autoload not found at /root/SignalBus")
	else:
		print(LOG_PREFIX, "SignalBus Found")
		# We need to manage this connection cleanup if possible, 
		# but for one-shot tests, the process termination usually handles it.
		# However, cleanly, we might want to store the callable.
		sb.on_combat_action_started.connect(func(u, t, type, _p): 
			print(LOG_PREFIX, "Signal Received from: ", u.name, " Type: ", type)
			if (u.name == "Flyer" or u.name == "Eldritch Beast" or u.name == "Nemesis Flyer") and type == "Attack":
				print(LOG_PREFIX, "Attack Detected!")
				state.combat_triggered = true
		)
	
	# 3. Setup Flyer
	var flyer_script = load("res://scripts/entities/enemies/FlyingEnemy.gd")
	var flyer = flyer_script.new()
	flyer.name = "Flyer"
	_track(flyer)
	
	print(LOG_PREFIX, "Flyer Primary Weapon: ", flyer.primary_weapon)
	if flyer.primary_weapon:
		print(LOG_PREFIX, "  Name: ", flyer.primary_weapon.display_name)
		print(LOG_PREFIX, "  Range: ", flyer.primary_weapon.weapon_range)
		print(LOG_PREFIX, "  Damage: ", flyer.primary_weapon.damage)
	else:
		print(LOG_PREFIX, "  Primary Weapon is NULL")
		
	print(LOG_PREFIX, "Flyer AttackRange Variable: ", flyer.attack_range)
	
	# 4. Setup Target
	var unit_script = load("res://scripts/entities/Unit.gd")
	var target = unit_script.new()
	target.faction = "Player"
	target.name = "TargetDummy"
	_track(target)
	
	# WALL OBSTRUCTION SCENARIO
	# Flyer at (0,0). Target at (4,0). Wall at (2,0).
	gm.grid_data[Vector2(0, 0)].elevation = 0
	flyer.grid_pos = Vector2(0, 0)
	flyer.position = Vector3(0, 8, 0) # ELEVATION 4 (Y=8)
	flyer.current_ap = 2
	
	target.grid_pos = Vector2(4, 0)
	target.position = Vector3(8, 0, 0)
	
	# Place Obstruction in between at (2,0) -> World (4,0,0)
	var wall_pos = Vector3(4.0, 1.0, 0) # Center of tile (2,0), Height 2 -> Base 0, Top 2
	var wall = StaticBody3D.new()
	wall.name = "HighWall"
	_track(wall)
	wall.position = wall_pos
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2, 2, 2) # Height 2 (Standard Full Cover)
	col.shape = box
	wall.add_child(col)
	
	print(LOG_PREFIX, "Flyer at (0,0) [Y=8]. Target at (4,0) [Y=0]. Wall at (2,0) [H=2].")
	
	await get_tree().process_frame
	
	# Data check
	print(LOG_PREFIX, "Flyer Weapon: ", flyer.primary_weapon)
	print(LOG_PREFIX, "Flyer Range: ", flyer.attack_range)
	
	# LOS Check Manually
	if flyer.has_method("check_los"):
		var los = flyer.check_los(flyer.grid_pos, target, gm)
		print(LOG_PREFIX, "Manual LOS Check (Flyer->Target): ", los)
	
	# Can Attack Check
	if flyer.has_method("_can_attack_target"):
		var can = flyer._can_attack_target(flyer.grid_pos, target, gm)
		print(LOG_PREFIX, "Manual CanAttack Check: ", can)

	# 5. Execute Turn
	print(LOG_PREFIX, "Flyer Deciding Action...")
	await flyer.decide_action([target], gm)
	
	print(LOG_PREFIX, "Action Decision Complete. Waiting for results...")
	await get_tree().process_frame
	await get_tree().process_frame
	
	if sb and state.combat_triggered:
		print(LOG_PREFIX, "SUCCESS: Flyer attacked.")
	else:
		print(LOG_PREFIX, "FAILURE: Flyer did NOT attack.")
		test_failed = true
	
	# --- TEST CASE 2: Nemesis Flyer (Generic EnemyUnit with Flying Behavior) ---
	print(LOG_PREFIX, "--- TEST CASE 2: Nemesis Flyer (Generic Unit) ---")
	
	# Reset combat triggered state for the new test
	state.combat_triggered = false
	
	# Load necessary data classes
	var EnemyData = load("res://scripts/resources/EnemyData.gd")
	var WeaponData = load("res://scripts/resources/WeaponData.gd")

	# Create Generic EnemyUnit
	var nemesis = load("res://scripts/entities/enemies/FlyingEnemy.gd").new()
	nemesis.name = "NemesisFlyer"
	_track(nemesis)
	
	# 1. Create Data via Factory (Integration Test)
	var EnemyFactory = load("res://scripts/factories/EnemyFactory.gd")
	var data = EnemyFactory.create_enemy_data("Flying") 
	# "Flying" archetype in Factory now has Bolt (Range 6)
	
	data.display_name = "Nemesis Flyer"
	# Behavior 7 (FLYING) is set by Factory
	
	nemesis.initialize_from_data(data)
	nemesis.position = Vector3(0, 8, 0) # Elevated
	nemesis.grid_pos = Vector2(0, 0)
	nemesis.current_ap = 2 # Ensure it has AP to act
	
	# Register unit on the grid (assuming grid_data can hold units directly or needs a wrapper)
	# This line might need adjustment based on actual GridManager implementation
	# For now, assuming it's just for tracking units on tiles.
	gm.grid_data[Vector2(0,0)]["unit"] = nemesis
	gm.grid_data[Vector2(0,0)]["is_walkable"] = false # Unit occupies tile
	
	# Run Logic
	print(LOG_PREFIX, "Nemesis Deciding Action...")
	await get_tree().process_frame
	nemesis.decide_action([target], gm) # Use gm instead of grid_manager
	
	# Wait for result
	await get_tree().create_timer(1.5).timeout
	
	# Check
	if sb and state.combat_triggered:
		print(LOG_PREFIX, "SUCCESS: Nemesis attacked.")
	else:
		print(LOG_PREFIX, "FAILURE: Nemesis did NOT attack.")
		test_failed = true

	# Final Report
	if test_failed:
		print(LOG_PREFIX, "ALL TESTS FAILED")
		_cleanup_and_quit(1)
	else:
		print(LOG_PREFIX, "ALL TESTS PASSED")
		_cleanup_and_quit(0)
