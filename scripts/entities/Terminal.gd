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

	# 1. Clear existing visuals (from Base Class initialization)
	for child in get_children():
		if child is MeshInstance3D:
			child.queue_free()

	# Override to look like a Terminal (Blue Box/Console)
	mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.0, 2.0, 1.0)  # High Cover
	mesh.mesh = box

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.0, 0.8)  # Tech Purple
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.2, 1.0)
	mat.emission_energy_multiplier = 1.0
	mesh.material_override = mat

	mesh.position.y = 1.0  # Center of 2.0 height
	add_child(mesh)


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
