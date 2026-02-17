extends Ability

# TENTACLE LASH
# A partially ranged melee attack that pulls the target closer.
# Range: 3 Tiles
# Damage: 12
# Effect: Pull 1 Tile
# Cost: 1 AP (Cheap to allow Move+Lash or Lash+Melee)
# Cooldown: 1 Turn (Frequent use)

func _init():
	display_name = "Tentacle Lash"
	description = "Lash out (Range 3). Deals 12 DMG and pulls target closer."
	ap_cost = 1
	cooldown_turns = 1
	ability_range = 3

func get_valid_tiles(grid_manager, user) -> Array[Vector2]:
	var tiles: Array[Vector2] = []
	var start = user.grid_pos
	
	# Simple Manhattan or Euclidean? Grid is Euclidean usually for range
	for x in range(-ability_range, ability_range + 1):
		for y in range(-ability_range, ability_range + 1):
			var pos = start + Vector2(x,y)
			if start.distance_to(pos) <= ability_range and start.distance_to(pos) > 1.0: # Min range 1? No, can lash adjacent too.
				if grid_manager.grid_data.has(pos):
					# Check for unit?
					var u = grid_manager.get_unit_at_grid_pos(pos)
					if u and u != user and u.get("faction") != user.get("faction"):
						tiles.append(pos)
	return tiles

func execute(user, target, target_grid, grid_manager) -> String:
	if not target: return "No Target"
	
	print(user.name, " Lashes ", target.name)
	
	# 1. Damage
	target.take_damage_from(12, user, GameManager.DMG_TYPE_MELEE)
	
	# 2. Pull Logic
	if target.current_hp > 0:
		var direction = (user.grid_pos - target.grid_pos).normalized()
		# Snap to grid step
		var pull_vec = Vector2(round(direction.x), round(direction.y))
		# If diagonal, maybe just pick one axis if strict grid?
		# Let's try raw pull 1 tile towards user.
		
		var new_pos = target.grid_pos + pull_vec
		
		# Validate New Pos
		if grid_manager.is_walkable(new_pos) and not grid_manager.get_unit_at_grid_pos(new_pos):
			# Move Unit
			grid_manager.move_unit(target, new_pos)
			if SignalBus:
				SignalBus.on_request_floating_text.emit(target, "PULLED!", Color.ORANGE)
		else:
			if SignalBus:
				SignalBus.on_request_floating_text.emit(target, "BLOCKED", Color.GRAY)
				
	start_cooldown()
	if user.has_method("spend_ap"): user.spend_ap(ap_cost)
	SignalBus.on_combat_action_finished.emit(user)
	return "Tentacle Lash Hit"

func get_ai_score(user, target, grid_manager) -> float:
	var dist = user.grid_pos.distance_to(target.grid_pos)
	if dist > ability_range:
		return -1.0
		
	# High priority if target is just outside melee range (dist 2 or 3)
	if dist > 1.5:
		return 35.0
	else:
		return 15.0 # Adjacent lash is okay, but melee might be better
