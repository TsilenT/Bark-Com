extends SceneTree

func _init():
	print("--- Testing Class Loading ---")
	
	# Watchdog
	var watchdog = load("res://tests/TestSafeGuard.gd").new()
	get_root().add_child(watchdog)
	
	test_dir_access()
	
	# Cleanup
	# watchdog.free() # Watchdog cleans itself up
	quit()

func test_dir_access():
	var path = "res://assets/data/classes/"
	var dir = DirAccess.open(path)
	if not dir:
		print("ERROR: Failed to open directory: ", path)
		print("Error Code: ", DirAccess.get_open_error())
		return

	print("Opened directory successfully: ", path)
	dir.list_dir_begin() # Defaults to including hidden?
	
	var file_name = dir.get_next()
	var count = 0
	while file_name != "":
		print("Found: '", file_name, "' | Is Dir: ", dir.current_is_dir())
		if not dir.current_is_dir():
			if file_name.ends_with("Data.tres"):
				print(" -> MATCH: ", file_name)
			elif file_name.ends_with("Data.tres.remap"):
				print(" -> REMAP MATCH: ", file_name)
		count += 1
		file_name = dir.get_next()
	
	print("Total entries: ", count)
