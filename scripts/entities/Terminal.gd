extends "res://scripts/entities/DestructibleCover.gd"
class_name Terminal

signal hack_complete(success: bool)

var is_hacked: bool = false
var difficulty: int = 0  # Modifier to hack chance?
var can_be_targeted: bool = false # Ignored by Enemy AI


func initialize(pos: Vector2, gm: Node, biome: String = "", variant_override: int = -1):
	# Call Base (DestructibleCover) to register with Grid
	# This WILL overwrite our visuals with a Crate/Variant.
	super.initialize(pos, gm, biome, variant_override)
	
	# RESTORE Terminal Visuals
	_setup_visuals()
	
	# Terminals are Full Cover (Override whatever set_variant did)
	# (Actually _setup_visuals makes a 2.0 high box, so it matches Full Cover visually)
	gm.update_tile_state(pos, false, 2.0, GridManager.TileType.COVER_FULL)





# VISUALS FIX: DestructibleCover calls set_variant() which makes a crate.
# Override to prevent double visuals.
func set_variant(_type: Variant):
	pass 

func _ready():
	# super._ready() calls _setup_visuals() via virtual method call,
	# preventing double mesh creation.
	super._ready()

	max_hp = 9999  # Terminals are indestructible visually (or override take_damage)
	current_hp = max_hp
	add_to_group("Terminals")


func take_damage(_amount: int):
	# Terminals are immune to damage
	SignalBus.on_request_floating_text.emit(self, "IMMUNE", Color.GRAY)


func _setup_visuals():
	# Allow suppression via Global Flag
	if GameManager and "is_test_mode" in GameManager and GameManager.is_test_mode:
		return

	# 1. Clear existing visuals (but preserve Collision)
	var sb: StaticBody3D = null
	for child in get_children():
		if child is StaticBody3D:
			sb = child
			continue # Don't delete collision
			
		if child is MeshInstance3D or child is Node3D: # Clear PropBuilder root or old meshes
			child.queue_free()

	# 2. Update Collision Shape if it exists
	if sb:
		for child in sb.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				child.shape.size = Vector3(1.0, 2.0, 1.0)
				child.position.y = 1.0

	# --- OMNISSIAH TERMINAL VISUALS ---
	var pb = load("res://scripts/builders/PropBuilder.gd").new()
	pb.start()
	
	# Colors
	var dark_metal = Color(0.15, 0.15, 0.18)
	var gold_trim = Color(0.7, 0.55, 0.2)
	var cable_black = Color(0.05, 0.05, 0.05)
	var parchment = Color(0.9, 0.85, 0.7)
	var wax_red = Color(0.6, 0.1, 0.1)
	
	# 1. Main Chassis (Gothic Arch Shape)
	# Base Plinth
	pb.add_box(Vector3(0, 0.2, 0), Vector3(1.2, 0.4, 1.2), dark_metal)
	# Main Body
	pb.add_box(Vector3(0, 1.0, 0), Vector3(1.0, 1.6, 0.8), dark_metal)
	# Arch Top (Approximated with Prism clipped or just top detail)
	pb.add_prism(Vector3(0, 1.9, 0), Vector3(1.0, 0.4, 0.8), dark_metal)
	
	# 2. Gold Trim / Buttresses
	# Side Columns
	pb.add_box(Vector3(-0.55, 1.0, 0), Vector3(0.1, 1.8, 0.9), gold_trim)
	pb.add_box(Vector3(0.55, 1.0, 0), Vector3(0.1, 1.8, 0.9), gold_trim)
	# Top Skull Motif (Representation)
	pb.add_sphere(Vector3(0, 1.9, 0.45), 0.15, gold_trim)
	
	# 3. Cables (Chaos/Industrial feel)
	for i in range(4):
		var x = -0.4 + i * 0.25
		pb.add_cylinder(Vector3(x, 0.8, -0.45), 0.05, 1.6, cable_black, Vector3(randf()*20, 0, 0))
		
	# 4. Purity Seal (The "Omnissiah" Touch)
	# Wax Seal
	pb.add_cylinder(Vector3(0.35, 1.4, 0.42), 0.08, 0.05, wax_red, Vector3(90, 0, 0))
	# Parchment Strips
	pb.add_box(Vector3(0.35, 1.1, 0.43), Vector3(0.1, 0.4, 0.01), parchment, Vector3(-5, 5, 0))
	
	# Commit Chassis
	pb.commit(self)
	
	# 5. Screen (Separate Mesh for Hacked State)
	mesh = MeshInstance3D.new()
	var screen_box = BoxMesh.new()
	screen_box.size = Vector3(0.7, 0.5, 0.1)
	mesh.mesh = screen_box
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.2, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 1.0, 0.0) # CRT Green (Un-hacked state: Generic Green text)
	# Wait, logic says purple/red = unhacked? 
	# Terminal.gd logic: is_hacked starts false.
	# Let's make Default state "Red/Unlock Me" and Hacked state "Green/Access Granted".
	# Existing Hack logic: 
	#   is_hacked = false
	#   _update_visuals_hacked() -> Change to Green.
	# So current default should be Red or "Waiting".
	
	mat.albedo_color = Color(0.3, 0.0, 0.0)
	mat.emission = Color(0.9, 0.1, 0.1) # Evil Red Eye / Locked
	mat.emission_energy_multiplier = 1.0
	mesh.material_override = mat
	
	mesh.position = Vector3(0, 1.3, 0.4) # Embedded on front face
	mesh.rotation_degrees.x = -15 # Tilted up slightly
	add_child(mesh)


