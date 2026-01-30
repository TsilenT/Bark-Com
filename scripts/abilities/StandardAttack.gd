extends Ability
class_name StandardAttack

func _init():
	display_name = "Shoot"
	ap_cost = 1 # Standard cost, can be modified by Unit logic
	ability_range = -1 # Use Weapon Range
	# description = "Fire primary weapon."

func get_valid_tiles(grid_manager, user) -> Array[Vector2]:
	var valid: Array[Vector2] = []
	var r = 50 # Max Range
	
	if not user or not user.is_inside_tree():
		return valid
		
	var tree = user.get_tree()
	
	# 1. Enemies
	# Start with all units, filter by faction
	var units = tree.get_nodes_in_group("Units")
	for u in units:
		if is_instance_valid(u) and "current_hp" in u and u.current_hp > 0:
			if "faction" in u and "faction" in user:
				var is_enemy = (u.faction != user.faction)
				var is_friendly_heal = (u.faction == user.faction and user.get("primary_weapon") and user.primary_weapon.display_name == "Syringe Gun")
				
				if is_enemy or is_friendly_heal:
					# Enemy or Heal Target found
					# OBJECTIVE SAFEGUARD (Units)
					if user.faction == "Player":
						if u.is_in_group("Objectives") or u.is_in_group("TreatBags"):
							continue

				if u.get("grid_pos") and u.grid_pos.distance_to(user.grid_pos) <= r:
					valid.append(u.grid_pos)
	
	# 2. Destructibles (Barrels, Cover, Doors)
	var destructibles = tree.get_nodes_in_group("Destructible")
	for d in destructibles:
		# Resolve Object
		var obj = d
		if d is StaticBody3D: obj = d.get_parent()
		
		if is_instance_valid(obj) and "grid_pos" in obj:
			# OBJECTIVE SAFEGUARD
			if user.faction == "Player":
				if obj.is_in_group("Objectives") or obj.is_in_group("TreatBags"):
					# Skip Friendly Objectives
					continue
			
			if obj.grid_pos.distance_to(user.grid_pos) <= r:
				if not valid.has(obj.grid_pos):
					valid.append(obj.grid_pos)
					
	return valid

func get_hit_chance_breakdown(grid_manager, user, target) -> Dictionary:
	# Delegate to CombatResolver for centralized rules (Infinite Range, Falloff, etc)
	# CombatResolver.calculate_hit_chance handles all modifiers.
	return CombatResolver.calculate_hit_chance(user, target, grid_manager)


func execute(user, target, grid_pos, grid_manager):
	# Delegate to Main's combat processing via Signal or Direct Call?
	# The Controller calls Main._execute_ability.
	# Main._execute_ability calls ability.execute.
	# So we should call Main._process_combat here? 
	# Or implement combat logic here? 
	# Combat logic is complex (Animation, Damage, Death).
	# Ideally, Main._process_combat handles the heavy lifting.
	# So we can return a "request" or call back to Main.
	
	# BUT `Ability.execute` is usually async.
	# Let's call `user.attack(target)` if it exists?
	# OR `Main` has `_process_combat(target_unit)`.
	
	# If we are refactoring, we should probably move `_process_combat` logic eventually.
	# For "Standardize Legacy", let's wrap the legacy call.
	
	# Current Architecture Issue: `Ability.execute` returns a result string.
	# Main._execute_ability expects this.
	
	# Hack: Call Main._process_combat directly? No, that's circular if passed Main.
	# Controller implementation of `_handle_ability_click` calls `main_node._execute_ability(selected_ability...)`.
	# If we use StandardAttack, `_execute_ability` will call `execute`.
	
	# Temporary Solution:
	# If we have access to Main (via user? no), or if we pass it? 
	# execute signature is (user, target, grid_pos, grid_manager).
	# We don't have Main.
	
	# Maybe we return a special signal/string that Main interprets?
	# OR we replicate `_process_combat` logic here?
	# `_process_combat` does `user.play_anim("Shoot")`, `target.take_damage`, etc.
	
	# Let's try to delegate back to Main?
	# Main._execute_ability checks ability type? No.
	
	# Let's make `StandardAttack` emit a signal via SignalBus?
	# `SignalBus.on_request_combat.emit(user, target)`?
	# Then Main listens and runs `_process_combat`.
	
	# Let's add `on_request_standard_attack` to SignalBus?
	# Placeholder execution if this is ever called directly
	print("StandardAttack Executed.")
	if user.has_method("spend_ap"):
		user.spend_ap(ap_cost)
	
	SignalBus.on_combat_action_finished.emit(user)
	return "Attack Initiated"
