class_name ClassIconManager
extends RefCounted

const SHEET_PATH = "res://assets/ui/class_icons_sheet.jpg"

# Cache
static var _atlas_texture: Texture2D
static var _icons = {}

static func clear_cache():
	_icons.clear()

static func get_class_icon(c_name: String) -> Texture2D:
	if _icons.has(c_name):
		return _icons[c_name]
		

		
	# Format path: class_gunner.svg, class_medic.svg, etc.
	# c_name input might be "Gunner", "Medic". Need to lower case.
	
	# Detect Enemy status from name or known list
	var is_enemy = false
	if "Enemy" in c_name or "Rusher" in c_name or "Spitter" in c_name or "Whisperer" in c_name:
		is_enemy = true

	# Helper: Clean up enemy names if they come in as "ExploderEnemy"
	var clean_name = c_name.replace("Enemy", "").replace("Unit", "")
	
	# Mapping for special cases
	var file_name = "class_" + clean_name.to_lower()
	
	# Append _enemy suffix if it's a conflict class (Sniper, Tank) AND it's an enemy
	# OR just always append _enemy for enemies to be safe and consistent?
	# User wants "distinctly different".
	# Let's force suffix for shared names: Sniper, Tank.
	if is_enemy and (clean_name == "Sniper" or clean_name == "Tank" or clean_name == "Heavy"):
		file_name += "_enemy"
	
	# Note: "Heavy" maps to "class_heavy" naturally now.
		
	# Handle Bosses
	if "Dogthulhu" in c_name:
		file_name = "class_boss"
		
	var path = "res://assets/ui/icons/" + file_name + ".svg"
	
	if ResourceLoader.exists(path):
		var tex = load(path)
		_icons[c_name] = tex
		return tex
	else:
		# Fallback to Recruit if not found
		if c_name != "Recruit":
			return get_class_icon("Recruit")
		else:
			push_error("ClassIconManager: Default icon not found at " + path)
			return null
