extends Node

const LOG_PREFIX = "TestDoubleText: "

# Mocks
var fog_manager
var unit
var poison_effect
var watchdog

var text_emissions = []

func _ready():
	# 0. Setup Watchdog (Required by Test Runner)
	watchdog = load("res://tests/TestSafeGuard.gd").new()
	add_child(watchdog)

	_setup_test_environment()
	run_test()

func _setup_test_environment():
	print(LOG_PREFIX, "Setting up test environment...")
	
	# 1. Access SignalBus (Should be globally available in Scene run)
	if SignalBus:
		print(LOG_PREFIX, "Connected to SignalBus.")
		SignalBus.on_request_floating_text.connect(_on_floating_text)
	else:
		print(LOG_PREFIX, "CRITICAL: SignalBus not found via global access.")
		# Check if we can find it in root
		var sb = get_node_or_null("/root/SignalBus")
		if sb:
			print(LOG_PREFIX, "Found SignalBus in root (Autoload).")
			sb.on_request_floating_text.connect(_on_floating_text)
		else:
			print(LOG_PREFIX, "CRITICAL: SignalBus truly missing.")
			quit(1)

	# 2. Setup Unit
	unit = load("res://scripts/entities/Unit.gd").new()
	unit.name = "TestUnit"
	unit.unit_name = "TestUnit"
	unit.max_hp = 10
	unit.current_hp = 10
	unit.max_sanity = 100
	unit.current_sanity = 100
	
	# Add Label3D to trigger legacy checks in PoisonEffect
	var lbl = Label3D.new()
	lbl.name = "Label3D"
	unit.add_child(lbl)
	
	add_child(unit) # Add to tree so it can find things if needed
	
	# 3. Setup FogManager
	fog_manager = load("res://scripts/managers/FogManager.gd").new()
	fog_manager.name = "FogManager"
	# We need to mock 'is_tile_explored' or just use its internal state
	fog_manager.visited_tiles = {} # Empty = Unexplored
	add_child(fog_manager)
	
	# 4. Setup Poison Effect
	poison_effect = load("res://scripts/resources/effects/PoisonEffect.gd").new()

func _on_floating_text(target, text, color):
	print(LOG_PREFIX, "Captured Text: '", text, "' for ", target.name)
	text_emissions.append(text)

func run_test():
	print(LOG_PREFIX, "--- STARTING TESTS ---")
	
	# TEST 1: Fog Damage
	print(LOG_PREFIX, "Test 1: Fog Damage Double Text")
	text_emissions.clear()
	
	# Force unit to take fog damage
	# FogManager apply_sanity_penalties expects unit to be in "units" list
	if unit.current_hp > 0:
		fog_manager.apply_sanity_penalties([unit])
	
	# Assertions
	# Expectation: 1 message (Sanity Dmg only)
	print(LOG_PREFIX, "Emissions: ", text_emissions)
	if text_emissions.size() == 1:
		print(LOG_PREFIX, "[SUCCESS-FIX] Verified Single Text for Fog.")
	else:
		print(LOG_PREFIX, "[FAILURE-FIX] Fog Text Count is ", text_emissions.size(), " (Expected 1)")

	# TEST 2: Poison Damage
	print(LOG_PREFIX, "Test 2: Poison Damage Double Text")
	text_emissions.clear()
	
	unit.current_hp = 10 # Reset
	unit.apply_effect(poison_effect)
	# Trigger Turn End
	poison_effect.on_turn_end(unit)
	
	# Assertions
	# Expectation: 1 message (Damage number only)
	print(LOG_PREFIX, "Emissions: ", text_emissions)
	
	if text_emissions.size() == 1:
		print(LOG_PREFIX, "[SUCCESS-FIX] Verified Single Text for Poison.")
	else:
		print(LOG_PREFIX, "[FAILURE-FIX] Poison Text Count is ", text_emissions.size(), " (Expected 1)")
		
	quit(0)

func quit(code):
	# Cleanup
	if unit: unit.queue_free()
	if fog_manager: fog_manager.queue_free()
	get_tree().quit(code)
