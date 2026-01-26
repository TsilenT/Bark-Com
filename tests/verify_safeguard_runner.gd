extends Node3D

# verify_safeguard_runner.gd
# Validates Friendy Fire Safeguard (Objectives should be Invalid Targets for StandardAttack)

const StandardAttack = preload("res://scripts/abilities/StandardAttack.gd")
const GridManager = preload("res://scripts/managers/GridManager.gd")
const Unit = preload("res://scripts/entities/Unit.gd") 
# We need a proper Unit class or Mock

func _ready():
	add_child(load("res://tests/TestSafeGuard.gd").new())
	print("--- Starting Safeguard Verification ---")
	
	# 1. Setup Mock GM
	var gm = GridManager.new()
	gm.name = "GridManager"
	gm.add_to_group("GridManager") # Unit searches for this group
	add_child(gm)
	
	# Mock data
	gm.grid_data = {
		Vector2(0,0): {"type": 0, "is_walkable": true, "elevation": 0},
		Vector2(1,0): {"type": 0, "is_walkable": true, "elevation": 0},
		Vector2(2,0): {"type": 0, "is_walkable": true, "elevation": 0}
	}
	gm._setup_astar()
	
	# 2. Setup Player Unit
	var player = Unit.new()
	player.name = "PlayerUnit"
	add_child(player)
	player.initialize(Vector2(0,0))
	# player.grid_manager = gm # Removed
	player.faction = "Player"
	
	# 3. Setup Objective Unit (LootCrate / Hydrant)
	# Objectives are usually in group "Objectives" or "Interactive" (and Faction Neutral)
	var obj = Unit.new() # Using Unit as base for simplicity, or Mock
	obj.name = "Objective"
	obj.add_to_group("Objectives") # The critical group
	obj.faction = "Neutral"
	add_child(obj)
	obj.initialize(Vector2(1,0))
	# obj.grid_manager = gm
	
	# 4. Setup Ability
	var ability = StandardAttack.new()
	
	# CHECK: Is (1,0) a valid target?
	# StandardAttack.get_valid_tiles should EXCLUDE (1,0) because it contains an Objective.
	
	var valid_tiles = ability.get_valid_tiles(gm, player)
	print("Valid Tiles: ", valid_tiles)
	
	if valid_tiles.has(Vector2(1,0)):
		print("FAIL: Objective at (1,0) was included as a valid target!")
		get_tree().quit(1)
		return
	else:
		print("PASS: Objective at (1,0) was EXCLUDED from valid targets.")
		
	# 5. Check Enemy (Control)
	var enemy = Unit.new()
	enemy.name = "Enemy"
	enemy.faction = "Enemy"
	add_child(enemy)
	enemy.initialize(Vector2(2,0))
	# enemy.grid_manager = gm
	
	valid_tiles = ability.get_valid_tiles(gm, player)
	if valid_tiles.has(Vector2(2,0)):
		print("PASS: Enemy at (2,0) IS a valid target.")
	else:
		print("FAIL: Enemy at (2,0) was NOT valid?")
		get_tree().quit(1)
		return
		
	print("ALL SAFEGUARD TESTS PASSED")
	get_tree().quit()
