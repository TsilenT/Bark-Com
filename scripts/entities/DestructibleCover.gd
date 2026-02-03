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
	SERVER_RACK,
	WALL
}

var mesh: Node3D
var variant_type: Variant = Variant.CRATE

# Static Caches for Optimization
static var _material_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}

# Map Enum to PackedScene (Drag and drop in Editor or load from resources)
@export var variant_scenes: Dictionary = {}

static func flush_cache():
	_material_cache.clear()
	_mesh_cache.clear()

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
		"Server Rack": return Variant.SERVER_RACK
		"Wall": return Variant.WALL
	return -1
	
func initialize(pos: Vector2, gm: Node, biome: String = "", variant_override: int = -1):
	super.initialize(pos, gm)
	
	if variant_override != -1:
		set_variant(variant_override)
	else:
		# Auto-Variant based on Biome
		match biome:
			"Street":
				if randf() > 0.5: set_variant(Variant.HYDRANT)
				else: set_variant(Variant.TRASH_CAN)
			"Garden":
				set_variant(Variant.PLANTER)
			"Indoors":
				if randf() > 0.5: set_variant(Variant.SERVER_RACK)
				else: set_variant(Variant.CRATE)
			"Snow":
				set_variant(Variant.CRATE) 
			"Desert":
				set_variant(Variant.TRASH_CAN) 
			_:
				set_variant(Variant.CRATE)

	# Update Grid Logic based on Variant
	var cover_type = GridManager.TileType.COVER_HALF
	if variant_type in [Variant.HYDRANT, Variant.SERVER_RACK]:
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
	mesh = MeshInstance3D.new()
	
	# 1. Configuration Data (Defaults)
	var m_mesh: Mesh = null
	var m_mat: Material = null
	var c_size: Vector3 = Vector3(1, 1, 1)
	var c_offset_y: float = 0.5
	var v_offset_y: float = 0.5
	var new_hp: int = 5
	
	# 2. Check Cache First
	if _mesh_cache.has(type):
		m_mesh = _mesh_cache[type]
		m_mat = _material_cache[type]

	# 3. Define Variant Data (Must run to set offsets, even if cached)
	match type:
		Variant.CRATE:
			new_hp = 5
			v_offset_y = 0.5
			c_size = Vector3(1, 1, 1)
			c_offset_y = 0.5
			if not m_mesh:
				var m = BoxMesh.new()
				m.size = c_size
				m_mesh = m
				m_mat = StandardMaterial3D.new()
				m_mat.albedo_color = Color(0.6, 0.4, 0.2) # Wood

		Variant.HYDRANT:
			new_hp = 12
			v_offset_y = 0.6
			c_size = Vector3(0.8, 1.2, 0.8) # Approx Box
			c_offset_y = 0.6
			if not m_mesh:
				var m = CylinderMesh.new()
				m.top_radius = 0.3
				m.bottom_radius = 0.4
				m.height = 1.2
				m_mesh = m
				m_mat = StandardMaterial3D.new()
				m_mat.albedo_color = Color(1.0, 0.8, 0.0) # Safety Yellow

		Variant.TRASH_CAN:
			new_hp = 6
			v_offset_y = 0.5
			c_size = Vector3(0.8, 1.0, 0.8)
			c_offset_y = 0.5
			if not m_mesh:
				var m = CylinderMesh.new()
				m.top_radius = 0.4
				m.bottom_radius = 0.35
				m.height = 1.0
				m_mesh = m
				m_mat = StandardMaterial3D.new()
				m_mat.albedo_color = Color(0.5, 0.5, 0.55) 

		Variant.PLANTER:
			new_hp = 3
			v_offset_y = 0.3
			c_size = Vector3(1.0, 0.6, 1.0)
			c_offset_y = 0.3
			if not m_mesh:
				var m = CylinderMesh.new()
				m.top_radius = 0.5
				m.bottom_radius = 0.3
				m.height = 0.6
				m_mesh = m
				m_mat = StandardMaterial3D.new()
				m_mat.albedo_color = Color(0.8, 0.5, 0.3)

		Variant.SERVER_RACK:
			new_hp = 8
			v_offset_y = 0.9
			c_size = Vector3(0.8, 1.8, 0.8)
			c_offset_y = 0.9
			if not m_mesh:
				var m = BoxMesh.new()
				m.size = c_size
				m_mesh = m
				m_mat = StandardMaterial3D.new()
				m_mat.albedo_color = Color(0.1, 0.1, 0.2)
				m_mat.emission_enabled = true
				m_mat.emission = Color(0.2, 0.8, 1.0)
				m_mat.emission_energy_multiplier = 0.5

		Variant.WALL:
			new_hp = 20
			v_offset_y = 1.25
			c_size = Vector3(2.0, 2.5, 2.0)
			c_offset_y = 1.25
			if not m_mesh:
				var m = BoxMesh.new()
				m.size = c_size
				m_mesh = m
				m_mat = StandardMaterial3D.new()
				m_mat.albedo_color = Color(0.5, 0.45, 0.4)

	# 4. Cache if new
	if not _mesh_cache.has(type):
		_mesh_cache[type] = m_mesh
		_material_cache[type] = m_mat

	# 5. Apply Resources
	mesh.mesh = m_mesh
	mesh.material_override = m_mat
	
	# 6. Apply Instance Configuration (Offsets/Sizes) -> ALWAYS RUNS
	mesh.position.y = v_offset_y
	add_child(mesh)
	
	max_hp = new_hp
	current_hp = max_hp

	# 7. Apply Collision
	# Ensure StaticBody structure
	var sb = null
	var shape_node = null
	
	for child in get_children():
		if child is StaticBody3D and not child.is_queued_for_deletion():
			sb = child
			for sub in sb.get_children():
				if sub is CollisionShape3D:
					shape_node = sub
					break
			break
			
	if not sb:
		sb = StaticBody3D.new()
		add_child(sb)
		_setup_collision_hooks(sb)
		
	if not shape_node:
		shape_node = CollisionShape3D.new()
		shape_node.shape = BoxShape3D.new()
		sb.add_child(shape_node)
		
	# Apply Collision Config
	shape_node.shape.size = c_size
	shape_node.position.y = c_offset_y


