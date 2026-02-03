extends Node

func _ready():
	print("TEST: Verifying Version.gd...")
	
	# Add Watchdog (Strict Requirement)
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)
	
	# 1. Check File Existence
	if not FileAccess.file_exists("res://scripts/core/Version.gd"):
		print("FAILURE: res://scripts/core/Version.gd does not exist!")
		get_tree().quit(1)
		return

	# 2. Check Loadability and Content
	var script = load("res://scripts/core/Version.gd")
	if not script:
		print("FAILURE: Could not load Version.gd script!")
		get_tree().quit(1)
		return
		
	# 3. Check Constant
	var instance = script.new()
	if "BUILD_VERSION" in script:
		print("SUCCESS: Found static const BUILD_VERSION: ", script.BUILD_VERSION)
	elif "BUILD_VERSION" in instance: # Instance fallback
		print("SUCCESS: Found instance member BUILD_VERSION: ", instance.BUILD_VERSION)
	else:
		print("FAILURE: Version.gd loaded but missing BUILD_VERSION constant!")
		get_tree().quit(1)
		return

	# 4. Check BaseScene (Static Check)
	var base_scene = load("res://scripts/ui/BaseScene.gd")
	var source_code = base_scene.get_source_code()
	if "_setup_version_label" in source_code:
		print("SUCCESS: BaseScene has _setup_version_label method.")
	else:
		print("FAILURE: BaseScene missing _setup_version_label method!")
		get_tree().quit(1)
		return
	
	print("ALL CHECKS PASSED.")
	# Allow frame to process for nice cleanup
	await get_tree().process_frame
	get_tree().quit(0)
