extends Node
# NemesisManager.gd
# Manages enemy promotions, surviving nemeses, and injecting them into missions.

const LOG_PREFIX = "NemesisManager: "
const SAVE_PATH = "user://nemesis_data.tres"

# A list of dictionaries or custom resources representing promoted enemies
# { "name": "Gore-Tooth", "base_type": "Rusher", "level": 2, "skills": [], "victim_log": [] }
var active_nemeses: Array = [] 
var graveyard: Array = [] # Dead nemeses

func _ready():
	add_to_group("NemesisManager")
	_load_data()

func _load_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var data = file.get_var()
		if data:
			active_nemeses = data.get("care", [])
			graveyard = data.get("grave", [])
			GameManager.log(LOG_PREFIX, "Loaded ", active_nemeses.size(), " nemeses.")

func save_data():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var data = {
		"care": active_nemeses,
		"grave": graveyard
	}
	file.store_var(data)

func register_survivor(enemy_data: Dictionary):
	# enemy_data: { "name": ..., "base_type": ..., "victim_log": [...] }
	
	# Check if already exists (by name)
	for nem in active_nemeses:
		if nem.name == enemy_data.name:
			# Already tracked, maybe level up?
			_promote_existing(nem, enemy_data)
			return
	
	# Determine Name
	# Use existing name if it has one (e.g. from NameGen), otherwise generated.
	var final_name = enemy_data.name
	
	# New Promotion!
	var new_nem = {
		"name": final_name,
		"title": "The Survivor",
		"base_type": enemy_data.base_type,
		"level": 1,
		"skills": [],
		"victim_log": enemy_data.victim_log,
		"visual_tint": Color(randf(), randf(), randf()) # Random tint for uniqueness
	}
	
	# Grant initial skill
	_grant_random_skill(new_nem)
	
	active_nemeses.append(new_nem)
	GameManager.log(LOG_PREFIX, "New Nemesis Promoted: ", new_nem.name)
	save_data()
	
	SignalBus.on_request_floating_text.emit(Vector3(0,0,0), "NEMESIS PROMOTED!", Color.RED) # Global notification?

func _promote_existing(nemesis: Dictionary, recent_data: Dictionary):
	nemesis.level += 1
	nemesis.victim_log.append_array(recent_data.victim_log)
	_grant_random_skill(nemesis)
	GameManager.log(LOG_PREFIX, nemesis.name, " leveled up to ", nemesis.level)
	save_data()

func _grant_random_skill(nemData: Dictionary):
	# Simplified Skill Pool for v0.5
	var skills = ["health_boost_1", "mobility_boost_1", "damage_boost_1", "extra_action_1"]
	var pick = skills.pick_random()
	if not nemData.skills.has(pick):
		nemData.skills.append(pick)

# Invaders Logic
func get_invasion_candidates(budget: int) -> Array:
	# Return a list of EnemyData objects generated from Nemeses
	# that fit within budget (or replace a spawn).
	var candidates = []
	for nem in active_nemeses:
		# 20% chance per mission to appear?
		if randf() < 0.2:
			candidates.append(_create_data_from_nemesis(nem))
	return candidates

func _create_data_from_nemesis(nem: Dictionary) -> Resource:
	# LOAD BASE DATA using Factory matching base_type
	var data = EnemyFactory.create_enemy_data(nem.base_type) # No GM ref needed for generic re-load, or pass GM if needed
	
	# OVERRIDE with Nemesis Stats
	data.display_name = nem.name + " " + nem.title
	data.visual_color = nem.visual_tint
	
	# Scaling logic: Add bonuses based on level/skills
	# (Base stats are already set by factory)
	
	data.max_hp += (nem.level * 2)
	
	# Apply Skills
	for s_id in nem.skills:
		match s_id:
			"health_boost_1": data.max_hp += 4
			"mobility_boost_1": data.mobility += 2
			"extra_action_1": data.action_points += 1
			"damage_boost_1": 
				if data.primary_weapon:
					data.primary_weapon.damage += 1
			# ...
			
	return data

func on_nemesis_died(name: String):
	for i in range(active_nemeses.size()):
		if active_nemeses[i].name == name: # Or check exact match if name includes Title
			var dead_guy = active_nemeses.pop_at(i)
			graveyard.append(dead_guy)
			GameManager.log(LOG_PREFIX, "Nemesis Defeated: ", name)
			save_data()
			break

