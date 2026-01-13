extends AIBehaviorBase
class_name InfiltratorBehavior

func evaluate_position(unit, tile: Vector2, target, gm) -> float:
	var score = 0.0
	var dist = tile.distance_to(target.grid_pos)
	
	if dist <= 1.5:
		score += 300.0 # Ambush!
	else:
		# Approach
		score -= (dist * 5.0) 
		
		# Concealment: Prefer tiles with NO LOS to target
		if unit.has_method("check_los"):
			if not unit.check_los(tile, target, gm):
				score += 100.0 # Stay hidden while approaching
			else:
				score -= 50.0 # Exposed!
				
	return score
