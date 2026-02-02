extends "res://scripts/resources/StatusEffect.gd"

const LOG_PREFIX = "ShakeyPawsEffect: "

func _init():
	display_name = "Shakey Paws"
	duration = 2
	type = EffectType.DEBUFF
	description = "Uncontrollable trembling reduces Aim by 20."
	# Fallback icon (Shakey Paws missing)
	icon = preload("res://assets/icons/status/disoriented.svg")

func on_apply(unit: Node):
	GameManager.log(LOG_PREFIX, unit.name, " has Shakey Paws! Aim reduced by 20.")
	# Apply logic usually handled by stats check,
	# but we can modify the modifiers dictionary if Unit supports it.
	# Unit.gd has 'modifiers'.
	if "modifiers" in unit:
		if unit.modifiers.has("aim"):
			unit.modifiers["aim"] -= 20
		else:
			unit.modifiers["aim"] = -20

	SignalBus.on_request_floating_text.emit(
		unit, "SHAKEY PAWS!", Color.LIGHT_CORAL
	)


func on_remove(unit: Node):
	GameManager.log(LOG_PREFIX, unit.name, " recovered from Shakey Paws.")
	if "modifiers" in unit and unit.modifiers.has("aim"):
		unit.modifiers["aim"] += 20
