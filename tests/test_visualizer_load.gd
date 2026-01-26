extends Node3D

# test_visualizer_load.gd (Refactored)

func _ready():
	print("--- TEST: Visualizer Load ---")
	
	# Watchdog
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)

	_run_test()
	
func _run_test():
	var scene = load("res://scenes/debug/ModelVisualizer.tscn")
	var instance = scene.instantiate()
	add_child(instance)
	
	# Simulate one frame
	await get_tree().process_frame
	
	print("Visualizer instantiated successfully.")
	
	# Check if defaults loaded (Corgi mode)
	if instance.ui_mode_select.get_selected_id() == 0:
		print("Default mode: Corgi - OK")
	else:
		print("Default mode incorrect.")
		
	# Test switching to Enemy mode
	instance._on_mode_changed(1) # Enemy
	
	await get_tree().process_frame
	
	if instance.pivot.get_child_count() > 0:
		print("Spawned enemy model successfully.")
	else:
		print("Failed to spawn enemy model.")
		
	await get_tree().process_frame
	get_tree().quit(0)
