extends AIBehaviorBase
class_name DogthulhuBehavior

# Aggressive Boss Behavior
# 1. Prioritizes maximizing targets for AoE (Howl).
# 2. Uses Lash to pull kiters.
# 3. Closes distance aggressively (Melee preference).

func evaluate_position(unit, tile: Vector2, target, gm) -> float:
	var score = 0.0
	var dist = tile.distance_to(target.grid_pos)
	
	# 1. OPTIMAL RANGE
	if dist <= 1.5:
		score += 100.0 # Melee Range is KING
	elif dist <= 3.0:
		score += 50.0 # Lash/Howl Range is Good
	else:
		# Penalty for being far
		score -= (dist * 5.0)

	# 3. MOMENTUM
	var current_dist = unit.grid_pos.distance_to(target.grid_pos)
	if dist < current_dist:
		score += 20.0
		
	return score

# Override special action scoring if needed? 
# AIBehaviorBase doesn't have score_action.
# EnemyUnit handles that.

