extends Node
class_name LevelGenerator

## LevelGenerator
##
## Procedural Map Generator.
## Generates a 20x20 Grid by stitching together 4x4 Chunks (5x5 tiles each).
##
## Features:
## - Chunk-based Architecture: Uses predefined 5x5 templates (e.g. GARDEN, SNIPER_NEST).
## - Biome Support: Assigns biomes (Street, Garden, Indoors) to chunks.
## - Connectivity Validation: Ensures the generated map is playable via Flood Fill.
## - Fallback Mechanism: Generates a flat safe map if validation fails 10 times.

# Constants
const LOG_PREFIX = "LevelGenerator: "
const CHUNK_SIZE = 5
const TILE_SIZE = 2.0

# Tile Codes for Template
# . = Ground (Walkable, No Cover)
# # = Obstacle (Non-walkable, Full Cover, Indestructible)
# H = High Cover (Non-walkable, Full Cover 2.0)
# L = Low Cover (Non-walkable, Half Cover 1.0, Destructible)
# W = Destructible Wall (Non-walkable, Full Cover 2.0, Breaks into Ground)
# D = Destructible Cover (Non-walkable, Half Cover 1.0, Breaks into Ground)
# + = High Ground (Walkable, Elevation 1)
# ^ = Ramp (Walkable, Transitions Elevation 0<->1)
# = = Ladder (Walkable, Ladder Tile)
# | = Door (Walkable initially, converted to Door entity)

const CHUNK_KITCHEN = ["##.##", "#...#", ".H.H.", ".....", "##.##"]

const CHUNK_GARDEN = ["L...L", ".....", "..L..", ".....", "L...L"]

# --- TACTICAL STREET CHUNKS ---
# Killbox: Open center, cover on edges for crossfire
const CHUNK_KILLBOX = [
	"W...W", # W = Destructible Wall 
	".....", 
	".D.D.", 
	".....", 
	"W...W"
] 

# Flank Lane: Long cover running North-South
const CHUNK_FLANK_LANE = [
	".L.L.", 
	".L.L.", 
	".L.L.", 
	".L.L.", 
	".L.L."
]

# Sniper Nest: High ground corner overlooking open area
# FIXED: Added Ramp (^) for access
const CHUNK_SNIPER_NEST = [
	"###..", 
	"#++.L", 
	".^+.L", # Ramp adjacent to High Ground
	"..L..", 
	"L...."
]

const CHUNK_BRIDGE = [".^.^.", ".+.+.", ".+.+.", ".+.+.", ".^.^."]

const CHUNK_LADDER_TEST = [".....", ".H+++", ".=H+.", ".H+++", "....."] 

const CHUNK_SPLIT_LEVEL = ["+++++", "+=...", "+=.L.", "+=...", "....."]

const CHUNK_PARK = [".....", ".L.L.", ".....", ".L.L.", "....."]

const CHUNK_ALLEY = ["#####", "#...#", "L...L", "#...#", "#####"]

const CHUNK_ROOFTOP = [".....", ".=+++", ".=+++", ".=+++", "....."]

const CHUNK_PILLBOX = [".###.", "#+++#", "#+++#", "#=+=#", "....."]

const CHUNK_LABYRINTH = ["##W##", ".....", ".#W#.", ".....", "##W##"] # Added Destructible Walls

# --- NEW CHUNKS (Set 2) ---
# Checkpoint: Choke point with destructible cover and a DOOR
const CHUNK_CHECKPOINT = ["W...W", "D...D", "..|..", "D...D", "W...W"]

# Secure Room: Enclosed space with Door access
const CHUNK_SECURE_ROOM = ["#####", "#.|.#", "#...#", "#...#", "#####"]

# Guard Tower: Central high ground with ladder access
const CHUNK_GUARD_TOWER = [".....", ".+++.", ".=++.", ".+++.", "....."]

# Construction Site: Walls and ramp to unfinished floor
const CHUNK_CONSTRUCTION = ["W.W^.", ".....", "W.W+.", ".....", "D.D.."]

