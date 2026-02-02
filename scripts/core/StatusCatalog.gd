class_name StatusCatalog

# Hardcoded references to ensure export inclusions

const STATUSES = [
	"res://scripts/resources/statuses/BurningEffect.gd",
	"res://scripts/resources/statuses/ConfusedStatus.gd",
	"res://scripts/resources/statuses/ShreddedArmorStatus.gd",
	"res://scripts/resources/statuses/SitStayStatus.gd",
	"res://scripts/resources/statuses/SlowedStatus.gd",
	"res://scripts/resources/statuses/SuppressedStatus.gd",
	"res://scripts/resources/statuses/VulnerableStatus.gd",
	"res://scripts/resources/statuses/sanity/FrozenEffect.gd",
	"res://scripts/resources/statuses/sanity/ShakeyPawsEffect.gd",
	"res://scripts/resources/statuses/sanity/PanicRunEffect.gd",
	"res://scripts/resources/statuses/sanity/BerserkEffect.gd"
]

const EFFECTS = [
	"res://scripts/resources/effects/ArmorBuffEffect.gd",
	"res://scripts/resources/effects/DisorientedEffect.gd",
	"res://scripts/resources/effects/GoodBoyBuff.gd",
	"res://scripts/resources/effects/PoisonEffect.gd",
	"res://scripts/resources/effects/StunEffect.gd"
]

static func get_all_statuses() -> Array:
	return _instantiate_list(STATUSES)

static func get_all_effects() -> Array:
	return _instantiate_list(EFFECTS)

static func _instantiate_list(path_list: Array) -> Array:
	var instances = []
	for path in path_list:
		var script_res = load(path)
		if script_res:
			instances.append(script_res.new())
	return instances
