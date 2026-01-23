extends Node3D

@export var grid_manager: Node

var tile_meshes = {}  # coord: Vector2 -> MeshInstance3D


func _ready():
	if not grid_manager:
		# Try to find it if not assigned
		grid_manager = get_node("../GridManager")

	if grid_manager:
		grid_manager.grid_generated.connect(_on_grid_generated)
	else:
		push_error("GridVisualizer: GridManager not found!")
		
	_setup_lof_visuals()


# Enum matching LevelGenerator
enum Biome { INDOORS, GARDEN, STREET }


func _on_grid_generated():
	clear_visuals()
	visualize_grid()
	_setup_lof_visuals() # Re-create LOF container after clear


func clear_visuals():
	for child in get_children():
		child.queue_free()
	tile_meshes.clear()





func show_highlights(tiles: Array, color: Color):
	# Optimization: Use shader highlight on existing tiles instead of new geometry
	# First, clear old highlights (reset shader params on ALL tiles)
	# This might be slow if we iterate all 400 tiles. 
	# Better: Keep track of currently highlighted tiles.
	
	clear_highlights()
	
	for tile_entry in tiles:
		var coord = Vector2.ZERO
		if tile_entry is Vector2:
			coord = tile_entry
		elif tile_entry is Dictionary and tile_entry.has("world_pos"):
			# Convert back to grid coord? Or just find tile at pos?
			# GridVisualizer is keyed by Coord.
			if grid_manager:
				coord = grid_manager.get_grid_coord(tile_entry["world_pos"])
		
		if tile_meshes.has(coord):
			var tile = tile_meshes[coord]
		if tile_meshes.has(coord):
			var tile = tile_meshes[coord]
			if tile.has_method("show_highlight"):
				tile.show_highlight(true, color)
				_highlighted_tiles.append(coord)

# We need a way to track highlighted tiles to clear them efficiently without iterating all 400.
var _highlighted_tiles = []

func clear_highlights():
	# Clear previous highlights
	for coord in _highlighted_tiles:
		if tile_meshes.has(coord):
			var tile = tile_meshes[coord]
			if tile.has_method("show_highlight"):
				tile.show_highlight(false)
	_highlighted_tiles.clear()
	
	# Also clear old node-based highlights if any exist (legacy support)
	var existing = get_node_or_null("Highlights")
	if existing:
		existing.free()



func visualize_grid():
	var data = grid_manager.grid_data

	# Preload MapTile
	var map_tile_scene = preload("res://scenes/map/MapTile.tscn")

	for coord in data:
		var tile = data[coord]
		var type = tile["type"]
		var is_walkable = tile["is_walkable"]
		var elevation = tile.get("elevation", 0)
		var biome = tile.get("biome", 1) # Default Garden

		# Instantiate MapTile
		var map_tile = map_tile_scene.instantiate()
		if not map_tile:
			push_error("Failed to instantiate MapTile!")
			continue
			
		add_child(map_tile)
		
		# Initialize (Positions and Visuals)
		if map_tile.has_method("initialize"):
			map_tile.initialize(coord, biome, type, elevation, is_walkable, grid_manager)
		
		# Store reference
		tile_meshes[coord] = map_tile
		
		# Manual Collision for Raycast (Still needed for interactions)
		# NOTE: MapTile doesn't have collision by default to keep it light?
		# Actually, we should check if MapTile handles its own physics.
		# The plan said "No physics process", but static bodies are fine.
		# For now, we ADD the collider here to ensure existing input logic works.
		# Ideally MapTile scene should have it, but we kept it minimal.
		# Let's add the collider as a child of MapTile so it moves with it.
		
		var static_body = StaticBody3D.new()
		static_body.name = "TileBody_" + str(coord)
		var collision_shape = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		
		# Determine shape size based on type (Ramp/Ladder logic from before)
		if type == GridManager.TileType.RAMP:
			# Ramps need special collision or just a block for clicking?
			# Detailed ramp collision is better for cursor height.
			# For now, box is "okay" if centered correctly, but let's stick to simple box.
			shape.size = Vector3(1.8, 1.0, 1.8) # Taller for ramp?
			collision_shape.position.y = 0.5
		elif type == GridManager.TileType.LADDER:
			shape.size = Vector3(0.6, 2.5, 0.2)
		else:
			# Standard Ground
			shape.size = Vector3(1.8, 0.2, 1.8) # Matches visual thickness
			
		collision_shape.shape = shape
		static_body.add_child(collision_shape)
		map_tile.add_child(static_body)
		
		# Important: Set Meta for clicking logic
		static_body.set_meta("grid_coord", coord)

		
		# Debug Label (Optional)
		# map_tile.set_debug_text("W" if is_walkable else "X")


