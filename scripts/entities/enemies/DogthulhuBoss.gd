extends EnemyUnit

func _ready():
	super._ready()
	
	# CENTRALIZED STATS: Load from Factory
	# This ensures we use the 70 HP / Abilities defined in EnemyFactory.gd
	var Factory = load("res://scripts/factories/EnemyFactory.gd")
	var data = Factory.create_enemy_data("Boss", get_node_or_null("/root/GameManager"))
	
	initialize_from_data(data)
	
	# Override specific Boss visuals/behavior that Factory might not cover fully yet
	# (Though initialize_from_data handles model creation, we want custom material/label)
	
	_load_behavior(9) # BOSS
	
	# Custom Visuals (Override Factory's generic model if needed)
	var mesh_node = get_node_or_null("ModelRoot") # Factory creates ModelRoot
	if mesh_node:
		# Apply Boss Material to all meshes in model
		_apply_boss_material(mesh_node)
		
	var label = get_node_or_null("Label3D")
	if label: label.text = "THE ANCIENT ONE"
	
	# FORCE MELEE BEHAVIOR (If not set by data)
	# behavior_resource = load("res://scripts/ai/DogthulhuBehavior.gd").new() # Factory sets this now? 
	# Factory sets AIBehavior.BOSS enum. EnemyUnit uses that to load behavior?
	# EnemyUnit.initialize_from_data doesn't load behavior script from enum yet?
	# Let's check EnemyUnit.gd ... likely needs update if we want purely data driven.
	# For now, keep specific behavior override here to be safe.
	behavior_resource = load("res://scripts/ai/DogthulhuBehavior.gd").new()

func _apply_boss_material(node):
	if node is MeshInstance3D:
		if not node.material_override:
			node.material_override = StandardMaterial3D.new()
		node.material_override.albedo_color = Color(0.1, 0.0, 0.1) # Dark Purple/Black
	
	for child in node.get_children():
		_apply_boss_material(child)

# CUSTOM BOSS AI: Global Seeking (Ignores Fog) + Hydrant Targeting
func _acquire_target(units: Array, gm: GridManager):
	target_unit = null
	var best_score = -9999.0
	var candidates = []
	
	for u in units:
		if not is_instance_valid(u): continue
		
		# Valid Targets: Players OR The Golden Hydrant (Group check)
		# Note: Hydrant is now faction="Player", so standard check covers it too.
		if "faction" in u and u.faction == "Player" and u.current_hp > 0:
			
			var score = 0.0
			var dist = grid_pos.distance_to(u.grid_pos)
			score -= dist
			
			# Priority: Real Players > Hydrant
			# If it's the Hydrant, slightly penalty so we prefer eating dogs
			if u.is_in_group("Objectives"): # GoldenHydrant is in this group
				score -= 5.0 
			elif u.current_hp <= 10: # Blood scent
				score += 5.0
				
			if score > best_score:
				best_score = score
				candidates = [u]
			elif score == best_score:
				candidates.append(u)

	if candidates.size() > 0:
		target_unit = candidates.pick_random()