# Market Stalls: Dense destructible cover lanes
const CHUNK_MARKET = ["D.L.D", ".....", "D.L.D", ".....", "D.D.D"]

# The Overlook: High ground strip with ramp access
const CHUNK_OVERLOOK = ["..^..", "L.+.L", ".+++.", ".+++.", "....."]

# Door Maze: Dense doors for testing
const CHUNK_DOOR_MAZE = ["W|W|W", "|...|", "W.|.W", "|...|", "W|W|W"]

# Map Biome Types to Colors in Visualizer later?
enum Biome { INDOORS, GARDEN, STREET, SNOW, DESERT }

# Generation Override for Verification Scenarios
static var override_mode: String = ""


static func get_biome_string(biome: int) -> String:
	match biome:
		Biome.INDOORS: return "Indoors"
		Biome.GARDEN: return "Garden"
		Biome.STREET: return "Street"
		Biome.SNOW: return "Snow"
		Biome.DESERT: return "Desert"
		_: return "Street"


## Generates a new 20x20 Level Dictionary.
## Returns `grid_data` format: { coordinates: { type, is_walkable, elevation, ... } }
##
## Process:
## 1. Selects 16 Chunks (randomly or via override).
## 2. Applies Biome Logic (Street, Garden, etc).
## 3. Stitches chunks into a single Grid.
## 4. Validates Connectivity (Flood Fill). Retries if failing.
func generate_level(biome_override: int = -1) -> Dictionary:
	var final_grid = {}
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# Layout: 2x2 Chunks for 10x10 map
	var attempts = 0
	var max_attempts = 50
	var valid_map = false

	if LevelGenerator.override_mode == "DOOR_TEST":
		# Force Door Maze Grid
		print("LevelGenerator: OVERRIDE MODE = DOOR_TEST. Generating Door Heavy Map.")
		for cx in range(4):
			for cy in range(4):
				var template = CHUNK_DOOR_MAZE
				# Alternating Rotation
				if (cx + cy) % 2 == 0: template = _rotate_template(template, 1)
				_stitch_chunk(final_grid, template, cx * CHUNK_SIZE, cy * CHUNK_SIZE, Biome.INDOORS)
		return final_grid

	while attempts < max_attempts and not valid_map:
		final_grid.clear()
		attempts += 1

		# Generate 4x4 Chunks
		for cx in range(4):
			for cy in range(4):
				var type_roll = rng.randi() % 19
				var template = []
				var biome = Biome.GARDEN

				match type_roll:
					0:
						template = CHUNK_KITCHEN
						biome = Biome.INDOORS
					1:
						template = CHUNK_GARDEN
						biome = Biome.GARDEN
					2:
						template = CHUNK_KILLBOX
						biome = Biome.STREET
					3:
						template = CHUNK_FLANK_LANE
						biome = Biome.STREET
					4:
						template = CHUNK_SNIPER_NEST
						biome = Biome.STREET
					5:
						template = CHUNK_KILLBOX # Higher weight
						biome = Biome.STREET
					6:
						template = CHUNK_BRIDGE
						biome = Biome.STREET
					7:
						template = CHUNK_LADDER_TEST
						biome = Biome.STREET
					8:
						template = CHUNK_SPLIT_LEVEL
						biome = Biome.STREET
					9:
						template = CHUNK_PARK
						biome = Biome.GARDEN
					10:
						template = CHUNK_ALLEY
						biome = Biome.STREET
					11:
						template = CHUNK_ROOFTOP
						biome = Biome.STREET
					12:
						template = CHUNK_PILLBOX
						biome = Biome.STREET
					13:
						template = CHUNK_LABYRINTH
						biome = Biome.STREET
					14:
						template = CHUNK_CHECKPOINT
						biome = Biome.STREET
					15:
						template = CHUNK_GUARD_TOWER
						biome = Biome.STREET
					16:
						template = CHUNK_CONSTRUCTION
						biome = Biome.STREET
					17:
						template = CHUNK_MARKET
						biome = Biome.STREET
					18:
						template = CHUNK_OVERLOOK
						biome = Biome.STREET
				
				# Apply Map-Wide Biome Override (unless Chunk is strictly Indoors/Special?)
				# For now, let's override everything except explicit Indoors rooms (Kitchen) if we want?
				# The user requested "full biome missions". So even mixing usually means consistency.
				# Kitchen is explicitly INDOORS. If Mission is GARDEN, we probably shouldn't have a Kitchen chunk?
				# But for now, simple override of the 'variable' biomes is safest.
				# Or just force it.
				
				if biome_override != -1:
					# If the chunk was naturally INDOORS (0), should we force it to DESERT?
					# A Kitchen in the Desert is weird. 
					# But if we are doing "Full Biome", maybe we avoid mismatched chunks?
					# For now, override non-Indoors chunks OR just override all. 
					# Let's override ALL to ensure the goal "Full Biome Missions" is met.
					# Even if "Kitchen" visually renders as "Desert", it might look like a ruin?
					# Actually LevelGenerator doesn't change geometry based on biome, only 'biome' tag which changes Props.
					# So Kitchen Geometry + Desert Props = Desert Ruin? Acceptable.
					biome = biome_override

				# Biome Variety Override (Only if NO strict override is set)
				if biome_override == -1 and biome == Biome.STREET:
					var biome_roll = rng.randf()
					if biome_roll < 0.1:
						biome = Biome.SNOW
					elif biome_roll < 0.2:
						biome = Biome.DESERT

				# Rotation
				var rots = rng.randi() % 4
				template = _rotate_template(template, rots)

				_stitch_chunk(final_grid, template, cx * CHUNK_SIZE, cy * CHUNK_SIZE, biome)

		# Validation
		if _validate_connectivity(final_grid):
			valid_map = true
			print("LevelGenerator: Map Validated on attempt ", attempts)
		else:
			print("LevelGenerator: Map Rejected on attempt ", attempts, ". Retrying...")

	if not valid_map:
		print(LOG_PREFIX, "GENERATION FALLBACK. Generating Emergency Safe Map.")
		_generate_safe_map(final_grid)

	# Post-Process: Validate Door Logic (Prevent Floating Doors)
	_validate_door_placement(final_grid)

	return final_grid


