extends InteractiveObject
class_name DestructibleCover

@export var max_hp: int = 5
var current_hp: int = 5
@export var prop_scene: PackedScene # Optional now, we use proc gen
@export var explosion_scene: PackedScene # Lazy loaded
const EXPLOSION_PATH = "res://scenes/vfx/CoverExplosion.tscn"

# Optimization: Allow suppressing the small debris explosion if a bigger one is happening
var suppress_destruction_vfx: bool = false


enum Variant {
	CRATE,
	HYDRANT,
	TRASH_CAN,
	PLANTER,
	FILING_CABINET,
	WALL,
	DUMPSTER,
	BENCH,
	RUIN_PILLAR,
	ROCK_STACK,
	SNOWMAN,
	CRYO_TANK,
	ICE_CRYSTAL,
	OFFICE_DESK,
	COFFEE_MACHINE,
	STONE_PLANTER,
	HEDGE_BLOCK,
	FOUNTAIN_BASE,
	CACTUS
}

var mesh: Node3D
var variant_type: Variant = Variant.CRATE
var prop_builder = load("res://scripts/builders/PropBuilder.gd").new()

# Static Caches for Optimization
static var _material_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}

# Map Enum to PackedScene (Drag and drop in Editor or load from resources)
@export var variant_scenes: Dictionary = {}

static func flush_cache():
	_material_cache.clear()
	_mesh_cache.clear()
	# PropBuilder static cache
	var pb = load("res://scripts/builders/PropBuilder.gd")
	if pb and pb.has_method("flush_cache"):
		pb.flush_cache()

func _ready():
	_setup_collision()
	current_hp = max_hp
	add_to_group("Destructible")

func _setup_collision():
	# Default Proc-Gen Collision (Fallback)
	# Only create if we don't already have children (which might happen if instantiated from a full scene)
	if get_child_count() > 0:
		return

	var sb = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.0, 1.0, 1.0)
	shape.shape = box_shape
	shape.position.y = 0.5
	sb.add_child(shape)
	add_child(sb)
	_setup_collision_hooks(sb)

func _setup_collision_hooks(sb: StaticBody3D):
	if not sb.is_in_group("Destructible"):
		sb.add_to_group("Destructible")
	if not sb.has_meta("owner_node"):
		sb.set_meta("owner_node", self)


static func get_variant_from_string(name: String) -> int:
	match name:
		"Crate": return Variant.CRATE
		"Hydrant": return Variant.HYDRANT
		"Trash Can": return Variant.TRASH_CAN
		"Planter": return Variant.PLANTER
		"Filing Cabinet": return Variant.FILING_CABINET
		"Wall": return Variant.WALL
		"Dumpster": return Variant.DUMPSTER
		"Bench": return Variant.BENCH
		"Ruin Pillar": return Variant.RUIN_PILLAR
		"Cactus": return Variant.ROCK_STACK
		"Snowman": return Variant.SNOWMAN
		"Cryo Tank": return Variant.CRYO_TANK
		"Ice Crystal": return Variant.ICE_CRYSTAL
		"Office Desk": return Variant.OFFICE_DESK
		"Coffee Machine": return Variant.COFFEE_MACHINE
		"Stone Planter": return Variant.STONE_PLANTER

		"Fountain Base": return Variant.FOUNTAIN_BASE
		"Cactus": return Variant.CACTUS
	return -1
	