var beam_mesh: MeshInstance3D

func on_vision_update(is_visible: bool, is_explored: bool):
	# Base visibility handled by VisionManager setting .visible = is_visible
	# But we want the Beam to depend on IS_EXPLORED.
	
	if is_explored:
		_show_beam(true)
		_update_beam_color()
	else:
		_show_beam(false)

func _show_beam(active: bool):
	if active:
		if not beam_mesh:
			_create_beam()
		beam_mesh.visible = true
	else:
		if beam_mesh:
			beam_mesh.visible = false

func _update_beam_color():
	if not beam_mesh or not beam_mesh.material_override:
		return
		
	var mat = beam_mesh.material_override
	if is_hacked:
		mat.albedo_color = Color(0.0, 1.0, 0.2, 0.3) # Green Transparent
		mat.emission = Color(0.0, 1.0, 0.2)
	else:
		mat.albedo_color = Color(0.0, 1.0, 1.0, 0.3) # Cyan Transparent
		mat.emission = Color(0.0, 1.0, 1.0)

func _create_beam():
	beam_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 10.0 # Tall beam
	beam_mesh.mesh = cyl
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 1.0, 1.0, 0.3) # Cyan Transparent
	mat.emission_enabled = true
	mat.emission = Color(0.0, 1.0, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	beam_mesh.material_override = mat
	beam_mesh.position.y = 7.1 # Sit on top of terminal (Height 2.1 + Half-Beam 5.0)
	add_child(beam_mesh)

func hack(user) -> bool:
	if is_hacked:
		print("Terminal already hacked!")
		return false

	var tech = 0
	if "tech_score" in user:
		tech = user.tech_score
	
	var base_chance = 70
	var final_chance = clamp(base_chance + tech, 0, 100)
	
	# Roll
	var roll = randi() % 100 + 1
	var success = roll <= final_chance
	
	print("Terminal: Hack Attempt by ", user.name, " (Tech: ", tech, "). Roll: ", roll, " vs ", final_chance)

	on_hack_result(success)
	return success



func on_hack_result(success: bool):
	if success:
		is_hacked = true
		_update_visuals_hacked()
		_update_beam_color() # Update beam immediately
		emit_signal("hack_complete", true)
		SignalBus.on_request_floating_text.emit(
			self, "HACKED!", Color.GREEN
		)
		if GameManager and GameManager.audio_manager:
			GameManager.audio_manager.play_sfx("SFX_Menu")  # Placeholder for Hack Sound
	else:
		emit_signal("hack_complete", false)  # Failure trigger
		SignalBus.on_request_floating_text.emit(
			self, "ACCESS DENIED", Color.RED
		)
		if GameManager and GameManager.audio_manager:
			GameManager.audio_manager.play_sfx("SFX_Miss")  # Placeholder for Error


func _update_visuals_hacked():
	if mesh and mesh.material_override:
		var mat = mesh.material_override
		mat.albedo_color = Color(0.0, 0.8, 0.2)  # Green
		mat.emission = Color(0.2, 1.0, 0.2)
