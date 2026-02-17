extends Node

const LOG_PREFIX = "VerifySaveProtection: "
const PROD_SAVE_PATH = "user://savegame.dat"
const TEST_SAVE_PATH = "user://test_savegame.dat"

func _ready():
	_run_test()

func _run_test():
	print(LOG_PREFIX + "Starting Test...")
	
	# 1. Setup Dummy Production Save
	var f = FileAccess.open(PROD_SAVE_PATH, FileAccess.WRITE)
	f.store_string("CRITICAL_USER_DATA")
	f.close()
	
	if not FileAccess.file_exists(PROD_SAVE_PATH):
		_fail("Failed to create dummy production save.")
		return
		
	print(LOG_PREFIX + "Dummy Production Save Created.")
	
	# 2. Initialize Game Manager (if not present, but likely AutoLoad)
	# But we are in a test runner usually.
	# If running via run_tests.ps1, GM is AutoLoad.
	# If running via raw godot command, GM might be AutoLoad if configured in project.godot
	
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		_fail("GameManager not found.")
		return
		
	# 3. Instantiate TestSafeGuard (Simulate Test Environment)
	print(LOG_PREFIX + "Initializing TestSafeGuard...")
	var safeguard_script = load("res://tests/TestSafeGuard.gd")
	var safeguard = safeguard_script.new()
	add_child(safeguard)
	
	# 4. Verify Safety Intercepts
	print(LOG_PREFIX + "Verifying GM Config...")
	if not gm.is_test_mode:
		_fail("TestSafeGuard failed to set is_test_mode.")
		return
		
	if not gm.TEST_MOCK_ENABLED:
		_fail("TestSafeGuard failed to set TEST_MOCK_ENABLED.")
		return
		
	if gm.save_file_path == PROD_SAVE_PATH:
		_fail("GameManager is still pointing to PRODUCTION save path!")
		return
		
	if gm.save_file_path != TEST_SAVE_PATH:
		print(LOG_PREFIX + "WARNING: Save path is " + gm.save_file_path + " (Expected " + TEST_SAVE_PATH + ")")
	
	# 5. Trigger Destruction
	print(LOG_PREFIX + "Triggering delete_save()...")
	gm.delete_save()
	
	# 6. Verify Production Save Survives
	if not FileAccess.file_exists(PROD_SAVE_PATH):
		_fail("CRITICAL FAILURE: Production save was DELETED!")
		return
		
	var content = FileAccess.get_file_as_string(PROD_SAVE_PATH)
	if content != "CRITICAL_USER_DATA":
		_fail("CRITICAL FAILURE: Production save content corrupted!")
		return
		
	print("PASSED: Production Save Intact.")
	
	# Cleanup
	# Delete dummy files
	DirAccess.remove_absolute(PROD_SAVE_PATH)
	DirAccess.remove_absolute(TEST_SAVE_PATH)
	
	get_tree().quit(0)

func _fail(msg):
	print("FAIL: " + msg)
	get_tree().quit(1)