func initialize(pos: Vector2, gm: Node, biome_data = null, variant_override = -1):
	super.initialize(pos, gm)
	
	# Handle Defaults manually to match parent signature (Variant/Null)
	var final_biome = 2 # Default Street
	if biome_data != null:
		if biome_data is int:
			final_biome = biome_data
		elif biome_data is String:
			# Fallback Mapping
			match biome_data:
				"Office", "Indoors": final_biome = LevelGenerator.Biome.OFFICE
				"Garden": final_biome = LevelGenerator.Biome.GARDEN
				"Snow": final_biome = LevelGenerator.Biome.SNOW
				"Desert": final_biome = LevelGenerator.Biome.DESERT
				_: final_biome = LevelGenerator.Biome.STREET
	
	var final_variant = -1
	if variant_override != null and variant_override != -1:
		final_variant = int(variant_override)

	var biome_int = final_biome # Alias for logic below

	if final_variant != -1:
		# Biome Override for Generic Walls
		if final_variant == Variant.WALL:
			match biome_int:
				LevelGenerator.Biome.GARDEN: set_variant(Variant.HEDGE_BLOCK)
				LevelGenerator.Biome.DESERT: set_variant(Variant.RUIN_PILLAR)
				LevelGenerator.Biome.SNOW: set_variant(Variant.ICE_CRYSTAL)
				LevelGenerator.Biome.OFFICE: set_variant(Variant.FILING_CABINET) 
				_: set_variant(Variant.WALL)
		else:
			set_variant(final_variant)
	else:
		# Auto-Variant based on Biome
		match biome_int:
			LevelGenerator.Biome.STREET:
				var roll = randf()
				if roll < 0.4: set_variant(Variant.HYDRANT) 
				elif roll < 0.7: set_variant(Variant.DUMPSTER) 
				elif roll < 0.9: set_variant(Variant.BENCH) 
				else: set_variant(Variant.TRASH_CAN) 
			LevelGenerator.Biome.GARDEN:
				var roll = randf()
				if roll < 0.4: set_variant(Variant.HEDGE_BLOCK)
				elif roll < 0.7: set_variant(Variant.STONE_PLANTER)
				else: set_variant(Variant.FOUNTAIN_BASE)
			LevelGenerator.Biome.OFFICE:
				var roll = randf()
				if roll < 0.4: set_variant(Variant.OFFICE_DESK)
				elif roll < 0.7: set_variant(Variant.FILING_CABINET)
				elif roll < 0.9: set_variant(Variant.COFFEE_MACHINE)
				else: set_variant(Variant.CRATE)
			LevelGenerator.Biome.SNOW:
				var roll = randf()
				if roll < 0.5: set_variant(Variant.SNOWMAN)
				elif roll < 0.8: set_variant(Variant.ICE_CRYSTAL)
				else: set_variant(Variant.CRYO_TANK)
			"Desert":
				var roll = randf()
				if roll < 0.4: set_variant(Variant.RUIN_PILLAR)
				elif roll < 0.7: set_variant(Variant.CACTUS)
				elif roll < 0.9: set_variant(Variant.ROCK_STACK)
				else: set_variant(Variant.CRATE) # Desert Crate
			_:
				set_variant(Variant.CRATE)

	# Update Grid Logic based on Variant
	var cover_type = GridManager.TileType.COVER_HALF
	if variant_type in [Variant.HYDRANT, Variant.FILING_CABINET, Variant.WALL, Variant.COFFEE_MACHINE, Variant.RUIN_PILLAR, Variant.HEDGE_BLOCK, Variant.ICE_CRYSTAL, Variant.CACTUS]:
		cover_type = GridManager.TileType.COVER_FULL
		
	gm.update_tile_state(pos, false, 2.0 if cover_type == GridManager.TileType.COVER_FULL else 1.0, cover_type)

	# Register as Occupant (Prevents overlaps)
	if gm.grid_data.has(pos):
		gm.grid_data[pos]["unit"] = self


func set_variant(type: Variant):
	variant_type = type
	
	# Cleanup previous (if switching variants dynamically)
	_clear_visuals()

	# 1. Try Scene-Based (Preferred)
	if variant_scenes.has(type) and variant_scenes[type]:
		_instantiate_variant_scene(variant_scenes[type])
	else:
		# 2. Fallback to Procedural
		_create_procedural_variant(type)

func _clear_visuals():
	if mesh: 
		mesh.queue_free()
		mesh = null
	# Note: For procedural, we reused the initial StaticBody. 
	# For Scene-based, we might have instantiated a new one. 
	# This cleanup is tricky if mixing methods. 
	# For now, we assume _clear_visuals cleans up the mesh, 
	# and we re-find/reset collision in the creation steps.

func _instantiate_variant_scene(scene: PackedScene):
	# Nuke default collision if it exists (assuming it was the generic one)
	for child in get_children():
		if child is StaticBody3D:
			child.queue_free()
			
	var instance = scene.instantiate()
	add_child(instance)
	
	# Find hooks
	var found_sb = false
	if instance is StaticBody3D:
		_setup_collision_hooks(instance)
		found_sb = true
	else:
		# Search children
		for child in instance.get_children():
			if child is StaticBody3D:
				_setup_collision_hooks(child)
				found_sb = true
				break
	
	if not found_sb:
		push_warning("DestructibleCover: Variant scene " + str(variant_type) + " is missing a StaticBody3D!")
		
	# Assume the instance contains the mesh
	# We set 'mesh' ref to the instance to allow visual effects (flashing) to find materials
	# BUT, instance might be Node3D. We need to find the MeshInstance3D inside.
	mesh = _find_mesh_recursive(instance)


