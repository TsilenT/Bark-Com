extends Node

# verify_door_logic.gd
# Verifies that LevelGenerator post-processing removes invalid (free-standing) doors.

var generator_script = load("res://scripts/core/LevelGenerator.gd")
var generator

func _ready():
	print("Starting Door Logic Verification...")
	add_child(load("res://tests/TestSafeGuard.gd").new())
	await setup()
	test_invalid_door_removal()
	cleanup()
	print("Verification Completed.")
	get_tree().quit()

func setup():
	generator = generator_script.new()
	add_child(generator)
	await get_tree().process_frame

func test_invalid_door_removal():
	print("TEST: Invalid Door Removal")
	
	# Manually construct a grid with a floating door
	var grid = {}
	var center = Vector2(2,2)
	
	# 3x3 Grid of Floor
	for x in range(5):
		for y in range(5):
			var pos = Vector2(x,y)
			grid[pos] = {
				"type": 0, # GROUND
				"is_walkable": true,
				"elevation": 0
			}
			
	# Place Floating Door at Center
	grid[center] = {
		"type": 0,
		"is_walkable": true,
		"variant": "Door",
		"destructible": true
	}
	
	# Run Validation (We need to expose or call a new function, 
	# but strictly we test 'generate_level' which calls it.
	# Since generating a full level is random, we'll unit-test the validation function 
	# once we write it. For now, let's try to call the new function we PLAN to write: '_validate_door_placement')
	
	generator._validate_door_placement(grid)
	
	# Check result
	if grid[center].get("variant", "") == "Door":
		print("FAILURE: Floating door was NOT removed.")
	else:
		print("PASS: Floating door was removed/converted to Type " + str(grid[center]["type"]) + ".")

func cleanup():
	generator.queue_free()
