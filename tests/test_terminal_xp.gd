extends Node

var terminal_script = load("res://scripts/ui/TerminalPanel.gd")

func _ready():
	print("--- TEST: Terminal XP Command HP Scaling ---")
	
	# Anti-Ghosting
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		print("❌ FAIL: GameManager not found.")
		return
		
	# SAFETY
	gm.TEST_MOCK_ENABLED = true
	gm.save_file_path = "user://test_savegame.dat"
	
	# 1. Setup Roster: Recruit at Lvl 1 with Damage
	# Initial Stats for Recruit Lvl 1: Max HP ~31? (Depends on Unit.gd Base)
	# Let's say we set HP to 1. Damage Taken = Max - 1.
	# Level 2 should increase Max HP by X. 
	# New Current HP should be New Max - Damage Taken.
	
	var unit_script = load("res://scripts/entities/Unit.gd")
	var temp = unit_script.new()
	# USE UNKNOWN CLASS TO TRIGGER FALLBACK (Simulate User Issue)
	temp.apply_class_stats("Recruit") 
	temp.rank_level = 1
	temp.recalculate_stats()
	var base_max = temp.max_hp
	temp.queue_free()
	
	var unit_data = {
		"name": "TestSubject",
		"class": "Recruit", # Valid Class
		"level": 1,
		"xp": 0,
		"max_hp": base_max,
		"hp": 1, 
		"sanity": 100,
		"inventory": [],
		"cosmetics": {},
		"status": "Ready"
	}
	
	gm.roster.clear()
	gm.roster.append(unit_data)
	
	print("Initial State: Lvl 1, HP 1/" + str(base_max))
	
	# 2. Instantiate Terminal
	var terminal = terminal_script.new()
	add_child(terminal)
	
	# 3. Simulate Command: Give enough XP to hit Level 2 (100 XP)
	print("Executing 'xp 100'...")
	terminal._process_command("xp 100")
	
	await get_tree().process_frame
	
	# 4. Verify Roster
	var res = gm.roster[0]
	print("Result State: Class " + res.get("class", "???") + ", Lvl " + str(res["level"]) + ", HP " + str(res["hp"]) + "/" + str(res["max_hp"]))
	
	var passed = true
	
	if res.get("class") != "Recruit":
		print("❌ FAIL: Class Reset! Expected Recruit, Got: " + str(res.get("class")))
		passed = false

	if res["level"] != 2:
		print("❌ FAIL: Level did not increase to 2.")
		passed = false
		
	if res["max_hp"] <= base_max:
		print("❌ FAIL: Max HP did not increase. (Old: " + str(base_max) + ", New: " + str(res["max_hp"]) + ")")
		passed = false
		
	# Damage Calculation
	# Damage Taken was (base_max - 1).
	# Expected HP = (new_max) - (base_max - 1)
	# i.e. NewHP - OldHP should equal NewMax - OldMax (Growth is applied to both)
	var growth = res["max_hp"] - base_max
	var expected_hp = 1 + growth
	
	if res["hp"] != expected_hp:
		print("❌ FAIL: HP Persistence broken. Expected " + str(expected_hp) + ", Got " + str(res["hp"]))
		passed = false
	else:
		print("✅ PASS: HP grew correctly by " + str(growth) + ".")
		
	if passed:
		print("✅ ALL CHECKS PASSED.")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
