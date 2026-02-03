extends Node
class_name MissionManager

# Signals
signal wave_started(wave_index, wave_count)
signal wave_cleared(wave_index)
signal mission_completed(mission_data)
signal mission_failed(reason)

# Config
var active_mission_config: MissionConfig
var current_wave_index: int = 0
var spawned_units: Array = []
var grid_manager = null  # Reference to GridManager
var turn_manager = null  # Reference to TurnManager
var _mission_ended_flag: bool = false
const LOG_PREFIX = "MissionManager: "


func _ready():
	SignalBus.on_unit_died.connect(_on_unit_died)





# Enemies (Hardcoded Archetypes for now, could be Resources too)
const ENEMY_SCRIPTS = {
	"Rusher": "res://scripts/entities/EnemyUnit.gd",
	"Sniper": "res://scripts/entities/EnemyUnit.gd", 
	"Spitter": "res://scripts/entities/SpitterUnit.gd",
	"Whisperer": "res://scripts/entities/WhispererUnit.gd",
	"Exploder": "res://scripts/entities/enemies/ExploderEnemy.gd",
	"Tank": "res://scripts/entities/enemies/TankEnemy.gd",
	"Flying": "res://scripts/entities/enemies/FlyingEnemy.gd",
	"Infiltrator": "res://scripts/entities/enemies/InfiltratorEnemy.gd",
	"Boss": "res://scripts/entities/enemies/DogthulhuBoss.gd",
	"Nemesis": "res://scripts/entities/EnemyUnit.gd" # Placeholder
}
func generate_mission_config(level: int) -> MissionConfig:
	var generator = load("res://scripts/builders/MissionGenerator.gd").new()
	return generator.generate_mission_config(level)


func _create_wave(budget: int, allowed: Array) -> WaveDefinition:
	var w = WaveDefinition.new()
	w.budget_points = budget
	w.allowed_archetypes.assign(allowed) # Godot Array copy
	return w


func start_mission(config: MissionConfig, grid: GridManager):
	active_mission_config = config
	grid_manager = grid
	current_wave_index = 0
	spawned_units.clear()
	
	if grid_manager:
		turn_manager = grid_manager.get_node_or_null("../TurnManager")

	GameManager.log(LOG_PREFIX, "--- MISSION STARTED: ", config.mission_name, " ---")
	
	var spawner = load("res://scripts/builders/ObjectiveSpawner.gd").new()

	GameManager.log(LOG_PREFIX, "Objective Type is ", active_mission_config.objective_type)
	if active_mission_config.objective_type != 0:
		var count = spawner.spawn_objectives(active_mission_config.objective_type, active_mission_config.objective_target_count, active_mission_config, grid_manager)
		
		# Sync ObjectiveManager if counts differ (e.g. spawner failures)
		if count < active_mission_config.objective_target_count:
			GameManager.log(LOG_PREFIX, "Syncing ObjectiveManager to actual spawn count: ", count)
			var om = get_node_or_null("../ObjectiveManager")
			if om: om.target_count = count
			
	else:
		if randf() <= 0.1:
			spawner.spawn_loot(grid_manager)

	# Start First Wave
	start_next_wave()


func register_player_units(_player_units: Array):
	# Initialize TurnManager tracking
	if not SignalBus.on_turn_changed.is_connected(_on_turn_changed):
		SignalBus.on_turn_changed.connect(_on_turn_changed)
	if not SignalBus.on_unit_died.is_connected(_on_unit_died):
		SignalBus.on_unit_died.connect(_on_unit_died)



