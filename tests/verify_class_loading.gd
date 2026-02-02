extends SceneTree

func _init():
	print("TEST START: Class Loading Verification")
	
	# Watchdog
	var watchdog = load("res://tests/TestSafeGuard.gd").new()
	get_root().add_child(watchdog)
	
	await process_frame
	
	# Check GameManager presence (Autoload)
	var gm = get_root().get_node_or_null("GameManager")
	if not gm:
		print("CRITICAL: GameManager not found!")
		quit(1)
		return

	var classes = gm.get_available_classes()
	print("Classes Found: ", classes)
	
	# Assertions
	if classes.size() == 0:
		print("FAILURE: No classes returned.")
		quit(1)
		return
		
	if not classes.has("Recruit"):
		print("FAILURE: 'Recruit' class missing.")
		quit(1)
		return

	for c in classes:
		if c.ends_with("Data") or c.ends_with(".tres") or c.ends_with(".remap"):
			print("FAILURE: Class name not cleaned: ", c)
			quit(1)
			return

	print("SUCCESS: Class loading verified.")
	
	# Cleanup
	# watchdog.free() # Watchdog cleans itself up or on tree exit
		
	print("Test Finished Successfully.")
	quit(0)
