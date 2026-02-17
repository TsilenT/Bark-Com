extends Node

var grid_manager_script = load("res://scripts/managers/GridManager.gd")
var mock_unit_script = load("res://tests/MockPlayerUnit.gd")
var volatile_cover_script
var explode_ability_script

var gm
var exploder
var tank
var barrel

func _ready():
	print("TEST: _ready started.")
	
	# Check Autoloads
	if get_node_or_null("/root/GameManager"):
		print("TEST: GameManager found.")
	else:
		print("TEST: GameManager NOT found! Mocking...")
		var m = Node.new()
		m.name = "GameManager"
		# Inject minimal constants
		var s = GDScript.new()
		s.source_code = "extends Node\nconst DMG_TYPE_EXPLOSION = 'Explosion'\nconst DMG_TYPE_GENERIC = 'Generic'"
		s.reload()
		m.set_script(s)
		get_root().call_deferred("add_child", m)
		
	if get_node_or_null("/root/SignalBus"):
		print("TEST: SignalBus found.")
	else:
		print("TEST: SignalBus NOT found! Mocking...")
		var m = Node.new()
		m.name = "SignalBus"
		var s = GDScript.new()
		s.source_code = "extends Node\nsignal on_request_vfx(a,b,c,d,e)\nsignal on_request_floating_text(a,b,c)\nsignal on_turn_changed(a,b)\nsignal on_cinematic_mode_changed(a)\nsignal on_request_camera_zoom(a,b,c)"
		s.reload()
		m.set_script(s)
		get_root().call_deferred("add_child", m)

	# Delayed setup to allow mocks to enter tree
	await get_tree().process_frame
	await get_tree().process_frame
	
	volatile_cover_script = load("res://scripts/entities/VolatileCover.gd")
	explode_ability_script = load("res://scripts/abilities/ExplodeAbility.gd")
	
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)
	
	setup()
	run_test()

func get_root():
	return get_tree().root


func setup():
	# 1. Setup GridManager
	gm = grid_manager_script.new()
	gm.name = "GridManager"
	add_child(gm)
	
	# Minimal Grid Data
	gm.grid_data.clear()
	for x in range(10):
		for y in range(10):
			gm.grid_data[Vector2(x, y)] = { "type": 0, "is_walkable": true, "elevation": 0 }
	gm.setup_astar()
	
	# 2. Setup Tank (Victim)
	tank = mock_unit_script.new()
	tank.name = "Tank"
	add_child(tank)
	
	# Inject Script with take_damage_from
	var tank_script = GDScript.new()
	tank_script.source_code = """
extends "res://tests/MockPlayerUnit.gd"
var armor = 2
var unit_name = "Tank"
var is_dead = false
func take_damage_from(amt, src=null, type=""):
	var dmg = amt - armor
	if dmg < 0: dmg = 0
	current_hp -= dmg
	print(unit_name, " took ", dmg, " damage (Raw: ", amt, ") from ", src.name if src else "Unknown")
	if current_hp <= 0:
		is_dead = true
"""
	tank_script.reload()
	tank.set_script(tank_script)
	
	# Set Stats AFTER script injection
	tank.max_hp = 12
	tank.current_hp = 12
	tank.armor = 2
	tank.unit_name = "Tank"
	tank.grid_pos = Vector2(5, 6) # Adjacent to Exploder
	tank.position = gm.get_world_position(tank.grid_pos)
	tank.add_to_group("Units")
	
	
	# 3. Setup Exploder (Attacker)
	exploder = mock_unit_script.new()
	exploder.name = "Exploder"
	add_child(exploder)
	
	# Inject Script
	var exploder_script = GDScript.new()
	exploder_script.source_code = """
extends "res://tests/MockPlayerUnit.gd"
var unit_name = "Exploder"
var is_dead = false
func take_damage_from(amt, src=null, type=""):
	current_hp -= amt
	print("Exploder took ", amt, " damage.")
	if current_hp <= 0: die()

func die():
	print("Exploder died.")
	is_dead = true
	queue_free()
"""
	exploder_script.reload()
	exploder.set_script(exploder_script)
	
	# Set Stats AFTER script injection
	exploder.max_hp = 6
	exploder.current_hp = 6
	exploder.unit_name = "Exploder"
	exploder.grid_pos = Vector2(5, 5) # Center
	exploder.position = gm.get_world_position(exploder.grid_pos)
	exploder.add_to_group("Units")
	
	# 4. Setup Volatile Barrel
	barrel = volatile_cover_script.new()
	barrel.name = "Barrel"
	barrel.grid_pos = Vector2(6, 5) # Adjacent to Exploder
	barrel.position = gm.get_world_position(barrel.grid_pos)
	barrel.grid_manager = gm # Essential for destroy()
	# VolatileCover adds itself to Destructible in _ready, assuming it runs
	add_child(barrel)
	
	# Ensure barrel is ready
	# barrel.initialize(barrel.grid_pos, gm) # VolatileCover doesn't override initialize fully without super call issues?
	# Let's rely on _ready.
	# We need to manually set stats if defaults aren't enough
	barrel.explosion_damage = 10
	barrel.explosion_range = 3
	barrel.max_hp = 5
	barrel.current_hp = 5

func run_test():
	print("TEST: Starting Exploder Damage Test...")
	
	# Scenario 1: Verify Stats
	print("TEST: Tank Stats - HP:", tank.current_hp, " Armor:", tank.armor)
	print("TEST: Exploder at ", exploder.grid_pos)
	print("TEST: Tank at ", tank.grid_pos)
	print("TEST: Barrel at ", barrel.grid_pos)
	
	# Execute Explosion
	var ability = explode_ability_script.new()
	print("TEST: Executing Explode Ability...")
	
	# Execute!
	ability.execute(exploder, null, Vector2.ZERO, gm)
	
	# Check Tank HP
	print("TEST: Tank HP after explosion: ", tank.current_hp)
	
	# Expected Math:
	# 1. Exploder hits Tank: 8 Dmg - 2 Armor = 6 Dmg. Tank HP: 6.
	# 2. Exploder hits Barrel: 8 Dmg. Barrel dies.
	# 3. Barrel Detonates (Chain Reaction).
	# 4. Barrel hits Tank: 10 Dmg - 2 Armor = 8 Dmg. Tank HP: -2.
	
	if tank.current_hp <= 0:
		print("SUCCESS: Tank died from Chain Reaction as expected.")
	else:
		print("FAILURE: Tank survived with ", tank.current_hp, " HP.")
		# If it failed, maybe chain reaction didn't happen or armor worked differently?
		
	_cleanup()
	get_tree().quit(0)

func _cleanup():
	if is_instance_valid(gm): gm.free()
	if is_instance_valid(tank): tank.free()
	if is_instance_valid(exploder): exploder.free()
	if is_instance_valid(barrel): barrel.free()