# Handle Unit Death (Player Permadeath & Wave Logic)
func _on_unit_died(unit):
	if not unit:
		return
	
	# 1. Player Death (Permadeath)
	if "faction" in unit and unit.faction == "Player":
		GameManager.log(LOG_PREFIX, "Player Unit Died! Registering death...")
		if GameManager:
			var data = {
				"name": unit.name,
				"class": unit.unit_class if "unit_class" in unit else "Recruit",
				"level": unit.level if "level" in unit else 1,
				"unlocked_talents": unit.unlocked_talents if "unlocked_talents" in unit else []
			}
			
			var cod = "Killed in Action"
			if "last_damage_source_name" in unit and unit.last_damage_source_name != "":
				var killer = unit.last_damage_source_name
				var type = unit.last_damage_type if "last_damage_type" in unit else GameManager.DMG_TYPE_GENERIC
				
				# Default Verb
				var verb = "Killed by"
				if GameManager.COD_MAP.has(type):
					verb = GameManager.COD_MAP[type]
				
				# Special Grammer handling
				if type == GameManager.DMG_TYPE_POISON:
					# "Succumbed to Poison" usually doesn't need "by [Killer]" strictly, but XCOM does "Poisoned by Thin Man"
					# Our map says "Succumbed to Poison".
					if killer == "Unknown Source":
						cod = verb # Just "Succumbed to Poison"
					else:
						# If we want to credit the poisoner: "Poisoned by [Name]"?
						# For now, let's stick to the map's string as the prefix.
						if "Succumbed" in verb:
							cod = verb # Ignore killer for pure status death if map implies self-contained
						else:
							cod = verb + " " + killer
				else:
					cod = verb + " " + killer
			
			GameManager.register_fallen_hero(data, cod)

	# 2. Enemy/Wave Logic
	if unit in spawned_units:
		spawned_units.erase(unit)

		if spawned_units.is_empty():
			GameManager.log(LOG_PREFIX, "Wave Cleared!")
			wave_cleared.emit(current_wave_index)
			
			if current_wave_index < active_mission_config.waves.size():
				get_tree().create_timer(2.0).timeout.connect(start_next_wave)
			else:
				# Waves Exhausted. 
				# Only Trigger Victory if Deathmatch (0) or Defense (4).
				# For Hacker (3), Retrieve (2), Rescue (1), the player must complete the objective manually.
				if active_mission_config.objective_type == 0 or active_mission_config.objective_type == 4:
					_complete_mission()
				else:
					GameManager.log(LOG_PREFIX, "Waves Clear. Waiting for Objective Completion...")
	
	# 3. Generic Status Check
	_check_mission_status()


func _on_turn_changed(_phase, turn_num):
	_check_mission_status(turn_num)


func _check_mission_status(turn_num: int = -1):
	if not grid_manager:
		return

	var om = grid_manager.get_node_or_null("../ObjectiveManager")
	var tm = grid_manager.get_node_or_null("../TurnManager")
	
	if not om or not tm:
		return
		
	# Pass current units list to status checker
	# print("MissionManager: Checking Status... Turn:", turn_num)
	var status = om.check_status(tm.units, turn_num if turn_num != -1 else om.current_turn)
	GameManager.log(LOG_PREFIX, "Status Result -> ", status)
	
	if status == "WIN":
		GameManager.log(LOG_PREFIX, "Victory Condition Met!")
		_complete_mission()
	elif status == "LOSS":
		GameManager.log(LOG_PREFIX, "Defeat Condition Met!")
		_handle_defeat(tm.units)
		SignalBus.on_mission_ended.emit(false, 0)



func start_next_wave():
	if current_wave_index >= active_mission_config.waves.size():
		_complete_mission()
		return

	var wave_def = active_mission_config.waves[current_wave_index]
	current_wave_index += 1
	wave_started.emit(current_wave_index, active_mission_config.waves.size())

	GameManager.log(LOG_PREFIX, ">>> WAVE ", current_wave_index, ": ", wave_def.wave_message)
	_spawn_wave(wave_def)


