extends GrenadeToss


func _init():
	super._init()
	display_name = "Throw Grenade"
	ap_cost = 1  # Item usage cost is handled by Unit.use_item
	ability_range = 5
	cooldown_turns = 0  # Items don't have cooldowns, just count
	charges = 1 # Force validity
