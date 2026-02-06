extends Node

func _ready():
	print("Verify ModelVisualizer Load: START")
	
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)
	
	var scene = load("res://scenes/debug/ModelVisualizer.tscn")
	if not scene: 
		print("Failed to load scene")
		get_tree().quit(1)
		return
		
	var viz = scene.instantiate()
	add_child(viz)
	
	# Wait for ready
	await get_tree().process_frame
	
	# Test switching to Cover Mode (Index 2)
	print("Switching to Cover Mode...")
	viz._on_mode_changed(2) # MODE_COVER
	
	await get_tree().process_frame
	
	# Test Spawning a Cover
	print("Spawning Cover Variant 0...")
	viz._on_cover_changed(0)
	
	await get_tree().process_frame
	
	# Verify pivot has children
	if viz.pivot.get_child_count() == 0:
		print("ERROR: Pivot has no children after spawn!")
		get_tree().quit(1)
		return
		
	var cover = viz.pivot.get_child(0)
	print("Spawned: ", cover)
	
	# Verify it has mesh
	# DestructibleCover now has 'mesh' property which might be a Node3D or MeshInstance
	if not cover.get("mesh"):
		print("ERROR: Cover has no mesh property set")
		get_tree().quit(1)
		return
		
	print("Verify ModelVisualizer Load: SUCCESS")
	get_tree().quit(0)
