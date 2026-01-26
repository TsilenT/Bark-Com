extends StatusEffect
class_name StunEffect


const LOG_PREFIX = "StunEffect: "

func _init():
	display_name = "Stunned"
	description = "Cannot act (0 AP)."
	duration = 1
	type = EffectType.DEBUFF
	icon = preload("res://assets/icons/status/stun.svg")


func on_apply(unit: Node):
	GameManager.log(LOG_PREFIX, unit.name, " is STUNNED!")
	SignalBus.on_request_floating_text.emit(
		unit, "STUNNED!", Color.YELLOW
	)
	if unit.get("current_ap") != null:
		unit.current_ap = 0
		SignalBus.on_unit_stats_changed.emit(unit)


func on_turn_start(unit: Node):
	# Drain AP
	if unit.get("current_ap") != null:
		unit.current_ap = 0
		GameManager.log(LOG_PREFIX, "Stun drained AP from ", unit.name)
		SignalBus.on_request_floating_text.emit(
			unit, "NO AP!", Color.YELLOW
		)