func _find_mesh_recursive(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var res = _find_mesh_recursive(child)
		if res: return res
	return null

func _create_procedural_variant(type: Variant):
	prop_builder.start()
	
	var c_size = Vector3(1, 1, 1)
	var c_offset_y = 0.5
	var new_hp = 5
	
	match type:
		# --- GENERIC ---
		Variant.CRATE:
			new_hp = 5
			c_size = Vector3(1, 1, 1)
			prop_builder.add_box(Vector3(0, 0.5, 0), Vector3(1, 1, 1), Color(0.6, 0.4, 0.2)) # Wood
			
		# --- STREET ---
		Variant.HYDRANT:
			new_hp = 12
			c_size = Vector3(0.6, 1.2, 0.6)
			c_offset_y = 0.6
			# Yellow Body
			prop_builder.add_cylinder(Vector3(0, 0.5, 0), 0.25, 1.0, Color(1.0, 0.8, 0.0), Vector3.ZERO, 0.3, 0.5) 
			# Silver Cap
			prop_builder.add_sphere(Vector3(0, 1.0, 0), 0.26, Color(0.8, 0.8, 0.9), 0.2)
			# Side Ports
			prop_builder.add_cylinder(Vector3(0, 0.7, 0), 0.1, 0.8, Color(0.8, 0.8, 0.9), Vector3(0, 0, 90), 0.3, 0.8)

		Variant.TRASH_CAN:
			new_hp = 6
			c_size = Vector3(0.7, 1.0, 0.7)
			# Metal Cylinder Body
			prop_builder.add_cylinder(Vector3(0, 0.45, 0), 0.35, 0.9, Color(0.5, 0.55, 0.6))
			# Lid (Slightly wider)
			prop_builder.add_cylinder(Vector3(0, 0.95, 0), 0.37, 0.1, Color(0.4, 0.45, 0.5))
			# Handle (Small box on top)
			prop_builder.add_box(Vector3(0, 1.0, 0), Vector3(0.1, 0.05, 0.2), Color(0.3, 0.3, 0.3))
			# Vertical Ribs
			prop_builder.add_box(Vector3(0.35, 0.5, 0), Vector3(0.05, 0.8, 0.1), Color(0.4, 0.45, 0.5))
			prop_builder.add_box(Vector3(-0.35, 0.5, 0), Vector3(0.05, 0.8, 0.1), Color(0.4, 0.45, 0.5))
			prop_builder.add_box(Vector3(0, 0.5, 0.35), Vector3(0.1, 0.8, 0.05), Color(0.4, 0.45, 0.5))
			prop_builder.add_box(Vector3(0, 0.5, -0.35), Vector3(0.1, 0.8, 0.05), Color(0.4, 0.45, 0.5))

		Variant.PLANTER:
			new_hp = 8
			c_size = Vector3(1.2, 0.8, 1.2)
			c_offset_y = 0.4
			# Contemporary Concrete Box
			prop_builder.add_box(Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 1.2), Color(0.7, 0.7, 0.72))
			# Soil
			prop_builder.add_box(Vector3(0, 0.75, 0), Vector3(1.0, 0.1, 1.0), Color(0.25, 0.15, 0.1))
			# Small Bush
			prop_builder.add_sphere(Vector3(0, 1.1, 0), 0.4, Color(0.2, 0.7, 0.2))

		Variant.WALL:
			new_hp = 25 # Tough
			var length = 2.0
			var height = 2.0
			var thickness = 0.4
			c_size = Vector3(length, height, thickness)
			c_offset_y = height / 2.0
			_snap_rotation(false) # Align with grid/neighbors if possible, assume parallel
			# Concrete Slab
			prop_builder.add_box(Vector3(0, height/2.0, 0), Vector3(length, height, thickness), Color(0.5, 0.5, 0.55))
			# Rebar Detail (sticking out top?)
			prop_builder.add_cylinder(Vector3(-0.5, height+0.2, 0), 0.05, 0.4, Color(0.4, 0.3, 0.3))
			prop_builder.add_cylinder(Vector3(0.5, height+0.2, 0), 0.05, 0.4, Color(0.4, 0.3, 0.3))
		
		Variant.DUMPSTER:
			new_hp = 15
			c_size = Vector3(1.5, 1.2, 1.0) # Full Tile width almost
			c_offset_y = 0.6
			_snap_rotation(true) # Back to wall
			# Green Body
			prop_builder.add_box(Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 0.9), Color(0.1, 0.3, 0.1), Vector3.ZERO, 0.7, 0.2)
			# Black Lids (Angled)
			prop_builder.add_box(Vector3(0, 1.05, 0), Vector3(1.45, 0.1, 0.95), Color(0.1, 0.1, 0.1), Vector3(5, 0, 0))

		Variant.BENCH:
			new_hp = 8
			c_size = Vector3(1.8, 0.8, 0.6)
			c_offset_y = 0.4
			_snap_rotation(true)
			# Seat
			prop_builder.add_box(Vector3(0, 0.5, 0), Vector3(1.8, 0.1, 0.5), Color(0.6, 0.3, 0.1))
			# Backrest (Moved to +Z, so Front is -Z)
			prop_builder.add_box(Vector3(0, 0.8, 0.25), Vector3(1.8, 0.6, 0.1), Color(0.6, 0.3, 0.1))
			# Legs
			prop_builder.add_box(Vector3(-0.8, 0.225, 0), Vector3(0.1, 0.45, 0.5), Color(0.2, 0.2, 0.2), Vector3.ZERO, 0.5, 0.8)
			prop_builder.add_box(Vector3(0.8, 0.225, 0), Vector3(0.1, 0.45, 0.5), Color(0.2, 0.2, 0.2), Vector3.ZERO, 0.5, 0.8)
			
		Variant.WALL: # Concrete Street Wall
			new_hp = 20
			c_size = Vector3(1.8, 2.0, 0.5)
			c_offset_y = 1.0
			_snap_rotation(false) 
			# Concrete Slab
			prop_builder.add_box(Vector3(0, 1.0, 0), Vector3(1.8, 2.0, 0.5), Color(0.4, 0.4, 0.45))
			# Rebar / Details
			prop_builder.add_box(Vector3(0, 2.0, 0), Vector3(1.6, 0.1, 0.3), Color(0.35, 0.35, 0.4))
			# Graffiti
			prop_builder.add_box(Vector3(0.3, 1.2, 0.26), Vector3(0.5, 0.5, 0.05), Color(0.8, 0.2, 0.2), Vector3(0, 0, 15))

		# --- DESERT ---
		Variant.RUIN_PILLAR:
			new_hp = 20
			c_size = Vector3(0.8, 2.0, 0.8)
			c_offset_y = 1.0
			var rot_y = randf_range(-10, 10)
			# Base
			prop_builder.add_box(Vector3(0, 0.2, 0), Vector3(0.9, 0.4, 0.9), Color(0.7, 0.6, 0.5), Vector3(0, rot_y, 0))
			# Column
			prop_builder.add_cylinder(Vector3(0, 1.2, 0), 0.35, 1.6, Color(0.7, 0.6, 0.5), Vector3(randf()*5, rot_y, randf()*5))
			# Top Crumble
			prop_builder.add_box(Vector3(0.2, 2.1, 0), Vector3(0.4, 0.3, 0.5), Color(0.7, 0.6, 0.5), Vector3(10, rot_y+20, 0))

		Variant.ROCK_STACK: # Renamed from CACTUS
			new_hp = 20
			c_size = Vector3(1.2, 2.0, 1.2)
			c_offset_y = 1.0
			var base_rot = randf() * 360
			# Rock 1 (Base)
			prop_builder.add_box(Vector3(0, 0.3, 0), Vector3(1.2, 0.6, 1.1), Color(0.7, 0.6, 0.5), Vector3(randf()*10, base_rot, randf()*10))
			# Rock 2
			prop_builder.add_box(Vector3(0.1, 0.9, 0), Vector3(1.0, 0.7, 0.9), Color(0.75, 0.65, 0.55), Vector3(randf()*10, base_rot+20, randf()*10))
			# Rock 3 (Top)
			prop_builder.add_box(Vector3(-0.1, 1.6, 0.1), Vector3(0.8, 0.8, 0.8), Color(0.7, 0.6, 0.5), Vector3(randf()*10, base_rot-15, randf()*10))

		Variant.CACTUS:
			new_hp = 12
			c_size = Vector3(1.0, 2.2, 1.0)
			c_offset_y = 1.1
			var rot_y = randf() * 360
			# Trunk
			prop_builder.add_cylinder(Vector3(0, 1.0, 0), 0.35, 2.0, Color(0.2, 0.5, 0.2), Vector3(0, rot_y, 0))
			# Arms
			var num_arms = randi_range(1, 3)
			for i in range(num_arms):
				var h = randf_range(1.0, 1.6)
				var angle = randf() * 360
				var arm_len = randf_range(0.4, 0.6)
				var arm_thick = 0.25
				# Arm Joint (Horizontal)
				var joint_off = Vector3(0.3, h, 0).rotated(Vector3.UP, deg_to_rad(angle))
				prop_builder.add_cylinder(joint_off, arm_thick, 0.4, Color(0.2, 0.5, 0.2), Vector3(0, angle, 90))
				# Arm Upright (Vertical)
				var up_off = Vector3(0.5, h + arm_len/2.0, 0).rotated(Vector3.UP, deg_to_rad(angle))
				prop_builder.add_cylinder(up_off, arm_thick, arm_len, Color(0.2, 0.5, 0.2), Vector3(0, angle, 0))


		# --- SNOW ---
		Variant.SNOWMAN:
			new_hp = 3
			c_size = Vector3(0.8, 1.8, 0.8) 
			c_offset_y = 0.9
			var look_rot = randf() * 360
			# Bottom
			prop_builder.add_sphere(Vector3(0, 0.4, 0), 0.5, Color.WHITE)
			# Middle
			prop_builder.add_sphere(Vector3(0, 1.0, 0), 0.35, Color.WHITE)
			# Head
			prop_builder.add_sphere(Vector3(0, 1.5, 0), 0.25, Color.WHITE)
			# Nose (Orange cone approximation via prism or small cylinder?)
			prop_builder.add_box(Vector3(0, 1.5, 0.3).rotated(Vector3.UP, deg_to_rad(look_rot)), Vector3(0.05, 0.05, 0.2), Color(1.0, 0.5, 0.0), Vector3(0, look_rot, 0))

		Variant.ICE_CRYSTAL:
			new_hp = 15
			c_size = Vector3(1.0, 1.5, 1.0)
			c_offset_y = 0.75
			# Central Core (Darker, Opaque)
			prop_builder.add_cylinder(Vector3(0, 0.6, 0), 0.25, 1.2, Color(0.2, 0.3, 0.5, 1.0), Vector3(randf()*10, 0, randf()*10), 0.2, 0.1)
			# Inner Shell (Translucent)
			prop_builder.add_prism(Vector3(0, 0.5, 0), Vector3(0.6, 1.4, 0.6), Color(0.4, 0.7, 1.0, 0.6), Vector3(0, 45, 0), 0.1, 0.2)
			# Outer Spikes (Clear)
			for i in range(16):
				var r_rot = Vector3(randf_range(-45, 45), randf() * 360, randf_range(-45, 45))
				var scale_y = randf_range(0.6, 1.8)
				var width = randf_range(0.1, 0.25)
				var off = Vector3(0.25, 0, 0).rotated(Vector3(0,1,0), r_rot.y)
				prop_builder.add_prism(Vector3(0, scale_y/2.0, 0) + off, Vector3(width, scale_y, width), Color(0.8, 0.9, 1.0, 0.3), r_rot, 0.05, 0.1)

		Variant.CRYO_TANK:
			new_hp = 12
			c_size = Vector3(1.0, 1.5, 1.0)
			c_offset_y = 0.75
			# Cryo Tank Design
			# Main Tank (Glass/Liquid)
			prop_builder.add_cylinder(Vector3(0, 0.75, 0), 0.4, 1.4, Color(0.1, 0.8, 1.0, 0.4))
			# Top/Bottom Caps
			prop_builder.add_cylinder(Vector3(0, 0.1, 0), 0.45, 0.2, Color(0.3, 0.3, 0.35))
			prop_builder.add_cylinder(Vector3(0, 1.4, 0), 0.45, 0.2, Color(0.3, 0.3, 0.35))
			# Side Struts (Reinforcement)
			for i in range(3):
				var rot = i * 120
				var off = Vector3(0.42, 0.75, 0).rotated(Vector3.UP, deg_to_rad(rot))
				prop_builder.add_box(off, Vector3(0.1, 1.4, 0.1), Color(0.4, 0.4, 0.45), Vector3(0, rot, 0))

		# --- GARDEN ---
		Variant.STONE_PLANTER:
			new_hp = 6
			c_size = Vector3(1.2, 0.6, 1.2)
			c_offset_y = 0.3
			# Stone Box
			prop_builder.add_box(Vector3(0, 0.3, 0), Vector3(1.2, 0.6, 1.2), Color(0.5, 0.5, 0.55))
			# Dirt/Plants
			prop_builder.add_box(Vector3(0, 0.65, 0), Vector3(1.0, 0.2, 1.0), Color(0.2, 0.4, 0.1))

		Variant.HEDGE_BLOCK:
			new_hp = 10
			c_size = Vector3(1.2, 1.5, 1.2)
			c_offset_y = 0.75
			# Blocky "Voxel" Noise Design
			# Main Mass
			prop_builder.add_box(Vector3(0, 0.75, 0), Vector3(1.0, 1.4, 1.0), Color(0.1, 0.4, 0.1))
			# Surface Noise (Random small blocks sticking out)
			for i in range(12):
				var p = Vector3(randf_range(-0.55, 0.55), randf_range(0.2, 1.3), randf_range(-0.55, 0.55))
				# Bias towards edge
				if abs(p.x) < 0.4 and abs(p.z) < 0.4: continue
				
				prop_builder.add_box(p, Vector3(0.3, 0.3, 0.3), Color(0.15, 0.5, 0.15), Vector3(randf()*20, randf()*20, randf()*20))
		
		Variant.FOUNTAIN_BASE:
			new_hp = 8
			c_size = Vector3(1.4, 0.8, 1.4)
			c_offset_y = 0.4
			# Base Ring
			prop_builder.add_cylinder(Vector3(0, 0.2, 0), 0.7, 0.4, Color(0.6, 0.6, 0.65))
			# Water - Raised slightly to avoid z-fighting/hiding
			prop_builder.add_cylinder(Vector3(0, 0.38, 0), 0.5, 0.1, Color(0.2, 0.6, 0.9, 0.8))
			# Center Spout
			prop_builder.add_cylinder(Vector3(0, 0.6, 0), 0.2, 0.8, Color(0.6, 0.6, 0.65))

		# --- INDOORS ---
		Variant.OFFICE_DESK:
			new_hp = 6
			c_size = Vector3(1.6, 0.8, 0.8) 
			c_offset_y = 0.4
			_snap_rotation(false) # Perpendicular to wall? or back to wall. Desk usually back against wall or free.
			# Top
			prop_builder.add_box(Vector3(0, 0.75, 0), Vector3(1.6, 0.05, 0.8), Color(0.8, 0.8, 0.8))
			# Legs
			prop_builder.add_box(Vector3(-0.7, 0.35, 0), Vector3(0.05, 0.75, 0.7), Color(0.2, 0.2, 0.2)) # Panel leg
			prop_builder.add_box(Vector3(0.7, 0.35, 0), Vector3(0.05, 0.75, 0.7), Color(0.2, 0.2, 0.2))
			# Monitor
			prop_builder.add_box(Vector3(0, 0.95, -0.2), Vector3(0.4, 0.3, 0.05), Color(0.1, 0.1, 0.1))

		Variant.COFFEE_MACHINE:
			new_hp = 8
			c_size = Vector3(1.2, 1.0, 0.8) # Cabinet size
			c_offset_y = 0.5
			_snap_rotation(true)
			
			# Side Elements (Glowing Strips on Cylinder) - Symmetric on X, no Z change needed for cylinder axis
			# Cylinder is at 0,0,0.
			# prop_builder.add_cylinder(Vector3(0.6, 1.0, 0), 0.05, 1.8, Color(1.0, 0.6, 0.0))
			# prop_builder.add_cylinder(Vector3(-0.6, 1.0, 0), 0.05, 1.8, Color(1.0, 0.6, 0.0))
			
			# Base Cabinet
			prop_builder.add_box(Vector3(0, 0.5, 0), Vector3(1.2, 1.0, 0.8), Color(0.2, 0.2, 0.2))
			
			# Countertop
			prop_builder.add_box(Vector3(0, 1.02, 0), Vector3(1.3, 0.05, 0.9), Color(0.9, 0.9, 0.95))
			
			# Coffee Brewer (Industrial Style) - Moved Back (+Z is back now)
			prop_builder.add_box(Vector3(0, 1.3, 0.0), Vector3(0.5, 0.6, 0.4), Color(0.1, 0.1, 0.1)) # Main Body
			prop_builder.add_box(Vector3(0, 1.5, 0.0), Vector3(0.52, 0.1, 0.42), Color(0.7, 0.7, 0.75)) # Metallic Top Trim
			
			# Glass Carafe (Pot) - Front is -Z
			# Liquid (Opaque Dark Coffee)
			prop_builder.add_cylinder(Vector3(0, 1.13, -0.3), 0.11, 0.2, Color(0.15, 0.05, 0.0, 1.0)) 
			# Glass Shell (Surrounding it)
			prop_builder.add_cylinder(Vector3(0, 1.15, -0.3), 0.125, 0.25, Color(0.8, 0.9, 1.0, 0.3)) 
			# Handle
			prop_builder.add_box(Vector3(0.16, 1.15, -0.3), Vector3(0.02, 0.2, 0.05), Color(0.1, 0.1, 0.1))
			
			# Paper Cups (Stack)
			prop_builder.add_cylinder(Vector3(0.4, 1.1, -0.2), 0.08, 0.15, Color(0.9, 0.9, 0.8))
			prop_builder.add_cylinder(Vector3(0.45, 1.1, 0.0), 0.08, 0.15, Color(0.9, 0.9, 0.8))
			
			# Sugar/Creamer containers
			prop_builder.add_box(Vector3(-0.35, 1.1, 0), Vector3(0.15, 0.15, 0.15), Color(1.0, 1.0, 1.0))
			prop_builder.add_box(Vector3(-0.52, 1.1, -0.1), Vector3(0.12, 0.12, 0.12), Color(0.9, 0.8, 0.5))

		Variant.FILING_CABINET:
			new_hp = 10
			c_size = Vector3(0.8, 1.5, 0.8)
			c_offset_y = 0.75
			_snap_rotation(true) # Back against wall
			
			# Main Metal Body (Beige/Grey)
			prop_builder.add_box(Vector3(0, 0.75, 0), Vector3(0.7, 1.5, 0.7), Color(0.75, 0.75, 0.7))
			
			# Drawers (3 stacked) - Front is -Z
			# Drawer 1
			prop_builder.add_box(Vector3(0, 0.35, -0.36), Vector3(0.6, 0.4, 0.05), Color(0.7, 0.7, 0.65))
			prop_builder.add_box(Vector3(0, 0.35, -0.39), Vector3(0.1, 0.02, 0.02), Color(0.5, 0.5, 0.5)) # Handle
			
			# Drawer 2
			prop_builder.add_box(Vector3(0, 0.8, -0.36), Vector3(0.6, 0.4, 0.05), Color(0.7, 0.7, 0.65))
			prop_builder.add_box(Vector3(0, 0.8, -0.39), Vector3(0.1, 0.02, 0.02), Color(0.5, 0.5, 0.5)) # Handle

			# Drawer 3
			prop_builder.add_box(Vector3(0, 1.25, -0.36), Vector3(0.6, 0.4, 0.05), Color(0.7, 0.7, 0.65))
			prop_builder.add_box(Vector3(0, 1.25, -0.39), Vector3(0.1, 0.02, 0.02), Color(0.5, 0.5, 0.5)) # Handle
			
		_:
			# Fallback Crate
			prop_builder.add_box(Vector3(0, 0.5, 0), Vector3(1, 1, 1), Color(0.6, 0.4, 0.2))

	mesh = prop_builder.commit(self)
	max_hp = new_hp
	current_hp = max_hp

	# Collision Setup (Simplified: Just resize the generic box)
	# For detailed props, we still just use a bounding box for cover logic
	var sb = null
	var shape_node = null
	
	for child in get_children():
		if child is StaticBody3D:
			sb = child
			for sub in sb.get_children():
				if sub is CollisionShape3D: shape_node = sub
			break
			
	if not sb:
		sb = StaticBody3D.new()
		add_child(sb)
		_setup_collision_hooks(sb)
		
	if not shape_node:
		shape_node = CollisionShape3D.new()
		shape_node.shape = BoxShape3D.new()
		sb.add_child(shape_node)

	shape_node.shape.size = c_size
	shape_node.position.y = c_offset_y

