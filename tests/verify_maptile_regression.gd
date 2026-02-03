extends Node

# verify_maptile_regression.gd
# Validates visual consistency of MapTile across refactors.
# Checks effective color for Biomes, Elevation, and Fog.

const LOG_PREFIX = "RegressionTest: "

func _ready():
	print(LOG_PREFIX + "START")
	
	# Watchdog
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)

	var map_tile_scene = load("res://scenes/map/MapTile.tscn")
	if not map_tile_scene:
		_fail("Could not load MapTile.tscn")
		return

	# Test Cases
	# Format: [BiomeEnum, Name, ExpectedBaseColor]
	# Biome Enums from LevelGenerator: INDOORS=0, GARDEN=1, STREET=2, SNOW=3, DESERT=4
	var test_cases = [
		[0, "INDOORS", Color(0.8, 0.75, 0.6)],
		[1, "GARDEN", Color(0.2, 0.6, 0.2)],
		[2, "STREET", Color(0.2, 0.2, 0.25)],
		[3, "SNOW", Color(0.9, 0.95, 1.0)],
		[4, "DESERT", Color(0.9, 0.8, 0.5)]
	]

	for tc in test_cases:
		var biome_id = tc[0]
		var biome_name = tc[1]
		var expected = tc[2]
		
		print(LOG_PREFIX + "Testing Biome: " + biome_name + " (ID: " + str(biome_id) + ")")
		
		# 1. Test Base Color (Elevation 0, No Fog)
		var tile = map_tile_scene.instantiate()
		add_child(tile)
		tile.initialize(Vector2(0,0), biome_id, 0, 0, true, null)
		
		var actual = _get_tile_effective_color(tile)
		if not _colors_match(actual, expected):
			_fail("Biome Color Mismatch for " + biome_name + ". Expected " + str(expected) + ", Got " + str(actual))
			return
		
		print(LOG_PREFIX + "  PASS: Base Color")
		tile.queue_free()

		# 2. Test Elevation Tint (Elevation 2)
		# Logic: color.lightened(0.1 * min(elev, 5)) -> lightened(0.2)
		tile = map_tile_scene.instantiate()
		add_child(tile)
		tile.initialize(Vector2(0,0), biome_id, 0, 2, true, null) # Elev=2
		
		var elev_expected = expected.lightened(0.2)
		actual = _get_tile_effective_color(tile)
		
		if not _colors_match(actual, elev_expected):
			_fail("Elevation Tint Mismatch for " + biome_name + ". Expected " + str(elev_expected) + ", Got " + str(actual))
			return
			
		print(LOG_PREFIX + "  PASS: Elevation Tint")
		tile.queue_free()

		# 3. Test Fog (Visible=True, Fogged=True)
		# Logic in MapTile:
		# gray = r*0.299 + g*0.587 + b*0.114
		# lerp(original, gray_col, 0.5).darkened(0.5)
		tile = map_tile_scene.instantiate()
		add_child(tile)
		tile.initialize(Vector2(0,0), biome_id, 0, 0, true, null)
		tile.set_vision_state(true, true) # Fogged
		
		var gray = expected.r * 0.299 + expected.g * 0.587 + expected.b * 0.114
		var gray_col = Color(gray, gray, gray)
		var fog_expected = expected.lerp(gray_col, 0.5).darkened(0.5)
		
		actual = _get_tile_effective_color(tile)
		
		if not _colors_match(actual, fog_expected):
			_fail("Fog Tint Mismatch for " + biome_name + ". Expected " + str(fog_expected) + ", Got " + str(actual))
			return
			
		print(LOG_PREFIX + "  PASS: Fog Tint")
		tile.queue_free()


	print(LOG_PREFIX + "SUCCESS. All visual states verified.")
	get_tree().quit(0)

func _get_tile_effective_color(tile):
	var mesh = tile.get_node("MeshInstance3D")
	var mat = mesh.material_override
	
	if mat is ShaderMaterial:
		return mesh.get_instance_shader_parameter("albedo_mod")
	elif mat is StandardMaterial3D:
		return mat.albedo_color
	else:
		return Color.MAGENTA

func _colors_match(c1, c2, tolerance=0.01):
	if c1 == null or c2 == null: return false
	return (
		abs(c1.r - c2.r) < tolerance and
		abs(c1.g - c2.g) < tolerance and
		abs(c1.b - c2.b) < tolerance
	)

func _fail(msg):
	print(LOG_PREFIX + "FAILURE: " + msg)
	get_tree().quit(1)
