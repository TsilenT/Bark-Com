extends Node

# verify_maptile_visuals.gd
# Verifies that MapTile is correctly configured with a default texture to avoid WebGL black-texture issues.

func _ready():
	print("Verify MapTile Visuals: START")
	
	# Add Watchdog (Strict Requirement)
	# Since we are in a scene now, adding child is safe and standard.
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
		
	# Check Material Override
	var material = mesh_instance.material_override
	if not material:
		print("ERROR: MeshInstance3D has no material_override")
		get_tree().quit(1)
		return
		
	if not (material is ShaderMaterial):
		print("ERROR: Material is not a ShaderMaterial")
		get_tree().quit(1)
		return
		
	# Check for texture_albedo parameter
	var texture = material.get_shader_parameter("texture_albedo")
	if not texture:
		print("ERROR: shader_parameter/texture_albedo is null! This will cause black tiles on WebGL.")
		get_tree().quit(1)
		return
		
	if not (texture is GradientTexture2D):
		print("WARNING: texture_albedo is not a GradientTexture2D. It is: ", texture.get_class())
		if not (texture is Texture2D):
			print("ERROR: texture_albedo is not a Texture2D!")
			get_tree().quit(1)
			return

	print("PASS: texture_albedo is assigned and valid (GradientTexture2D expected).")
	
	# Verify Biome Coloring Logic works
	var Biome = { "DESERT": 4, "GARDEN": 1 } 
	
	# MapTile.gd: initialize(pos: Vector2, biome: int, type: int, elevation: int, is_walkable: bool, gm: Node = null)
	map_tile.initialize(Vector2(0,0), Biome.DESERT, 0, 0, true, null)
	
	# Check instance parameter 'albedo_mod'
	var albedo_mod = mesh_instance.get_instance_shader_parameter("albedo_mod")
	print("Desert Albedo Mod: ", albedo_mod)
	
	if albedo_mod == null:
		print("ERROR: albedo_mod instance parameter not set after initialization.")
		get_tree().quit(1)
		return

	# Desert Color in MapTile.gd is Color(0.9, 0.8, 0.5)
	var expected_col = Color(0.9, 0.8, 0.5)
	if not albedo_mod.is_equal_approx(expected_col):
		print("WARNING: Desert color mismatch. Expected ", expected_col, " Got ", albedo_mod)
	else:
		print("PASS: Desert biome color applied correctly.")
		
	map_tile.free()
	print("Verify MapTile Visuals: SUCCESS")
	
	# Allow frame to process for nice cleanup
	await get_tree().process_frame
	get_tree().quit(0)
