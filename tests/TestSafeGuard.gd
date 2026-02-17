extends Node
# TestSafeGuard.gd
# Threaded Watchdog to prevent ghosts even if Main Thread freezes.

var timeout: float = 30.0
var _thread: Thread
var _quit_requested = false

func _ready():
	_thread = Thread.new()
	_thread.start(_watchdog_loop)
	print("TestSafeGuard: Watchdog started (Threaded). Timeout: ", timeout, "s")
	
	# Auto-Inject Test Mode (Suppress Audio/Visuals)
	# Use dynamic access to avoid compile-time dependency on GameManager Autoload
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.is_test_mode = true
		gm.TEST_MOCK_ENABLED = true # FORCE SAFETY
		# Force update save path immediately to be safe
		if gm.save_file_path == "user://savegame.dat":
			gm.save_file_path = "user://test_savegame.dat"
			print("TestSafeGuard: ENFORCED SAFE SAVE PATH -> ", gm.save_file_path)
	
	# Auto-Attach LeakDetector
	var ld_script = load("res://tests/LeakDetector.gd")
	if ld_script:
		var ld = ld_script.new()
		ld.name = "LeakDetector"
		add_child(ld)

func _exit_tree():
	_quit_requested = true
	if _thread.is_started():
		_thread.wait_to_finish()
		
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.is_test_mode = false
		
	# Check leaks on exit (if LeakDetector child exists)
	# Tolerance 2: TestSafeGuard itself + LeakDetector child are often counted as orphans during _exit_tree
	var ld = get_node_or_null("LeakDetector")
	if ld:
		ld.check_leaks(2)

func _watchdog_loop():
	var start_time = Time.get_ticks_msec()
	var limit_ms = timeout * 1000
	
	while not _quit_requested:
		if Time.get_ticks_msec() - start_time > limit_ms:
			_force_quit()
			break
		OS.delay_msec(500)

func _force_quit():
	# This runs on a thread. Godot API safety is limited.
	# Printing to stdout is usually safe.
	print("!!! TestSafeGuard: TIMEOUT REACHED (", timeout, "s) !!!")
	print("!!! FORCE QUITTING (Threaded) !!!")
	
	# Attempt to quit via Main Loop first (if responsive)
	call_deferred("_main_thread_quit")
	
	# Hard wait for main thread to react
	OS.delay_msec(2000)
	
	# If still here, panic exit.
	# OS.kill(OS.get_process_id()) is not available in GDScript 4.x standard API easily?
	# Using OS.crash() or triggering a fatal error.
	# print_stack() might help.
	# We can use OS.alert() but headless...
	
	# Try to exit aggressively
	get_tree().quit(1) 
	
	# If main loop is truly deadlocked, get_tree().quit() might queue nicely but never run.
	# We need a way to kill process.
	var pid = OS.get_process_id()
	
	if OS.get_name() == "Windows":
		OS.execute("taskkill", ["/F", "/PID", str(pid)])
	else:
		OS.execute("kill", ["-9", str(pid)])
		
	# Fallback crash if execute fails
	printerr("FATAL: WATCHDOG TIMEOUT. PROCESS HUNG. FORCING CRASH.")
	OS.crash("Watchdog Timeout")

func _main_thread_quit():
	get_tree().quit(1)
