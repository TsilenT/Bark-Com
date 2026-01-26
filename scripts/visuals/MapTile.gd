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
	
	_setup_visuals(biome, type, elevation, gm)
	
	# Initial State
	set_walkable(is_walkable)
	
	# Default to hidden (Vision system will reveal)
	visible = false

func _setup_visuals(biome: int, type: int, elevation: int, gm: Node):
	# 1. Apply Biome Colors (Default)
	_apply_biome_visuals(biome)
		
	# Geometry & Type Specifics (Can override color)
	if type == GridManager.TileType.RAMP and gm:
		_base_color = Color(0.6, 0.5, 0.3)
		
		# Create Ramp Mesh
		var ramp = PrismMesh.new()
		ramp.left_to_right = 1.0 # Wedge
		ramp.size = Vector3(1.8, 1.0, 2.0)
		mesh_instance.mesh = ramp
		mesh_instance.position.y = 0.5
		
		# Orientation Logic (Context Aware)
		# We want to find the direction that represents "Up Slope".
		# This connects a Lower/Equal tile to a Higher tile.
		# Check all 4 dirs and score them.
		var best_score = -999
		var best_dir = Vector2(1, 0) # Default East
		
		var dirs = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
		
		for d in dirs:
			var score = 0
			var target = grid_pos + d
			var source = grid_pos - d
			
			var my_elev = elevation
			if gm.grid_data.has(grid_pos): my_elev = gm.grid_data[grid_pos].get("elevation", 0)

			# Score Target (Upward connection)
			if gm.grid_data.has(target):
				var t_elev = gm.grid_data[target].get("elevation", 0)
				# Reward higher target
				if t_elev > my_elev: score += 2
				elif t_elev == my_elev: score += 0 # Neutral
				else: score -= 5 # Penalty for pointing at lower tile (Cliff)
			else:
				score -= 2 # Edge of map

			# Score Source (Downward connection)
			if gm.grid_data.has(source):
				var s_elev = gm.grid_data[source].get("elevation", 0)
				# Reward lower source (or equal)
				if s_elev < my_elev: score += 1
				elif s_elev == my_elev: score += 1 # Good connector
				else: score -= 2 # Penalty for source being higher (V-shape)
			
			if score > best_score:
				best_score = score
				best_dir = d
				
		# Apply Rotation based on Best Dir
		if best_dir == Vector2(1, 0): mesh_instance.rotation_degrees.y = 0
		elif best_dir == Vector2(-1, 0): mesh_instance.rotation_degrees.y = 180
		elif best_dir == Vector2(0, 1): mesh_instance.rotation_degrees.y = -90
		elif best_dir == Vector2(0, -1): mesh_instance.rotation_degrees.y = 90

	elif type == GridManager.TileType.LADDER and gm:
		# 1. Floor Mesh (Standard Ground Logic)
		# We want the floor to look like normal ground (Biome Color)
		# _base_color is already set by _apply_biome_visuals at top of function
		
		var thickness = 0.2
		var height = thickness
		var offset_y = 0.0
		
		# Allow Elevation extension (Columns)
		if elevation > 0:
			height = (elevation * 1.0) + thickness
			offset_y = (thickness / 2.0) - (height / 2.0)
			
		var floor_box = BoxMesh.new()
		floor_box.size = Vector3(2.0, height, 2.0)
		mesh_instance.mesh = floor_box
		mesh_instance.position.y = offset_y
		
		# 2. Ladder Prop
		var ladder_node = MeshInstance3D.new()
		var ladder = BoxMesh.new()
		ladder.size = Vector3(0.6, 2.5, 0.2)
		ladder_node.mesh = ladder
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.3, 0.1) # Wood
		ladder_node.material_override = mat
		
		# Orientation Logic
		var neighbors = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]
		for n in neighbors:
			var target = grid_pos + n
			if gm.grid_data.has(target) and gm.grid_data[target].get("elevation", 0) > gm.grid_data[grid_pos].get("elevation", 0):
				# Move slightly towards wall
				ladder_node.position += Vector3(n.x, 0, n.y) * 0.9 # Push to edge (Tile radius is 1.0)
				if n.x != 0: ladder_node.rotation_degrees.y = 90
				break
		
		add_child(ladder_node)
				
	elif type == GridManager.TileType.OBSTACLE and gm:
		# WALL
		_base_color = Color(0.2, 0.2, 0.2) # Dark/Black
		var wall = BoxMesh.new()
		wall.size = Vector3(2.0, 2.0, 2.0) # Full Block
		mesh_instance.mesh = wall
		mesh_instance.position.y = 1.0 # Center up
		
	elif (type == GridManager.TileType.COVER_FULL or type == GridManager.TileType.COVER_HALF) and gm:
		# STATIC COVER (Indestructible)
		# Only render if NOT marked as destructible in data (Main spawns those)
		# We check 'destructible' flag from GridManager.
		var is_destructible = false
		if gm.grid_data.has(grid_pos):
			is_destructible = gm.grid_data[grid_pos].get("destructible", false)
			
		if not is_destructible:
			# Render Static Cover Mesh
			var cvr = BoxMesh.new()
			if type == GridManager.TileType.COVER_FULL:
				cvr.size = Vector3(1.8, 2.0, 1.8) # Tall Block
				_base_color = Color(0.4, 0.4, 0.45) # Concrete
				mesh_instance.position.y = 1.0
			else:
				cvr.size = Vector3(1.8, 1.0, 1.8) # Half Block
				_base_color = Color(0.5, 0.5, 0.55) # Concrete/Stone low wall
				mesh_instance.position.y = 0.5
				
			mesh_instance.mesh = cvr
		

	
	else:
		# Standard Ground (Pillar for Elevation)
		# Extends downwards from surface to keep "Cliff" solid.
		var thickness = 0.2
		var height = thickness
		var offset_y = 0.0
		
		if elevation > 0:
			# Height from Surface (0) down to Ground (-elevation)
			height = (elevation * 1.0) + thickness
			# Mesh centered at (Top + Bottom) / 2
			# Top is thickness/2. Bottom is -elevation - thickness/2.
			# Actually, if we want surface at Y=0 (local Node), and BoxMesh centers on its Origin...
			# We want Top of Box to be at +thickness/2.
			# Center Y = (thickness/2) - (height/2)
			# = 0.1 - (height/2).
			# If height = 1.2 (Elev 1), Center = 0.1 - 0.6 = -0.5. Checks out.
			offset_y = (thickness / 2.0) - (height / 2.0)
			
		var box = BoxMesh.new()
		box.size = Vector3(2.0, height, 2.0)
		mesh_instance.mesh = box
		mesh_instance.position.y = offset_y
		
	# 3. Apply Elevation Tint
	# Higher = Brighter / "Closer to Sun" (Subtle)
	if mesh_instance and elevation > 0:
		_base_color = _base_color.lightened(0.1 * min(elevation, 5)) # Cap brightness gain

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


# --- VISUAL VARIETY ---

func _apply_biome_visuals(biome: int):
	# Mapping Biome to Visuals
	
	match biome:
		LevelGenerator.Biome.GARDEN: # GARDEN (Grass) -> Richer Green
			_base_color = Color(0.2, 0.6, 0.2) 
		LevelGenerator.Biome.STREET: # STREET (Asphalt) -> Darker, slightly blue
			_base_color = Color(0.2, 0.2, 0.25) 
		LevelGenerator.Biome.INDOORS: # INDOORS (Tile) -> Cleaner, warmer
			_base_color = Color(0.8, 0.75, 0.6) 
		LevelGenerator.Biome.SNOW: # SNOW -> Bright White/Blue
			_base_color = Color(0.9, 0.95, 1.0)
		LevelGenerator.Biome.DESERT: # DESERT -> Sand Yellow
			_base_color = Color(0.9, 0.8, 0.5)
		_:
			# Fallback
			_base_color = Color(0.8, 0.75, 0.7)
