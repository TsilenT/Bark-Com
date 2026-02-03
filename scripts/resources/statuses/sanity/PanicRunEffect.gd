extends "res://scripts/resources/StatusEffect.gd"

const LOG_PREFIX = "PanicRunEffect: "

func _init():
	display_name = "Fleeing"
	duration = 2 # Duration 2 ensures visibility persists through turn start decrement
	type = EffectType.DEBUFF # Implicitly debuff akin to Panic
	description = "Unit is terrified and will run from enemies."
	icon = preload("res://assets/icons/status/panic_run.svg") 

func on_apply(unit: Node):
	GameManager.log(LOG_PREFIX, unit.name, " is Fleeing!")
	SignalBus.on_request_floating_text.emit(unit, "FLEEING", Color.ORANGE)

func on_turn_start(unit: Node):
	pass