func _snap_rotation(back_to_wall: bool):
	# Concept: Check neighbors.
	# If back_to_wall is true, we want to face normals AWAY from wall? 
	# Or rather, the "Back" of the object should be touching the wall.
	# Default forward is usually -Z. Back is +Z.
	# So if Wall is at North (Z-1), we want to face South (Z+1)?
	# Wait, standard look_at logic.
	
	# Let's get generic neighbor data if possible
	var n_mask = 0 # Bitmask: N=1, E=2, S=4, W=8
	var offsets = {
		Vector2(0, -1): 1, # North
		Vector2(1, 0): 2,  # East
		Vector2(0, 1): 4,  # South
		Vector2(-1, 0): 8  # West
	}
	
	var wall_dir = Vector2.ZERO
	var found_wall = false
	
	# Safety Check for Testing/Benchmarks where GM isn't set yet
	if not grid_manager:
		return
	
	for off in offsets:
		var check = grid_pos + off
		# GridManager instance access
		if grid_manager.is_obstacle_at(check):
			wall_dir = off
			found_wall = true
			break # Stick to first wall found
			
	if found_wall:
		# If Back To Wall, we want our Back (+Z) to point towards WallDir? 
		# Or our Forward (-Z) to point AWAY from WallDir?
		# Yes, Forward = -WallDir
		
		# If NOT Back To Wall (e.g. Desk), maybe we want to face the room (Parallel or Away)?
		# Let's just default to "Face Away from Wall" for everything for now,
		# unless it's a Bench where we want the BACK against the wall.
		
		# If Bench (Back to Wall):
		# We want local +Z to be WallDir.
		# Rotation should be set such that basis.z aligns with wall_dir (3D).
		
		var target_look = Vector3(wall_dir.x, 0, wall_dir.y) 
		var look_pos = global_position - target_look # Look AWAY from wall
		
		look_at(look_pos, Vector3.UP)
		
		# Correction for specific props if their forward is different?
		# PropBuilder assumes standard orientation.
	else:
		# Random rotation if no wall
		rotation_degrees.y = randf() * 360



