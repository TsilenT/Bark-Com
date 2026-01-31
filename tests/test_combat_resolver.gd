extends Node

# Usage: Run via tests/test_combat_runner.tscn

var CombatResolver

# Mocks
class CombatMockGridManager extends "res://scripts/managers/GridManager.gd":
	func get_grid_coord(pos): return Vector2(round(pos.x/2), round(pos.z/2))
	func get_tile_data(pos): return {} # Default no elevation
	func is_tile_cover(pos): return false
	



class MockUnit extends Node3D:
	var unit_name = "MockUnit"
	var grid_pos = Vector2.ZERO
	var accuracy = 65
	var defense = 0
	var faction = "Player"
	var primary_weapon = null
	var modifiers = {}
	
	func get_active_bond_bonuses(): return {}

	
class MockWeapon:
	var weapon_range = 5 # Default optimal
	var damage = 3
	var display_name = "Rifle"

func _ready():
	print("--- STARTING COMBAT RESOLVER TESTS ---")
	add_child(load("res://tests/TestSafeGuard.gd").new())
	await get_tree().process_frame
	
	CombatResolver = load("res://scripts/managers/CombatResolver.gd")
	if not CombatResolver:
		print("ERROR: Could not load CombatResolver!")
		await TestUtils.finalize_and_quit(get_tree(), 1)
		return

	test_base_hit_chance()
	test_range_falloff()
	test_min_hit_chance()
	test_max_hit_chance()
	test_null_target()
	
	print("--- ALL TESTS PASSED ---")
	await TestUtils.finalize_and_quit(get_tree(), 0)

func assert_eq(actual, expected, context):
	if actual != expected:
		print("FAIL [", context, "]: Expected ", expected, " but got ", actual)
		await TestUtils.finalize_and_quit(get_tree(), 1)
	else:
		print("PASS [", context, "]")

func test_base_hit_chance():
	var gm = CombatMockGridManager.new()
	var attacker = MockUnit.new()
	var target = MockUnit.new()
	target.faction = "Enemy"
	target.grid_pos = Vector2(1, 0) # Adjacent (Dist 1)
	
	# Base 65, Def 0, Dist 1 (<= 5 optimal) -> 65%
	var result = CombatResolver.calculate_hit_chance(attacker, target, gm)
	assert_eq(int(result["hit_chance"]), 65, "Base Hit Chance (Close Range)")
	TestUtils.free_node(gm)
	TestUtils.free_node(attacker)
	TestUtils.free_node(target)

func test_range_falloff():
	var gm = CombatMockGridManager.new()
	var attacker = MockUnit.new()
	var target = MockUnit.new()
	target.faction = "Enemy"
	
	# Optimal Range = 5
	attacker.primary_weapon = MockWeapon.new()
	attacker.primary_weapon.weapon_range = 5
	
	# Target at Distance 7 (2 tiles over)
	# Penalty: 2 * 5% = 10%
	target.grid_pos = Vector2(7, 0)
	
	var result = CombatResolver.calculate_hit_chance(attacker, target, gm)
	var expected = 65 - 10
	assert_eq(int(result["hit_chance"]), expected, "Range Falloff (7 tiles)")
	TestUtils.free_node(gm)
	TestUtils.free_node(attacker)
	TestUtils.free_node(target)

func test_min_hit_chance():
	var gm = CombatMockGridManager.new()
	var attacker = MockUnit.new()
	var target = MockUnit.new()
	target.faction = "Enemy"
	
	# Optimal Range 5
	attacker.primary_weapon = MockWeapon.new()
	
	# Distance 50 (45 tiles over -> -225% penalty)
	target.grid_pos = Vector2(50, 0)
	
	var result = CombatResolver.calculate_hit_chance(attacker, target, gm)
	assert_eq(int(result["hit_chance"]), 0, "Minimum Hit Chance Clamp (0%)")
	TestUtils.free_node(gm)
	TestUtils.free_node(attacker)
	TestUtils.free_node(target)

func test_max_hit_chance():
	var gm = CombatMockGridManager.new()
	var attacker = MockUnit.new()
	attacker.accuracy = 200 # God mode
	var target = MockUnit.new()
	target.faction = "Enemy"
	target.grid_pos = Vector2(1, 0)
	
	var result = CombatResolver.calculate_hit_chance(attacker, target, gm)
	assert_eq(int(result["hit_chance"]), 100, "Maximum Hit Chance Clamp (100%)")
	TestUtils.free_node(gm)
	TestUtils.free_node(attacker)
	TestUtils.free_node(target)
	
func test_null_target():
	var gm = CombatMockGridManager.new()
	var attacker = MockUnit.new()
	
	# Pass null as target
	var result = CombatResolver.calculate_hit_chance(attacker, null, gm)
	
	assert_eq(int(result["hit_chance"]), 0, "Null Target Safety (Hit Chance)")
	assert_eq(result["breakdown"], "No Target", "Null Target Safety (Breakdown)")
	TestUtils.free_node(gm)
	TestUtils.free_node(attacker)