func reset_vision():
	for coord in tile_meshes:
		var mesh = tile_meshes[coord]
		mesh.visible = false


func reveal_visible(coord: Vector2):
	if tile_meshes.has(coord):
		var tile = tile_meshes[coord]
		if tile.has_method("set_vision_state"):
			tile.set_vision_state(true, false)
		else:
			tile.visible = true # Fallback

func reveal_fogged(coord: Vector2):
	if tile_meshes.has(coord):
		var tile = tile_meshes[coord]
		if tile.has_method("set_vision_state"):
			tile.set_vision_state(true, true)
		else:
			tile.visible = true # Fallback


# AI Debugging
var score_labels = {}  # coord: Vector2 -> Label3D


func show_debug_score(coord: Vector2, score: float):
	if not tile_meshes.has(coord):
		return

	var label: Label3D
	if score_labels.has(coord):
		label = score_labels[coord]
	else:
		label = Label3D.new()
		label.font_size = 64
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color.YELLOW
		tile_meshes[coord].add_child(label)
		label.position = Vector3(0, 2.5, 0)
		score_labels[coord] = label

	label.text = str(int(score))
	label.visible = true


func clear_debug_scores():
	for coord in score_labels:
		score_labels[coord].visible = false

	# Clear Debug Lines
	if has_node("DebugLines"):
		get_node("DebugLines").queue_free()


func draw_ai_intent(from: Vector3, to: Vector3, color: Color):
	var lines_node
	if has_node("DebugLines"):
		lines_node = get_node("DebugLines")
	else:
		lines_node = MeshInstance3D.new()
		lines_node.name = "DebugLines"
		lines_node.mesh = ImmediateMesh.new()
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		lines_node.material_override = mat
		add_child(lines_node)

	var mesh = lines_node.mesh as ImmediateMesh
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, lines_node.material_override)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(from + Vector3(0, 1, 0))
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(to + Vector3(0, 1, 0))
	mesh.surface_end()


func preview_path(points: Array, color: Color = Color.CYAN):
	clear_preview_path()
	
	if points.size() < 2:
		return

	var lines_node = MeshInstance3D.new()
	lines_node.name = "PreviewPath"
	lines_node.mesh = ImmediateMesh.new()
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color # Fallback
	lines_node.material_override = mat
	add_child(lines_node)

	var mesh = lines_node.mesh as ImmediateMesh
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	
	for p in points:
		var pos = p
		if p is Vector2:
			pos = grid_manager.get_world_position(p)
		
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(pos + Vector3(0, 0.5, 0)) # Lift slightly
		
	mesh.surface_end()


func clear_preview_path():
	var existing = get_node_or_null("PreviewPath")
	if existing:
		existing.free()


func show_hover_cursor(grid_pos: Vector2):
	clear_hover_cursor()
	
	if not grid_manager:
		return
		
	var world_pos = grid_manager.get_world_position(grid_pos)
	
	var cursor = MeshInstance3D.new()
	cursor.name = "HoverCursor"
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.7, 0.15, 1.7) # Slightly larger/thicker than highlights
	cursor.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.6 # Pop!
	cursor.material_override = mat
	
	cursor.position = world_pos + Vector3(0, 0.65, 0) # Just above highlights
	add_child(cursor)


func clear_hover_cursor():
	var existing = get_node_or_null("HoverCursor")
	if existing:
		existing.free()


func preview_aoe(tiles: Array, color: Color = Color(1, 0, 0, 0.4)):
	clear_preview_aoe()
	
	if tiles.is_empty():
		return
		
	var container = Node3D.new()
	container.name = "PreviewAoE"
	add_child(container)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.4 
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.6, 0.2, 1.6) # Slightly thicker/distinct
	
	for tile_entry in tiles:
		var world_pos = Vector3.ZERO
		if tile_entry is Vector2:
			if grid_manager:
				world_pos = grid_manager.get_world_position(tile_entry)
		elif tile_entry is Dictionary and tile_entry.has("world_pos"):
			world_pos = tile_entry["world_pos"]
			
		if world_pos != Vector3.ZERO:
			var mi = MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			mi.position = world_pos + Vector3(0, 0.7, 0) # Raise above cursor
			container.add_child(mi)

func clear_preview_aoe():
	var existing = get_node_or_null("PreviewAoE")
	if existing:
		existing.free()

# --- LOF Visuals ---
var lof_node: Node3D

