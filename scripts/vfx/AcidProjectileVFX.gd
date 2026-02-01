extends Node3D

var projectile_mesh: MeshInstance3D

func _ready():
	projectile_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	projectile_mesh.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.LIME 
	mat.emission_enabled = true
	mat.emission = Color.LIME
	mat.emission_energy_multiplier = 0.5
	projectile_mesh.material_override = mat
	
	add_child(projectile_mesh)
	
func initialize(target_data):
	var end_pos = Vector3.ZERO
	if target_data is Vector3:
		end_pos = target_data
	elif target_data is Node3D:
		end_pos = target_data.global_position
	else:
		# No valid target, just drop?
		end_pos = global_position + Vector3(0, -1, 5) # Fallback forward
		
	_start_arc(end_pos)

func _start_arc(end_pos: Vector3):
	var start_pos = global_position
	var duration = 0.8
	var peak_height = 4.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Horizontal Linear
	tween.tween_property(self, "global_position:x", end_pos.x, duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "global_position:z", end_pos.z, duration).set_trans(Tween.TRANS_LINEAR)
	
	# Vertical Arc
	# Up
	(tween.tween_property(self, "global_position:y", start_pos.y + peak_height, duration / 2.0)
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD))
	
	# Down
	(tween.chain().tween_property(self, "global_position:y", end_pos.y, duration / 2.0)
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD))
		
	# Rotation
	var spin_tween = create_tween()
	spin_tween.tween_property(projectile_mesh, "rotation_degrees", Vector3(720, 360, 0), duration)
	
	await tween.finished
	_on_impact(end_pos)
	
func _on_impact(pos: Vector3):
	# Request Explosion
	var vfx_mgr = get_node_or_null("/root/GameManager/VFXManager")
	if not vfx_mgr:
		# Try global helper or standard path
		var root = get_tree().root
		if root.has_node("GameManager"):
			# Just rely on SignalBus to spawn recursive VFX?
			SignalBus.on_request_vfx.emit("Explosion", pos, Vector3.ZERO, null, null)
	else:
		# Direct call if available (unlikely due to singleton structure)
		pass
		
	# Fallback if no manager found: SignalBus is safe
	SignalBus.on_request_vfx.emit("Explosion", pos, Vector3.ZERO, null, null)
	
	queue_free()
