extends Ability
class_name HackAbility


func _init():
	display_name = "Hack"
	ap_cost = 1
	ability_range = 1  # Base
	cooldown_turns = 1  # Prevent spam? Or unlimited if AP allows? 1 turn cooldown seems fair.


func get_valid_tiles(grid_manager: GridManager, user) -> Array[Vector2]:
	var valid: Array[Vector2] = []

	# Determine Range based on Tech Score
	# Scouts (Tech > 0) get range 5. Others get 1.
	# Determine Range based on Tech Score (Scaled)
	# Base 1.5 (Adjacent) + 0.2 per Tech
	# Tech 10 -> 3.5 Range. Tech 20 -> 5.5 Range.
	var tech = 0
	if "tech_score" in user:
		tech = user.tech_score
		
	var effective_range = 1.5 + (float(tech) * 0.2)

	# Find Terminals
	var terminals = user.get_tree().get_nodes_in_group("Terminals")
	for t in terminals:
		if is_instance_valid(t) and not t.is_hacked:
			if t.grid_pos.distance_to(user.grid_pos) <= effective_range:
				valid.append(t.grid_pos)

	return valid



func get_hit_chance_breakdown(_grid_manager, user, _target) -> Dictionary:
	var tech = user.tech_score if "tech_score" in user else 0
	var base = 70
	var chance = clamp(base + tech, 0, 100)
	
	var breakdown = {
		"Base Tech Chance": base,
		"Tech Bonus": tech
	}
	
	return {
		"hit_chance": chance,
		"breakdown": breakdown
	}


func execute(user, target_unit, target_tile: Vector2, grid_manager: GridManager) -> String:
	# Resolve Target
	var terminal = null

	# Target might be passed as target_unit if it was clicked directly and processed by Main
	if target_unit and target_unit.is_in_group("Terminals"):
		terminal = target_unit
	else:
		# Find terminal at grid pos
		var terminals = user.get_tree().get_nodes_in_group("Terminals")
		for t in terminals:
			if t.grid_pos == target_tile:
				terminal = t
				break

	if not terminal:
		return "No Terminal found!"
	if terminal.is_hacked:
		return "Already Hacked!"

	if not user.spend_ap(ap_cost):
		return "Not enough AP!"

	# Calculate Chance (Visual only, Logic is in Terminal)
	var tech = user.tech_score if "tech_score" in user else 0
	var chance = 70 + tech
	print(user.name, " using HACK ABILITY on ", terminal.name)

	# VFX: Datapad Beam?
	SignalBus.on_combat_action_started.emit(user, terminal, "Hack", terminal.position)

	# Execute via Terminal (Unified Logic)
	var success = terminal.hack(user)

	if success:
		SignalBus.on_combat_action_finished.emit(user)
		return "Hack Successful!"
	else:
		SignalBus.on_combat_action_finished.emit(user)
		return "Hack Failed!"