func _spawn_wave(wave_def: WaveDefinition):
	var spawner = load("res://scripts/builders/UnitSpawner.gd").new()
	var generator = load("res://scripts/builders/MissionGenerator.gd").new()
	
	# OPTIMIZATION: Pre-fetch valid spawn tiles to avoid O(N^2) shuffling in GridManager
	# This drastically improves load times for high level missions (Level 20+)
	var spawn_candidates = grid_manager.get_all_valid_spawn_tiles() # Shuffled
	var spawn_index = 0

	# Helper to get next spot from the pre-shuffled list
	var _get_next_spot = func():
		while spawn_index < spawn_candidates.size():
			var pos = spawn_candidates[spawn_index]
			spawn_index += 1
			# Double check it's still free (in case we just spawned there)
			# Though our single-threaded logic ensures we don't double book if we trust the list order.
			# But GridManager checks validity deeply.
			if not grid_manager.grid_data[pos].get("unit"):
				return pos
		return Vector2(-1, -1)

	# 1. Guaranteed Spawns
	for type in wave_def.guaranteed_spawns:
		var count = wave_def.guaranteed_spawns[type]
		for _i in range(count):
			var pos = _get_next_spot.call()
			if pos == Vector2(-1, -1):
				GameManager.log(LOG_PREFIX, "Wave Spawn Warning: No more spawn spots for guaranteed unit!")
				break
				
			var unit = spawn_enemy_at(type, pos) # Uses SELF method
			# if unit: spawned_units.append(unit) # Handled by spawn_enemy_at internally


	# 0. Check for Nemesis Invasions (NemesisManager)
	if GameManager:
		var nm = GameManager.get_node_or_null("NemesisManager")
		if nm:
			# Ask for candidates
			var invaders = nm.get_invasion_candidates(wave_def.budget_points)
			for invader_data in invaders:
				if wave_def.budget_points >= 4: # Min budget check to ensure slot
					var pos = _get_next_spot.call()
					if pos != Vector2(-1, -1):
						# We don't have spawn_nemesis_at on self.
						# We might need to use spawner logic if it exists.
						# Or just spawn generic enemy and initialize data.
						var unit = spawner.spawn_nemesis(invader_data, grid_manager, turn_manager) # Fallback to random if no explicit 'at'
						# Ideally we force pos. unit.position = ... unit.grid_pos = ...
						if unit: 
							unit.position = grid_manager.get_world_position(pos)
							unit.grid_pos = pos
							# Update grid
							if grid_manager.grid_data.has(pos):
								grid_manager.grid_data[pos]["unit"] = unit
							spawned_units.append(unit)
							
						wave_def.budget_points -= 5 # Explicit cost for Nemesis
						GameManager.log(LOG_PREFIX, "WARNING: Nemesis Invasion! ", invader_data.display_name)
	
	# 2. Budget Spawns
	var budget = wave_def.budget_points
	var attempts = 0
	
	while budget > 0 and attempts < 100:
		var type = generator.pick_random_archetype(wave_def)
		if type == "":
			break  # No valid types

		var cost = generator.get_cost(type)

		if cost <= budget:
			var pos = _get_next_spot.call()
			if pos == Vector2(-1, -1):
				GameManager.log(LOG_PREFIX, "Wave Spawn Warning: Board is Full! Stopping spawn.")
				break

			var unit = spawn_enemy_at(type, pos) # Self method
			if unit: 
				# spawned_units.append(unit) # Handled by spawn_enemy_at
				budget -= cost
		else:
			attempts += 1  # Try to find cheaper unit or exit


func _spawn_enemy(type_name: String):
	if not grid_manager:
		return

	var script_path = ENEMY_SCRIPTS.get(type_name)
	
	# Case-Insensitive Fallback
	if not script_path:
		for key in ENEMY_SCRIPTS:
			if key.to_lower() == type_name.to_lower():
				script_path = ENEMY_SCRIPTS[key]
				type_name = key # Auto-correct canonical name
				break
	if not script_path or not ResourceLoader.exists(script_path):
		GameManager.log(LOG_PREFIX, "Error: Unknown enemy script for ", type_name)
		return

	# 1. Determine Resource Type
	var resource = load(script_path)
	var enemy = null
	
	if resource is PackedScene:
		enemy = resource.instantiate()
	else:
		# Assume GDScript
		enemy = resource.new()

	# Find Spawn Position
	var spawn_pos = Vector2(-1, -1)
	for i in range(20): # Try 20 times
		var candidate = grid_manager.get_random_valid_position()
		
		# Check Reachability from Player Start Zone (Approx 1,1)
		# AStar ensures valid path exists (ignores range)
		var path = grid_manager.get_move_path(Vector2(1, 1), candidate)
		if not path.is_empty():
			spawn_pos = candidate
			break
			
	if spawn_pos == Vector2(-1, -1):
		GameManager.log(LOG_PREFIX, "Could not find reachable spawn for ", type_name)
		spawn_pos = grid_manager.get_random_valid_position() # Fallback


	enemy.position = grid_manager.get_world_position(spawn_pos)
	enemy.grid_pos = spawn_pos
	
	# Register in Grid immediately to prevent stacking!
	if grid_manager.grid_data.has(spawn_pos):
		grid_manager.grid_data[spawn_pos]["unit"] = enemy


	# Default Visibility: Hidden (VisionManager will reveal if seen)
	enemy.visible = false

	grid_manager.get_parent().add_child(enemy)
	enemy.add_to_group("Units")
	enemy.add_to_group("Enemies")
	spawned_units.append(enemy)

	# Register with TurnManager (Critical for Targeting/Turn Logic)
	# Register with TurnManager (Critical for Targeting/Turn Logic)
	if not turn_manager and grid_manager:
		turn_manager = grid_manager.get_node_or_null("../TurnManager")
		
	if turn_manager:
		turn_manager.register_unit(enemy)

	# Factory Configuration (Applied AFTER add_child so _ready (visuals) exist)
	_configure_enemy(enemy, type_name)

	# Initialize if needed (some scripts use _ready, others initialize())
	if enemy.has_method("initialize"):
		enemy.initialize(spawn_pos)

	GameManager.log(LOG_PREFIX, "Spawned ", type_name, " at ", spawn_pos)
	return enemy


