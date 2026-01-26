extends "res://scripts/resources/Ability.gd"

const BASE_RADIUS = 1.0

func _init():
	display_name = "Acid Spit"
	description = "Spits acid that creates a hazardous zone."
	ap_cost = 1 # or 2?
	cooldown_turns = 2
	ability_range = 6
	icon_path = "res://assets/icons/abilities/acid.svg" # Placeholder

func execute(user, target, target_tile: Vector2, gm: GridManager):
	print(user.name, " uses Acid Spit on ", target_tile)
	
	# Visuals (Spit Projectile)
	# Ideally we await this, but Execute is often fire-and-forget or handled by signal?
	# We can spawn a separate helper for the animation or signal global VFX.
	# For now, simplistic animation skip or signal.
	
	# Logic: Spawn Hazard
	var center = target_tile
	var offsets = [
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(-1, 0),
		Vector2(0, 1),
		Vector2(0, -1),
		Vector2(1, 1),
		Vector2(1, -1),
		Vector2(-1, 1),
		Vector2(-1, -1)
	]
	
	var scene_root = user.get_tree().current_scene
	
	for offset in offsets:
		var tile = center + offset
		if gm.grid_data.has(tile):
			var zone = load("res://scripts/entities/HazardZone.gd").new()
			scene_root.add_child(zone)
			zone.initialize(tile, gm)
			
	SignalBus.on_request_floating_text.emit(
		gm.get_world_position(center), "ACID SPLASH!", Color.LIME
	)
	
	# Trigger Cooldown
	start_cooldown()

# Scoring logic for AI
func get_ai_score(user, target, gm: GridManager) -> float:
	if current_cooldown > 0: return -100.0
	
	var score = 0.0
	var dist = user.grid_pos.distance_to(target.grid_pos)
	if dist <= ability_range:
		score += 50.0
		# Bonus if target is clumped?
		var world_radius = gm.get_world_aoe_radius(BASE_RADIUS)
		var neighbors = gm.get_units_in_radius_cylindrical(target.global_position, world_radius, 3.0)
		if neighbors.size() > 1:
			score += 30.0 * neighbors.size()
			
	return score
