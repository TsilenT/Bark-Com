extends Node

var ui_script = load("res://scripts/ui/MissionControlTab.gd")
var ui

func log_msg(msg):
	print(msg)
	# Optional: Write to file if needed, but print is captured by runner
	# var f = FileAccess.open("user://verify_ui_log.txt", FileAccess.READ_WRITE)
	# if f:
	# 	f.seek_end()
	# 	f.store_line(msg)
	# 	f.close()

func _ready():
	print("--- Verify UI Persistence Logic ---")
	
	# Watchdog is handled by Runner usually, or we can add it safely
	# add_child(load("res://tests/TestSafeGuard.gd").new())
	
	await get_tree().process_frame
	
	# 1. Setup GameManager (Use Global Singleton)
	if not GameManager:
		print("FATAL: GameManager Autoload missing in Runner.")
		return
		
	GameManager.TEST_MOCK_ENABLED = true
	GameManager.roster.clear()
	
	# Add Units
	log_msg("Adding Recruits...")
	GameManager._add_recruit("Alpha", 1, "Scout")  # Index 0
	log_msg("Added Alpha")
	GameManager._add_recruit("Beta", 1, "Heavy")   # Index 1
	log_msg("Added Beta")
	GameManager._add_recruit("Gamma", 1, "Sniper") # Index 2
	log_msg("Added Gamma")
	GameManager._add_recruit("Delta", 1, "Medic")  # Index 3
	log_msg("Added Delta")
	GameManager._add_recruit("Echo", 1, "Scout")   # Index 4
	log_msg("Added Echo")
	
	# Mock Persistence: Last squad was Gamma (Idx 2) and Echo (Idx 4)
	GameManager.last_squad_ids = ["Gamma", "Echo"]
	log_msg("Set last_squad_ids")
	
	# 2. Setup UI
	log_msg("Instantiating UI...")
	ui = ui_script.new()
	# Add directly to tree to ensure _ready runs if needed (MissionControlTab uses add_child)
	add_child(ui) 
	
	ui.initialize(GameManager) # Inject Singleton
	ui.max_squad_size = 4
	log_msg("UI Instantiated.")
	
	log_msg("--- Calling _select_default_squad (Logic Check) ---")
	ui._select_default_squad()
	
	var sel = ui.selected_indices
	log_msg("Selected Indices: " + str(sel))
	
	var names = []
	for idx in sel:
		if idx < GameManager.roster.size():
			names.append(GameManager.roster[idx]["name"])
            
	log_msg("Selected Names: " + str(names))
	
	# EXPECTED: ["Gamma", "Echo", "Alpha", "Beta"] (Priority to last squad, then fill from start)
	
	var score = 0
	if names.has("Gamma") and names.has("Echo"):
		log_msg("SUCCESS: Persistence respected (Found Gamma & Echo).")
		score += 1
	else:
		log_msg("FAILURE: Did not prioritize Gamma and Echo.")
		
	if sel.size() == 4:
		log_msg("SUCCESS: Filled squad to max size.")
		score += 1
	else:
		log_msg("FAILURE: Squad size incorrect. Got: " + str(sel.size()))
		
	# Strict ordering check
	if names[0] == "Gamma" and names[1] == "Echo":
		log_msg("SUCCESS: Priority ordering correct.")
		score += 1
	else:
		log_msg("WARNING: Ordering differ or persistence failed.")
		
	if score >= 3:
		log_msg("VERIFICATION PASSED")
		# Signal success to runner (standardize via TestUtils later if needed, but for now just finish)
		# Or rely on standard runner output parsing "PASSED"
		pass
	else:
		log_msg("VERIFICATION FAILED")
		# Force failure
		printerr("FAIL: Score too low.")

	# Cleanup
	queue_free()
	get_tree().quit()
