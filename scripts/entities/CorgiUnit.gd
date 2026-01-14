extends "res://scripts/entities/Unit.gd"
class_name CorgiUnit

# Corgi Specifics
var is_splooting: bool = false
var turns_without_attack: int = 0


func _ready():
	super._ready()


func _setup_visuals():
	# Use UnitVisuals
	if not visuals:
		visuals = UnitVisuals.new()
		visuals.name = "UnitVisuals"
		add_child(visuals)
	
	# Clear Existing (for class changes)
	for c in visuals.get_children():
		c.queue_free()

	# Generate Model
	var Factory = load("res://scripts/utils/CorgiModelFactory.gd")
	# Pass unit_class (e.g. Recruit, Scout) to generate specific accessories
	var gen_data = Factory.generate_corgi(unit_class, visuals)

	# Pass data to Visuals
	visuals.setup(gen_data["anim_player"], gen_data["sockets"])

	# COLLISION SHAPE (Essential for Raycast Selection)
	# Only add if missing (CollisionShape is distinct from Visuals usually, but here it was mixed?)
	# Originally, col was added to 'self' (CorgiUnit), not visuals.
	# So we don't need to re-add collision. 
	# But original code added it here. Check if it already exists.
	if not has_node("CollisionShape3D"):
		var col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var col_shape = CapsuleShape3D.new()
		col_shape.height = 1.0
		col_shape.radius = 0.3
		col.shape = col_shape
		col.position.y = 0.5
		add_child(col)


# Override to update visuals when class changes
func apply_class_stats(cls_name: String):
	super.apply_class_stats(cls_name)
	_setup_visuals()


# --- Abilities ---


# Passive: Low Profile
# This would be called by the Damage/Hit calculation system.
# returns true if this unit benefits from Low Profile
func has_low_profile() -> bool:
	return true


func get_defense_modifier(_cover_type) -> int:
	# Bonus from Low Profile?
	# Implementation: The CombatResolver checks for "CorgiUnit" type directly or we can make it cleaner here.
	# For now, kept logic in CombatResolver as requested, but we can boost base defense.
	return 0


# Active: Sploot
func activate_sploot():
	if is_splooting:
		print(name, " is already splooting!")
		return

	is_splooting = true
	mobility = 0
	print(name, " used SPLOOT! Defense UP, Mobility 0.")
	# In a real system, we'd apply a status effect modifier for Defense here.


func deactivate_sploot():
	if is_splooting:
		is_splooting = false
		mobility = base_mobility
		print(name, " stood up. Mobility restored.")


# Passive: Zoomies
# Should be called at the start of a turn
func check_zoomies_trigger():
	if turns_without_attack >= 3:
		mobility = base_mobility * 2
		print(name, " has ZOOMIES! Mobility doubled to ", mobility)
	else:
		mobility = base_mobility  # Reset if it was doubled last turn and used?
		# Or maybe Zoomies is a one-turn buff? Assuming one turn for now.


# Active: Bark
# AOE Buff
func bark(allies: Array):
	print(name, " used BARK!")
	for ally in allies:
		if ally != self and position.distance_to(ally.position) < 5.0:  # 5 unit radius
			ally.heal_sanity(2)
			print(" - ", ally.name, " feels less afraid.")


func on_attack():
	turns_without_attack = 0


func on_turn_end():
	# If didn't attack this turn (logic to be handled by TurnManager/Actions)
	# For now, manually incrementing for testing
	turns_without_attack += 1
	# Deactivate sploot at start of next turn? Or user toggled?
	# Usually 'Hunker Down' lasts until move or next turn. Let's say user must deactivate or it lasts 1 turn.
	# For now, leaving as toggle.
