extends AIBehaviorBase
class_name GenericBehavior

func evaluate_position(unit, tile: Vector2, target, gm) -> float:
	var score = 0.0

	# Self Preservation Mod
	score += _get_self_preservation_score(unit, tile, target, gm)

	# A. Distance logic
	var ideal = 4
	var dist = tile.distance_to(target.grid_pos)
	var deviation = abs(dist - ideal)
	score -= (deviation * 5.0)

	# B. Defensive Cover
	var cover_h = CombatResolver.get_cover_height_at_pos(tile, target.grid_pos, gm)
	if cover_h >= 2.0:
		score += 30.0
	elif cover_h >= 1.0:
		score += 15.0

	# C. Flanking
	var target_cover_h = CombatResolver.get_cover_height_at_pos(target.grid_pos, tile, gm)
	if target_cover_h <= 0.0:
		score += 30.0
		# If flanking but no LOS, penalty
		if unit.has_method("check_los"):
			if not unit.check_los(tile, target, gm):
				score -= 20.0
	else:
		# If no flank and no LOS, penalty depends on distance
		if unit.has_method("check_los"):
			if not unit.check_los(tile, target, gm):
				if dist < 4:
					score -= 100.0  # Must see target at close range
				else:
					score -= 20.0  # Okay to lose sight while maneuvering far away

	# D. Hit Chance (Simulated)
	# We can't easily simulate hit chance for a hypothetical tile without calling CombatResolver
	# CombatResolver.calculate_hit_chance takes 'from_pos'
	var combat_data = CombatResolver.calculate_hit_chance(unit, target, gm, tile)
	var hit_chance = combat_data["hit_chance"]
	if hit_chance >= 50:
		score += (hit_chance * 0.5)
	elif hit_chance < 30:
		score -= 20.0

	return score
