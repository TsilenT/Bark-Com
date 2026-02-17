extends DestructibleCover
class_name GoldenHydrant

# The Sacred Artifact.
# If destroyed, the Base Defense fails (Game Over).

var faction: String = "Player"

	# Override Visuals (Gold Tint)
	# faction = "Player" # Already set

func initialize(pos: Vector2, gm: Node, _biome_data = null, _variant_override = -1):
	# Force base class to register with Grid, but ignore biome/variant randomization
	super.initialize(pos, gm, null, Variant.HYDRANT) # Force HYDRANT variant to get correct HP/Collision
	
	# Override Visuals immediately
	_setup_golden_visuals()

# Override base class procedural logic to prevent overwriting HP with default Hydrant HP (12)
func _create_procedural_variant(_type: Variant):
	# Do nothing, we handle visuals in _setup_golden_visuals
	# But ensure HP is correct
	max_hp = 100
	current_hp = 100


func _setup_golden_visuals():
	# 1. Clear existing mesh (from PropBuilder)
	if mesh:
		mesh.queue_free()
		mesh = null
		
	# 2. Create Custom Gold Mesh
	mesh = MeshInstance3D.new()
	mesh.name = "GoldenMesh"
	
	# Hydrant Body
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.35
	cyl.height = 1.0
	mesh.mesh = cyl
	mesh.position.y = 0.5
	add_child(mesh)
	
	# Material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.84, 0.0)  # Gold
	mat.metallic = 1.0
	mat.roughness = 0.2
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.0)
	mat.emission_energy_multiplier = 0.5
	mesh.material_override = mat
	
	# 3. GOLDEN BEAM (The Beacon)
	var beam = MeshInstance3D.new()
	beam.name = "GoldenBeam"
	var beam_mesh = CylinderMesh.new()
	beam_mesh.top_radius = 0.1
	beam_mesh.bottom_radius = 0.1
	beam_mesh.height = 20.0 # Sky high
	beam.mesh = beam_mesh
	beam.position.y = 10.0
	
	var beam_mat = StandardMaterial3D.new()
	beam_mat.albedo_color = Color(1.0, 0.84, 0.0, 0.3) # Transparent Gold
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.emission_enabled = true
	beam_mat.emission = Color(1.0, 0.84, 0.0)
	beam_mat.emission_energy_multiplier = 2.0
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = beam_mat
	
	add_child(beam)
	
	# Light
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.84, 0.0)
	light.light_energy = 2.0
	light.omni_range = 5.0
	light.position.y = 1.5
	add_child(light)

func _ready():
	super._ready()
	add_to_group("Objectives")
	
	# Override Stats if not initialized (fallback)
	max_hp = 100
	current_hp = 100
	
	# If placed manually in editor, setup visuals
	if not mesh and get_child_count() == 0:
		_setup_golden_visuals()
	var label = Label3D.new()
	label.text = "THE HYDRANT"
	label.modulate = Color.GOLD
	label.position = Vector3(0, 2.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func take_damage_from(amount: int, source = null, dmg_type: String = GameManager.DMG_TYPE_GENERIC):
	super.take_damage_from(amount, source, dmg_type)
	if current_hp <= 0:
		_on_destroyed()


func _on_destroyed():
	print("GoldenHydrant: DESTROYED! THE BASE IS LOST!")
	SignalBus.on_mission_ended.emit(false, 0)  # Instant Defeat

func get_data_snapshot() -> Dictionary:
	return {
		"name": "The Golden Hydrant",
		"class": "Objective",
		"level": 1,
		"rank": "Legendary Artifact",
		"stats": { "max_hp": max_hp }
	}
