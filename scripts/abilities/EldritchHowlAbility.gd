extends Ability

# ELDRITCH HOWL
# A terrifying scream that damages Sanity and Health in a wide area around the Boss.
# Radius: 3 Tiles
# Damage: 5 Physical + 20 Sanity
# Cooldown: 3 Turns
# Cost: 1 AP

var vfx_scene_path: String = "res://scenes/vfx/EldritchHowl.tscn"

func _init():
	display_name = "Eldritch Howl"
	description = "AoE Scream. Deals 5 DMG + 20 Sanity DMG to all nearby enemies."
	ap_cost = 1
	cooldown_turns = 3
	ability_range = 0 # Self-centered AoE

func get_valid_tiles(grid_manager, user) -> Array[Vector2]:
	# Always valid if enemies are nearby, but target is SELF for execution context usually?
	# Or we return the User's tile to clickable?
	# For AI, we just need to know it CAN be used.
	# Let's return the user's tile as the valid "target" to trigger the AoE.
	return [user.grid_pos]

func execute(user, _target, _target_pos, grid_manager) -> String:
	print(user.name, " uses ELDRITCH HOWL!")
	
	# Play VFX (Mock)
	if SignalBus:
		SignalBus.on_request_floating_text.emit(user, "ROOOOAAAAR!", Color.PURPLE)

	# Find Targets in Range 3
	var center = user.grid_pos
	var radius = 3
	
	var affected_units = []
	
	# Scan all units (more efficient than scanning all tiles)
	var tree = grid_manager.get_tree()
	if tree:
		var units = tree.get_nodes_in_group("Units")
		for u in units:
			if u != user and u.get("faction") != user.get("faction") and u.current_hp > 0:
				var dist = center.distance_to(u.grid_pos)
				if dist <= radius:
					affected_units.append(u)
	
	if affected_units.is_empty():
		start_cooldown()
		if user.has_method("spend_ap"): user.spend_ap(ap_cost)
		SignalBus.on_combat_action_finished.emit(user)
		return "Howled at nothing."
		
	for u in affected_units:
		# Deal Physical Damage
		u.take_damage_from(5, user, GameManager.DMG_TYPE_PSYCHIC)
		
		# Deal Sanity Damage
		if u.has_method("take_sanity_damage"):
			u.take_sanity_damage(20)
			
		# Apply status? (Optional, plan said Maybe Panic/Vuln, but let's stick to raw stats for now to keep it simple/balanced as requested)
		
	start_cooldown()
	if user.has_method("spend_ap"): user.spend_ap(ap_cost)
	SignalBus.on_combat_action_finished.emit(user)
	return "Shattered Minds!"

func get_ai_score(user, _target, grid_manager) -> float:
	# Score based on number of targets hit
	var center = user.grid_pos
	var radius = 3
	var hits = 0
	
	var tree = grid_manager.get_tree()
	if tree:
		var units = tree.get_nodes_in_group("Units")
		for u in units:
			if u != user and u.get("faction") != user.get("faction") and u.current_hp > 0:
				if center.distance_to(u.grid_pos) <= radius:
					hits += 1
	
	if hits == 0:
		return -1.0
		
	# Base Score 20 per hit
	return hits * 20.0
