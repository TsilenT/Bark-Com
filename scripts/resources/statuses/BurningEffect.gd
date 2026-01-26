extends StatusEffect
class_name BurningEffect

const LOG_PREFIX = "BurningEffect: "

var damage_per_turn: int = 2

func _init():
	display_name = "Burning"
	description = "Takes 2 Damage at start of turn."
	duration = 2
	type = EffectType.DEBUFF
	icon = preload("res://assets/icons/status/burning.svg")

func on_apply(unit: Node):
	GameManager.log(LOG_PREFIX, unit.name, " caught FIRE!")
	SignalBus.on_request_floating_text.emit(
		unit, "BURNING!", Color.ORANGE
	)

func on_turn_start(unit: Node):
	if unit.has_method("take_damage"):
		unit.take_damage(damage_per_turn)
		GameManager.log(LOG_PREFIX, unit.name, " burns for ", damage_per_turn)
