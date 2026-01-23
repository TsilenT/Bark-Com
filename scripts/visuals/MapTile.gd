extends Node3D
class_name MapTile

# Components
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D if has_node("Label3D") else null

# State
var grid_pos: Vector2
var _base_color: Color = Color.WHITE

func _ready():
	# Optimization: Disable Processing
	set_process(false)
	set_physics_process(false)
	
func initialize(pos: Vector2, biome: int, type: int, elevation: int, is_walkable: bool, gm: Node = null):
	if not mesh_instance:
		mesh_instance = get_node_or_null("MeshInstance3D")
		
	if not mesh_instance:
		push_error("MapTile: MeshInstance3D missing at " + str(pos))
		return

	grid_pos = pos
	position = Vector3(pos.x * 2.0, elevation, pos.y * 2.0)
	
	_setup_visuals(biome, type, gm)
	
	# Initial State
	set_walkable(is_walkable)
	
	# Default to hidden (Vision system will reveal)
	visible = false

func _setup_visuals(biome: int, type: int, gm: Node):
	# Biome Colors
	match biome:
		0: _base_color = Color(0.8, 0.75, 0.7) # INDOORS
		1: _base_color = Color(0.2, 0.6, 0.2) # GARDEN
		2: _base_color = Color(0.3, 0.3, 0.3) # STREET
		
	# Geometry & Type Specifics
	if type == GridManager.TileType.RAMP and gm:
		_base_color = Color(0.6, 0.5, 0.3)
		
		# Create Ramp Mesh
		var ramp = PrismMesh.new()
		ramp.left_to_right = 1.0 # Wedge
		ramp.size = Vector3(1.8, 1.0, 2.0)
		mesh_instance.mesh = ramp
		
		# Orientation Logic
		var neighbors = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]
		for n in neighbors:
			var target = grid_pos + n
			if gm.grid_data.has(target):
				var n_elev = gm.grid_data[target].get("elevation", 0)
				var n_type = gm.grid_data[target].get("type", 0)
				# If neighbor is higher and NOT a ramp (so we lean against a wall/block)
				if n_elev > gm.grid_data[grid_pos].get("elevation", 0) and n_type != GridManager.TileType.RAMP:
					if n == Vector2(1, 0): mesh_instance.rotation_degrees.y = 0
					elif n == Vector2(-1, 0): mesh_instance.rotation_degrees.y = 180
					elif n == Vector2(0, 1): mesh_instance.rotation_degrees.y = -90
					elif n == Vector2(0, -1): mesh_instance.rotation_degrees.y = 90
					break

	elif type == GridManager.TileType.LADDER and gm:
		_base_color = Color(0.5, 0.3, 0.1)
		var ladder = BoxMesh.new()
		ladder.size = Vector3(0.6, 2.5, 0.2)
		mesh_instance.mesh = ladder
		
		# Orientation Logic
		var neighbors = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]
		for n in neighbors:
			var target = grid_pos + n
			if gm.grid_data.has(target) and gm.grid_data[target].get("elevation", 0) > gm.grid_data[grid_pos].get("elevation", 0):
				# Move slightly towards wall
				mesh_instance.position += Vector3(n.x, 0, n.y) * 0.4
				if n.x != 0: mesh_instance.rotation_degrees.y = 90
				break
				
	elif type == GridManager.TileType.OBSTACLE and gm:
		# WALL
		_base_color = Color(0.2, 0.2, 0.2) # Dark/Black
		var wall = BoxMesh.new()
		wall.size = Vector3(2.0, 2.0, 2.0) # Full Block
		mesh_instance.mesh = wall
		mesh_instance.position.y = 1.0 # Center up
	
	else:
		# Standard Box
		var box = BoxMesh.new()
		box.size = Vector3(2.0, 0.2, 2.0)
		mesh_instance.mesh = box
		
	# Apply Base Color
	_update_visual_state(false, false)

func set_walkable(walkable: bool):
	# Optional: Visual indicator?
	pass

func set_vision_state(is_visible: bool, is_fogged: bool):
	visible = is_visible or is_fogged
	_update_visual_state(is_visible, is_fogged)

func _update_visual_state(is_visible: bool, is_fogged: bool):
	# We use Instance Shader Parameters to drive appearance
	# "color_mod" -> vec4
	
	var final_color = _base_color
	if is_fogged:
		# Desaturate manually: Lerp towards grayscale equivalent
		var gray = final_color.r * 0.299 + final_color.g * 0.587 + final_color.b * 0.114
		var gray_color = Color(gray, gray, gray)
		final_color = final_color.lerp(gray_color, 0.5).darkened(0.5)
		
	# Set the parameter on the geometry instance
	# This avoids duplicating the material resource
	mesh_instance.set_instance_shader_parameter("albedo_mod", final_color)

func show_highlight(active: bool, color: Color = Color.WHITE):
	# Toggle highlight
	# Optimization: Use a float param "highlight_strength" 0.0 or 1.0
	mesh_instance.set_instance_shader_parameter("highlight_strength", 1.0 if active else 0.0)
	mesh_instance.set_instance_shader_parameter("highlight_color", color)
