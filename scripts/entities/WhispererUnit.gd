extends "res://scripts/entities/EnemyUnit.gd"
class_name WhispererUnit

# Passive: Dread Aura
# Range: 3 tiles
# Effect: -5 Sanity on Turn End


func _ready():
	super._ready()
	name = "The Whisperer"
	max_hp = 40  # Low HP
	current_hp = 40
	mobility = 6  # Mobile

	# Visuals: Purple
	var mesh = get_node_or_null("Mesh")
	if mesh:
		if not mesh.material_override:
			mesh.material_override = StandardMaterial3D.new()
		mesh.material_override.albedo_color = Color(0.5, 0.0, 0.8)  # Purple

	# Update Label
	var label = get_node_or_null("Label3D")
	if label:
		label.text = "WHISPERER"

	# Add Abilities
	var mf_script = load("res://scripts/abilities/MindFractureAbility.gd")
	if mf_script:
		var mf = mf_script.new()
		abilities.append(mf)
	
	# Set Behavior: CONTROLLER (4)
	_load_behavior(4)


# Hook: Called by TurnManager when this unit's turn ends
func process_turn_end_effects():
	super.process_turn_end_effects()  # Standard resets
	_apply_dread_aura()


func _apply_dread_aura():
	print("The Whisperer emits a wave of Dread...")
	# VFX here?

	# Empowered HACK: Iterate all siblings if they are Unit
	for sibling in get_parent().get_children():
		if sibling is Unit and sibling != self and "faction" in sibling and sibling.faction == "Player":
			if sibling.current_hp > 0:
				var dist = grid_pos.distance_to(sibling.grid_pos)
				if dist <= 3.0:
					if sibling.has_method("take_sanity_damage"):
						sibling.take_sanity_damage(5)
					print(sibling.name, " suffers 5 Dread damage!")
