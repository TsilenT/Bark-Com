extends Node

var ability_script = load("res://scripts/abilities/GoForAnklesAbility.gd")
var mock_unit_script = load("res://tests/MockPlayerUnit.gd")
var grid_manager_script = load("res://scripts/managers/GridManager.gd")

var user
var target
var gm
var ability

func _ready():
	print("TEST: _ready started.")
	
	# Mock Singletons if needed
	if not get_node_or_null("/root/GameManager"):
		var m = Node.new()
		m.name = "GameManager"
		var s = GDScript.new()
		s.source_code = "extends Node\nconst DMG_TYPE_MELEE = 'Melee'\nconst DMG_TYPE_GENERIC = 'Generic'"
		s.reload()
		m.set_script(s)
		get_root().call_deferred("add_child", m)
		
	if not get_node_or_null("/root/SignalBus"):
		var m = Node.new()
		m.name = "SignalBus"
		var s = GDScript.new()
		s.source_code = "extends Node\nsignal on_request_floating_text(a,b,c)\nsignal on_combat_action_finished(a)"
		s.reload()
		m.set_script(s)
		get_root().call_deferred("add_child", m)

	await get_tree().process_frame
	await get_tree().process_frame
	
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)
	
	setup()
	run_test()

func get_root():
	return get_tree().root

func setup():
	gm = grid_manager_script.new()
	gm.name = "GridManager"
	add_child(gm)
	
	# Setup User
	user = mock_unit_script.new()
	user.name = "Scout"
	add_child(user)
	
	# Inject Script for User
	var user_script = GDScript.new()
	user_script.source_code = """
extends "res://tests/MockPlayerUnit.gd"
var unit_name = "Scout"

class MockWeapon:
	var damage = 4

var primary_weapon = MockWeapon.new()

func spend_ap(amount):
	current_ap -= amount
"""
	user_script.reload()
	user.set_script(user_script)
	
	user.grid_pos = Vector2(5, 5)
	user.current_ap = 2
	user.add_to_group("Units")
	
	# Setup Target
	target = mock_unit_script.new()
	target.name = "Enemy"
	add_child(target)
	
	# Inject Target Script to handle effects
	var t_script = GDScript.new()
	t_script.source_code = """
extends "res://tests/MockPlayerUnit.gd"
var unit_name = "Enemy"
var effects = []
func take_damage_from(amt, src=null, type=""):
	current_hp -= amt
	print("Target took ", amt, " damage of type ", type)

func apply_effect(eff):
	effects.append(eff)
	print("Effect Applied: ", eff)
"""
	t_script.reload()
	target.set_script(t_script)
	
	target.unit_name = "Enemy"
	target.grid_pos = Vector2(6, 6) # Diagonal (dist ~1.41)
	target.max_hp = 10
	target.current_hp = 10
	target.add_to_group("Units")
	
	ability = ability_script.new()

func run_test():
	print("TEST: Starting GoForAnkles Verification...")
	
	# 1. Execute Ability
	var result = ability.execute(user, target, target.grid_pos, gm)
	print("TEST: Execute Result: ", result)
	
	# 2. Verify Damage
	if target.current_hp < 10:
		print("SUCCESS: Target took damage.")
	else:
		print("FAILURE: Target took NO damage.")
		
	# 3. Verify Effects
	if target.effects.size() >= 2:
		print("SUCCESS: Target has ", target.effects.size(), " effects (Expected 2+).")
	else:
		print("FAILURE: Target has ", target.effects.size(), " effects (Expected 2).")
		
	_cleanup()
	get_tree().quit(0)

func _cleanup():
	if is_instance_valid(gm): gm.free()
	if is_instance_valid(user): user.free()
	if is_instance_valid(target): target.free()
