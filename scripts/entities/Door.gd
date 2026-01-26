extends DestructibleCover
class_name Door

# Door Entity
# - Blocks movement/vision when closed (OBSTACLE)
# - Can be opened (Interact) -> Becomes GROUND (Walkable)
# - Can be destroyed (Shoot) -> Becomes GROUND (Walkable)

var is_open: bool = false
var hinge_node: Node3D

func _ready():
	# Specs
	max_hp = 10
	current_hp = 10
	add_to_group("Interactive")
	
	super._ready() # Registers Signals and calls _setup_collision

func _setup_collision():
	# Override Base: We want collision on the Hinge so it rotates.
	_setup_visuals_and_collision()

func _setup_visuals_and_collision():
	# Hinge Node (Pivot Point)
	hinge_node = Node3D.new()
	hinge_node.name = "Hinge"
	hinge_node.position = Vector3(-0.9, 0, 0) 
	add_child(hinge_node)
	
	# Mesh
	mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.8, 2.5, 0.2)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.35, 0.15)
	mesh.material_override = mat
	mesh.position = Vector3(0.9, 1.25, 0)
	hinge_node.add_child(mesh)
	
	# Collider (Attached to Hinge)
	var sb = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.8, 2.5, 0.2)
	shape.shape = box_shape
	shape.position = Vector3(0.9, 1.25, 0) # Match Mesh
	
	sb.add_child(shape)
	hinge_node.add_child(sb)
	
	# Metadata for Raycasting/Destruction
	if not sb.is_in_group("Destructible"):
		sb.add_to_group("Destructible")
	sb.set_meta("owner_node", self)

func initialize(pos: Vector2, gm: Node, biome: String = "", variant_override: int = -1):
	super.initialize(pos, gm, biome, variant_override)
	
	# Override Grid State: Default is OBSTACLE (Blocking)
	# ...
	gm.update_tile_state(pos, false, 2.0, GridManager.TileType.OBSTACLE)
	
	# Orientation Logic
	# Default Mesh aligns along X-axis (Rotation 0).
	# This connects Left (-X) and Right (+X).
	# We want to match the "Wall Line".
	# Check for walls at North/South (Rot 90) or East/West (Rot 0).
	
	if gm and "grid_data" in gm:
		var n_north = pos + Vector2(0, -1)
		var n_south = pos + Vector2(0, 1)
		var has_wall_ns = false
		
		# Check North
		if gm.grid_data.has(n_north):
			var t = gm.grid_data[n_north].get("type", 0)
			if t == GridManager.TileType.OBSTACLE or t == GridManager.TileType.COVER_FULL:
				has_wall_ns = true
		
		# Check South (Confirmation)
		if gm.grid_data.has(n_south):
			var t = gm.grid_data[n_south].get("type", 0)
			if t == GridManager.TileType.OBSTACLE or t == GridManager.TileType.COVER_FULL:
				has_wall_ns = true
				
		if has_wall_ns:
			# Wall line is Vertical (Z-axis). Rotate Door to match.
			rotation_degrees.y = 90
		else:
			# Default Horizontal (X-axis).
			rotation_degrees.y = 0

func interact(unit):
	if is_open:
		# Maybe close it? For now just say it's open.
		GameManager.log("Door", "Already open.")
		return
		
	GameManager.log("Door", "Opening door at ", grid_pos)
	_open_door()

func _open_door():
	is_open = true
	
	# Update Grid: Walkable, No Cover
	grid_manager.update_tile_state(grid_pos, true, 0.0, GridManager.TileType.GROUND)
	
	# Clear Occupancy (So GridManager pathfinding allows movement)
	if grid_manager.grid_data.has(grid_pos):
		grid_manager.grid_data[grid_pos]["unit"] = null
	
	# Visuals: Rotate Hinge
	var tween = create_tween()
	tween.tween_property(hinge_node, "rotation_degrees:y", 90.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Play Sound?
	# if AudioManager.instance: AudioManager.instance.play_sfx("door_open")

func destroy():
	# If destroyed, it breaks apart.
	# Logic matches DestructibleCover: Spawns particles, removes self.
	
	# IMPORTANT: Ensure grid is cleared (Walkable)
	# DestructibleCover.destroy() calls queue_free() but might not update grid tile to WALKABLE Ground?
	# Let's check DestructibleCover.destroy() implementation in mind...
	# Usually it does. If not, we do it here.
	if grid_manager:
		grid_manager.update_tile_state(grid_pos, true, 0.0, GridManager.TileType.GROUND)
		
	super.destroy() # Spawns explosion, queue_free


func set_variant(_type: Variant):
	# Door handles its own visuals in _setup_visuals.
	# Prevent DestructibleCover.initialize from overwriting mesh with Crate/Hydrant.
	pass
