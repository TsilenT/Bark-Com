extends Node

func _ready():
	print("Verify Cover Visuals: START")
	
	# Watchdog
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)

	var root = Node3D.new()
	add_child(root)

	# Setup Camera
	var cam = Camera3D.new()
	cam.position = Vector3(10, 10, 15)
	root.add_child(cam)
	cam.look_at(Vector3(10, 0, 5))
	
	# Setup Light
	var light = DirectionalLight3D.new()
	light.position = Vector3(5, 10, 5)
	root.add_child(light)
	light.look_at(Vector3(0,0,0))
	
	# Setup GridManager
	var gm = GridManager.new()
	root.add_child(gm)
	
	# MOCK: Add a wall at (1, -1) to test rotation for prop at (1, 0)
	gm.grid_data[Vector2(1, -1)] = { 
		"type": GridManager.TileType.OBSTACLE,
		"is_walkable": false
	}

	var script = load("res://scripts/entities/DestructibleCover.gd")
	var variants = script.Variant.values()
	
	var x = 0
	var z = 0
	var stride = 3.0
	
	for v in variants:
		var cover = script.new()
		root.add_child(cover)
		cover.grid_pos = Vector2(x, z) # Mock grid pos
		cover.global_position = Vector3(x * stride, 0, z * stride)
		
		# Testing specific variants
		print("Spawning Variant Index: ", v)
		cover.initialize(Vector2(x,z), gm, "", v)
		
		# Add a label
		var label = Label3D.new()
		# Reverse lookup enum name
		var v_name = script.Variant.keys()[v]
		label.text = v_name
		label.position = Vector3(0, 2.5, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color.BLACK
		label.font_size = 32
		cover.add_child(label)
		
		# Visual Helper for Wall check
		if x == 1 and z == 0:
			print(" -> This prop (", v_name, ") should align with Wall at (1, -1) relative to (1, 0)")
			var wall_marker = MeshInstance3D.new()
			wall_marker.mesh = BoxMesh.new()
			wall_marker.position = Vector3(1 * stride, 1, -1 * stride) # Approximate world pos
			root.add_child(wall_marker)

		x += 1
		if x > 5:
			x = 0
			z += 1
			
	print("Verify Cover Visuals: GENERATION COMPLETE")

	# Check if headless
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		# Cleanup to satisfy LeakDetector
		root.queue_free()
		await get_tree().process_frame
		print("Headless mode: Exiting successfully.")
		get_tree().quit(0)
	else:
		print("Visual Mode: Leaving scene open.")
