extends Node3D
class_name MapTile

# Components
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D if has_node("Label3D") else null

# State
var grid_pos: Vector2

# Visual State Tracking
var _current_biome: int = 1 # Default Garden
var _current_elevation: int = 0
var _is_fogged: bool = false

const MaterialCacheScript = preload("res://scripts/utils/MaterialCache.gd")

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
	# Store State for MaterialCache
	_current_biome = biome
	_current_elevation = elevation
	_is_fogged = false # Reset
	
	# Geometry & Type Specifics (Can override material completely)
	var custom_color = null
	
	if type == GridManager.TileType.RAMP and gm:
		# Biome Colors for Ramps
		match biome:
			LevelGenerator.Biome.GARDEN: custom_color = Color(0.3, 0.45, 0.25) # Garden
			LevelGenerator.Biome.OFFICE: custom_color = Color(0.6, 0.5, 0.3) # Office (Wood/Carpet?)
			LevelGenerator.Biome.DESERT: custom_color = Color(0.75, 0.65, 0.5) # Desert
			LevelGenerator.Biome.SNOW: custom_color = Color(0.7, 0.85, 0.95) # Snow
			_: custom_color = Color(0.2, 0.25, 0.3) # Street (Asphalt/Dark Metal)

		# Persist this color for fog updates!
		if not has_meta("biome_color_override"):
			set_meta("biome_color_override", custom_color)
		else:
			# Update it just in case setup called again
			set_meta("biome_color_override", custom_color)
		
		# Create Ramp Mesh
		var ramp = PrismMesh.new()
		ramp.left_to_right = 1.0 # Wedge
		ramp.size = Vector3(1.8, 1.0, 2.0)
		mesh_instance.mesh = ramp
		mesh_instance.position.y = 0.5
		
		# Orientation Logic
		var best_score = -999
		var best_dir = Vector2(1, 0)
		var dirs = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
		
		for d in dirs:
			var score = 0
			var target = grid_pos + d
			var source = grid_pos - d
			
			var my_elev = elevation
			if gm.grid_data.has(grid_pos): my_elev = gm.grid_data[grid_pos].get("elevation", 0)

			if gm.grid_data.has(target):
				var t_elev = gm.grid_data[target].get("elevation", 0)
				if t_elev > my_elev: score += 2
				elif t_elev == my_elev: score += 0
				else: score -= 5
			else:
				score -= 2

			if gm.grid_data.has(source):
				var s_elev = gm.grid_data[source].get("elevation", 0)
				if s_elev < my_elev: score += 1
				elif s_elev == my_elev: score += 1
				else: score -= 2
			
			if score > best_score:
				best_score = score
				best_dir = d
				
		if best_dir == Vector2(1, 0): mesh_instance.rotation_degrees.y = 0
		elif best_dir == Vector2(-1, 0): mesh_instance.rotation_degrees.y = 180
		elif best_dir == Vector2(0, 1): mesh_instance.rotation_degrees.y = -90
		elif best_dir == Vector2(0, -1): mesh_instance.rotation_degrees.y = 90

	elif type == GridManager.TileType.LADDER and gm:
		# Floor logic matches Standard Ground (uses Cache via _update_visual_state later)
		var thickness = 0.2
		var height = thickness
		var offset_y = 0.0
		
		if elevation > 0:
			height = (elevation * 1.0) + thickness
			offset_y = (thickness / 2.0) - (height / 2.0)
			
		var floor_box = BoxMesh.new()
		floor_box.size = Vector3(2.0, height, 2.0)
		mesh_instance.mesh = floor_box
		mesh_instance.position.y = offset_y
		
		# Ladder Prop
		var ladder_node = MeshInstance3D.new()
		var ladder = BoxMesh.new()
		ladder.size = Vector3(0.6, 2.5, 0.2)
		ladder_node.mesh = ladder
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.3, 0.1) # Wood
		ladder_node.material_override = mat
		
		var neighbors = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]
		for n in neighbors:
			var target = grid_pos + n
			if gm.grid_data.has(target) and gm.grid_data[target].get("elevation", 0) > gm.grid_data[grid_pos].get("elevation", 0):
				ladder_node.position += Vector3(n.x, 0, n.y) * 0.9
				if n.x != 0: ladder_node.rotation_degrees.y = 90
				break
		add_child(ladder_node)
				
	elif type == GridManager.TileType.OBSTACLE and gm:
		# --- HIGH FIDELITY BIOME OBSTACLES ---
		# Uses PropBuilder to generate composite meshes
		
		var pb = load("res://scripts/builders/PropBuilder.gd").new()
		pb.start()
		
		# Default Grey
		custom_color = Color(0.2, 0.2, 0.2) 

		match biome:
			1: # GARDEN (Overgrown Stone Wall)
				custom_color = Color(0.35, 0.3, 0.25)
				# Main Wall
				pb.add_box(Vector3(0, 1.0, 0), Vector3(2.0, 2.0, 2.0), custom_color)
				# Vines / Leaves
				for i in range(8):
					var p = Vector3(randf_range(-1.0, 1.0), randf_range(0.5, 1.8), 1.05 * (1 if randf() > 0.5 else -1))
					if i % 2 == 0: # Side flip
						p = Vector3(1.05 * (1 if randf() > 0.5 else -1), p.y, randf_range(-1.0, 1.0))
					
					pb.add_box(p, Vector3(0.4, 0.4, 0.2), Color(0.1, 0.4, 0.1), Vector3(randf()*45, randf()*45, 0))

			0: # INDOORS (Server Mainframe)
				custom_color = Color(0.1, 0.1, 0.12)
				# Main Tower
				pb.add_box(Vector3(0, 1.0, 0), Vector3(1.8, 2.0, 1.8), custom_color)
				# Vents (Top)
				pb.add_box(Vector3(0, 1.9, 0), Vector3(1.4, 0.05, 1.4), Color(0.05, 0.05, 0.05))
				# Glowing Light Strips (Vertical)
				pb.add_box(Vector3(-0.8, 1.0, 0.91), Vector3(0.1, 1.8, 0.05), Color(0.0, 0.5, 1.0))
				pb.add_box(Vector3(0.8, 1.0, 0.91), Vector3(0.1, 1.8, 0.05), Color(0.0, 0.5, 1.0))
				# Data Banks (Rows of lights)
				for i in range(4):
					var y = 0.5 + i * 0.4
					pb.add_box(Vector3(0, y, 0.91), Vector3(1.0, 0.2, 0.02), Color(0.1, 0.2, 0.3))
					# Active LEDs
					pb.add_box(Vector3(-0.35 + randf()*0.7, y, 0.92), Vector3(0.05, 0.05, 0.05), Color(0.2, 1.0, 0.2))

			4: # DESERT (Sandstone Ruin Wall - Modular)
				custom_color = Color(0.7, 0.6, 0.5)
				# Blocky construction to tile well
				# Base Block
				pb.add_box(Vector3(0, 0.5, 0), Vector3(2.0, 1.0, 2.0), custom_color)
				# Top Block (Slightly offset for ruin look)
				pb.add_box(Vector3(0.1, 1.5, 0), Vector3(1.8, 1.0, 1.8), custom_color)
				# Erosion/Detail bits
				pb.add_box(Vector3(0.9, 0.2, 0.9), Vector3(0.4, 0.4, 0.4), custom_color, Vector3(15, 45, 0))
				pb.add_box(Vector3(-0.9, 1.8, -0.9), Vector3(0.3, 0.3, 0.3), custom_color, Vector3(10, 10, 10))
				
			3: # SNOW (Glacial Ice Ridge - Modular)
				custom_color = Color(0.6, 0.8, 1.0, 0.9) # Translucent Blue
				# Main Ice Block (Irregular Prism-like)
				# To make it wall-like, we use a wide prism or box
				pb.add_box(Vector3(0, 0.8, 0), Vector3(2.0, 1.6, 1.8), custom_color)
				# Snow Cap (White)
				pb.add_box(Vector3(0, 1.7, 0), Vector3(2.0, 0.3, 1.8), Color(0.95, 0.95, 1.0))
				# Spikes/Irregularity
				pb.add_prism(Vector3(0.5, 2.0, 0.5), Vector3(0.5, 0.8, 0.5), Color(0.95, 0.95, 1.0), Vector3(0, 15, 5))
				pb.add_prism(Vector3(-0.6, 1.8, -0.4), Vector3(0.6, 0.6, 0.6), Color(0.95, 0.95, 1.0), Vector3(10, -20, 0))

			_: # STREET (Reinforced Concrete Barrier)
				custom_color = Color(0.3, 0.3, 0.3)
				# Main Concrete Slab
				pb.add_box(Vector3(0, 1.0, 0), Vector3(2.0, 2.0, 1.8), custom_color)
				# Chamfered Top? Or just simple
				# Warning Stripes (Corners)
				var yellow = Color(0.9, 0.8, 0.1)
				pb.add_box(Vector3(0.95, 1.0, 0.91), Vector3(0.15, 2.0, 0.05), yellow) # Front R
				pb.add_box(Vector3(-0.95, 1.0, 0.91), Vector3(0.15, 2.0, 0.05), yellow) # Front L
				pb.add_box(Vector3(0.95, 1.0, -0.91), Vector3(0.15, 2.0, 0.05), yellow) # Back R
				pb.add_box(Vector3(-0.95, 1.0, -0.91), Vector3(0.15, 2.0, 0.05), yellow) # Back L
				# Rebar sticking out top
				for i in range(3):
					pb.add_cylinder(Vector3(-0.5 + i*0.5, 2.1, 0), 0.05, 0.4, Color(0.4, 0.2, 0.1), Vector3(randf()*10, 0, randf()*10))
				
		# Finalize
		var model = pb.commit(self)
		
		# Cleanup the placeholder mesh instance
		mesh_instance.visible = false
		# mesh_instance.queue_free() # FIX: Caused crash in _update_visual_state. Keep it alive but hidden.
		
		# Set model position (PropBuilder assumes local 0,0,0 usually, but we added at world 0,0,0 relative to tile?)
		# Tile children are relative to Tile.
		# PropBuilder adds to target_parent (self).
		# MapTile is centered at (x*2, elev, y*2).
		# PropBuilder `add_box` pos is local offset.
		# So `Vector3(0, 1.0, 0)` means 1m up from Tile origin. Correct.
		
		# Ensure visibility
		visible = false # Hidden until FOW reveals it

		
	elif (type == GridManager.TileType.COVER_FULL or type == GridManager.TileType.COVER_HALF) and gm:
		var is_destructible = false
		if gm.grid_data.has(grid_pos):
			is_destructible = gm.grid_data[grid_pos].get("destructible", false)
			
		if not is_destructible:
			var cvr = BoxMesh.new()
			if type == GridManager.TileType.COVER_FULL:
				cvr.size = Vector3(1.8, 2.0, 1.8)
				custom_color = Color(0.4, 0.4, 0.45)
				mesh_instance.position.y = 1.0
			else:
				cvr.size = Vector3(1.8, 1.0, 1.8)
				custom_color = Color(0.5, 0.5, 0.55)
				mesh_instance.position.y = 0.5
			mesh_instance.mesh = cvr
		
	else:
		# Standard Ground
		var thickness = 0.2
		var height = thickness
		var offset_y = 0.0
		
		if elevation > 0:
			height = (elevation * 1.0) + thickness
			offset_y = (thickness / 2.0) - (height / 2.0)
			
		var box = BoxMesh.new()
		box.size = Vector3(2.0, height, 2.0)
		mesh_instance.mesh = box
		mesh_instance.position.y = offset_y
		
	# Apply Initial Material
	if custom_color != null:
		# Unique props use own material
		var mat = StandardMaterial3D.new()
		mat.albedo_color = custom_color
		mesh_instance.material_override = mat
	else:
		# Standard Tiles use Shared Cache
		_update_visual_state(false, false)

