extends AIBehaviorBase
class_name TankBehavior

func evaluate_position(unit, tile: Vector2, target, gm) -> float:
	var score = 0.0

	# Slow Advance
	var dist = tile.distance_to(target.grid_pos)
	score -= (dist * 5.0) 
	
	if dist <= 1.5:
		score += 100.0 # Melee range
		
	# Fearless: No self preservation score
	
	return score
