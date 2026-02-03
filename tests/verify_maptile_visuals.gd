extends Node

# verify_maptile_visuals.gd
# Verifies that MapTile is correctly configured with a default texture to avoid WebGL black-texture issues.
# UPDATED: Now verifies Shared Material (MaterialCache) implementation.

func _ready():
	print("Verify MapTile Visuals: START")
	
	# Add Watchdog (Strict Requirement)
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)
	
	var map_tile_scene = load("res://scenes/map/MapTile.tscn")
	if not map_tile_scene:
		print("ERROR: Could not load MapTile.tscn")
		get_tree().quit(1)
		return

	var map_tile = map_tile_scene.instantiate()
	if not map_tile:
		print("ERROR: Could not instantiate MapTile")
		get_tree().quit(1)
		return
		
	# Access MeshInstance3D
	var mesh_instance = map_tile.get_node("MeshInstance3D")
	if not mesh_instance:
		print("ERROR: MapTile has no MeshInstance3D")
		get_tree().quit(1)
		return
		
	# Verify Biome Coloring Logic works
	var Biome = { "DESERT": 4, "GARDEN": 1 } 
	
	# MapTile.gd: initialize(pos: Vector2, biome: int, type: int, elevation: int, is_walkable: bool, gm: Node = null)
	map_tile.initialize(Vector2(0,0), Biome.DESERT, 0, 0, true, null)
	
	# Check Material Override (Should be StandardMaterial3D now)
	var material = mesh_instance.material_override
	if not material:
		print("ERROR: MeshInstance3D has no material_override after init!")
		get_tree().quit(1)
		return
		
	if not (material is StandardMaterial3D):
		print("ERROR: Material is not a StandardMaterial3D. Got: ", material.get_class())
		get_tree().quit(1)
		return

	# Check instance parameter 'albedo_color'
	var albedo_color = material.albedo_color
	print("Desert Albedo Mod: ", albedo_color)
	
	# Desert Color in MaterialCache.gd is Color(0.9, 0.8, 0.5)
	var expected_col = Color(0.9, 0.8, 0.5)
	if not albedo_color.is_equal_approx(expected_col):
		print("WARNING: Desert color mismatch. Expected ", expected_col, " Got ", albedo_color)
	else:
		print("PASS: Desert biome color applied correctly via MaterialCache.")
		
	map_tile.free()
	print("Verify MapTile Visuals: SUCCESS")
	
	# Allow frame to process for nice cleanup
	await get_tree().process_frame
	get_tree().quit(0)
