extends "res://scripts/entities/EnemyUnit.gd"

var is_cloaked: bool = true

func _ready():
	super._ready()
	mobility = 7
	_load_behavior(8) # INFILTRATOR
	
	SignalBus.on_combat_action_started.connect(_on_action_started)
	
	# Initial Visual
	# Wait for mesh to be ready?
	await get_tree().process_frame
	_update_camo_visuals()

func on_turn_start(all_units = [], grid_manager = null):
	super.on_turn_start(all_units, grid_manager)
	# Re-cloak at start of turn
	is_cloaked = true
	_update_camo_visuals()

func _on_action_started(unit, target, type, pos):
	if unit == self:
		if type == "Attack":
			is_cloaked = false
			_update_camo_visuals()
			# Floating Text
			SignalBus.on_request_floating_text.emit(self, "REVEALED!", Color.RED)

func _update_camo_visuals():
	var mesh = get_node_or_null("Mesh")
	if not mesh: return
	
	if not mesh.material_override:
		mesh.material_override = StandardMaterial3D.new()
		
	var mat = mesh.material_override
	if is_cloaked:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.1, 0.1, 0.1, 0.2) # Ghostly dark
	else:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.albedo_color = Color(0.2, 0.2, 0.2, 1.0) # Dark Gray