# --- INTERACTION FEEDBACK ---
var highlight_tween: Tween
var _is_material_instanced: bool = false # Optimization Flag

func _ensure_material_unique():
	if _is_material_instanced:
		return
		
	if mesh and mesh.material_override:
		mesh.material_override = mesh.material_override.duplicate()
		_is_material_instanced = true

func _mouse_enter():
	if mesh and mesh.material_override:
		_ensure_material_unique() # COW: Copy on Write
		
		mesh.material_override.emission_enabled = true
		mesh.material_override.emission = Color(1.0, 0.8, 0.0) # Gold
		
		# Pulse Effect
		if highlight_tween: highlight_tween.kill()
		highlight_tween = create_tween().set_loops()
		highlight_tween.tween_property(mesh.material_override, "emission_energy_multiplier", 2.0, 0.5).from(0.5)
		highlight_tween.tween_property(mesh.material_override, "emission_energy_multiplier", 0.5, 0.5)

func _mouse_exit():
	if highlight_tween:
		highlight_tween.kill()
		highlight_tween = null

	if mesh and mesh.material_override:
		# Reset emission
		if variant_type == Variant.SERVER_RACK:
			mesh.material_override.emission_enabled = true
			mesh.material_override.emission = Color(0.2, 0.8, 1.0)
			mesh.material_override.emission_energy_multiplier = 0.5
		else:
			mesh.material_override.emission_enabled = false
			mesh.material_override.emission_energy_multiplier = 0.0

		# Optimization: If we wanted to save memory, we could revert to cached material here if state matches base.
		# But keeping the unique material is safer to avoid flickering or complexity.


func take_damage(amount: int):
	current_hp -= amount
	print("Cover at ", grid_pos, " took ", amount, " damage. HP: ", current_hp)

	var color = Color(1.0, 0.84, 0.0) # Gold
	
	SignalBus.on_request_floating_text.emit(self, str(amount), color)

	# Visual Feedback: Flash or Darken
	if mesh and mesh.material_override:
		_ensure_material_unique() # COW

		# Flash Emission
		var tw = create_tween()
		mesh.material_override.emission_enabled = true
		mesh.material_override.emission = Color.RED
		mesh.material_override.emission_energy_multiplier = 1.0
		tw.tween_property(mesh.material_override, "emission_energy_multiplier", 0.0, 0.3)
		tw.tween_callback(func(): mesh.material_override.emission_enabled = false)
		
		# Permanent Damage Visuals (Crack/Darken)
		if float(current_hp) / float(max_hp) < 0.5:
			# Darken/Tint Albedo to look damaged
			var current_color = mesh.material_override.albedo_color
			mesh.material_override.albedo_color = current_color.darkened(0.1)

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
