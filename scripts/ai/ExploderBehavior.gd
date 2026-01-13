extends AIBehaviorBase
class_name ExploderBehavior

func evaluate_position(unit, tile: Vector2, target, gm) -> float:
	var score = 0.0

	# 1. Be Adjacent!
	var dist = tile.distance_to(target.grid_pos)
	
	if dist <= 1.5:
		score += 500.0 # MAIN GOAL
	else:
		score -= (dist * 20.0) # Get closer ASAP
		
	# 2. Ignore Cover
	# 3. Ignore Safety (Suicidal)
	
	return score