func spawn_enemy_at(type_name: String, grid_pos: Vector2):
	if not grid_manager:
		GameManager.log(LOG_PREFIX, "Error: GridManager missing.")
		return

	var script_path = ENEMY_SCRIPTS.get(type_name)
	
	# Case-Insensitive Fallback
	if not script_path:
		for key in ENEMY_SCRIPTS:
			if key.to_lower() == type_name.to_lower():
				script_path = ENEMY_SCRIPTS[key]
				type_name = key # Auto-correct canonical name
				break
	if not script_path or not ResourceLoader.exists(script_path):
		GameManager.log(LOG_PREFIX, "Error: Unknown enemy script for ", type_name)
		return

	# Validation: Check bounds and walkability
	if not grid_manager.grid_data.has(grid_pos):
		GameManager.log(LOG_PREFIX, "Error: Spawn Failed. Coordinate ", grid_pos, " is VOID (not in grid).")
		return null
		
	if not grid_manager.is_walkable(grid_pos):
		GameManager.log(LOG_PREFIX, "Error: Spawn Failed. Coordinate ", grid_pos, " is BLOCKED (Wall/Obstacle).")
		return null

	# 1. Instantiate
	var resource = load(script_path)
	var enemy = null
	if resource is PackedScene:
		enemy = resource.instantiate()
	else:
		enemy = resource.new()

	enemy.position = grid_manager.get_world_position(grid_pos)
	enemy.grid_pos = grid_pos
	
	# Register in Grid
	if grid_manager.grid_data.has(grid_pos):
		grid_manager.grid_data[grid_pos]["unit"] = enemy
		# Force walkable false? Units usually handle AStar updates themselves or GridManager does.

	# Default Visibility
	enemy.visible = true # FORCE VISIBLE for debug spawns

	grid_manager.get_parent().add_child(enemy)
	enemy.add_to_group("Units")
	enemy.add_to_group("Enemies")
	spawned_units.append(enemy)

	# Register with TurnManager
	# Register with TurnManager
	if not turn_manager and grid_manager:
		turn_manager = grid_manager.get_node_or_null("../TurnManager")

	if turn_manager:
		turn_manager.register_unit(enemy)

	# Factory Configuration
	_configure_enemy(enemy, type_name)

	# Initialize
	if enemy.has_method("initialize"):
		enemy.initialize(grid_pos)

	# Sync with Main.spawned_units to ensure VisionManager sees it
	var main_node = grid_manager.get_parent()
	if main_node and "spawned_units" in main_node:
		main_node.spawned_units.append(enemy)

	GameManager.log(LOG_PREFIX, "Spawned ", type_name, " at ", grid_pos)
	
	# Visual Confirmation
	SignalBus.on_request_floating_text.emit(enemy, "SPAWNED!", Color.GREEN)

	return enemy