# --- INTERACTION FEEDBACK ---
var highlight_tween: Tween
var _is_material_instanced: bool = false # Optimization Flag

func _get_all_meshes() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if not mesh:
		return result
		
	if mesh is MeshInstance3D:
		result.append(mesh)
	else:
		# Recursive or specific child check? PropBuilder puts them directly under root.
		# PropBuilder implementation: root_node.add_child(mi) -> PropRoot.
		for child in mesh.get_children():
			if child is MeshInstance3D:
				result.append(child)
	return result

func _ensure_material_unique():
	if _is_material_instanced:
		return
	
	var all_meshes = _get_all_meshes()
	for m in all_meshes:
		if m.material_override:
			m.material_override = m.material_override.duplicate()
	
	_is_material_instanced = true

func _mouse_enter():
	var all_meshes = _get_all_meshes()
	if all_meshes.is_empty():
		return

	_ensure_material_unique() # COW: Copy on Write

	if highlight_tween: highlight_tween.kill()
	highlight_tween = create_tween().set_loops()
	
	for m in all_meshes:
		if m.material_override:
			m.material_override.emission_enabled = true
			m.material_override.emission = Color(1.0, 0.8, 0.0) # Gold
			
			# Pulse Effect (Parallel Tweening)
			highlight_tween.parallel().tween_property(m.material_override, "emission_energy_multiplier", 2.0, 0.5).from(0.5)
			highlight_tween.parallel().tween_property(m.material_override, "emission_energy_multiplier", 0.5, 0.5)

