extends Node


# Material Cache (Simple Colors)
static var mat_cache = {}

static func create_model(unit) -> Node3D:
	var root = Node3D.new()
	root.name = "ModelRoot"
	
	# Determine Type based on Behavior logic
	# (Mapping AI definitions to Visual Themes)
	var type_name = "Generic"
	if unit.enemy_data:
		# Use behavior enum or name if available
		# Currently AIBehavior enum: 0=Rusher, 1=Sniper, 3=AreaDenial, 4=Controller, 5=Exploder, 6=Tank, 7=Flying, 8=Infiltrator, 9=Boss
		var b_id = unit.enemy_data.ai_behavior
		match b_id:
			0, 2: type_name = "Rusher" # Generic falls back here too?
			1: type_name = "Sniper"
			3: type_name = "AreaDenial" # Fire-based
			4: type_name = "Controller"
			5: type_name = "Exploder"
			6: type_name = "Tank"
			7: type_name = "Flying"
			8: type_name = "Infiltrator"
			9: type_name = "Boss"

	var color = Color.RED
	if unit.enemy_data:
		color = unit.enemy_data.visual_color

	match type_name:
		"Rusher":
			_build_rusher(root, color)
		"Sniper":
			_build_sniper(root, color)
		"Controller":
			_build_controller(root, color)
		"AreaDenial":
			_build_area_denial(root, color)
		"Exploder":
			_build_exploder(root, color)
		"Flying":
			_build_flying(root, color)
		"Infiltrator":
			_build_infiltrator(root, color)
		"Tank":
			_build_tank(root, color)
		"Boss":
			_build_boss(root, color)
		_:
			_build_rusher(root, color) # Default

	return root

# --- Builders ---

