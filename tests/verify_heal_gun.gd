extends Node

var main_node
var healer_unit
var patient_unit
var grid_manager
var std_attack

func _ready():
	print("--- TEST START: Syringe Gun Targeting Verify ---")
	# Watchdog
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	await test_syringe_targets_friendly()
	
	_cleanup()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)

func test_syringe_targets_friendly():
	# 1. Setup
	print("Context: Syringe Gun Friendly Targeting Test")
	
	main_node = load("res://scripts/core/Main.gd").new()
	main_node.is_test_mode = true
	add_child(main_node)
	
	grid_manager = GridManager.new()
	add_child(grid_manager)
	
	# Initializing Mock Components
	main_node.grid_manager = grid_manager
	main_node.turn_manager = Node.new() # Mock
	main_node.turn_manager.name = "TurnManager"
	main_node.turn_manager.set_script(load("res://scripts/managers/TurnManager.gd")) # Use real script if possible for units array
	main_node.turn_manager.units = []
	add_child(main_node.turn_manager)

	# 2. Spawn Healer (Player Faction)
	var healer_script = load("res://tests/MockHealerUnit.gd")
	healer_unit = healer_script.new()
	# healer_unit.set_script(healer_script) # Redundant
	healer_unit.name = "Healer"
	healer_unit.faction = "Player"
	healer_unit.grid_pos = Vector2(5, 5)

	healer_unit.current_ap = 2
	healer_unit.accuracy = 100 
	healer_unit.add_to_group("Units")
	
	# EQUIP SYRINGE GUN
	# Mock Weapon Resource
	var syringe = load("res://scripts/resources/WeaponData.gd").new()
	syringe.display_name = "Syringe Gun"
	syringe.damage = 4
	syringe.weapon_range = 5
	healer_unit.primary_weapon = syringe
	
	main_node.selected_unit = healer_unit
	main_node.turn_manager.units.append(healer_unit)
	main_node.add_child(healer_unit)
	
	# 3. Spawn Patient (Player Faction)
	patient_unit = healer_script.new()
	# patient_unit.set_script(healer_script) # Redundant
	patient_unit.name = "Patient"
	patient_unit.faction = "Player"
	patient_unit.max_hp = 10
	patient_unit.current_hp = 5 # Injured
	patient_unit.grid_pos = Vector2(5, 6) # Adjacent
	patient_unit.add_to_group("Units")
	
	main_node.turn_manager.units.append(patient_unit)
	main_node.add_child(patient_unit)

	# 4. Attempt Interaction (Attack/Heal)
	await get_tree().create_timer(0.1).timeout
	
	print("State: Healer Selected. Attempting click on Patient.")
	
	# Case A: Verify CombatResolver allows it (Unit Logic)
	var combat_res = load("res://scripts/managers/CombatResolver.gd").execute_attack(healer_unit, patient_unit, grid_manager)
	if combat_res != "HEAL":
		print("FAIL: CombatResolver returned ", combat_res, " instead of HEAL.")
	else:
		print("PASS: CombatResolver logic is correct.")
		
	# Case B: Verify Main.gd Input Logic (The Bug)
	
	# NEW: Verify StandardAttack.gd Logic (The Fix)
	std_attack = load("res://scripts/abilities/StandardAttack.gd").new()
	var valid_tiles = std_attack.get_valid_tiles(grid_manager, healer_unit)
	if valid_tiles.has(patient_unit.grid_pos):
		pass_test("StandardAttack valid_tiles INCLUDES patient (Fix Correct)")
	else:
		fail_test("StandardAttack valid_tiles EXCLUDES patient (Fix Failed)")

	# Force Targeting State
	main_node.current_input_state = main_node.InputState.TARGETING
	
	print("Triggering _process_combat via direct call simulation...")
	var hp_before = patient_unit.current_hp
	
	# We call _process_combat directly as if clicked
	main_node._process_combat(patient_unit)
	
	# 5. Assert
	if patient_unit.current_hp > hp_before:
		pass_test("Patient was healed! (HP " + str(hp_before) + " -> " + str(patient_unit.current_hp) + ")")
	else:
		fail_test("Patient was NOT healed. HP remained " + str(patient_unit.current_hp))
        
	# CLEANUP (Aggressive to prevent leaks)
	if is_instance_valid(healer_unit):
		healer_unit.primary_weapon = null
	
	if is_instance_valid(main_node) and main_node.turn_manager and is_instance_valid(main_node.turn_manager):
		main_node.turn_manager.units.clear()
	
	std_attack = null
	syringe = null

func _cleanup():
	# 1. Break Logic References
	if healer_unit and is_instance_valid(healer_unit):
		healer_unit.primary_weapon = null
		
	# 2. Clear Arrays holding references
	if main_node and is_instance_valid(main_node):
		if main_node.turn_manager and is_instance_valid(main_node.turn_manager):
			main_node.turn_manager.units.clear()
			
	# 3. Explicit Node Destruction (Immediate free)
	# Free Std Attack (Reference)
	if std_attack and std_attack is Object and not std_attack.is_queued_for_deletion():
		std_attack = null # Resources are RefCounted, nullify to free

	if healer_unit and is_instance_valid(healer_unit):
		healer_unit.free()
	if patient_unit and is_instance_valid(patient_unit):
		patient_unit.free()
		
	if grid_manager and is_instance_valid(grid_manager):
		if grid_manager.astar: grid_manager.astar.clear(); grid_manager.astar = null
		grid_manager.free()
		
	if main_node and is_instance_valid(main_node):
		# TurnManager is valid here?
		if main_node.turn_manager and is_instance_valid(main_node.turn_manager):
			main_node.turn_manager.free()
		main_node.free()

func pass_test(msg):
	print("PASS: " + msg)

func fail_test(msg):
	print("FAIL: " + msg)
	get_tree().quit(1)
