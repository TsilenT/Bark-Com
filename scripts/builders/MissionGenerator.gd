extends RefCounted
class_name MissionGenerator

const LOG_PREFIX = "MissionGenerator: "

# ----------------------------
# LOGIC EXTRACTION FROM MissionManager
# ----------------------------

func generate_mission_config(level: int) -> MissionConfig:
	var config = MissionConfig.new()
	config.mission_name = "Sector Sweep (Level " + str(level) + ")"
	config.description = "Clear all hostiles in the sector."
	config.reward_kibble = 50 * level
	config.biome_type = randi() % LevelGenerator.Biome.size() # Random Biome
	
	if level == 1:
		# Level 1: 1 Wave, Max Threat 5, Only Snipers/Rushers
		var wave1 = _create_wave(5, ["Rusher", "Sniper"])
		wave1.wave_message = "Hostiles Detected!"
		config.waves.append(wave1)

	elif level == 2:
		# Level 2: 2 Waves, Spitter Limit 1 (per wave)
		
		# Wave 1: Intro (Lighter)
		var wave1 = _create_wave(6, ["Rusher", "Sniper"]) 
		wave1.wave_message = "First Wave Incoming!"
		config.waves.append(wave1)
		
		# Wave 2: Escalation (With Spitter)
		var wave2 = _create_wave(8, ["Rusher", "Sniper", "Spitter"])
		wave2.guaranteed_spawns["Spitter"] = 1
		wave2.budget_points = 5 
		wave2.allowed_archetypes.assign(["Rusher", "Sniper"])
		wave2.wave_message = "Reinforcements! Caution: Acid Detected!"
		config.waves.append(wave2)

	elif level >= 3:
		# Level 3+: 3 Waves, Scaling Difficulty
		# Budget Scaling: Base + (Level * Multiplier)
		
		# Wave 1: Warmup (50% of Power)
		var b1 = 4 + (level * 2)
		var w1 = _create_wave(b1, ["Rusher", "Sniper"])
		config.waves.append(w1)
		
		# Wave 2: Escalation (75% of Power)
		var b2 = 6 + (level * 3)
		var w2 = _create_wave(b2, ["Rusher", "Sniper", "Spitter", "Exploder"])
		config.waves.append(w2)
		
		# Wave 3: Climax (100% Power + Full Variety)
		var b3 = 8 + (level * 4) 
		var w3 = _create_wave(b3, ["Rusher", "Sniper", "Spitter", "Whisperer", "Exploder", "Tank", "Flying", "Infiltrator"])
		config.waves.append(w3)
	
	# Randomize Objective Type (Level 1 is always Deathmatch for simplicity)
	if level > 1:
		var types = [0, 2, 3] # Deathmatch, Retrieve, Hacker
		config.objective_type = types.pick_random()
		
		match config.objective_type:
			2: # Retrieve
				config.objective_target_count = randi_range(5, 7)
				config.mission_name = "Supply Run (Level " + str(level) + ")"
				config.description = "Retrieve " + str(config.objective_target_count) + " Treat Bags."
			3: # Hacker
				config.objective_target_count = randi_range(3, 4)
				config.mission_name = "Network Breach (Level " + str(level) + ")"
				config.description = "Hack " + str(config.objective_target_count) + " Terminals."
			_:
				config.objective_type = 0 # Default Deathmatch
				config.mission_name = "Sector Sweep (Level " + str(level) + ")"
				config.description = "Eliminate all hostiles."
	
	GameManager.log(LOG_PREFIX, "Generated Config: ", config.mission_name, " Biome:", config.biome_type)
	return config


func _create_wave(budget: int, allowed: Array) -> WaveDefinition:
	var w = WaveDefinition.new()
	w.budget_points = budget
	w.allowed_archetypes.assign(allowed) # Godot Array copy
	return w


func pick_random_archetype(wave_def: WaveDefinition) -> String:
	var pool = []
	if not wave_def.allowed_archetypes.is_empty():
		pool = wave_def.allowed_archetypes
	else:
		# Fallback (All Non-Boss Archetypes)
		pool = [
			EnemyData.ARCHETYPE_RUSHER, 
			EnemyData.ARCHETYPE_SNIPER, 
			EnemyData.ARCHETYPE_SPITTER, 
			EnemyData.ARCHETYPE_EXPLODER, 
			EnemyData.ARCHETYPE_FLYING, 
			EnemyData.ARCHETYPE_TANK,
			EnemyData.ARCHETYPE_WHISPERER,
			EnemyData.ARCHETYPE_INFILTRATOR
		]
	
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]


func get_cost(type_name: String) -> int:
	match type_name:
		"Rusher": return 1
		"Sniper": return 2
		"Spitter": return 3
		"Whisperer": return 4
		"Exploder": return 2
		"Tank": return 4
		"Flying": return 3
		"Infiltrator": return 4
		"Boss": return 99 
		"Nemesis": return 5
		_:
			return 1
