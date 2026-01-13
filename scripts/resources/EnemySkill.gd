extends Resource
class_name EnemySkill

# Skill Types:
# - PASSIVE_STAT: Adds raw stats (HP, Aim, etc)
# - PASSIVE_PERK: Adds a specific perk tag that logic checks
# - ACTIVE_ABILITY: Adds a new ability script
enum SkillType { PASSIVE_STAT, PASSIVE_PERK, ACTIVE_ABILITY }

@export var display_name: String = "New Skill"
@export var description: String = "Effect description."
@export var type: SkillType = SkillType.PASSIVE_STAT

# For PASSIVE_STAT
@export var stat_modifiers: Dictionary = {} # e.g. {"max_hp": 2, "mobility": 1}

# For PASSIVE_PERK
@export var perk_tag: String = "" # e.g. "regenerator"

# For ACTIVE_ABILITY
@export var ability_script: Script 

func apply(unit_data):
	# Applies this skill to an EnemyData resource (persistence)
	# Or directly to a Unit instance? 
	# EnemyData is better for persistence.
	
	match type:
		SkillType.PASSIVE_STAT:
			pass # Applied via logic reading skills
		SkillType.PASSIVE_PERK:
			pass # Applied via logic checking skills
		SkillType.ACTIVE_ABILITY:
			if ability_script:
				if not unit_data.abilities.has(ability_script):
					unit_data.abilities.append(ability_script)
					
func apply_to_unit(unit):
	# Runtime application
	match type:
		SkillType.PASSIVE_STAT:
			for stat in stat_modifiers:
				var val = stat_modifiers[stat]
				if stat == "max_hp":
					unit.max_hp += val
					unit.current_hp += val # Heal for upgrade
				elif stat == "mobility":
					# Modify base or modifier?
					unit.modifiers["mobility"] = unit.modifiers.get("mobility", 0) + val
				elif stat == "accuracy":
					unit.accuracy += val
				elif stat == "defense":
					unit.defense += val
					
		SkillType.PASSIVE_PERK:
			# Unit doesn't have a "perk list" like BarkTreeManager?
			# Unit.has_perk checks BarkTreeManager.
			# Enemies might need their own "tags" list.
			if not "enemy_tags" in unit:
				unit.set_meta("enemy_tags", [])
			var tags = unit.get_meta("enemy_tags")
			if not tags.has(perk_tag):
				tags.append(perk_tag)
			unit.set_meta("enemy_tags", tags)
			
		SkillType.ACTIVE_ABILITY:
			if ability_script:
				# Instantiate and add if not present
				var has_it = false
				for a in unit.abilities:
					if a.get_script() == ability_script:
						has_it = true
						break
				if not has_it:
					unit.abilities.append(ability_script.new())
