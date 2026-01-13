extends AIBehaviorBase
class_name RusherBehavior

func evaluate_position(unit, tile: Vector2, target, gm) -> float:
	var score = 0.0

	# Panic Check (Even rushers fear death)
	var preservation = _get_self_preservation_score(unit, tile, target, gm)
	if preservation > 0:
		score += (preservation * 0.5)

	# A. Aggression (Adjacency)
	var dist = tile.distance_to(target.grid_pos)

	# Goal: Dist 1.0
	# Penalty for distance
	score -= (dist * 10.0)

	if dist < 1.5:
		score += 200.0  # Massive bonus for biting range

	# Fallback: If we are stuck (Best tile is current tile, but we aren't in range)
	if dist > 1.5 and tile == unit.grid_pos:
		score -= 50.0  # Discourage standing still if not in range

	# B. Ignore Cover for Self (Beserker)
	# But Value Flanking! (Target has NO cover from me)
	var target_cover_h = CombatResolver.get_cover_height_at_pos(target.grid_pos, tile, gm)
	if target_cover_h <= 0.0:
		score += 30.0

	# C. LOS Check
	if unit.has_method("check_los"):
		if not unit.check_los(tile, target, gm):
			score -= 5.0
	
	return score