func _setup_lof_visuals():
	lof_node = Node3D.new()
	lof_node.name = "LOF_Container"
	add_child(lof_node)

func draw_lof(from: Vector3, to: Vector3, color: Color = Color.RED):
	if not lof_node: return
	
	# Clear previous
	for c in lof_node.get_children():
		c.queue_free()
		
	# Create Thick Line (Cylinder)
	var mesh_inst = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.05
	cylinder.bottom_radius = 0.05
	
	var dist = from.distance_to(to)
	cylinder.height = dist
	
	mesh_inst.mesh = cylinder
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.8
	mesh_inst.material_override = mat
	
	lof_node.add_child(mesh_inst)
	
	# Orient
	# Cylinder is upright (Y-axis), we need to rotate it to face 'to' from 'from'
	# Midpoint
	mesh_inst.position = (from + to) / 2.0
	
	# LookAt logic:
	# look_at aligns Z axis. Cylinder is Y axis.
	# We need to rotate Cylinder so its Y aligns with (to - from).
	# This is slightly tricky. Easy way: Use BoxMesh, or transform.
	
	if dist > 0.001:
		mesh_inst.look_at_from_position(mesh_inst.position, to, Vector3.UP)
		mesh_inst.rotate_object_local(Vector3.RIGHT, deg_to_rad(-90))


func clear_lof():
	if lof_node:
		for c in lof_node.get_children():
			c.queue_free()

# --- Cover Icons ---
var cover_icons = {} # coord -> Node3D

func update_cover_icons(cover_data: Dictionary): # coord -> type
	clear_cover_icons()
	
	for coord in cover_data:
		var type = cover_data[coord]
		var icon = _create_cover_icon(type)
		add_child(icon)
		# Safety check for grid_manager
		if grid_manager:
			icon.position = grid_manager.get_world_position(coord) + Vector3(0, 1.8, 0)
		else:
			icon.position = Vector3(coord.x * 2, 1.8, coord.y * 2) # Fallback
		cover_icons[coord] = icon

func clear_cover_icons():
	for coord in cover_icons:
		var icon = cover_icons[coord]
		if is_instance_valid(icon):
			icon.queue_free()
	cover_icons.clear()

func _create_cover_icon(type):
	var mesh_inst = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	mesh_inst.mesh = quad
	
	var mat = StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var texture_path = ""
	var fallback_color = Color.WHITE
	
	if type == GridManager.TileType.COVER_FULL: # GREEN
		texture_path = "res://assets/ui/shield_icon_full.svg"
		fallback_color = Color.GREEN
	elif type == GridManager.TileType.COVER_HALF: # YELLOW
		texture_path = "res://assets/ui/shield_icon_half.svg"
		fallback_color = Color.YELLOW
	
	if texture_path != "":
		# Try load standard
		if ResourceLoader.exists(texture_path):
			mat.albedo_texture = load(texture_path)
			mat.albedo_color = Color.WHITE
		else:
			# Just in case headless fails or file missing
			mat.albedo_color = fallback_color
	else:
		mat.albedo_color = fallback_color
		
	mesh_inst.material_override = mat
	return mesh_inst

# --- Predictive Cover Icon (Movement Preview) ---
var predictive_icon: Node3D
var last_predictive_coord: Vector2 = Vector2(-999, -999)
var last_predictive_type: int = -1

func show_predictive_cover_icon(coord: Vector2, type: int):
	# Optimization: Don't recreate if same state
	if predictive_icon and is_instance_valid(predictive_icon) and coord == last_predictive_coord and type == last_predictive_type:
		return

	# Clear previous
	clear_predictive_cover_icon()
	
	if type == 0: return
	
	var icon = _create_cover_icon(type)
	icon.name = "PredictiveCoverIcon"
	add_child(icon)
	predictive_icon = icon
	last_predictive_coord = coord
	last_predictive_type = type
	
	# Position above cursor
	if grid_manager:
		icon.position = grid_manager.get_world_position(coord) + Vector3(0, 2.5, 0)
		
	# visual pulse?
	# FIX: Bind tween to the icon so it cleans up automatically
	var tween = create_tween().set_loops()
	tween.bind_node(icon) 
	tween.tween_property(icon, "scale", Vector3(1.2, 1.2, 1.2), 0.5)
	tween.tween_property(icon, "scale", Vector3(1.0, 1.0, 1.0), 0.5)

func clear_predictive_cover_icon():
	if predictive_icon:
		if is_instance_valid(predictive_icon):
			predictive_icon.queue_free()
		predictive_icon = null
	last_predictive_coord = Vector2(-999, -999)
	last_predictive_type = -1
