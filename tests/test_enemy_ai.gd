extends Node

# --- TEST: Enemy AI Logic ---
# Verifies: Target Selection, Movement Scoring, Attack Logic
# Dependencies: EnemyUnit.gd, GridManager.gd, CombatResolver.gd

var grid_manager
var enemy_unit
var player_unit
var mock_tm

class MockTurnManager extends Node:
	var current_turn = 1 
	var units = []
	func check_auto_end_turn(): pass
	func handle_reaction_fire(unit, from_pos): pass

class MockGridVisualizer extends Node:
	func clear_debug_scores(): pass
	func debug_score_tiles(u, tiles): pass
	func show_debug_score(pos, score): pass
	func draw_ai_intent(start, end, color): pass
	func visualize_path(path): pass

class MockVisionManager extends Node:
	func check_visibility(a, b): return true
	func update_vision(units=[]): pass

class MockPlayerUnit extends Node3D:
	var grid_pos = Vector2(0,0)
	var faction = "Player"
	var current_hp = 10
	var max_hp = 10
	# var position is inherited from Node3D
	var is_dead = false
	var modifiers = {}
	var accuracy = 65
	var defense = 10
	var armor = 0
	
	func get_type(): return "Unit"
	
	func take_damage_from(amount, _source, _type):
		current_hp -= amount
		
	func has_perk(p): return false
	
	func get_data_snapshot():
		return {
			"hp": current_hp,
			"pos": grid_pos
		}
	
func _exit_tree():
	if is_instance_valid(grid_manager): grid_manager.free()
	if is_instance_valid(mock_tm): mock_tm.free()
	if is_instance_valid(get_node_or_null("GridVisualizer")): get_node("GridVisualizer").free()
	if is_instance_valid(get_node_or_null("VisionManager")): get_node("VisionManager").free()

func _ready():
	print("--- TEST START: Enemy AI ---")
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	setup_env()
	
	# Async Execution
	run_tests()

func setup_env():
	# 1. Grid Manager
	grid_manager = load("res://scripts/managers/GridManager.gd").new()
	add_child(grid_manager)
	
	# Setup simple 10x10 open grid
	for x in range(10):
		for y in range(10):
			var tile = Vector2(x,y)
			grid_manager.grid_data[tile] = {
				"type": 0, "is_walkable": true, "world_pos": Vector3(x, 0, y)
			}

	# 2. TurnManager (Group)
	mock_tm = MockTurnManager.new()
	mock_tm.add_to_group("TurnManager")
	mock_tm.add_to_group("TurnManager")
	add_child(mock_tm)
	
	# 3. Visualizer (Mock)
	var gv = MockGridVisualizer.new()
	gv.name = "GridVisualizer"
	add_child(gv)
	
	# 4. VisionManager (Mock)
	var vm = MockVisionManager.new()
	vm.name = "VisionManager"
	add_child(vm)
	
	# Setup AStar (Critical!)
	grid_manager._setup_astar()

func run_tests():
	await test_movement_towards_enemy()
	await test_attack_in_range()
	await test_rusher_behavior()
	await test_sniper_behavior()
	await test_exploder_behavior()
	
	if failures > 0:
		print("❌ FAILED: ", failures, " tests failed.")
		await TestUtils.finalize_and_quit(get_tree(), 1)
	else:
		print("✅ ALL AI TESTS PASSED")
		await TestUtils.finalize_and_quit(get_tree(), 0)

var failures = 0
func fail(msg):
	print("❌ " + msg)
	failures += 1
	
func pass_test(msg):
	print("✅ " + msg)

func test_movement_towards_enemy():
	print("\nTest: Movement Towards Enemy (Generic)...")
	
	# Setup
	var enemy = load("res://scripts/entities/EnemyUnit.gd").new()
	enemy.name = "AI_Generic"
	add_child(enemy)
	enemy.initialize(Vector2(0,0))
	enemy.mobility = 4
	enemy.attack_range = 1 # Melee
	enemy.current_ap = 2 
	
	mock_tm.units.append(enemy)
	
	var target = MockPlayerUnit.new()
	target.grid_pos = Vector2(8,0) # Far away
	target.position = Vector3(8,0,0)
	target.name = "TargetDummy"
	add_child(target)
	mock_tm.units.append(target)
	
	# Execute
	if enemy.grid_pos != Vector2(0,0):
		fail("Enemy not at start.")
		return
	
	print("Running decide_action...")
	await enemy.decide_action([target, enemy], grid_manager)
	
	# Check Result
	print("Enemy End Pos: ", enemy.grid_pos)
	
	if enemy.grid_pos.x > 0:
		pass_test("Enemy moved towards target.")
	else:
		fail("Enemy did not move. Pos: " + str(enemy.grid_pos))
		
	TestUtils.free_node(enemy)
	TestUtils.free_node(target)

