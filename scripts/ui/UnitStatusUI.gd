extends Node3D

# UnitStatusUI
# Displays overhead icons (Sprite3D) for active statuses.

var unit
var sprites: Array[Sprite3D] = []

# Panic Icons
const PANIC_ICONS = {
	1: preload("res://assets/icons/status/panic_freeze.svg"),
	2: preload("res://assets/icons/status/panic_run.svg"),
	3: preload("res://assets/icons/status/panic_berserk.svg")
}

func _ready():
	unit = get_parent()
	if not unit:
		queue_free()
		return

	# Connect Signals
	SignalBus.on_status_applied.connect(_on_status_changed)
	SignalBus.on_status_removed.connect(_on_status_changed)
	# Assuming panic changes triggers stats changed or we might need a specific panic signal?
	# Usually Panic adds a status or we check each turn. 
	# For now, let's hook into stats changed too just in case.
	SignalBus.on_unit_stats_changed.connect(_on_status_changed_wrapper)

	_refresh_full()
	
func _exit_tree():
	if SignalBus:
		if SignalBus.on_status_applied.is_connected(_on_status_changed):
			SignalBus.on_status_applied.disconnect(_on_status_changed)
		if SignalBus.on_status_removed.is_connected(_on_status_changed):
			SignalBus.on_status_removed.disconnect(_on_status_changed)
		if SignalBus.on_unit_stats_changed.is_connected(_on_status_changed_wrapper):
			SignalBus.on_unit_stats_changed.disconnect(_on_status_changed_wrapper)


func _on_status_changed(_u, _id):
	if _u == unit:
		_refresh_full()

func _on_status_changed_wrapper(u):
	if u == unit:
		_refresh_full()

func _refresh_full():
	# Clear existing
	for s in sprites:
		s.queue_free()
	sprites.clear()

	var icons_to_show = []

	# 1. Active Effects
	if "active_effects" in unit:
		for eff in unit.active_effects:
			if "icon" in eff and eff.icon:
				icons_to_show.append(eff.icon)
	
	# 2. Panic State
	if "current_panic_state" in unit and unit.current_panic_state != 0:
		if PANIC_ICONS.has(unit.current_panic_state):
			icons_to_show.append(PANIC_ICONS[unit.current_panic_state])

	# 3. Cover Status (Holograms)
	# Access GridManager via Group (Safe)
	var gm = get_tree().get_first_node_in_group("GridManager")
	if gm and "grid_pos" in unit:
		_update_directional_cover_indicators(gm)
	else:
		_clear_cover_indicators()

	# 4. High Ground (Elevation > 0)
	var elev = 0
	if gm and gm.grid_data.has(unit.grid_pos):
		elev = gm.grid_data[unit.grid_pos].get("elevation", 0)
	
	# Allow unit override (e.g. Flying)
	if unit.has_method("get_elevation_offset"):
		elev += unit.get_elevation_offset()
		
	if elev > 0:
		if ResourceLoader.exists("res://assets/ui/high_ground.svg"):
			icons_to_show.append(load("res://assets/ui/high_ground.svg"))

	_create_icons(icons_to_show)


func _create_icons(icons: Array):
	if icons.is_empty():
		return

	var count = icons.size()
	var spacing = 0.6 # Adjust based on icon size
	var start_x = -(count - 1) * spacing * 0.5
	
	for i in range(count):
		var tex = icons[i]
		var sprite = Sprite3D.new()
		sprite.texture = tex
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.005
		sprite.position = Vector3(start_x + (i * spacing), 2.5, 0)
		sprite.no_depth_test = true # Ensure visible on top?
		sprite.render_priority = 10 # Draw on top of unit
		add_child(sprite)
		sprites.append(sprite)


# --------------------------------------------------------------------------
# NEW: Directional Cover Indicators (Holograms)
# --------------------------------------------------------------------------
var cover_indicators: Array[Node3D] = []

func _clear_cover_indicators():
	for c in cover_indicators:
		c.queue_free()
	cover_indicators.clear()

func _update_directional_cover_indicators(gm: Node):
	_clear_cover_indicators()
	
	if not unit: return
	var pos = unit.grid_pos
	
	# Check 4 Neighbors
	var directions = {
		Vector2(0, -1): 0,   # North
		Vector2(0, 1): 180,  # South
		Vector2(1, 0): -90,  # East
		Vector2(-1, 0): 90   # West
	}
	
	for dir in directions:
		var target = pos + dir
		if gm.grid_data.has(target):
			var h = gm.grid_data[target].get("cover_height", 0.0)
			if h > 0:
				_spawn_indicator(dir, directions[dir], h)

func _spawn_indicator(dir: Vector2, rot_y: float, height: float):
	var mesh_inst = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(1.6, 1.0) # Wide but not full tile width
	
	mesh_inst.mesh = quad
	
	# Material
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED # Double sided
	
	if height >= 2.0:
		mat.albedo_color = Color(0.2, 1.0, 0.2, 0.4) # Green Transparent
		quad.size.y = 1.6 # Taller
	else:
		mat.albedo_color = Color(1.0, 1.0, 0.0, 0.4) # Yellow Transparent
		quad.size.y = 0.8
		
	# Texture (Hologrrid pattern?)
	# Ideally we load a texture, but color is fine for MVP.
	
	mesh_inst.material_override = mat
	
	# Positioning
	# Move to Edge: 1.0 unit in 'dir' direction from center?
	# Tile size is 2.0. So center to edge is 1.0.
	# We want it slightly INSIDE the tile so it doesn't clip walls.
	var offset = Vector3(dir.x, 0, dir.y) * 0.85 
	mesh_inst.position = offset + Vector3(0, quad.size.y * 0.5, 0)
	
	# Rotation
	mesh_inst.rotation_degrees.y = rot_y
	
	# Add to scene
	add_child(mesh_inst)
	cover_indicators.append(mesh_inst)
