extends Node

var destructible_cover_script = load("res://scripts/entities/DestructibleCover.gd")
var pmc_script = load("res://scripts/controllers/PlayerMissionController.gd")
var grid_manager_script = load("res://scripts/managers/GridManager.gd")
var mock_unit_script = load("res://tests/MockPlayerUnit.gd")

var gm
var player
var cover
var pmc

func _ready():
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)
	
	setup()
	run_test()

func setup():
	# 1. Setup Grid
	gm = grid_manager_script.new()
	gm.name = "GridManager"
	add_child(gm)
	gm.grid_data.clear()
	for x in range(10):
		for y in range(10):
			var coord = Vector2(x, y)
			gm.grid_data[coord] = {
				"type": 0, # GROUND
				"is_walkable": true,
				"elevation": 0,
				"cover_height": 0.0
			}
	gm.setup_astar()
	
	# 2. Setup Player Unit
	player = mock_unit_script.new()
	player.name = "Player"
	player.grid_pos = Vector2(5, 5)
	player.faction = "Player"
	add_child(player)
	
	# 3. Setup Destructible Cover
	cover = destructible_cover_script.new()
	cover.name = "Cover"
	cover.grid_pos = Vector2(6, 5) # Adjacent
	add_child(cover)
	
	# 4. Setup PMC
	print("TEST: Creating PMC...")
	if not pmc_script:
		printerr("FAILURE: PlayerMissionController script failed to load!")
		get_tree().quit(1)
		return
		
	pmc = pmc_script.new()
	if not pmc:
		printerr("FAILURE: Failed to instantiate PMC!")
		get_tree().quit(1)
		return
		
	pmc.name = "PMC"
	pmc.grid_manager = gm
	pmc.main_node = self # Mock main
	pmc.selected_unit = player
	add_child(pmc)
	print("TEST: PMC Created: ", pmc)

var ability_executed = false
# Mock Main functions called by PMC
func _execute_ability(ability, user, target, grid_pos):
	ability_executed = true
	print("TEST: Ability Executed on ", target)

func _process_move_or_interact(grid_pos):
	print("TEST: Process Move or Interact called for ", grid_pos)

func _clear_targeting_visuals():
	pass
	
func _on_mouse_hover(grid_pos):
	pass

func run_test():
	print("TEST: Starting Cover Targeting Test...")
	
	if not pmc:
		printerr("FAILURE: PMC is null in run_test!")
		get_tree().quit(1)
		return
		
	# Attempt to validate via PMC public API
	# InputState.TARGETING = 2
	pmc.set_input_state(2)
	pmc.selected_ability = null # Default attack
	
	# Simulate Click on Cover
	print("TEST: Simulating click on cover at ", cover.grid_pos)
	pmc.handle_tile_clicked(cover.grid_pos, MOUSE_BUTTON_LEFT)
	print("TEST: Click handled. Waiting for result...")
	
	await get_tree().create_timer(0.5).timeout
	
	if not ability_executed:
		printerr("FAILURE: Cover was NOT targeted/attacked. PMC Validation likely failed.")
		# Force exit with failure for runner
		get_tree().quit(1)
	else:
		print("SUCCESS: Cover was targeted successfully.")
		_cleanup()
		get_tree().quit(0)

func _cleanup():
	if is_instance_valid(pmc): pmc.free()
	if is_instance_valid(cover): cover.free()
	if is_instance_valid(player): player.free()
	if is_instance_valid(gm): gm.free()
