extends "res://scripts/resources/StatusEffect.gd"

const LOG_PREFIX = "FrozenEffect: "

func _init():
	display_name = "Frozen"
	duration = 2 # Duration 2 ensures it survives the immediate decrement on turn start
	type = EffectType.DEBUFF
	description = "Unit is paralyzed by fear. Cannot move or act."
	icon = preload("res://assets/icons/status/panic_freeze.svg")

func on_apply(unit: Node):
	GameManager.log(LOG_PREFIX, unit.name, " is Frozen in fear! Cannot move.")
	if "current_ap" in unit:
		unit.current_ap = 0

	SignalBus.on_request_floating_text.emit(unit, "FROZEN", Color.CYAN)


func on_turn_start(unit: Node):
	# Re-apply AP removal if it persists across turns
	# GUARD: Only remove AP if unit is ACTUALLY in Freeze Panic State (1)
	# This prevents "Zombie" effects (removed but waiting for cleanup) from stealing a turn.
	if "current_panic_state" in unit and unit.current_panic_state == 1: # PanicState.FREEZE
		if "current_ap" in unit:
			unit.current_ap = 0
			GameManager.log(LOG_PREFIX, unit.name, " is still Frozen.")
