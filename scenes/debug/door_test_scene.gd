extends "res://scripts/core/Main.gd"

# scenes/debug/door_test_scene.gd
# Playable Scene that forces a Door-Heavy map for QA.

func _ready():
	print("--- MANUAL DOOR TEST SCENE ---")
	
	# Override Generator
	# LevelGenerator is referenced by Main via GridManager->generate_grid().
	LevelGenerator.override_mode = "DOOR_TEST"
	
	# Call Main._ready() which initializes GridManager and spawns scenario
	super._ready()
	
	# Clear Enemies for minimal test
	await get_tree().process_frame
	var units = get_tree().get_nodes_in_group("Units")
	for u in units:
		if is_instance_valid(u) and u.get("faction") == "Enemy":
			u.queue_free()
	print("Door Test: Enemies removed.")
	
	# Add Floating Text to confirm
	await get_tree().process_frame
	SignalBus.on_request_floating_text.emit(Vector3(5, 5, 5), "DOOR TEST MODE", Color.ORANGE)

func _exit_tree():
	# Reset Override
	LevelGenerator.override_mode = ""
