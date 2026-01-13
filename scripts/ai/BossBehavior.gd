extends AIBehaviorBase
class_name BossBehavior

func evaluate_position(unit, tile: Vector2, target, gm) -> float:
	var score = 0.0
	
	# Bosses don't care about cover as much (Arrogance)
	# They prefer high ground though
	var elev_bonus = 0.0
	var my_elev = gm.get_tile_data(tile).get("elevation", 0)
	var target_elev = gm.get_tile_data(target.grid_pos).get("elevation", 0)
	if my_elev > target_elev:
		elev_bonus = 50.0
	score += elev_bonus

	# Optimal Range: 3-5
	var dist = tile.distance_to(target.grid_pos)
	if dist >= 3 and dist <= 5:
		score += 40.0
	else:
		score -= abs(dist - 4) * 10
		
	# Line of Sight is Critical
	if unit.has_method("check_los"):
		if not unit.check_los(tile, target, gm):
			score -= 100.0
			
	return score
