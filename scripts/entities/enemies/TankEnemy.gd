extends "res://scripts/entities/EnemyUnit.gd"

func _ready():
	super._ready()
	mobility = 3 # Slow
	if max_hp < 12: max_hp = 12 # Tanky
	current_hp = max_hp
	armor = 2 # Natural armor
	
	_load_behavior(6) # TANK
	
	# Visuals (Dark Green/Brown)
	_setup_visuals()

func _setup_visuals():
	var mesh = get_node_or_null("Mesh")
	if mesh:
		if not mesh.material_override:
			mesh.material_override = StandardMaterial3D.new()
		mesh.material_override.albedo_color = Color(0.3, 0.2, 0.1) # Muddy

	var label = get_node_or_null("Label3D")
	if label: label.text = "TANK"
