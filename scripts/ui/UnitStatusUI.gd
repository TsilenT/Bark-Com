extends Node3D

# UnitStatusUI
# Displays overhead icons (Sprite3D) for active statuses.

var unit
var sprites: Array[Node3D] = []

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
	# 5. Connect Step Completed (Refresh on Move)
	SignalBus.on_unit_step_completed.connect(_on_step_completed)

	call_deferred("_refresh_full")
	
func _exit_tree():
	if SignalBus:
		if SignalBus.on_status_applied.is_connected(_on_status_changed):
			SignalBus.on_status_applied.disconnect(_on_status_changed)
		if SignalBus.on_status_removed.is_connected(_on_status_changed):
			SignalBus.on_status_removed.disconnect(_on_status_changed)
		if SignalBus.on_unit_stats_changed.is_connected(_on_status_changed_wrapper):
			SignalBus.on_unit_stats_changed.disconnect(_on_status_changed_wrapper)
		if SignalBus.on_unit_step_completed.is_connected(_on_step_completed):
			SignalBus.on_unit_step_completed.disconnect(_on_step_completed)

func _on_step_completed(u):
	if u == unit:
		_refresh_full()

func _on_status_changed(_u, _id):
	if _u == unit:
		_refresh_full()

func _on_status_changed_wrapper(u):
	if u == unit:
		_refresh_full()

func _refresh_full():
	if not is_inside_tree(): return
	
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
	
	# 2. Panic State (REMOVED)
	# Panic logic now strictly uses StatusEffects (BerserkEffect, etc) which have their own icons.
	# Checking both caused duplicate icons.
	
	# 3. Cover Status (Holograms)
	var show_cover = true
	# User Request: Hide cover for non-relevant objectives (Treat Bags) but keep for Allies/Enemies/Rescue Targets
	if "faction" in unit and unit.faction == "Neutral":
		# Simple name check for now (Rescue Target is "Lost Human")
		if not ("Human" in unit.name or "Rescue" in unit.name):
			show_cover = false

	# Access GridManager via Group (Safe)
	var gm = get_tree().get_first_node_in_group("GridManager")
	if show_cover and gm and "grid_pos" in unit:
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
	var spacing = 0.6
	var start_x = -(count - 1) * spacing * 0.5
	
	for i in range(count):
		var tex = icons[i]
		
		# 1. Background (Visibility Fix)
		var bg = MeshInstance3D.new()
		var quad = QuadMesh.new()
		quad.size = Vector2(0.4, 0.4) # Slightly larger than icon
		bg.mesh = quad
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0, 0, 0, 0.7) # Semi-transparent black
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA # Fix for Opaque Box
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.render_priority = 9 # Behind icon
		bg.material_override = mat
		
		bg.position = Vector3(start_x + (i * spacing), 2.5, -0.01)
		add_child(bg)
		sprites.append(bg) # Add to list for cleanup
		
		# 2. Icon
		var sprite = Sprite3D.new()
		sprite.texture = tex
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.005
		sprite.position = Vector3(start_x + (i * spacing), 2.5, 0)
		sprite.no_depth_test = true
		sprite.render_priority = 10
		add_child(sprite)
		sprites.append(sprite)


# --------------------------------------------------------------------------
# NEW: Directional Cover Indicators (Holograms)
# --------------------------------------------------------------------------
var cover_indicators: Array[Node3D] = []
var _threat_pos: Vector2 = Vector2(-999, -999) # Grid Position of current attacker (if any)
var _threat_active: bool = false

func set_threat_context(pos: Vector2):
	_threat_pos = pos
	_threat_active = true
	_refresh_full() # Trigger redraw

func clear_threat_context():
	_threat_active = false
	_refresh_full()

func _clear_cover_indicators():
	for c in cover_indicators:
		c.queue_free()
	cover_indicators.clear()

func _update_directional_cover_indicators(gm: Node):
	_clear_cover_indicators()
	
	if not unit: return
	if not unit.is_inside_tree(): return # Wait for tree
	
	# Use new position from Unit
	var pos = unit.grid_pos
	
	# My Elevation (for relative height check)
	var my_elev = 0
	if gm.grid_data.has(pos):
		my_elev = gm.grid_data[pos].get("elevation", 0)
	
	# Attacker Elevation (if active context)
	var attacker_elev = 0
	if _threat_active and gm.grid_data.has(_threat_pos):
		attacker_elev = gm.grid_data[_threat_pos].get("elevation", 0)

	var elevation_advantage = 0
	if _threat_active:
		elevation_advantage = max(0, attacker_elev - my_elev)
	
	# Check 4 Neighbors
	var directions = {
		Vector2(0, -1): 180,   # North (Look -Z)
		Vector2(0, 1): 0,      # South (Look +Z)
		Vector2(1, 0): 90,     # East (Look +X)
		Vector2(-1, 0): -90    # West (Look -X)
	}
	
	# Calculate Base Position using GridManager
	var base_pos = gm.get_world_position(pos)
	
	# Direction to threat (for filtering which wall is affected)
	var dir_to_threat = Vector2.ZERO
	if _threat_active:
		dir_to_threat = (_threat_pos - pos).normalized()
	
	for dir in directions:
		var target = pos + dir
		if gm.grid_data.has(target):
			var tile = gm.grid_data[target]
			var raw_cover = tile.get("cover_height", 0.0)
			
			if raw_cover > 0:
				var n_elev = tile.get("elevation", 0)
				
				# 1. Base Effective Height (Relative to my feet)
				var effective = (n_elev + raw_cover) - my_elev
				
				# 2. Threat Negation
				# If this wall is BETWEEN me and the threat, apply elevation penalty
				if _threat_active and dir_to_threat.dot(dir.normalized()) > 0.7:
					effective -= elevation_advantage
				
				# 3. Determine Visuals
				if effective >= 1.5:
					_spawn_indicator(dir, directions[dir], 2.0, base_pos)
				elif effective >= 0.5:
					_spawn_indicator(dir, directions[dir], 1.0, base_pos)
				# Else: < 0.5 means No Cover (Broken/Hidden)

func _spawn_indicator(dir: Vector2, rot_y: float, height: float, base_pos: Vector3):
	var mesh_inst = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(1.6, 1.0)
	
	mesh_inst.mesh = quad
	
	# Material
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	if height >= 2.0:
		mat.albedo_color = Color(0.2, 1.0, 0.2, 0.4) # Green Transparent
		quad.size.y = 1.6
	else:
		mat.albedo_color = Color(1.0, 1.0, 0.0, 0.4) # Yellow Transparent
		quad.size.y = 0.8
		
	mesh_inst.material_override = mat
	
	# Positioning (Global Space Logic)
	# 1. Add to Scene FIRST (so it has a valid transform context)
	add_child(mesh_inst)
	cover_indicators.append(mesh_inst)

	# 2. Set Top Level (Ignore Parent Transform)
	mesh_inst.set_as_top_level(true)
	
	# 3. Set Global Position (GridManager Based)
	var offset_local = Vector3(dir.x, 0, dir.y) * 0.85
	mesh_inst.global_position = base_pos + Vector3(0, quad.size.y * 0.5, 0) + offset_local
	mesh_inst.global_rotation_degrees.y = rot_y
