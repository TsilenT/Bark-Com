extends "res://scripts/resources/Ability.gd"


const BASE_RADIUS = 2.5
var aoe_radius: float = BASE_RADIUS

func _init():
	display_name = "Rocket Launcher"
	ap_cost = 2
	ability_range = 12
	cooldown_turns = 1 # Cooldown even if charges limited?
	uses_charges = true
	
func get_valid_tiles(grid_manager, user) -> Array[Vector2]:
	return grid_manager.get_tiles_in_radius(user.grid_pos, float(ability_range))
	
func get_hit_chance_breakdown(_grid_manager, _user, _target) -> Dictionary:
	return {
		"hit_chance": 100,
		"breakdown": {"Precision Guided": 100}
	}
	
	
func execute(user, _target_unit, target_pos: Vector2, grid_manager) -> String:
	if charges <= 0:
		print("No rockets left!")
		return "NO_AMMO"
		
	charges -= 1
	var world_pos = grid_manager.get_world_position(target_pos)
	print(user.name, " fires a ROCKET at ", world_pos)
	
	# --- MISSILE ANIMATION ---
	var missile_script = load("res://scripts/vfx/MissileProjectile.gd")
	if missile_script:
		var missile = missile_script.new()
		user.get_tree().root.add_child(missile)
		missile.launch(user.global_position + Vector3(0, 1.5, 0), world_pos)
		await missile.impact
	
	# AOE Logic
	var world_radius = grid_manager.get_world_aoe_radius(aoe_radius)
	
	# Use Cylindrical check to ensure units at the edge (with height diff) are hit
	var units = grid_manager.get_units_in_radius_cylindrical(world_pos, world_radius, 3.0)
	
	for unit in units:
		# Friendly Fire is ENABLED for Rockets
		unit.take_damage_from(6, user, GameManager.DMG_TYPE_EXPLOSION)
		
		# Shred Armor
		var shred = load("res://scripts/resources/statuses/ShreddedArmorStatus.gd").new()
		unit.apply_effect(shred)
		
	# Detonate Explosives (Barrels)
	var destructibles = user.get_tree().get_nodes_in_group("Destructible")
	for obj in destructibles:
		var target_obj = obj
		if obj is StaticBody3D:
			target_obj = obj.get_parent()
			
		if not is_instance_valid(target_obj):
			continue
			
		# Check distance
		var obj_pos_2d = Vector2(target_obj.global_position.x, target_obj.global_position.z)
		var center_2d = Vector2(world_pos.x, world_pos.z)
		
		if obj_pos_2d.distance_to(center_2d) <= world_radius:
			target_obj.take_damage_from(999, user, GameManager.DMG_TYPE_EXPLOSION) # INSTANT DETONATION

	# Deduct AP
	if user.has_method("spend_ap"):
		user.spend_ap(ap_cost)
		
	start_cooldown()
	SignalBus.on_combat_action_finished.emit(user)
	return "ROCKET AWAY!"
		
	# Destroy Cover? (Requires GridManager logic for cover destruction)
	# grid_manager.destroy_cover_at_world(target_pos, 2.0)
	
	# VFX
	SignalBus.on_request_vfx.emit("Explosion", world_pos, Vector3.ZERO, null, null)
	
	user.spend_ap(ap_cost)
	start_cooldown()
	SignalBus.on_combat_action_finished.emit(user)
	return "ROCKET"
