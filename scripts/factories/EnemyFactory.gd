class_name EnemyFactory

const WeaponScript = preload("res://scripts/resources/WeaponData.gd")

static func create_enemy_data(archetype: String, gm_ref = null) -> Resource:
	var data = EnemyData.new()
	
	# Common Defaults
	data.action_points = 2
	
	match archetype:
		"Rusher":
			data.archetype_name = "Rusher"
			var theme = ["Fleshy", "Suburbia"].pick_random()
			if gm_ref and gm_ref.has_method("get_enemy_name"):
				data.display_name = gm_ref.get_enemy_name(theme)
			else:
				data.display_name = "Feral Rusher"

			data.ai_behavior = data.AIBehavior.RUSHER
			data.max_hp = 8
			data.mobility = 6
			data.visual_color = Color.ORANGE
			
			var w = WeaponScript.new()
			w.display_name = "Bite"
			w.damage = 3
			w.weapon_range = 1
			w.damage_type = GameManager.DMG_TYPE_MELEE
			data.primary_weapon = w

		"Sniper":
			data.archetype_name = "Sniper"
			var theme = ["Abstract", "Aquatic"].pick_random()
			if gm_ref and gm_ref.has_method("get_enemy_name"):
				data.display_name = gm_ref.get_enemy_name(theme)
			else:
				data.display_name = "Eldritch Sniper"

			data.ai_behavior = data.AIBehavior.SNIPER
			data.max_hp = 6
			data.mobility = 3
			data.visual_color = Color.CYAN
			
			var w = WeaponScript.new()
			w.display_name = "Eye Rifle"
			w.damage = 4
			w.weapon_range = 10
			data.primary_weapon = w
			
			
		"Spitter":
			data.archetype_name = "Spitter"
			var theme = ["Fleshy", "Abstract"].pick_random()
			if gm_ref and gm_ref.has_method("get_enemy_name"):
				data.display_name = gm_ref.get_enemy_name(theme)
			else:
				data.display_name = "Acid Spitter"
				
			data.ai_behavior = data.AIBehavior.AREA_DENIAL
			data.max_hp = 10
			data.mobility = 5
			data.visual_color = Color.WEB_GREEN
			
			var w = WeaponScript.new()
			w.display_name = "Acid Spit"
			w.damage = 2
			w.weapon_range = 6 # Matches SpitterUnit.gd
			w.damage_type = GameManager.DMG_TYPE_ACID
			data.primary_weapon = w
			
			data.abilities.append(preload("res://scripts/abilities/AcidSpitAbility.gd"))

		"Exploder":
			data.archetype_name = "Exploder"
			var theme = ["Fleshy"].pick_random()
			if gm_ref and gm_ref.has_method("get_enemy_name"):
				data.display_name = gm_ref.get_enemy_name(theme)
			else:
				data.display_name = "Volatile Bloat"

			data.ai_behavior = data.AIBehavior.EXPLODER
			data.max_hp = 6
			data.mobility = 8
			data.visual_color = Color.RED
			data.action_points = 2
			
			data.abilities.append(preload("res://scripts/abilities/ExplodeAbility.gd"))

		"Flying":
			data.archetype_name = "Flying"
			var theme = ["Abstract"].pick_random()
			if gm_ref and gm_ref.has_method("get_enemy_name"):
				data.display_name = gm_ref.get_enemy_name(theme)
			else:
				data.display_name = "Night Gaunt"

			data.ai_behavior = data.AIBehavior.FLYING
			data.max_hp = 10 # Matches Unit.gd default (was 8)
			data.mobility = 8 # Matches FlyingEnemy.gd (was 7)
			data.visual_color = Color.INDIGO
			data.action_points = 2
			
			var w = WeaponScript.new()
			w.display_name = "Ectoplasm Bolt"
			w.damage = 1
			w.weapon_range = 6
			data.primary_weapon = w

		"Tank":
			data.archetype_name = "Tank"
			var theme = ["Suburbia", "Fleshy"].pick_random()
			if gm_ref and gm_ref.has_method("get_enemy_name"):
				data.display_name = gm_ref.get_enemy_name(theme)
			else:
				data.display_name = "Armored Hulk"

			data.ai_behavior = data.AIBehavior.TANK
			data.max_hp = 12 # Matches TankEnemy.gd (was 20)
			data.mobility = 3 # Matches TankEnemy.gd (was 4)
			data.armor = 2
			data.visual_color = Color.DARK_SLATE_GRAY
			data.action_points = 2
			
			var w = WeaponScript.new()
			w.display_name = "Smash"
			w.damage = 6
			w.weapon_range = 1
			w.damage_type = GameManager.DMG_TYPE_MELEE
			data.primary_weapon = w

		"Infiltrator":
			data.archetype_name = "Infiltrator"
			var theme = ["Suburbia", "Abstract"].pick_random()
			if gm_ref and gm_ref.has_method("get_enemy_name"):
				data.display_name = gm_ref.get_enemy_name(theme)
			else:
				data.display_name = "Stalker"

			data.ai_behavior = data.AIBehavior.INFILTRATOR
			data.max_hp = 10 # Matches Unit.gd default (was 8)
			data.mobility = 7 # Matches InfiltratorEnemy.gd (was 6)
			data.visual_color = Color.TRANSPARENT
			data.action_points = 3
			
			var w = WeaponScript.new()
			w.display_name = "Backstab"
			w.damage = 5
			w.weapon_range = 1
			w.damage_type = GameManager.DMG_TYPE_MELEE
			data.primary_weapon = w

		"Whisperer":
			data.archetype_name = "Whisperer"
			var theme = ["Abstract"].pick_random()
			if gm_ref and gm_ref.has_method("get_enemy_name"):
				data.display_name = gm_ref.get_enemy_name(theme)
			else:
				data.display_name = "Whisperer"
			
			data.ai_behavior = data.AIBehavior.CONTROLLER
			data.max_hp = 40 # Matches WhispererUnit.gd (was 8)
			data.mobility = 6 # Matches WhispererUnit.gd (was 4)
			data.visual_color = Color.PURPLE
			data.action_points = 2
			
			# Add Ability
			data.abilities.append(preload("res://scripts/abilities/MindFractureAbility.gd"))
			
			# Load resource if exists for complex data, else default
			if ResourceLoader.exists("res://assets/data/enemies/WhispererData.tres"):
				var res = load("res://assets/data/enemies/WhispererData.tres")
				if res is EnemyData:
					data = res.duplicate()
					data.archetype_name = "Whisperer" # Re-apply after dup
					if gm_ref: data.display_name = gm_ref.get_enemy_name(theme)
					return data
		
		"Boss":
			data.archetype_name = "Boss"
			data.display_name = "Dogthulhu"
			data.ai_behavior = data.AIBehavior.BOSS
			data.max_hp = 100
			data.mobility = 5
			data.visual_color = Color.CRIMSON
			data.action_points = 4

		_:
			# Default / Fallback
			data.archetype_name = "Generic"
			data.display_name = "Unknown Entity"
			data.ai_behavior = data.AIBehavior.GENERIC
			data.max_hp = 5
			data.mobility = 4
			data.visual_color = Color.GRAY

	return data
