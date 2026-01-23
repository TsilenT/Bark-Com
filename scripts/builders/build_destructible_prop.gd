@tool
extends SceneTree

func _init():
	var root = Node3D.new()
	root.name = "DestructibleProp"
	
	# Mesh Instance
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "PropMesh"
	
	var box = BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	mesh_inst.mesh = box
	
	# Material (Crate Texture)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.4, 0.2) # Brown
	mat.roughness = 0.8
	mesh_inst.material_override = mat
	
	# Offset to sit on ground (Center is at 0,0,0, so move up by 0.5)
	mesh_inst.position.y = 0.5
	
	root.add_child(mesh_inst)
	mesh_inst.owner = root
	
	# We don't need collision here because DestructibleCover.gd adds a StaticBody.
	# But maybe we should include it here for simpler usage?
	# The plan says "Create DestructibleProp scene (Visuals)".
	# DestructibleCover.gd currently creates StaticBody manually. 
	# Let's keep it purely visual to match current architecture, 
	# allowing DestructibleCover to wrap it.
	
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(root)
	if result == OK:
		var dir = DirAccess.open("res://")
		if not dir.dir_exists("scenes/entities"):
			dir.make_dir("scenes/entities")
			
		var err = ResourceSaver.save(packed_scene, "res://scenes/entities/DestructibleProp.tscn")
		if err == OK:
			print("Successfully saved DestructibleProp.tscn")
		else:
			print("Failed to save DestructibleProp.tscn: ", err)
	else:
		print("Failed to pack scene: ", result)
	
	quit()