func test_attack_in_range():
	print("\nTest: Attack In Range...")
	
	var enemy = load("res://scripts/entities/EnemyUnit.gd").new()
	enemy.name = "AI_Shooter"
	add_child(enemy)
	enemy.initialize(Vector2(5,5))
	enemy.accuracy = 200 # Force 100% hit chance for test stability
	enemy.attack_range = 4
	enemy.current_ap = 10 # Ensure AP for move + shoot
	mock_tm.units.append(enemy)
	
	var target = MockPlayerUnit.new()
	target.grid_pos = Vector2(5,9) # Distance 4 (Ideal)
	target.position = Vector3(5,0,9)
	target.name = "Victim"
	add_child(target)
	mock_tm.units.append(target)
	
	# Spy on Combat?
	# CombatResolver.execute_attack -> writes to target.current_hp
	var start_hp = target.current_hp
	
	await enemy.decide_action([target, enemy], grid_manager)
	
	if target.current_hp < start_hp:
		pass_test("Enemy attacked target (HP Dropped: " + str(start_hp) + " -> " + str(target.current_hp) + ")")
	else:
		fail("Enemy did not damage target.")

	TestUtils.free_node(enemy)
	TestUtils.free_node(target)

func test_rusher_behavior():
	print("\nTest: Rusher Behavior (Aggression)...")
	# Rushers should prefer getting ADJACENT (Dist 1.0) over just getting in range (Dist 1.5+)
	
	var enemy = load("res://scripts/entities/EnemyUnit.gd").new()
	add_child(enemy)
	enemy.initialize(Vector2(0,0))
	enemy.mobility = 5
	# Load Rusher Behavior manually
	enemy._load_behavior(0) # RUSHER
	
	var target = MockPlayerUnit.new()
	target.grid_pos = Vector2(5,0)
	target.position = Vector3(5,0,0)
	add_child(target)
	
	# Evaluate Tile scores manually to verify logic
	var gm = grid_manager
	var beh = enemy.behavior_resource
	
	# Tile (4,0) is Adjacent (Dist 1). Tile (3,0) is Dist 2.
	var score_adj = beh.evaluate_position(enemy, Vector2(4,0), target, gm)
	var score_near = beh.evaluate_position(enemy, Vector2(3,0), target, gm)
	
	print("Score Adjacent (4,0): ", score_adj)
	print("Score Near (3,0): ", score_near)
	
	if score_adj > score_near:
		pass_test("Rusher prefers adjacency.")
	else:
		fail("Rusher failed to classify adjacency as better.")
		
	TestUtils.free_node(enemy)
	TestUtils.free_node(target)

func test_sniper_behavior():
	print("\nTest: Sniper Behavior (Range Preference)...")
	
	var enemy = load("res://scripts/entities/EnemyUnit.gd").new()
	add_child(enemy)
	enemy.initialize(Vector2(0,0))
	enemy._load_behavior(1) # SNIPER
	
	var target = MockPlayerUnit.new()
	target.grid_pos = Vector2(15,0) # Far away
	target.position = Vector3(15,0,0)
	add_child(target)
	
	var beh = enemy.behavior_resource
	var gm = grid_manager # No cover in this mock grid, so purely distance check
	
	# Range 8-12 is ideal.
	# Tile (5,0) -> Dist 10 (Ideal)
	# Tile (10,0) -> Dist 5 (Too close)
	# Tile (0,0) -> Dist 15 (Too far)
	
	var score_ideal = beh.evaluate_position(enemy, Vector2(5,0), target, gm)
	var score_close = beh.evaluate_position(enemy, Vector2(10,0), target, gm)
	
	print("Score Ideal Dist 10: ", score_ideal)
	print("Score Close Dist 5: ", score_close)
	
	if score_ideal > score_close:
		pass_test("Sniper prefers ideal range.")
	else:
		fail("Sniper logic failed range preference.")
		
	TestUtils.free_node(enemy)
	TestUtils.free_node(target)

func test_exploder_behavior():
	print("\nTest: Exploder Behavior (Suicide Rush)...")
	
	var enemy = load("res://scripts/entities/enemies/ExploderEnemy.gd").new()
	add_child(enemy)
	enemy.initialize(Vector2(0,0))
	enemy.mobility = 10
	
	var target = MockPlayerUnit.new()
	target.grid_pos = Vector2(8,0)
	target.position = Vector3(8,0,0)
	add_child(target)
	
	# Verify Behavior Loaded
	if not enemy.behavior_resource:
		fail("Exploder did not load behavior on init.")
	
	var beh = enemy.behavior_resource
	var gm = grid_manager
	
	# Tile (7,0) -> Dist 1. Should be HUGE score.
	# Tile (6,0) -> Dist 2. Should be much lower.
	
	var score_suicide = beh.evaluate_position(enemy, Vector2(7,0), target, gm)
	var score_approach = beh.evaluate_position(enemy, Vector2(6,0), target, gm)
	
	print("Score Suicide (Dist 1): ", score_suicide)
	print("Score Approach (Dist 2): ", score_approach)
	
	if score_suicide > (score_approach + 100):
		pass_test("Exploder massively prefers suicide range.")
	else:
		fail("Exploder not suicidal enough.")

	TestUtils.free_node(enemy)
	TestUtils.free_node(target)
