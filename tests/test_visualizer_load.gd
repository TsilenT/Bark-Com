extends SceneTree

func _init():
	print("--- TEST: Visualizer Load ---")
	var scene = load("res://scenes/debug/ModelVisualizer.tscn")
	var instance = scene.instantiate()
	root.add_child(instance)
	
	# Simulate one frame
	await process_frame
	
	print("Visualizer instantiated successfully.")
	
	# Check if defaults loaded (Corgi mode)
	if instance.ui_mode_select.get_selected_id() == 0:
		print("Default mode: Corgi - OK")
	else:
		print("Default mode incorrect.")
		
	# Test switching to Enemy mode
	instance._on_mode_changed(1) # Enemy
	if instance.pivot.get_child_count() > 0:
		print("Spawned enemy model successfully.")
	else:
		print("Failed to spawn enemy model.")
		
	quit(0)