func spawn_enemy_near_player(type_name: String):
	if not turn_manager:
		GameManager.log(LOG_PREFIX, "TurnManager missing, cannot find player.")
		return null
		
	var players = []
	for u in turn_manager.units:
		if is_instance_valid(u) and "faction" in u and u.faction == "Player" and u.current_hp > 0:
			players.append(u)
			
	if players.is_empty():
		GameManager.log(LOG_PREFIX, "No active players found. Fallback to Random.")
		return _spawn_enemy(type_name) # Fallback
		
	var target = players.pick_random()
	var start_pos = target.grid_pos
	
	# ROBUST SEARCH: Scan all tiles, sort by distance, pick closest valid.
	var valid_candidates = []
	var min_dist = 2.0
	
	GameManager.log(LOG_PREFIX, "DEBUG: Searching for spawn near ", start_pos, " Map Size: ", grid_manager.grid_data.size())
	
	# 1. Gather Candidates
	for coord in grid_manager.grid_data:
		# Check basic validity
		var tile = grid_manager.get_tile_data(coord)
		
		# DEBUG: Only log first few failures
		# if not tile.get("is_walkable", false): continue 
		if not grid_manager.is_walkable(coord): continue
		
		if tile.get("unit"): 
			GameManager.log(LOG_PREFIX, "DEBUG: Reject Occupied ", coord)
			continue # Occupied by Unit
		
		var d = start_pos.distance_to(coord)
		if d < min_dist: 
			GameManager.log(LOG_PREFIX, "DEBUG: Reject Too Close ", coord, " Dist: ", d)
			continue
		
		valid_candidates.append({"pos": coord, "dist": d})
		
	GameManager.log(LOG_PREFIX, "DEBUG: Found ", valid_candidates.size(), " valid candidates.")
	
	# 2. Sort by Distance (Ascending)
	valid_candidates.sort_custom(func(a, b): return a.dist < b.dist)
	
	# 3. Pick Best (Top 5 slightly randomized to avoid stacking identical spots if spamming)
	if not valid_candidates.is_empty():
		var top_n = min(valid_candidates.size(), 5)
		var choice = valid_candidates.slice(0, top_n).pick_random()
		var best_pos = choice.pos
		
		# Log result for debug
		GameManager.log(LOG_PREFIX, "Found spawn spot at ", best_pos, " (Dist: ", choice.dist, ")")
		return spawn_enemy_at(type_name, best_pos)
		
	else:
		GameManager.log(LOG_PREFIX, "CRITICAL: No valid spawn spots found near player! Fallback to Random.")
		return _spawn_enemy(type_name) # Fallback to standard random spawn logic (MissionManager function)


func _configure_enemy(enemy, type_name: String):
	var gm_global = null
	if has_node("/root/GameManager"):
		gm_global = get_node("/root/GameManager")

	var data = EnemyFactory.create_enemy_data(type_name, gm_global)
	if data:
		enemy.initialize_from_data(data)




func _complete_mission():
	if _mission_ended_flag:
		return
	_mission_ended_flag = true

	GameManager.log(LOG_PREFIX, "Mission Complete! Emitting Victory Signal.")
	mission_completed.emit(active_mission_config)
	
	# Also notify global bus so Main.gd shows victory screen
	var rewards = 100
	if active_mission_config and "reward_kibble" in active_mission_config:
		rewards = active_mission_config.reward_kibble
		
	SignalBus.on_mission_ended.emit(true, rewards)


func _handle_defeat(units: Array):
	if _mission_ended_flag:
		return
	_mission_ended_flag = true

	GameManager.log(LOG_PREFIX, "Processing Defeat Persistence...")
	if not GameManager:
		return

	# Collect Survivors (Player)
	var survivors = []
	for u in units:
		if is_instance_valid(u) and "faction" in u and u.faction == "Player" and u.current_hp > 0:
			survivors.append({
				"name": u.name,
				"hp": u.current_hp,
				"xp": u.current_xp if "current_xp" in u else 0,
				"level": u.rank_level if "rank_level" in u else 1,
				"sanity": u.current_sanity if "current_sanity" in u else 0,
				"inventory": u.inventory if "inventory" in u else []
			})

	# Collect Enemy Survivors (Nemesis System)
	var enemy_survivors = []
	for u in units:
		if is_instance_valid(u) and "faction" in u and u.faction == "Enemy" and u.current_hp > 0:
			if "victim_log" in u and u.victim_log.size() > 0:
				enemy_survivors.append({
					"name": u.name,
					"victim_log": u.victim_log,
					"base_type": "Rusher" # Simplified
				})

	GameManager.complete_mission(survivors, false, enemy_survivors)


