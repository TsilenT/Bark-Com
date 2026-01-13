extends Resource
class_name AIBehaviorBase

# Evaluate a specific tile position for the unit against a target
func evaluate_position(unit, tile: Vector2, target, grid_manager) -> float:
	return 0.0

# Optional: Determine if this behavior prefers a specific action *instead* of moving
func get_special_action(unit, grid_manager) -> Dictionary:
	return {}

# Helper: Standard target evaluation
func evaluate_target(unit, target, grid_manager) -> float:
	var score = 0.0
	# Base distance logic?
	return score

func _get_self_preservation_score(unit, tile: Vector2, target, gm) -> float:
	if unit.current_hp > (unit.max_hp * 0.3):
		return 0.0
	
	var score = 0.0
	var dist = tile.distance_to(target.grid_pos)
	
	# 1. Run Away
	score += (dist * 10.0)
	
	# 2. Break LOS (Hide)
	if unit.has_method("check_los"):
		if not unit.check_los(tile, target, gm):
			score += 500.0
			
	# 3. Seek Cover matches
	var cover = CombatResolver.get_cover_height_at_pos(tile, target.grid_pos, gm)
	score += (cover * 50.0)
	
	return score
