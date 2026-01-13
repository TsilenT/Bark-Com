extends AIBehaviorBase
class_name AreaDenialBehavior

func evaluate_position(unit, tile: Vector2, target, gm) -> float:
	var score = 0.0

	# Standard Preservation
	score += _get_self_preservation_score(unit, tile, target, gm)

	# A. Range Preference (Medium-Long: 4-6)
	var dist = tile.distance_to(target.grid_pos)
	if dist >= 4 and dist <= 6:
		score += 40.0
	elif dist < 3:
		score -= 10.0 # Don't want to get melee'd
	elif dist > 7:
		score -= (dist - 7) * 5.0 # Move closer

	# B. LOS Limit
	if unit.has_method("check_los"):
		if not unit.check_los(tile, target, gm):
			score -= 50.0 # Need to see to spit

	# C. Cover (Moderate)
	var cover_h = CombatResolver.get_cover_height_at_pos(tile, target.grid_pos, gm)
	if cover_h >= 1.0:
		score += 20.0

	return score
