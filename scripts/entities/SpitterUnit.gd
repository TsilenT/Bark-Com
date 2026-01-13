extends "res://scripts/entities/EnemyUnit.gd"

func _ready():
	super._ready()
	# Spitter Specs
	if max_hp < 10:
		max_hp = 10
	current_hp = max_hp
	mobility = 5
	
	# Fallback Weapon
	if not primary_weapon:
		var spit = WeaponData.new()
		spit.display_name = "Weak Spit"
		spit.damage = 2
		spit.weapon_range = 6
		primary_weapon = spit

	# Visual Override
	_setup_spitter_visuals()
	
	# Add Acid Spit Ability
	abilities.append(load("res://scripts/abilities/AcidSpitAbility.gd").new())
	
	# Set Behavior directly (AREA_DENIAL = 3)
	_load_behavior(3)


func _setup_spitter_visuals():
	var mesh = get_node_or_null("Mesh")
	if mesh:
		if not mesh.material_override:
			mesh.material_override = StandardMaterial3D.new()
		mesh.material_override.albedo_color = Color.WEB_GREEN
