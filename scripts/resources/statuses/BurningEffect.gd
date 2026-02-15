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
	unit.take_damage_from(damage_per_turn, self, GameManager.DMG_TYPE_FIRE)
	GameManager.log(LOG_PREFIX, unit.name, " burns for ", damage_per_turn)
