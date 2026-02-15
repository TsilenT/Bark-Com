extends "res://scripts/resources/Ability.gd"

const BASE_RADIUS = 2.5
	
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
	# Tile size is 2.0. So 2.5 tiles = 5.0 units.
	var world_radius = gm.get_world_aoe_radius(BASE_RADIUS)
	
	var victims = gm.get_units_in_radius_cylindrical(user.global_position, world_radius, 3.0)
	
	for v in victims:
		if v != user:
			v.take_damage_from(8, user, GameManager.DMG_TYPE_EXPLOSION)
			
	# Damage Destructible Props (Walls, Barrels)
	var props = user.get_tree().get_nodes_in_group("Destructible")
	for p in props:
		var target_obj = p
		if p is StaticBody3D:
			target_obj = p.get_parent()
			
		# check if valid and in radius
		if is_instance_valid(target_obj) and target_obj.global_position.distance_to(user.global_position) <= world_radius:
			# Avoid double dipping if it somehow counted as a Unit (e.g. Barrel in both groups)
			if victims.has(target_obj):
				continue
				
			target_obj.take_damage_from(8, user, GameManager.DMG_TYPE_EXPLOSION)
			
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
