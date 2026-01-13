extends AIBehaviorBase
class_name FlyingBehavior

func evaluate_position(unit, tile: Vector2, target, gm) -> float:
	var score = 0.0

	# High Mobility Flanker
	var target_cover = CombatResolver.get_cover_height_at_pos(target.grid_pos, tile, gm)
	if target_cover <= 0.0:
		score += 80.0 # Love Flanking
		
	# Range (Close-Medium)
	var dist = tile.distance_to(target.grid_pos)
	if dist <= 5:
		score += 20.0
	else:
		score -= (dist * 2.0)
		
	# Elevation Bonus?
	# GridManager handles elevation, but flyers might prefer high ground
	var my_elev = gm.get_tile_data(tile).get("elevation", 0)
	var target_elev = gm.get_tile_data(target.grid_pos).get("elevation", 0)
	if my_elev > target_elev:
		score += 30.0
		
	return score
