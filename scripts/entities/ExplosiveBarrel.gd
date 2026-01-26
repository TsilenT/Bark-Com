extends "res://scripts/entities/VolatileCover.gd"
class_name ExplosiveBarrel

# Explosive Barrel
# Low HP, Instant/Short Fuse, Small Radius


func _ready():
	# Specs
	max_hp = 12
	current_hp = 12
	fuse_turns = 1  # 1 Turn fuse allows for "Warning" phase and reaction shots

	explosion_range = 2
	explosion_damage = 8

	super._ready()  # Registers signals


func initialize(pos: Vector2, gm: Node, biome: String = "", variant_override: int = -1):
	# Bypass DestructibleCover logic that forces "Crate" visuals
	# We call higher parent 'InteractiveObject' initialize manually?
	# InteractiveObject.initialize(pos, gm) -> super.initialize is DestructibleCover.
	
	# Actually, we can just call super.initialize() and THEN incorrectly reset visuals?
	# DestructibleCover.initialize calls `set_variant("Crate")`.
	# So we must override and NOT call super if we want to avoid that, OR undo it.
	# But DestructibleCover.initialize also handles grid logic.
	
	# Cleaner: Call super logic fully, but pass specific variant if supported?
	# DestructibleCover doesn't support "Barrel".
	# So we override completely.
	
	grid_pos = pos
	grid_manager = gm
	position = gm.get_world_position(pos)
	
	# Update Grid Logic (Barrels are OBSTACLES or COVER?)
	# Explosive Barrel usually FULL COVER (High) or HALF?
	# Cylinder height 1.2 is roughly Half Cover.
	gm.update_tile_state(pos, false, 1.0, GridManager.TileType.COVER_HALF)
	
	_setup_visuals() # Re-ensure visuals are correct
	
	current_hp = max_hp


func _setup_visuals():
	mesh = MeshInstance3D.new()
	var pyl = CylinderMesh.new()
	pyl.top_radius = 0.3
	pyl.bottom_radius = 0.3
	pyl.height = 1.2
	mesh.mesh = pyl

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	mesh.material_override = mat
	mesh.position.y = 0.6
	add_child(mesh)
