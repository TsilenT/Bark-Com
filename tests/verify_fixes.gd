
extends Node

const LOG_PREFIX = "VerifyFixes: "
var test_phase = ""

func _ready():
	print(LOG_PREFIX, "Starting Verification Tests (Scene Mode)...")
	
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	# Wait for Autoloads to settle
	await get_tree().process_frame
	
	_test_exploder_destruction()
	await get_tree().process_frame
	_test_acid_vfx_flow()
	
	print(LOG_PREFIX, "All Fixes Verified.")
	get_tree().quit()

func _test_exploder_destruction():
	test_phase = "Exploder Destruction"
	print(LOG_PREFIX, "--- ", test_phase, " ---")
	
	# Setup Context
	var root = Node3D.new()
	add_child(root)
	
	var user = Node3D.new()
	user.name = "Exploder"
	root.add_child(user)
	user.global_position = Vector3(0, 0, 0)
	
	# Setup Mock GridManager
	var gm_script = load("res://scripts/managers/GridManager.gd")
	var gm = gm_script.new()
	root.add_child(gm)
	
	# Spawn Destructible Object (Wall)
	var cover_script = load("res://scripts/entities/DestructibleCover.gd")
	var wall = Node3D.new()
	wall.set_script(cover_script)
	root.add_child(wall)
	wall.initialize(Vector2(1, 0), gm)
	wall.global_position = Vector3(2, 0, 0) # Within radius
	
	# Ensure it is in group
	if not wall.is_in_group("Destructible"):
		print("FAIL: Wall not in 'Destructible' group. Fix DestructibleCover.gd.")
		get_tree().quit(1)
		return

	# Load Ability
	var ability_script = load("res://scripts/abilities/ExplodeAbility.gd")
	var ability = ability_script.new()
	
	print("Executing ExplodeAbility...")
	# MOCK GridManager's get_world_aoe_radius relies on tile_size default
	
	ability.execute(user, null, Vector2.ZERO, gm)
	
	# Check Wall HP
	if wall.current_hp < wall.max_hp:
		print("PASS: Wall took damage (", wall.max_hp, " -> ", wall.current_hp, ")")
	else:
		print("FAIL: Wall took NO damage. Group iteration logic failed.")
		get_tree().quit(1)
		return
		
	# Cleanup
	root.queue_free()

func _test_acid_vfx_flow():
	test_phase = "Acid VFX"
	print(LOG_PREFIX, "--- ", test_phase, " ---")
	
	# 1. Check VFXManager Library
	var vfx_mgr_script = load("res://scripts/managers/VFXManager.gd")
	var vfx_mgr = vfx_mgr_script.new() # Singleton
	
	if vfx_mgr.vfx_library.has("AcidSpit"):
		print("PASS: 'AcidSpit' registered in VFXManager library.")
	else:
		print("FAIL: 'AcidSpit' missing from VFXManager library.")
		get_tree().quit(1)
		return
		
	# 3. Simulate Spawn
	var root = Node3D.new()
	add_child(root)
	
	print("Simulating Spawn AcidSpit...")
	var res = vfx_mgr.vfx_library["AcidSpit"]
	if res == null:
		print("FAIL: AcidSpit resource is null.")
		get_tree().quit(1)
		return
		
	var instance = res.new()
	if instance.has_method("initialize"):
		print("PASS: AcidProjectileVFX has 'initialize' method.")
	else:
		print("FAIL: AcidProjectileVFX missing 'initialize' method.")
		get_tree().quit(1)
		
	instance.queue_free()
	vfx_mgr.queue_free()
	root.queue_free()