func _validate_door_placement(grid: Dictionary):
	var doors_to_remove = []
	
	for pos in grid:
		var d = grid[pos]
		if d.get("variant") == "Door":
			# Needs opposing walls (N/S or E/W)
			var n_north = pos + Vector2(0, -1)
			var n_south = pos + Vector2(0, 1)
			var n_east = pos + Vector2(1, 0)
			var n_west = pos + Vector2(-1, 0)
			
			var walls_ns = _is_wall(grid, n_north) and _is_wall(grid, n_south)
			var walls_ew = _is_wall(grid, n_east) and _is_wall(grid, n_west)
			
			if not walls_ns and not walls_ew:
				doors_to_remove.append(pos)
				print(LOG_PREFIX, "Removing Invalid Door at ", pos)

	for pos in doors_to_remove:
		# Convert to standard Floor
		grid[pos]["variant"] = ""
		grid[pos]["destructible"] = false
		grid[pos]["type"] = 0 # GROUND
		grid[pos]["cover_height"] = 0.0


func _is_wall(grid: Dictionary, pos: Vector2) -> bool:
	if not grid.has(pos): return false
	var t = grid[pos].get("type", 0)
	# Obstacle (1) or High Cover (3) or Destructible Wall (Door variant check?)
	return t == 1 or t == 3 or (t == 2 and grid[pos].get("variant") == "Wall")


