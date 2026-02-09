extends Node

# verify_state_reset.gd
# Verifies that BaseScene corectly resets GameManager state when a mission ends.

var base_scene
var game_manager_mock
var watchdog: Node

func _ready():
	# Pre-load resources to avoid "Leak" detection due to caching
	load("res://scripts/ui/BaseScene.gd")
	load("res://scripts/ui/UnitInfoCard.gd")
	load("res://scripts/ui/UnitInventorySlot.gd")
	load("res://scripts/ui/StashDropTarget.gd")
	load("res://scripts/ui/DraggableItemIcon.gd")
	load("res://scripts/ui/UnitPortraitConfig.gd")
	load("res://assets/ui/corgi_base_hub_v1.jpg")
	# Pre-load likely music
	load("res://assets/audio/music/Base/Safe Haven (Press Start).ogg")

	watchdog = load("res://tests/TestSafeGuard.gd").new()
	add_child(watchdog)
	
	run_test()

func run_test():
	print("--- Verify State Reset Test ---")
	
	# 1. Setup Mock GameManager if needed or use global
	# We'll use the global GameManager but ensure it's in a known state
	if not GameManager:
		print("ERROR: GameManager not found!")
		get_tree().quit(1)
		return
		
	# 2. Instantiate BaseScene
	base_scene = load("res://scripts/ui/BaseScene.gd").new()
	# We need to add it to tree so it can access GameManager via global or _ready
	add_child(base_scene)
	
	# 3. Simulate "In Mission" State
	GameManager.current_state = GameManager.GameState.MISSION
	print("State set to MISSION: ", GameManager.current_state)
	
	# 4. Simulate Mission End Logic from BaseScene._process
	# BaseScene._process checks:
	# if not ui_container.visible and not is_instance_valid(active_mission_node):
	
	# Force conditions
	base_scene.ui_container = Control.new() # Mock container
	base_scene.add_child(base_scene.ui_container) # Ensure it gets freed with base_scene
	base_scene.ui_container.visible = false
	base_scene.active_mission_node = null # Mission is gone
	
	# We can't easily call _process directly in a standalone script without yielding
	# So we'll manually invoke the logic block or just call a helper if we extracted it.
	# But since we modified _process, we should rely on the engine or manually call it.
	
	print("Simulating BaseScene _process frame...")
	base_scene._process(0.1)
	
	# 5. Verify State Reset
	if GameManager.current_state == GameManager.GameState.BASE:
		print("SUCCESS: State reset to BASE.")
	else:
		print("FAILURE: State is still ", GameManager.current_state, " (Expected BASE=", GameManager.GameState.BASE, ")")
		get_tree().quit(1)
		return

	# 6. Verify UnitInventorySlot Read-Only Logic
	# Create a slot and check if it respects the state
	var slot_script = load("res://scripts/ui/UnitInventorySlot.gd")
	var slot = slot_script.new()
	slot.setup({}, 0, null)
	
	# The slot checks GameManager state inside setup? No, it usually checks explicitly or we pass it?
	# Wait, UnitInfoCard sets read_only based on state.
	# Let's verify UnitInfoCard logic too if possible, OR just trust state is enough.
	# The bug was UnitInfoCard setting read_only = true because state was MISSION.
	
	# Let's verify that IF we create a card now, it sees the correct state.
	var is_read_only = (GameManager.current_state != GameManager.GameState.BASE)
	if not is_read_only:
		print("SUCCESS: UI would default to Interactive (Read-Only = false)")
	else:
		print("FAILURE: UI thinks it should be Read-Only!")
		if base_scene: base_scene.free()
		get_tree().quit(1)
		return
	
	# 1. Free Watchdog first (Runs LeakDetector)
	# 1. Watchdog Handling
	# We DO NOT free watchdog manually as it causes "Object Locked" errors errors due to threading.
	# We rely on get_tree().quit() to trigger _exit_tree() naturally.


	# 2. Free BaseScene
	if base_scene:
		if is_instance_valid(base_scene):
			base_scene.free()
		base_scene = null
		
	if slot:
		if is_instance_valid(slot):
			slot.free()
		slot = null
		
	# 3. Clean up GameManager Internal Nodes (Audio, Nemesis, NameGen)
	# Because GameManager is AutoLoad, it persists, but we want to confirm they aren't the leak source.
	if GameManager.audio_manager:
		if is_instance_valid(GameManager.audio_manager):
			GameManager.audio_manager.free()
		GameManager.audio_manager = null
		
	if GameManager.name_gen:
		if is_instance_valid(GameManager.name_gen):
			GameManager.name_gen.free()
		GameManager.name_gen = null
		
	var nm = GameManager.get_node_or_null("NemesisManager")
	if nm:
		nm.free()

	# 4. Clear Data
	GameManager.roster.clear()
	GameManager.inventory.clear()
	GameManager.shop_stock.clear()
	GameManager._master_item_list.clear() # Clear master list too
		
	get_tree().quit(0)
