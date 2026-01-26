extends "res://scripts/resources/StatusEffect.gd"

const LOG_PREFIX = "FrozenEffect: "

func _init():
	display_name = "Frozen"
	duration = 1


func on_apply(unit: Node):
	GameManager.log(LOG_PREFIX, unit.name, " is Frozen in fear! Cannot move.")
	if "current_ap" in unit:
		unit.current_ap = 0

	SignalBus.on_request_floating_text.emit(unit, "FROZEN", Color.BLUE)


func on_turn_start(unit: Node):
	# Re-apply AP removal if it persists across turns
	if "current_ap" in unit:
		unit.current_ap = 0
		GameManager.log(LOG_PREFIX, unit.name, " is still Frozen.")
