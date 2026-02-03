extends Node3D


const MAX_PARTICLES = 32

# Static Resources (Shared across all instances)
static var _mesh: QuadMesh
static var _material: StandardMaterial3D
static var _process_material: ParticleProcessMaterial

func _ready():
	_ensure_resources()
	
	var particles = GPUParticles3D.new()
	particles.draw_pass_1 = _mesh
	particles.process_material = _process_material
	particles.amount = MAX_PARTICLES
	particles.lifetime = 1.0
	particles.explosiveness = 1.0
	particles.one_shot = true

	add_child(particles)
	particles.emitting = true

	# Auto cleanup
	await get_tree().create_timer(1.5).timeout
	queue_free()

static func _ensure_resources():
	if _mesh: return

	# Material
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.albedo_color = Color(1.0, 0.5, 0.0)  # Orange
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES

	# Mesh
	_mesh = QuadMesh.new()
	_mesh.size = Vector2(0.5, 0.5)
	_mesh.material = _material

	# Particle Process Material
	_process_material = ParticleProcessMaterial.new()
	_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_process_material.emission_sphere_radius = 0.5
	_process_material.direction = Vector3(0, 1, 0)
	_process_material.spread = 180.0
	_process_material.gravity = Vector3(0, 0, 0)
	_process_material.initial_velocity_min = 2.0
	_process_material.initial_velocity_max = 5.0
	_process_material.scale_min = 1.0
	_process_material.scale_max = 3.0
	_process_material.color = Color(1, 0.5, 0, 1)

