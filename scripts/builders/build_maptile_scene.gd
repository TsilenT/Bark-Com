@tool
extends SceneTree

func _init():
	var scene_root = Node3D.new()
	scene_root.name = "MapTile"
	scene_root.set_script(load("res://scripts/visuals/MapTile.gd"))
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	
	# Create Shader Material
	var shader = load("res://assets/shaders/MapTileShader.gdshader")
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader
	
	# Default Mesh (Can be swapped by script, but good for Editor Viz)
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(2.0, 0.2, 2.0)
	
	# Assign to MeshInstance
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = shader_mat # Use override to ensure it sticks
	
	scene_root.add_child(mesh_instance)
	mesh_instance.owner = scene_root
	
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(scene_root)
	if result == OK:
		var err = ResourceSaver.save(packed_scene, "res://scenes/map/MapTile.tscn")
		if err == OK:
			print("Successfully saved MapTile.tscn")
		else:
			print("Failed to save MapTile.tscn: ", err)
	else:
		print("Failed to pack scene: ", result)
	
	quit()
