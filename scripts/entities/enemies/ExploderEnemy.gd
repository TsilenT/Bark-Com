extends "res://scripts/entities/EnemyUnit.gd"

func _ready():
	super._ready()
	mobility = 8 # Fast
	if max_hp < 6: max_hp = 6
	current_hp = max_hp
	
	_load_behavior(5) # EXPLODER
	
	# Add Bomb Ability
	abilities.append(load("res://scripts/abilities/ExplodeAbility.gd").new())
	
	# Disable normal attack (Force behavior to use Ability)
	attack_range = 0
	
	# Visuals (Orange)
	_setup_visuals()

func _setup_visuals():
	var mesh = get_node_or_null("Mesh")
	if mesh:
		if not mesh.material_override:
			mesh.material_override = StandardMaterial3D.new()
		mesh.material_override.albedo_color = Color.FIREBRICK
