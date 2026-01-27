extends Node

func _ready():
	print("--- VERIFY RESCUE REFACTOR (SCENE MODE) ---")
	
	# Allow Autoloads to initialize
	await get_tree().process_frame
	
	# Autoloads
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		print("FAIL: GameManager autoload not found.")
		get_tree().quit(1)
		return
		
	# Setup Mock Mode
	gm.TEST_MOCK_ENABLED = true
	
	# Setup Environment
	var main_node = Node.new()
	main_node.name = "Main"
	get_tree().root.add_child(main_node)
	
	var grid_manager = load("res://scripts/managers/GridManager.gd").new()
	grid_manager.name = "GridManager"
	main_node.add_child(grid_manager)
	
	var mission_manager = load("res://scripts/managers/MissionManager.gd").new()
	mission_manager.name = "MissionManager"
	main_node.add_child(mission_manager)
	
	var objective_manager = load("res://scripts/managers/ObjectiveManager.gd").new()
	objective_manager.name = "ObjectiveManager"
	main_node.add_child(objective_manager)
	
	var turn_manager = load("res://scripts/managers/TurnManager.gd").new()
	turn_manager.name = "TurnManager"
	main_node.add_child(turn_manager)

	# 3. Create Rescue Mission Config
	var config = load("res://scripts/resources/MissionConfig.gd").new()
	config.mission_name = "Test Rescue"
	config.objective_type = 1 # RESCUE
	config.objective_target_count = 1
	config.reward_recruit_data = {
		"name": "Private Ryan",
		"class": "Scout",
		"level": 3
	}
	
	# 4. Initialize Grid
	grid_manager.generate_grid()
	
	# 4b. Initialize ObjectiveManager
	objective_manager.initialize(config.objective_type, turn_manager, config.objective_target_count)
	
	# 5. Start Mission
	print("Starting Mission...")
	mission_manager.start_mission(config, grid_manager)
	
	# 6. Verify Checks
	await get_tree().create_timer(0.2).timeout # Allow spawning frame
	check_spawn(mission_manager, objective_manager, grid_manager)
	
	get_tree().quit(0)



func check_spawn(mm, om, p_grid_manager):
	var targets = get_tree().get_nodes_in_group("RescueTargets")
	print("Rescue Targets Count: ", targets.size())
	
	if targets.size() != 1:
		print("FAIL: Expected 1 rescue target. Found: ", targets.size())
		get_tree().quit(1)
		return
		
	var target = targets[0]
	print("Target Name: ", target.name)
	
	# Check Visual Beacon
	var beacon = target.get_node_or_null("RescueBeacon")
	if beacon:
		print("SUCCESS: RescueBeacon found.")
	else:
		print("FAIL: RescueBeacon missing.")
		get_tree().quit(1)
		return
		
	# Check Objective Text
	om.rescue_target = target
	var text = om.get_objective_text()
	print("Objective Text: ", text)
	
	if text != "Rescue Private Ryan!":
		print("FAIL: Objective text incorrect.")
		get_tree().quit(1)
		return

	# Check Interaction Group Logic (Simulate GameUI check)
	if not target.is_in_group("RescueTargets"):
		print("FAIL: Target not in RescueTargets group.")
		get_tree().quit(1)
		return
		
	print("SUCCESS: Target is in RescueTargets group (GameUI will see it).")
	
	# Regression Test: Check get_adjacent_tiles existence (Crash Fix)
	print("Checking get_adjacent_tiles...")
	if p_grid_manager.has_method("get_adjacent_tiles"):
		var adj = p_grid_manager.get_adjacent_tiles(Vector2(0,0))
		print("SUCCESS: get_adjacent_tiles exists. Returns: ", adj)
	else:
		print("FAIL: get_adjacent_tiles missing from GridManager!")
		get_tree().quit(1)
		return
		
	print("--- VERIFICATION PASSED ---")