## Validates that the map is fully connected (Player can reach all walkable tiles).
## Uses a Flood Fill algorithm starting from the default Spawn Point (1, 1).
##
## @return True if reachable ratio >= 99%.
func _validate_connectivity(grid: Dictionary) -> bool:
	# Flood Fill from assumed Player Start
	# Main.gd spawns at (1, 1)
	var start = Vector2(1, 1)

	# Try explicit start + immediate neighbors (spawn region)
	if not grid.has(start) or not grid[start].get("is_walkable"):
		var potential = [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(2, 1), Vector2(1, 2)]
		for p in potential:
			if grid.has(p) and grid[p].get("is_walkable"):
				start = p
				break

	# If the spawn region is completely unwalkable, this map is bad for spawning.
	# We should NOT fallback to random keys, because then we might validate an island the player isn't on.
	if not grid.has(start) or not grid[start].get("is_walkable"):
		return false  # Spawn area is blocked

	if not grid.has(start) or not grid[start].get("is_walkable"):
		return false  # No walkable tiles?

	var total_walkable = 0
	for k in grid:
		if grid[k].get("is_walkable") or grid[k].get("destructible", false):
			total_walkable += 1

	var reachable = 0
	var queue = [start]
	var visited = {start: true}

	while not queue.is_empty():
		var current = queue.pop_front()
		reachable += 1

		# Logic mimics GridManager connection logic implicitly or explicitly
		# We need to respect standard movement rules (Neighbors + Ramps + Ladders)
		# Since we don't have GridManager instance here, we must replicate checks or be permissive.
		# Simplest is checking GridManager compatibility logic:
		var current_elev = grid[current].get("elevation", 0)
		var current_type = grid[current].get("type", 0)  # 0=Ground

		var neighbors = [
			Vector2(1, 0),
			Vector2(-1, 0),
			Vector2(0, 1),
			Vector2(0, -1),
			Vector2(1, 1),
			Vector2(1, -1),
			Vector2(-1, 1),
			Vector2(-1, -1)
		]

		for n in neighbors:
			var next_pos = current + n
			if not grid.has(next_pos):
				continue
			if visited.has(next_pos):
				continue

			var next_data = grid[next_pos]
			var is_accessible = next_data.get("is_walkable") or next_data.get("destructible", false)
			
			if not is_accessible:
				continue

			# Height Check (Replicating GM logic)
			var next_elev = next_data.get("elevation", 0)
			var next_type = next_data.get("type", 0)
			var diff = abs(next_elev - current_elev)

			var valid_move = false
			if diff == 0:
				valid_move = true
			elif diff == 1:
				if current_type == 4 or next_type == 4:  # RAMP
					valid_move = true
				elif current_type == 5 or next_type == 5:  # LADDER
					valid_move = true

			if valid_move:
				visited[next_pos] = true
				queue.append(next_pos)

	var ratio = float(reachable) / float(total_walkable)
	# print("Flood Fill: ", reachable, "/", total_walkable, " (", ratio, ")")
	
	# Strict Validation: 99% of walkable tiles must be reachable.
	# (Allows 1-2 glitch tiles if float math is weird, but essentially requires full connectivity).
	# High Ground Islands will cause failure here.
	return ratio >= 0.99


func _generate_safe_map(grid: Dictionary):
	grid.clear()
	# Just flat ground
	for x in range(20):
		for y in range(20):
			var pos = Vector2(x, y)
			grid[pos] = {
				"type": 0,  # GROUND
				"is_walkable": true,
				"cover_height": 0.0,
				"elevation": 0,
				"biome": 1,
				"world_pos": _get_world_pos(pos, 0.0)
			}


func _rotate_template(original: Array, times: int) -> Array:
	if times == 0:
		return original

	var current = original.duplicate()
	# Rotate 90 degrees clockwise 'times' times
	for t in range(times):
		var rotated = []
		for i in range(CHUNK_SIZE):
			var row_str = ""
			for j in range(CHUNK_SIZE):
				# Matrix Rotation:
				# Rotated[row][col] = Original[size-1-col][row]
				# Wait, i is ROW index for destination?
				# Let's verify standard algorithm:
				# dest[i][j] = src[N-1-j][i]

				var src_r = CHUNK_SIZE - 1 - j
				var src_c = i
				row_str += current[src_r][src_c]
			rotated.append(row_str)
		current = rotated
	return current