func setup_acidsplosion_scenario(grid_manager, unit_container):
	GameManager.log(LOG_PREFIX, "Setting up ACIDSPLOSION Scenario!")
	
	# 1. Spawn Spitters
	# ... logic existing ...
	pass

	# 1. Spawn Spitters
	# (Logic continues below)

	# Center the action around 10,10
	var spitter_positions = [
		Vector2(8, 8), Vector2(12, 8), Vector2(8, 12), Vector2(12, 12), Vector2(10, 6)
	]
	
	for pos in spitter_positions:
		# Ensure tile is valid (Force Clear)
		if grid_manager.grid_data.has(pos):
			grid_manager.grid_data[pos]["walkable"] = true
			grid_manager.grid_data[pos]["cover"] = 0.0
			# Remove any existing static body? 
			# GridManager usually manages data, LevelGenerator manages meshes.
			# We can't easily remove the mesh here without a reference map.
			# But we can update data so pathfinding works.
		
		var spitter = load("res://scripts/entities/SpitterUnit.gd").new()
		
		# Add to scene FIRST to trigger _ready() and setup nodes
		unit_container.add_child(spitter)
		spitter.position = grid_manager.get_world_position(pos)
		
		# Load minimal data manually
		var data = load("res://scripts/resources/EnemyData.gd").new()
		data.display_name = "Acid Spitter"
		data.max_hp = 10
		data.mobility = 5
		data.visual_color = Color.WEB_GREEN
		
		# Initialize Data (Updates Visuals & Stats)
		spitter.initialize_from_data(data)
		spitter.grid_pos = pos
		
		pass
		
	# 2. Spawn Explosive Barrels
	var barrel_positions = [
		Vector2(10, 10), # Center Bullseye
		Vector2(9, 9), Vector2(11, 9), Vector2(9, 11), Vector2(11, 11), # Inner Ring
		Vector2(10, 8), Vector2(10, 12), Vector2(8, 10), Vector2(12, 10) # Cross
	]
	
	for pos in barrel_positions:
		# Force Clear for Barrels too
		if grid_manager.grid_data.has(pos):
			grid_manager.grid_data[pos]["walkable"] = true
			grid_manager.grid_data[pos]["cover"] = 0.0

		var barrel = load("res://scripts/entities/ExplosiveBarrel.gd").new()
		# Add to scene
		unit_container.add_child(barrel)
		barrel.position = grid_manager.get_world_position(pos)
		barrel.initialize(pos, grid_manager)
		barrel.add_to_group("Destructible")
		
		GameManager.log(LOG_PREFIX, "Spawned Barrel at ", pos)

	print("MissionManager: Acidsplosion setup complete.")


func _attach_rescue_beacon(parent_node: Node3D):
	# 1. Container
	var beacon_pivot = Node3D.new()
	beacon_pivot.name = "RescueBeacon"
	beacon_pivot.position = Vector3(0, 3.5, 0) # High above head
	parent_node.add_child(beacon_pivot)
	
	# 2. Arrow Mesh (Prism pointing down)
	var mesh_inst = MeshInstance3D.new()
	var mesh = PrismMesh.new()
	mesh.size = Vector3(0.8, 1.2, 0.2) # Flat arrow
	mesh_inst.mesh = mesh
	mesh_inst.rotation_degrees.z = 180 # Point down
	
	# 3. Material (Gaudy Gold)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.84, 0.0) # Gold
	mat.metallic = 1.0
	mat.roughness = 0.2
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.84, 0.0)
	mat.emission_energy_multiplier = 2.0
	mesh_inst.material_override = mat
	
	beacon_pivot.add_child(mesh_inst)
	
	# 4. Animation (Tween)
	var tween = beacon_pivot.create_tween().set_loops()
	
	# Bounce
	tween.tween_property(mesh_inst, "position:y", 0.5, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mesh_inst, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	
	# Spin (Separate Tween)
	var spin_tween = beacon_pivot.create_tween().set_loops()
	spin_tween.tween_property(mesh_inst, "rotation_degrees:y", 360.0, 2.0).as_relative()
