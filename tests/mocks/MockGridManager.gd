extends GridManager
class_name MockGridManager



func get_random_valid_position() -> Vector2:
	return Vector2(randi_range(10, 15), randi_range(10, 15))

func get_world_position(grid_pos: Vector2) -> Vector3:
	return Vector3(grid_pos.x * 2, 0, grid_pos.y * 2)

func is_valid_tile(pos: Vector2) -> bool:
	return true
	

