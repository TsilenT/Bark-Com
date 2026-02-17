extends Node

func _ready():
	print("--- Verifying Boss Behavior & Abilities ---")
	await get_tree().process_frame
	_run_test()

func _run_test():
	# 1. Setup Environment
	if GameManager:
		GameManager.TEST_MOCK_ENABLED = true
	else:
		print("ERROR: GameManager not found!")
		
	var gm = load("res://scripts/managers/GridManager.gd").new()
	gm.name = "GridManager"
	add_child(gm)
	
	# Add TestSafeGuard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	# Create 10x10 grid
	gm.width = 10
	gm.height = 10
	for x in range(10):
		for y in range(10):
			var pos = Vector2(x,y)
			gm.grid_data[pos] = { "type": 0, "is_walkable": true, "unit": null, "world_pos": Vector3(x * 2.0, 0, y * 2.0) }
			
	# Initialize AStar
	gm.setup_astar()
	
	# 2. Spawn Boss
	var EnemyFactory = load("res://scripts/factories/EnemyFactory.gd")
	var boss_data = EnemyFactory.create_enemy_data("Boss", self)
	
	var boss = load("res://scripts/entities/enemies/DogthulhuBoss.gd").new()
	boss.name = "Dogthulhu"
	add_child(boss)
	boss.initialize_from_data(boss_data)
	boss.grid_pos = Vector2(5, 5)
	
	# Register Boss
	gm.grid_data[boss.grid_pos]["unit"] = boss
	boss.faction = "Enemy"
	
	# 3. Spawn Target (Player) at Range 3
	var player = load("res://scripts/entities/Unit.gd").new()
	player.name = "TestPlayer"
	player.max_hp = 50
	player.current_hp = 50
	player.faction = "Player"
	add_child(player)
	player.grid_pos = Vector2(5, 2) # Distance 3
	gm.grid_data[player.grid_pos]["unit"] = player
	
	print("Boss initialized at ", boss.grid_pos)
	print("Player initialized at ", player.grid_pos)
	print("Boss Mobility: ", boss.mobility)
	print("Boss AP: ", boss.max_ap)
	
	# Verify Abilities Loaded
	print("Boss Abilities: ", boss.abilities.size())
	for a in boss.abilities:
		print("- ", a.display_name, " (Range: ", a.ability_range, ")")
		
	# 4. Simulate Turn (Range 3)
	print("\n--- TURN 1 (Range 3) ---")
	boss.current_ap = 4
	# We can't easily wait for async AI logic in a headless script without a proper runner loop or awaits.
	# We'll call `decide_action` manually and see what happens.
	# But `decide_action` has awaits.
	# We'll rely on prints.
	
	await boss.decide_action([boss, player], gm)
	
	# Check Result
	# At Range 3, we expect Tentacle Lash (Range 3) OR Move.
	# Lash pulls to Range 2.
	print("Boss AP Left: ", boss.current_ap)
	print("Player Pos After Turn 1: ", player.grid_pos)
	
	if player.grid_pos != Vector2(5, 2):
		print("SUCCESS: Player was moved (Lash Pulled?)")
	else:
		print("INFO: Player checked for pull.")
		
	# 5. Simulate Turn 2 (Range 2 or 3)
	# Force cooldowns if Lash was used?
	# Let's see if Boss moves to Melee (Range 1) if Lash is on CD.
	print("\n--- TURN 2 (Force Lash CD) ---")
	boss.current_ap = 4
	for a in boss.abilities:
		if a.display_name == "Tentacle Lash":
			a.current_cooldown = 1 
			
	await boss.decide_action([boss, player], gm)
	
	print("Boss Pos After Turn 2: ", boss.grid_pos)
	var dist = boss.grid_pos.distance_to(player.grid_pos)
	print("Distance to Player: ", dist)
	
	if dist <= 1.5:
		print("SUCCESS: Boss closed into Melee Range.")
	else:
		print("FAILURE: Boss did not close gap!")
		
	# 6. Simulate Turn 3 (Melee Range - Check Howl/Ankles)
	print("\n--- TURN 3 (Melee Range) ---")
	boss.current_ap = 4
	await boss.decide_action([boss, player], gm)
	
	get_tree().quit(0)
