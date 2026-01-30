extends Node

var spawner
var gm
var tm

func _ready():
	print("--- TEST UNIT SPAWNER ---")
	
	# Anti-Hang Safeguard
	add_child(load("res://tests/TestSafeGuard.gd").new()) 

	setup_mocks()
	
	test_spawn_rusher()
	test_spawn_bad_type()
	
	print("ALL UNIT SPAWNER TESTS PASSED")
	_cleanup()

func setup_mocks():
	gm = load("res://scripts/managers/GridManager.gd").new()
	gm.astar = AStar3D.new() # Initialize AStar manually for mock
	add_child(gm)
	
	# Populate GridData manually so get_random_valid_position works
	# Create a 3x3 grid of walkable tiles
	for x in range(3):
		for y in range(3):
			var vec = Vector2(x, y)
			gm.grid_data[vec] = {
				"is_walkable": true,
				"global_pos": Vector3(x, 0, y)
			}
			# AStar setup usually done in _ready or init_grid
			# We can manually add points if AStar is initialized
			if gm.astar:
				var id = gm._get_point_id(vec)
				gm.astar.add_point(id, Vector3(x, 0, y))
				
	# Connect points
	if gm.astar:
		gm.astar.connect_points(gm._get_point_id(Vector2(0,0)), gm._get_point_id(Vector2(0,1)))
		# Connect 1,1 (Player Start Approx) to others
		gm.astar.connect_points(gm._get_point_id(Vector2(1,1)), gm._get_point_id(Vector2(0,0)))
		
	tm = Node.new()
	tm.name = "TurnManager"
	# Add mock units array
	tm.set_meta("units", []) 
	# GDScript: local script
	var script = GDScript.new()
	script.source_code = "extends Node\nvar units = []\nfunc register_unit(u): units.append(u)"
	script.reload()
	tm.set_script(script)
	add_child(tm)

	spawner = load("res://scripts/builders/UnitSpawner.gd").new()

func test_spawn_rusher():
	print("Testing Spawn Rusher...")
	var unit = spawner.spawn_enemy("Rusher", gm, tm)
	
	if not unit:
		fail_test("Unit is null")
		return
		
	if unit.name != "RusherEnemy": # Default name is usually class name or set in script
		# Might be "RusherEnemy" or "Rusher" depending on scene/script
		print("  > Spawned Name: ", unit.name)
		
	if unit.is_in_group("Enemies"):
		print("  > Group 'Enemies' OK")
	else:
		fail_test("Missing 'Enemies' group")
		
	if tm.units.has(unit):
		print("  > Registered in TurnManager OK")
	else:
		fail_test("Failed to register in TurnManager")
		
	print("PASS: Rusher Spawn")

func test_spawn_bad_type():
	print("Testing Spawn Invalid Type...")
	var unit = spawner.spawn_enemy("InvalidType", gm, tm)
	if unit == null:
		print("PASS: Invalid Type returned null")
	else:
		fail_test("Invalid Type returned a unit!")

func _cleanup():
	await get_tree().process_frame
	if gm: gm.queue_free()
	if tm: tm.queue_free()
	get_tree().quit(0)

func fail_test(msg):
	print("FAIL: " + msg)
	get_tree().quit(1)
