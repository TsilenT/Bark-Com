extends "res://scripts/resources/StatusEffect.gd"

const LOG_PREFIX = "BerserkEffect: "

func _init():
	display_name = "Berserk"
	duration = 2 # Duration 2 ensures visibility persists through turn start decrement
	type = EffectType.DEBUFF
	description = "Unit attacks the nearest target (friend or foe)."
	icon = preload("res://assets/icons/status/panic_berserk.svg")

func on_apply(unit: Node):
	GameManager.log(LOG_PREFIX, unit.name, " goes BERSERK!")
	SignalBus.on_request_floating_text.emit(unit, "BERSERK", Color.RED)
