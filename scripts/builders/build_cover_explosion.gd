@tool
extends SceneTree

func _init():
	var particles = GPUParticles3D.new()
	particles.name = "CoverExplosion"
	particles.set_script(load("res://scripts/vfx/AutoFree.gd"))
	
	# Material
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, -9.8, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.0
	
	particles.process_material = mat
	
	# Draw Pass (Splinters)
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.2, 0.2, 0.2)
	particles.draw_pass_1 = mesh
	
	particles.amount = 16
	particles.lifetime = 1.0
	particles.explosiveness = 1.0
	
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(particles)
	if result == OK:
		# Ensure directory exists
		var dir = DirAccess.open("res://")
		if not dir.dir_exists("scenes/vfx"):
			dir.make_dir("scenes/vfx")
			
		var err = ResourceSaver.save(packed_scene, "res://scenes/vfx/CoverExplosion.tscn")
		if err == OK:
			print("Successfully saved CoverExplosion.tscn")
		else:
			print("Failed to save CoverExplosion.tscn: ", err)
	else:
		print("Failed to pack scene: ", result)
	
	quit()
