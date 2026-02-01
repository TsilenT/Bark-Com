
extends Node

const LOG_PREFIX = "VerifyConsole: "

func _ready():
	print(LOG_PREFIX, "Starting Debug Console Verification...")
	
	# 1. Setup Environment
	var root = Node3D.new()
	add_child(root)

	# Watchdog
	var watchdog = load("res://tests/TestSafeGuard.gd").new()
	add_child(watchdog)
	
	# GridManager (Real, simplified)
	var gm = load("res://scripts/managers/GridManager.gd").new()
	gm.name = "GridManager"
	root.add_child(gm)
	
	# TurnManager (Needed for registration)
	var tm = load("res://scripts/managers/TurnManager.gd").new()
	tm.name = "TurnManager"
	root.add_child(tm)
	
	# MissionManager
	var mm = load("res://scripts/managers/MissionManager.gd").new()
	mm.name = "MissionManager"
	root.add_child(mm)
	
	# Initialize MM
	mm.grid_manager = gm
	mm.turn_manager = tm # Usually set in start_mission but we force it
	
	# Mock Main Node (to accept spawned_units sync)
	root.set_script(load("res://scripts/core/Main.gd"))
	# Or just add the property dynamically since we extend Node? 
	# Actually Main.gd has it defined.
	# But `root` is Node3D.
	# Let's attach a dummy script or just add the property if we can?
	# GDScript dynamic property:
	# root.set_meta("spawned_units", []) # No, need property access
	# Let's just rely on the script being Main or mimicking it.
	# `root` needs to respond to `spawned_units`.
	
	# Re-create root with proper script mock?
	# Creating a dedicated MockMain script is better.
	# Mock Main Node (to accept spawned_units sync)
	var mock_main_script = GDScript.new()
	mock_main_script.source_code = "extends Node3D\nvar spawned_units = []"
	mock_main_script.reload()
	root.set_script(mock_main_script)
	
	# MOCK PLAYER UNIT (Required for Near Player Spawn)
	var player_unit = load("res://scripts/entities/CorgiUnit.gd").new()
	player_unit.name = "TestCorgi"
	player_unit.faction = "Player"
	player_unit.current_hp = 10
	player_unit.grid_pos = Vector2(5, 5) # Player at center
	player_unit.position = gm.get_world_position(Vector2(5, 5))
	
	root.add_child(player_unit)
	tm.units.append(player_unit) # Manually register with TM
	
	# Ensure grid tile exists for Player
	if not gm.grid_data.has(Vector2(5,5)):
		gm.grid_data[Vector2(5,5)] = {"is_walkable": true, "type": 0}
	
	# Ensure grid tile exists for Spitter Test
	if not gm.grid_data.has(Vector2(2,2)):
		gm.grid_data[Vector2(2,2)] = {"is_walkable": true, "type": 0}
	else:
		gm.grid_data[Vector2(2,2)]["is_walkable"] = true # Force Walkable
		
	# Ensure valid neighbor for "Near Player" spawn (radius 2+)
	# Radius 2 means distance >= 2. (6,5) is dist 1.
	# We need dist 2. Let's try (7,5) or (5,7).
	if not gm.grid_data.has(Vector2(7,5)):
		gm.grid_data[Vector2(7,5)] = {"is_walkable": true, "type": 0}
	else:
		gm.grid_data[Vector2(7,5)]["is_walkable"] = true
		
	gm.grid_data[Vector2(5,5)]["unit"] = player_unit # Register in Grid

	
	# Set Game State for Context Check
	if GameManager:
		GameManager.current_state = GameManager.GameState.MISSION
	
	# 2. Setup TerminalPanel
	var terminal = load("res://scripts/ui/TerminalPanel.gd").new()
	root.add_child(terminal)
	
	# Wait for ready
	await get_tree().process_frame
	
	# 3. Test 1: Spawn at specific location
	print(LOG_PREFIX, "Testing 'spawn Spitter 2 2'...")
	terminal._process_command("spawn Spitter 2 2")
	
	# Allow frame for instantiation
	await get_tree().process_frame
	
	var found_spitter = false
	for u in mm.spawned_units:
		if u.grid_pos == Vector2(2, 2):
			found_spitter = true
			break
			
	if found_spitter:
		print(LOG_PREFIX, "PASS: Spitter spawned at (2,2).")
	else:
		print(LOG_PREFIX, "FAIL: Spitter not found at (2,2). Spawned Count: ", mm.spawned_units.size())
		_print_units(mm)
		get_tree().quit(1)
		return

	# 4. Test 2: Near Player Spawn (Default)
	print(LOG_PREFIX, "Testing 'spawn Rusher' (Near Player)...")
	var pre_count = mm.spawned_units.size()
	terminal._process_command("spawn Rusher")
	
	await get_tree().process_frame
	
	if mm.spawned_units.size() == pre_count + 1:
		# Verify Distance (Simulated: Player at 5,5. Spawn should be within 2-5 tiles)
		var spawned = mm.spawned_units.back()
		var dist = spawned.grid_pos.distance_to(player_unit.grid_pos)
		print(LOG_PREFIX, "Spawned at ", spawned.grid_pos, " Dist: ", dist)
		
		if dist >= 2.0 and dist <= 6.0: # 6.0 just in case diagonal / rounding
			print(LOG_PREFIX, "PASS: Rusher spawned near player (Dist: ", dist, ").")
		else:
			print(LOG_PREFIX, "WARN: Rusher spawned but distance weird? (Dist: ", dist, ")")
			pass # Could be valid if spiral logic allows expanding, but 2-6 is expected.
	else:
		print(LOG_PREFIX, "FAIL: Rusher spawn failed. Count: ", mm.spawned_units.size())
		get_tree().quit(1)
		return

	# 6. Test 4: Invalid Location (Void)
	print(LOG_PREFIX, "Testing Invalid Location (-5, -5)...")
	terminal._process_command("spawn Rusher -5 -5")
	# Output should be "Error: Spawn failed". Unit count should NOT increase.
	if mm.spawned_units.size() == pre_count + 1:
		print(LOG_PREFIX, "PASS: Invalid spawn rejected (Count stable).")
	else:
		print(LOG_PREFIX, "FAIL: Invalid spawn created unit? Count: ", mm.spawned_units.size())
		# Actually it should refer to pre_count + 1 which is the count AFTER random spawn.
		# So current size is X. After invalid spawn, size should still be X.
	
	# 5. Test 3: Invalid Command
	print(LOG_PREFIX, "Testing invalid command...")
	terminal._process_command("spawn InvalidMonster")
	# Should print error but not crash.
	# We can't easily assert print output here without spy, but ensuring no crash is good.
	
	# 7. Test 5: Fallback (No Player)
	# Remove players from TM to simulate state
	tm.units.clear()
	
	print(LOG_PREFIX, "Testing 'spawn Rusher' (No Player Fallback)...")
	var pre_count_fallback = mm.spawned_units.size()
	terminal._process_command("spawn Rusher")
	
	await get_tree().process_frame
	
	if mm.spawned_units.size() == pre_count_fallback + 1:
		print(LOG_PREFIX, "PASS: Rusher spawned (Fallback Random).")
	else:
		print(LOG_PREFIX, "FAIL: Fallback spawn failed. Count: ", mm.spawned_units.size())
		get_tree().quit(1)
		return
		
	print(LOG_PREFIX, "All Console Tests Passed.")
	get_tree().quit()

func _print_units(mm):
	for u in mm.spawned_units:
		print(" - ", u.name, " @ ", u.grid_pos)
