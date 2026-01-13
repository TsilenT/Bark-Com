extends AIBehaviorBase
class_name ControllerBehavior

func evaluate_position(unit, tile: Vector2, target, gm) -> float:
	var score = 0.0

	# Controller wants to survive to keep applying debuffs
	score += _get_self_preservation_score(unit, tile, target, gm)

	# A. Aura Range (Want to be close-ish, ~Range 3)
	var dist = tile.distance_to(target.grid_pos)
	
	if dist <= 3.0:
		score += 30.0 # Good for Aura
	elif dist > 5.0:
		score -= (dist - 5.0) * 5.0 # Too far
		
	# B. LOS?
	# Mind Fracture might require LOS.
	if unit.has_method("check_los"):
		if not unit.check_los(tile, target, gm):
			score -= 20.0 # Prefer LOS but not critical if we have AoEs
			
	# C. Cover (High Priority)
	var cover_h = CombatResolver.get_cover_height_at_pos(tile, target.grid_pos, gm)
	if cover_h >= 1.0:
		score += 40.0
		
	return score