func _get_world_pos(grid_pos: Vector2, elevation_offset: float = 0.0) -> Vector3:
	return Vector3(grid_pos.x * TILE_SIZE, elevation_offset, grid_pos.y * TILE_SIZE)


## Translates a specific Chunk Template into Global Grid Data.
## Handles Char Code mapping -> Tile Type, Cover Height, Walkability.
##
## Mapping:
## - '#' = OBSTACLE (Full Cover)
## - 'H' = HIGH COVER (Full)
## - 'L' = LOW COVER (Half)
## - 'W' = DESTRUCTIBLE WALL
## - '^' = RAMP
## - '=' = LADDER
## - '|' = DOOR
func _stitch_chunk(
	grid_data: Dictionary, template: Array, offset_x: int, offset_y: int, biome: int
):
	for y in range(CHUNK_SIZE):
		var row = template[y]
		for x in range(CHUNK_SIZE):
			var char_code = row[x]
			var global_coord = Vector2(offset_x + x, offset_y + y)

			var type = GridManager.TileType.GROUND
			var is_walkable = true
			var cover_height = 0.0

			var extra_data = {}

			match char_code:
				"#":
					type = GridManager.TileType.OBSTACLE
					is_walkable = false
					cover_height = 2.0
				"H":
					type = GridManager.TileType.COVER_FULL
					is_walkable = false
					cover_height = 2.0
				"D":
					# Destructible Cover (Half) - Crates, Hydrants
					type = GridManager.TileType.COVER_HALF
					is_walkable = false
					cover_height = 1.0
					extra_data = {
						"destructible": true,
						"variant": "Auto"
					}
				"W":
					# Destructible Wall (Full Cover) - Bricks
					type = GridManager.TileType.COVER_FULL
					is_walkable = false
					cover_height = 2.0
					extra_data = {
						"destructible": true,
						"variant": "Wall"
					}
				"L":
					type = GridManager.TileType.COVER_HALF
					is_walkable = false
					cover_height = 1.0
					extra_data = {
						"destructible": true,
						"variant": "Auto"
					}
				"|":
					# Door (High Wall initially)
					# FIX: Validation needs to see this as a connector.
					# Set is_walkable = true for Generation.
					# Door.gd will lock it (make Unwalkable) upon spawning/initialization.
					type = GridManager.TileType.GROUND 
					is_walkable = true
					cover_height = 2.0
					extra_data = {
						"variant": "Door",
						"destructible": true
					}
				".":
					pass
				"+":
					# High Ground
					grid_data[global_coord] = {
						"type": GridManager.TileType.GROUND,
						"is_walkable": true,
						"cover_height": 0.0,
						"elevation": 1,
						"biome": biome,
						"world_pos": _get_world_pos(global_coord, 1.0)
					}
					continue
				"^":
					# Ramp
					grid_data[global_coord] = {
						"type": GridManager.TileType.RAMP,
						"is_walkable": true,
						"cover_height": 0.0,
						"elevation": 0,
						"biome": biome,
						"world_pos": _get_world_pos(global_coord, 0.5)
					}
					continue
				"=":
					# Ladder
					grid_data[global_coord] = {
						"type": GridManager.TileType.LADDER,
						"is_walkable": true,
						"cover_height": 0.0,
						"elevation": 0,
						"biome": biome,
						"world_pos": _get_world_pos(global_coord, 0.0)
					}
					continue

			grid_data[global_coord] = {
				"type": type,
				"is_walkable": is_walkable,
				"cover_height": cover_height,
				"biome": biome,
				"world_pos": _get_world_pos(global_coord, 0.0)
			}
			# Merge Extra Data
			if not extra_data.is_empty():
				grid_data[global_coord].merge(extra_data)
