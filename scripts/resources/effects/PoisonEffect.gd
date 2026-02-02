extends StatusEffect
class_name PoisonEffect


const LOG_PREFIX = "PoisonEffect: "

func _init():
	display_name = "Poisoned"
	description = "Takes 2 Damage at end of turn."
	duration = 3
	type = EffectType.DEBUFF
	icon = preload("res://assets/icons/status/poison.svg")


func on_turn_end(unit: Node):
	super.on_turn_end(unit)
	if unit.has_method("take_damage"):
		GameManager.log(LOG_PREFIX, "Poison dealing damage to ", unit.name)
		if unit.has_method("take_damage_from"):
			unit.take_damage_from(2, null, GameManager.DMG_TYPE_POISON)
		else:
			unit.take_damage(2)
		# Add float text?
		if unit.has_node("Label3D"):  # Quick hack or use FloatingTextManager
			# FloatingTextManager is singleton
			SignalBus.on_request_floating_text.emit(
				unit, "POISON!", Color.GREEN
			)