func set_walkable(walkable: bool):
	pass

func set_vision_state(is_visible: bool, is_fogged: bool):
	visible = is_visible or is_fogged
	_update_visual_state(is_visible, is_fogged)

func _update_visual_state(is_visible: bool, is_fogged: bool):
	_is_fogged = is_fogged
	
	# Safety check: if we have a Custom Material (Ramp/Wall), we apply fog manually.
	# We identify custom material by checking if mesh is PrismMesh or large BoxMesh (Wall).
	# This avoids overwriting custom materials with Biome Cache.
	
	if mesh_instance.mesh is PrismMesh: 
		# FIX: Uses persisted biome color instead of hardcoded brown
		var ramp_col = Color(0.6, 0.5, 0.3)
		if has_meta("biome_color_override"):
			ramp_col = get_meta("biome_color_override")
			
		_apply_custom_fog(is_fogged, ramp_col)
		return
	elif mesh_instance.mesh is BoxMesh and (mesh_instance.mesh.size.y >= 2.0 and mesh_instance.mesh.size.x >= 1.9): # Wall check
		_apply_custom_fog(is_fogged, Color(0.2, 0.2, 0.2))
		return
	elif mesh_instance.mesh is BoxMesh and (mesh_instance.mesh.size.y == 2.0 and mesh_instance.mesh.size.x == 1.8): # Full Cover
		_apply_custom_fog(is_fogged, Color(0.4, 0.4, 0.45))
		return
	elif mesh_instance.mesh is BoxMesh and (mesh_instance.mesh.size.y == 1.0 and mesh_instance.mesh.size.x == 1.8): # Half Cover
		_apply_custom_fog(is_fogged, Color(0.5, 0.5, 0.55))
		return

	# Standard Tile Logic (Ground / Ladder Base)
	mesh_instance.material_override = MaterialCacheScript.get_tile_material(_current_biome, _current_elevation, _is_fogged)

func _apply_custom_fog(is_fogged: bool, base_col: Color):
	var final_col = base_col
	if is_fogged:
		var gray = final_col.r * 0.299 + final_col.g * 0.587 + final_col.b * 0.114
		var gray_color = Color(gray, gray, gray)
		final_col = final_col.lerp(gray_color, 0.5).darkened(0.5)
		
	if mesh_instance.material_override:
		mesh_instance.material_override.albedo_color = final_col