func _mouse_exit():
	if highlight_tween:
		highlight_tween.kill()
		highlight_tween = null

	var all_meshes = _get_all_meshes()
	for m in all_meshes:
		if m.material_override:
			# Reset emission
			m.material_override.emission_enabled = false
			m.material_override.emission_energy_multiplier = 0.0

		# Optimization: If we wanted to save memory, we could revert to cached material here if state matches base.
		# But keeping the unique material is safer to avoid flickering or complexity.


func take_damage_from(amount: int, source = null, dmg_type: String = GameManager.DMG_TYPE_GENERIC):
	current_hp -= amount
	print("Cover at ", grid_pos, " took ", amount, " damage (", dmg_type, "). HP: ", current_hp)

	var color = Color(1.0, 0.84, 0.0) # Default Gold
	match dmg_type:
		GameManager.DMG_TYPE_POISON, GameManager.DMG_TYPE_ACID:
			color = Color.GREEN
		GameManager.DMG_TYPE_FIRE, GameManager.DMG_TYPE_EXPLOSION:
			color = Color.ORANGE
	
	SignalBus.on_request_floating_text.emit(self, str(amount), color)

	# Visual Feedback: Flash or Darken
	_ensure_material_unique() # COW

	var all_meshes = _get_all_meshes()
	var tw = create_tween()

	for m in all_meshes:
		if m.material_override:
			# Flash Emission
			m.material_override.emission_enabled = true
			m.material_override.emission = Color.RED
			m.material_override.emission_energy_multiplier = 1.0
			tw.parallel().tween_property(m.material_override, "emission_energy_multiplier", 0.0, 0.3)
			tw.parallel().tween_callback(func(): m.material_override.emission_enabled = false)
			
			# Permanent Damage Visuals (Crack/Darken)
			if float(current_hp) / float(max_hp) < 0.5:
				# Darken/Tint Albedo to look damaged
				var current_color = m.material_override.albedo_color
				m.material_override.albedo_color = current_color.darkened(0.1)

	if current_hp <= 0:
		destroy()


func destroy():
	print("Crate destroyed!")
	# Update Grid: WALKABLE + NO COVER
	grid_manager.update_tile_state(grid_pos, true, 0.0, GridManager.TileType.GROUND)

	# Clear Occupancy
	if grid_manager.grid_data.has(grid_pos):
		if grid_manager.grid_data[grid_pos].get("unit") == self:
			grid_manager.grid_data[grid_pos]["unit"] = null

	# Visuals
	if mesh:
		mesh.visible = false
	
	# Spawn particles
	if not suppress_destruction_vfx:
		if not explosion_scene:
			if ResourceLoader.exists(EXPLOSION_PATH):
				explosion_scene = load(EXPLOSION_PATH)
			else:
				push_warning("DestructibleCover: Explosion VFX not found at " + EXPLOSION_PATH)

		if explosion_scene:
			var vfx = explosion_scene.instantiate()
			get_parent().add_child(vfx) # Add to world/parent to persist after self free
			vfx.global_position = global_position + Vector3(0, 0.5, 0)
		
	# queue_free after delay?
	# Particles handle themselves. We can remove ourselves immediately.
	queue_free()