static func _get_mat(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var k = str(color) + str(transparent)
	if mat_cache.has(k): return mat_cache[k]
	
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.6
	else:
		m.roughness = 0.2
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.5
		
	mat_cache[k] = m
	return m
	
static func _add_mesh(parent: Node, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func _add_anim(target: Node, type: int, speed: float, amp: float, axis: Vector3 = Vector3.UP):
	var AnimatorScript = load("res://scripts/utils/ProceduralAnimator.gd")
	var anim = AnimatorScript.new()
	anim.setup(type, speed, amp, axis)
	target.add_child(anim)

# 1. Rusher: Spike-Hound
static func _build_rusher(root: Node3D, color: Color):
	# Core
	var core_mesh = SphereMesh.new()
	core_mesh.radius = 0.3
	core_mesh.height = 0.6
	var core = _add_mesh(root, core_mesh, Vector3(0, 0.5, 0), _get_mat(Color.BLACK))
	
	# Spikes
	for i in range(8):
		var spike = CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.08
		spike.height = 0.8
		
		var s_node = _add_mesh(core, spike, Vector3.ZERO, _get_mat(color))
		# Random rotation
		s_node.rotation = Vector3(randf()*6.28, randf()*6.28, randf()*6.28)
		# Push out
		s_node.position = s_node.transform.basis.y * 0.3
		
	# Animation: Jitter (Twitch)
	# JITTER = 3
	_add_anim(core, 3, 10.0, 0.05)


# 2. Controller: The Watcher
static func _build_controller(root: Node3D, color: Color):
	# Center Eye
	var eye_mesh = SphereMesh.new()
	eye_mesh.radius = 0.4
	eye_mesh.height = 0.8
	var eye = _add_mesh(root, eye_mesh, Vector3(0, 1.5, 0), _get_mat(color))
	_add_anim(eye, 4, 2.0, 0.2)
	
	# Orbiting Rings
	for i in range(3):
		var pivot = Node3D.new()
		pivot.position = Vector3(0, 1.5, 0)
		# Random tilt
		pivot.rotation = Vector3(randf(), randf(), randf())
		root.add_child(pivot)
		
		# Satellite
		var sat_mesh = SphereMesh.new()
		sat_mesh.radius = 0.1
		sat_mesh.height = 0.2
		var sat = _add_mesh(pivot, sat_mesh, Vector3(0.8, 0, 0), _get_mat(Color.WHITE))
		
		# Rotate Pivot = 1
		_add_anim(pivot, 1, (i+1) * 1.5, 0, Vector3.UP)


# 3. Exploder: Boil-Mass
static func _build_exploder(root: Node3D, color: Color):
	var center = Node3D.new()
	center.position.y = 0.8
	root.add_child(center)
	
	for i in range(5):
		var b_mesh = SphereMesh.new()
		var r = randf_range(0.2, 0.4)
		b_mesh.radius = r
		b_mesh.height = r * 2
		
		var offset = Vector3(randf()-0.5, randf()-0.5, randf()-0.5).normalized() * 0.3
		var blob = _add_mesh(center, b_mesh, offset, _get_mat(color))
		
		# Pulse asynchronously = 2
		var AnimatorScript = load("res://scripts/utils/ProceduralAnimator.gd")
		var anim = AnimatorScript.new()
		anim.setup(2, randf_range(3, 8), 0.2)
		anim._time = randf() * 10.0 # Random start
		blob.add_child(anim)
		
	# Chase/Roll animation handled by Unit movement mostly, but let's wobble the whole thing
	_add_anim(center, 1, 2.0, 0, Vector3(1,1,0).normalized())


# 4. Flying: Void-Ray
static func _build_flying(root: Node3D, color: Color):
	var pivot = Node3D.new()
	pivot.position.y = 2.0
	root.add_child(pivot)
	
	# Torus Disc
	var torus = TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.6
	var ring = _add_mesh(pivot, torus, Vector3.ZERO, _get_mat(color))
	
	# Floating Core
	var core_mesh = BoxMesh.new()
	core_mesh.size = Vector3(0.3, 0.3, 0.3)
	_add_mesh(pivot, core_mesh, Vector3.ZERO, _get_mat(Color.CYAN))
	
	# Tentacles (Chains)
	for t in range(3):
		var t_root = Node3D.new()
		t_root.position = Vector3(cos(t*2.0)*0.5, 0, sin(t*2.0)*0.5)
		pivot.add_child(t_root)
		
		for seg in range(4):
			var cube = BoxMesh.new()
			cube.size = Vector3(0.1, 0.1, 0.1)
			var node = _add_mesh(t_root, cube, Vector3(0, -0.4 * (seg+1), 0), _get_mat(color, true))
			# Visual only, no sophisticated IK here yet
			
	_add_anim(pivot, 4, 1.0, 0.5)


# 5. Infiltrator: Shadow-Shift
static func _build_infiltrator(root: Node3D, color: Color):
	var cap = CapsuleMesh.new()
	cap.radius = 0.25
	cap.height = 1.8
	var ghost = _add_mesh(root, cap, Vector3(0, 0.9, 0), _get_mat(Color.DARK_GRAY, true))
	
	# Glitch Effect (Jitter)
	_add_anim(ghost, 3, 20.0, 0.02)
	_add_anim(ghost, 2, 2.0, 0.1)


# 6. Tank: Obelisk
static func _build_tank(root: Node3D, color: Color):
	var box = BoxMesh.new()
	box.size = Vector3(0.8, 1.5, 0.8)
	var main = _add_mesh(root, box, Vector3(0, 0.75, 0), _get_mat(color))
	
	# Floating Shield Plates
	for i in range(4):
		var plate_pivot = Node3D.new()
		plate_pivot.position = Vector3(0, 0.75, 0)
		plate_pivot.rotation.y = i * (PI/2.0)
		root.add_child(plate_pivot)
		
		var plate = BoxMesh.new()
		plate.size = Vector3(0.2, 1.0, 0.1)
		var p_node = _add_mesh(plate_pivot, plate, Vector3(0.6, 0, 0), _get_mat(Color.DARK_SLATE_GRAY))
		
	# Slow heavy rotation
	_add_anim(root, 4, 0.5, 0.1)


# 7. Boss: The Abomination
static func _build_boss(root: Node3D, color: Color):
	# Scale everything up via root container?
	var bosses_root = Node3D.new()
	bosses_root.scale = Vector3(2.0, 2.0, 2.0)
	root.add_child(bosses_root)
	
	# Combine Controller Rings + Rusher Spikes + Exploder Core
	_build_controller(bosses_root, Color.GOLD)
	_build_rusher(bosses_root, Color.BLACK)
	
	var aura = SphereMesh.new()
	aura.radius = 2.0
	aura.height = 4.0
	var aura_node = _add_mesh(root, aura, Vector3(0, 1.0, 0), _get_mat(Color.RED, true))
	_add_anim(aura_node, 2, 1.0, 0.5)


# 8. Area Denial: The Bile-Spout
static func _build_area_denial(root: Node3D, color: Color):
	# Main Spout (Cylinder)
	var pipe_mesh = CylinderMesh.new()
	pipe_mesh.top_radius = 0.3
	pipe_mesh.bottom_radius = 0.1
	pipe_mesh.height = 1.0
	var pipe = _add_mesh(root, pipe_mesh, Vector3(0, 0.5, 0), _get_mat(color))
	
	# Pulsing Sacks at base
	for i in range(3):
		var sack_mesh = SphereMesh.new()
		sack_mesh.radius = 0.25
		sack_mesh.height = 0.4
		var pivot = Node3D.new()
		root.add_child(pivot)
		pivot.rotation.y = i * (2.0 * PI / 3.0)
		
		var sack = _add_mesh(pivot, sack_mesh, Vector3(0.25, 0.2, 0), _get_mat(Color.YELLOW_GREEN))
		
		# Pulse = 2
		_add_anim(sack, 2, 2.0 + i, 0.1)

	# Wobble the pipe = 3 (Jitter)
	_add_anim(pipe, 3, 5.0, 0.02)


# 9. Sniper: The Prism
static func _build_sniper(root: Node3D, color: Color):
	# Main Crystal (Prism)
	var prism_mesh = PrismMesh.new()
	prism_mesh.size = Vector3(0.5, 1.5, 0.5)
	var prism = _add_mesh(root, prism_mesh, Vector3(0, 1.0, 0), _get_mat(color))
	
	# Orbiting Shards
	for i in range(2):
		var shard_mesh = BoxMesh.new()
		shard_mesh.size = Vector3(0.1, 0.4, 0.1)
		var pivot = Node3D.new()
		root.add_child(pivot)
		pivot.position.y = 1.0
		pivot.rotation.z = (randf() - 0.5) * 0.5 # Slight tilt
		
		var shard = _add_mesh(pivot, shard_mesh, Vector3(0.6, 0, 0), _get_mat(Color.WHITE))
		
		# Rotate Pivot = 1
		_add_anim(pivot, 1, 1.0 + (i * 0.5), 0, Vector3.UP)

	# Main slow rotation = 1
	_add_anim(prism, 1, 0.5, 0, Vector3.UP)
