extends "res://scripts/resources/Ability.gd"

func _init():
	display_name = "Self Destruct"
	cooldown_turns = 0
	ap_cost = 1
	ability_range = 1
	
func execute(user, target, target_tile: Vector2, gm: GridManager):
	print(user.name, " EXPLODES!")
	
	# VFX
	SignalBus.on_request_vfx.emit("Explosion", user.position, Vector3.ZERO, null, null)
	SignalBus.on_request_floating_text.emit(user.position, "BOOM!", Color.ORANGE)
	
	# Damage Radius (approx 2.5 tiles)
	var radius = 2.5 * 2.0 # Converted to World Units? GM.get_units_in_radius_world takes world units.
	# Tile size is 2.0. So 2.5 tiles = 5.0 units.
	
	var victims = gm.get_units_in_radius_world(user.global_position, 5.0)
	
	for v in victims:
		if v != user:
			v.take_damage(8)
			
	# Kill User
	if user.has_method("die"):
		user.die()
	else:
		user.queue_free()

func get_ai_score(user, target, gm) -> float:
	# Only explode if we can hit target (handled by range check usually)
	# But checking density is good
	var dist = user.grid_pos.distance_to(target.grid_pos)
	if dist <= 1.5:
		return 1000.0 # DO IT
	return 0.0
