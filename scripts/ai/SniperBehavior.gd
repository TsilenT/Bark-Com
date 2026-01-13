extends AIBehaviorBase
class_name SniperBehavior

func evaluate_position(unit, tile: Vector2, target, gm) -> float:
	var score = 0.0

	# Extreme Self Preservation
	var preservation = _get_self_preservation_score(unit, tile, target, gm)
	if preservation > 0:
		score += (preservation * 2.0)  # Cowardly

	# A. Range Goldilocks Zone (8-12)
	var dist = tile.distance_to(target.grid_pos)
	if dist >= 8 and dist <= 12:
		score += 50.0
	elif dist < 6:
		score -= (6.0 - dist) * 10.0  # Get away!

	# B. Seek High Cover ALWAYS
	var my_cover = CombatResolver.get_cover_height_at_pos(tile, target.grid_pos, gm)
	if my_cover >= 2.0:
		score += 100.0
	elif my_cover >= 1.0:
		score += 40.0
	else:
		score -= 50.0  # Hate open ground

	# C. Must have LOS to shoot
	if unit.has_method("check_los"):
		if not unit.check_los(tile, target, gm):
			# Unless we are retreating (Preservation > 0)
			if preservation == 0:
				score -= 200.0  # Useless if can't see

	# D. Flanking Bonus
	var target_cover = CombatResolver.get_cover_height_at_pos(target.grid_pos, tile, gm)
	if target_cover <= 0.0:
		score += 40.0

	return score
