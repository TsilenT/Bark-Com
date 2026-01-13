extends "res://scripts/entities/EnemyUnit.gd"

func _ready():
	super._ready()
	unit_name = "Dogthulhu"
	name = "Dogthulhu"
	
	max_hp = 150
	current_hp = max_hp
	armor = 2
	
	max_ap = 4
	current_ap = 4
	
	mobility = 6
	
	_load_behavior(9) # BOSS
	
	# Visuals
	var mesh = get_node_or_null("Mesh")
	if mesh:
		if not mesh.material_override:
			mesh.material_override = StandardMaterial3D.new()
		mesh.material_override.albedo_color = Color(0.1, 0.0, 0.1) # Dark Purple/Black
		
	var label = get_node_or_null("Label3D")
	if label: label.text = "THE ANCIENT ONE"
