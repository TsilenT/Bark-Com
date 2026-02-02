extends Node

# verify_panic_states.gd

# Helper class for Mock Enemy
class MockEnemy extends Node3D:
	var faction = "Enemy"
	var current_hp = 10
	var grid_pos = Vector2(10, 10)
	var active_effects = [] # Matches Unit.gd
	func take_damage(amount): pass
	func take_damage_from(amount, src, type): pass

func _ready():
	print("TEST START: verify_panic_states")
	
	# Watchdog (Required for Strict Analysis)
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	# SETUP
	var CorgiUnitScript = load("res://scripts/entities/CorgiUnit.gd")
	var unit = CorgiUnitScript.new()
	unit.name = "PanicDog"
	# Ensure unit is clean
	add_child(unit)
	
	# Use REAL GridManager to satisfy type hints in CombatResolver
	var GridManagerScript = load("res://scripts/managers/GridManager.gd")
	var gm = GridManagerScript.new()
	gm.name = "GridManager"
	# Mock minimal grid data
	# Mock minimal grid data (Shifted to prevent negative ID collisions)
	# Unit at (10,10). Enemy at (20,20). Run tiles at (11,10), (10,11), (9,10), (9,9).
	gm.grid_data = {
		Vector2(10,10): {"is_walkable": true, "type": 0, "elevation": 0, "world_pos": Vector3(20,0,20)},
		Vector2(11,10): {"is_walkable": true, "type": 0, "elevation": 0, "world_pos": Vector3(22,0,20)},
		Vector2(10,11): {"is_walkable": true, "type": 0, "elevation": 0, "world_pos": Vector3(20,0,22)},
		Vector2(9,10):  {"is_walkable": true, "type": 0, "elevation": 0, "world_pos": Vector3(18,0,20)},
		Vector2(9,9):   {"is_walkable": true, "type": 0, "elevation": 0, "world_pos": Vector3(18,0,18)},
		Vector2(20,20): {"is_walkable": true, "type": 0, "elevation": 0, "world_pos": Vector3(40,0,40)}
	}
	# We also need to mock astar setup if movement logic is called, but panic run calls _panic_run which uses get_random_valid_position which uses grid_data keys.
	gm._setup_astar()
	add_child(gm)
	
	# Unit needs to be in scene for StateMachine 
	
	# 1. VERIFY FREEZE
	print("DEBUG: Testing FREEZE state...")
	unit.state_machine.transition_to("Panic", {"type": "FREEZE"})
	
	# Verification 1: AP should be 0
	if unit.current_ap != 0:
		print("ERROR: Unit AP not drained in Freeze! AP=", unit.current_ap)
	else:
		print("DEBUG: Unit AP drained correctly.")

	# Verification 2: Check for FrozenEffect
	var has_frozen = false
	if "active_effects" in unit:
		for eff in unit.active_effects:
			if eff.display_name == "Frozen":
				has_frozen = true
				break
	
	if has_frozen:
		print("DEBUG: FrozenEffect found on unit.")
	else:
		print("ERROR: FrozenEffect NOT found on unit!")

	# 2. VERIFY RUN (Fleeing)
	print("DEBUG: Testing RUN (Fleeing) state...")
	# We need an enemy for this to work logic-wise, or it reverts to Idle.
	# Let's add a dummy enemy.
	var enemy = MockEnemy.new()
	enemy.name = "BadGuy"
	add_child(enemy)
	enemy.add_to_group("Units")
	enemy.grid_pos = Vector2(20, 20)
	
	unit.grid_pos = Vector2(10,10)
	unit.mobility = 4
	
	unit.state_machine.transition_to("Panic", {"type": "RUN"})
	
	# Verification 3: Check for Fleeing Effect
	var has_flee = false
	if "active_effects" in unit:
		for eff in unit.active_effects:
			if eff.display_name == "Fleeing":
				has_flee = true
				break
				
	if has_flee:
		print("DEBUG: Fleeing Effect found on unit.")
	else:
		print("ERROR: Fleeing Effect NOT found on unit!")

	
	# 3. VERIFY BERSERK
	print("DEBUG: Testing BERSERK state...")
	unit.state_machine.transition_to("Panic", {"type": "BERSERK"})
	
	# Verification 4: Check for Berserk Effect
	var has_berserk = false
	if "active_effects" in unit:
		for eff in unit.active_effects:
			if eff.display_name == "Berserk":
				has_berserk = true
				break
				
	if has_berserk:
		print("DEBUG: Berserk Effect found on unit.")
	else:
		print("ERROR: Berserk Effect NOT found on unit!")

	# 4. VERIFY EXCLUSIVITY (Freeze -> Berserk -> Check Frozen is GONE)
	# Logic: If we were Frozen, then switched to Berserk, Frozen should be removed.
	# Currently we just transitioned Idle -> Freeze -> Idle -> Run -> Idle -> Berserk because implementation resets to Idle.
	# Let's force a transition FREEZE -> BERSERK directly without Idle.
	print("DEBUG: Testing EXCLUSIVITY (Freeze -> Berserk)...")
	unit.state_machine.transition_to("Panic", {"type": "FREEZE"})
	# Now overload with Berserk
	unit.state_machine.transition_to("Panic", {"type": "BERSERK"})
	
	var frozen_lingers = false
	for eff in unit.active_effects:
		if eff.display_name == "Frozen":
			frozen_lingers = true
			break
	
	if frozen_lingers:
		print("ERROR: Frozen effect lingered after switching to Berserk!")
	else:
		print("DEBUG: Frozen effect correctly removed.")


	# 5. VERIFY EXPIRATION
	# Berserk duration is 1 turn.
	# Simulate end of turn / start of next turn.
	# Unit.gd: on_turn_start calls process_turn_start_effects(gm)
	print("DEBUG: Testing EXPIRATION...")
	
	# We are currently in Berserk (from step 4).
	# Call on_turn_start to process effects.
	if unit.has_method("process_turn_start_effects"):
		# Mocking turn passage. Usually duration decrements on turn start.
		# Berserk Duration=1. Start -> Apply(1). Next Turn -> Decrement(0) -> Remove.
		unit.on_turn_start([], gm) 
	
	var berserk_lingers = false
	for eff in unit.active_effects:
		if eff.display_name == "Berserk":
			berserk_lingers = true
			break
			
	if berserk_lingers:
		print("ERROR: Berserk effect DID NOT expire!")
	else:
		print("DEBUG: Berserk effect expired correctly.")

	print("TEST COMPLETE")
	
	if has_frozen and has_flee and has_berserk and not frozen_lingers and not berserk_lingers:
		print("TEST PASSED")
		
		# Cleanup to prevent leaks
		# 1. Clear Unit References to break potential cycles
		if is_instance_valid(unit):
			unit.active_effects.clear()
			unit.abilities.clear()
			unit.inventory.clear()
			if unit.state_machine:
				unit.state_machine.queue_free()
		
		# 2. Clear Global Caches/Refs
		var global_gm = get_node_or_null("/root/GameManager")
		if global_gm and global_gm.audio_manager:
			# Mock cleanup mimicking test_base_scene_promotion
			if global_gm.audio_manager.has_method("stop_all"):
				global_gm.audio_manager.stop_all()
			global_gm.audio_manager.queue_free()
			global_gm.audio_manager = null
			
			# Clear Persistent Lists which might hold Resources
			global_gm.roster.clear()
			global_gm.inventory.clear()
			global_gm.shop_stock.clear()
			global_gm.active_mission = null
			
			if global_gm.name_gen and is_instance_valid(global_gm.name_gen):
				global_gm.name_gen.queue_free()
				global_gm.name_gen = null
			
			var nm = global_gm.get_node_or_null("NemesisManager")
			if nm: nm.queue_free()
			
		var btm = get_node_or_null("/root/BarkTreeManager")
		if btm and btm.has_method("reset_state"):
			btm.reset_state()
			
		if ClassData:
			# If ClassData is static or holds anything... likely fine. 
			pass
			
		# ClassIconManager cache clear if available
		var cim = get_node_or_null("/root/ClassIconManager")
		if cim and cim.has_method("clear_cache"):
			cim.clear_cache()
		
		for child in get_children():
			child.queue_free()
		
		# Flush deletion queue
		for i in range(10):
			await get_tree().process_frame
			
		get_tree().quit(0)
	else:
		print("TEST FAILED: Missing visual status effects or cleanup failure.")
		get_tree().quit(1)
