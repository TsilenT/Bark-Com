extends Node
class_name MaterialCache

# MaterialCache.gd
# Caches shared StandardMaterial3D resources for MapTiles to avoid exceeding shader instance limits (WebGL).
# Key: [biome_id, elevation_int, is_fogged_bool]

# Static Cache
static var _material_cache = {}

static func get_tile_material(biome: int, elevation: int, is_fogged: bool) -> StandardMaterial3D:
	var key = str(biome) + "_" + str(elevation) + "_" + str(is_fogged)
	
	if _material_cache.has(key):
		return _material_cache[key]
		
	# Create New
	var mat = _create_material(biome, elevation, is_fogged)
	_material_cache[key] = mat
	return mat

static func clear_cache():
	_material_cache.clear()

static func _create_material(biome: int, elevation: int, is_fogged: bool) -> StandardMaterial3D:
	var base_color = _get_biome_color(biome)
	
	# 1. Elevation Tint
	if elevation > 0:
		base_color = base_color.lightened(0.1 * min(elevation, 5))
		
	# 2. Fog Tint
	if is_fogged:
		var gray = base_color.r * 0.299 + base_color.g * 0.587 + base_color.b * 0.114
		var gray_color = Color(gray, gray, gray)
		base_color = base_color.lerp(gray_color, 0.5).darkened(0.5)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.roughness = 0.8
	
	return mat

static func _get_biome_color(biome: int) -> Color:
	# Matches LevelGenerator Biome Enums
	match biome:
		LevelGenerator.Biome.OFFICE: return Color(0.8, 0.75, 0.6) # OFFICE
		LevelGenerator.Biome.GARDEN: return Color(0.2, 0.6, 0.2) # GARDEN
		LevelGenerator.Biome.STREET: return Color(0.2, 0.2, 0.25) # STREET
		LevelGenerator.Biome.SNOW: return Color(0.9, 0.95, 1.0) # SNOW
		LevelGenerator.Biome.DESERT: return Color(0.9, 0.8, 0.5) # DESERT
		_: return Color(0.8, 0.75, 0.7) # Fallback
