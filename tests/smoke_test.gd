extends Node

func _ready():
	print("🚬 Smoke Test: Starting...")
	
	# Instantiate the main game scene
	# Clean Corrupt Save from persistence tests
	if FileAccess.file_exists("user://test_savegame.dat"):
		DirAccess.remove_absolute("user://test_savegame.dat")
		
	# SAFETY CHECK
	if GameManager:
		GameManager.TEST_MOCK_ENABLED = true
		GameManager.save_file_path = "user://test_savegame.dat"
		
	var main_scene_res = load("res://scenes/Base.tscn")
	if not main_scene_res:
		printerr("❌ Smoke Test FAILED: Main scene not found!")
		await TestUtils.finalize_and_quit(get_tree(), 1)
		return

	var main_scene = main_scene_res.instantiate()
	add_child(main_scene)
	print("✅ Smoke Test: Main scene instantiated successfully.")
	
	# Anti-Ghosting Safegu	# Watchdog
	var watchdog_script = load("res://tests/TestSafeGuard.gd")
	var watchdog = watchdog_script.new()
	add_child(watchdog)
	
	print("Running Smoke Test...")
	
	await get_tree().create_timer(1.0).timeout
	
	print("Smoke Test Complete.")
	
	watchdog.queue_free()
	print("🚬 Smoke Test: PASSED.")
	
	# Cleanup
	if GameManager.audio_manager: GameManager.audio_manager.stop_music()
	
	TestUtils.free_node(main_scene)
	await get_tree().process_frame # Allow cleanup frame
	
	await TestUtils.finalize_and_quit(get_tree(), 0)
