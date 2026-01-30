extends Node
class_name GridManager

## GridManager
##
## Central Singleton responsible for the Tactical Grid, Pathfinding, and Tile Data.
## MANAGED BY: GameManager (Autoload)
##
## Core Responsibilities:
## 1. Storage: Holds `grid_data` dictionary (Coord -> Tile Properties).
## 2. Pathfinding: Wraps `AStar3D` for movement logic.
## 3. Querying: Provides helpers for Cover, LoS checks (via Walkability), and Range.
## 4. State Management: Tracks dynamic occupancy (Units/Props) via `refresh_pathfinding`.

# Signals
signal grid_generated

# Grid Constants
const GRID_SIZE = Vector2(20, 20)
const TILE_SIZE = 2.0  # World units (3D)
const HEIGHT_STEP = 1.0  # Vertical Units (Y) per elevation layer

# Data Structures
# grid_data keys are Vector2 coordinates (x, y)
# Values are Dictionaries: { "type": int, "is_walkable": bool, "height": float, "world_pos": Vector3 }
var grid_data = {}

enum TileType { GROUND, OBSTACLE, COVER_HALF, COVER_FULL, RAMP, LADDER }

var astar: AStar3D


func _ready():
	add_to_group("GridManager")


func generate_tactical_grid(biome_override: int = -1):
	grid_data.clear()

	# Use LevelGenerator
	var generator = load("res://scripts/core/LevelGenerator.gd").new()
	grid_data = generator.generate_level(biome_override)
	generator.free() # Fix Leak: Generator is a Node but not in tree.

	# Initialize 'items' array for every tile
	for coord in grid_data:
		grid_data[coord]["items"] = []

	print("Grid generated with ", grid_data.size(), " tiles.")
	_setup_astar()
	emit_signal("grid_generated")


func register_item(coord: Vector2, item_node: Node):
	if grid_data.has(coord):
		if not grid_data[coord].has("items"):
			grid_data[coord]["items"] = []
		grid_data[coord]["items"].append(item_node)

func remove_item(coord: Vector2, item_node: Node):
	if grid_data.has(coord) and grid_data[coord].has("items"):
		grid_data[coord]["items"].erase(item_node)

func get_items_at(coord: Vector2) -> Array:
	if grid_data.has(coord) and grid_data[coord].has("items"):
		# Prune invalid items on access
		var valid_items = []
		var dirty = false
		for item in grid_data[coord]["items"]:
			if is_instance_valid(item) and not item.is_queued_for_deletion():
				valid_items.append(item)
			else:
				dirty = true
		
		if dirty:
			grid_data[coord]["items"] = valid_items
			
		return valid_items
	return []


func _get_point_id(coord: Vector2) -> int:
	return int(coord.y) * 100 + int(coord.x)


## Initializes the AStar3D graph based on the generated `grid_data`.
## Called once after level generation.
##
## Logic:
## 1. Adds all Points (Tiles) to AStar.
## 2. Disables Points marked as `is_walkable: false`.
## 3. Connects Neighbors (including diagonals).
##    - Supports specific logic for Ramps and Ladders (elevation changes).
func _setup_astar():
	astar = AStar3D.new()

	# 1. Add Points & Configuration (Merged Pass)
	for coord in grid_data:
		var id = _get_point_id(coord)
		astar.add_point(id, get_world_position(coord))
		
		# Attributes
		var data = grid_data[coord]
		var is_walkable = data.get("is_walkable", false)
		if not is_walkable:
			astar.set_point_disabled(id, true)
			
		# Weights (Future proofing, default is 1.0)
		# astar.set_point_weight_scale(id, 1.0) 

	# 2. Connect Neighbors
	for coord in grid_data:
		var id = _get_point_id(coord)
		# No need to check has_point(id) if we iterate grid_data keys which we just added.
		# But safety first.
		
		var current_elev = grid_data[coord].get("elevation", 0)
		var current_type = grid_data[coord].get("type", TileType.GROUND)

		# Directions (Including Diagonals)
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
			var n_coord = coord + n
			var n_id = _get_point_id(n_coord)

			if astar.has_point(n_id):
				# Check Verticality
				var next_elev = grid_data[n_coord].get("elevation", 0)
				var next_type = grid_data[n_coord].get("type", TileType.GROUND)

				var diff = abs(next_elev - current_elev)

				var can_connect = false
				if diff == 0:
					can_connect = true
				elif diff == 1:
					# Allow if one of them is a Ramp/Ladder
					if current_type == TileType.RAMP or next_type == TileType.RAMP:
						can_connect = true
					elif current_type == TileType.LADDER or next_type == TileType.LADDER:
						can_connect = true

				if can_connect:
					astar.connect_points(id, n_id)


## Returns a sequence of Vector2 coordinates representing the path from A to B.
## Uses AStar3D internally.
## Returns Empty Array if no path exists.
func get_move_path(start: Vector2, end: Vector2) -> Array[Vector2]:
	var start_id = _get_point_id(start)
	var end_id = _get_point_id(end)

	if not astar.has_point(start_id) or not astar.has_point(end_id):
		return []

	var path_3d = astar.get_point_path(start_id, end_id)
	var path_2d: Array[Vector2] = []

	for p in path_3d:
		path_2d.append(get_grid_coord(p))

	return path_2d


func calculate_path_cost(path: Array[Vector2]) -> int:
	var total_cost = 0
	if path.size() < 2:
		return 0

	for i in range(1, path.size()):
		var curr = path[i]
		
		# Step Cost (Matches get_reachable_tiles logic)
		var cost = 1
		# UPDATE: Ladders now cost 1.
		# var type = grid_data[curr].get("type", TileType.GROUND)
		# if type == TileType.LADDER:
		# 	cost = 2
			
		total_cost += cost

	return total_cost


func is_valid_destination(coord: Vector2) -> bool:
	if not grid_data.has(coord):
		return false
		
	# NEW: Check Dynamic Occupancy (Updated by refresh_pathfinding)
	if _unit_occupancy.has(coord):
		return false # Cannot stop on ANY unit (Friend or Foe)

	# Cannot end turn on a Ladder
	if grid_data[coord].get("type") == TileType.LADDER:
		return false

	# Must be walkable and not blocked by static obstacle
	return grid_data[coord].get("is_walkable", false)


func get_tile_data(coord: Vector2) -> Dictionary:
	return grid_data.get(coord, {})


func is_walkable(coord: Vector2) -> bool:
	var data = get_tile_data(coord)
	return data.get("is_walkable", false)


func is_tile_blocked(coord: Vector2) -> bool:
	# Checks dynamic AStar state (including units)
	if not astar:
		return true
	var id = _get_point_id(coord)
	if not astar.has_point(id):
		return true
	return astar.is_point_disabled(id)


const TILE_THICKNESS = 0.2
const RAMP_SURFACE_OFFSET = 0.5


func get_world_position(coord: Vector2) -> Vector3:
	var elev = 0
	if grid_data.has(coord):
		elev = grid_data[coord].get("elevation", 0)

	var pos = Vector3(coord.x * TILE_SIZE, elev * HEIGHT_STEP, coord.y * TILE_SIZE)

	if grid_data.has(coord):
		if grid_data[coord].has("world_pos"):
			pos = grid_data[coord]["world_pos"]

		var type = grid_data[coord].get("type", TileType.GROUND)

		# Define Surface Height based on Configured Thickness
		# Visual Meshes are instantiated CENTERED at 'pos'.
		# Surface is Top Face.
		if type == TileType.RAMP:
			pos.y += RAMP_SURFACE_OFFSET
		else:
			# Standard Tile
			pos.y += TILE_THICKNESS / 2.0

	return pos


func get_grid_coord(world_pos: Vector3) -> Vector2:
	var x = round(world_pos.x / TILE_SIZE)
	var y = round(world_pos.z / TILE_SIZE)
	return Vector2(x, y)


func get_nearest_walkable_tile(target: Vector2) -> Vector2:
	if is_walkable(target):
		return target

	# Spiral / BFS search for nearest
	var queue = [target]
	var visited = {target: true}

	while not queue.is_empty():
		var current = queue.pop_front()
		if is_walkable(current):
			return current

		var neighbors = [
			Vector2(0, 1),
			Vector2(0, -1),
			Vector2(1, 0),
			Vector2(-1, 0),
			Vector2(1, 1),
			Vector2(1, -1),
			Vector2(-1, 1),
			Vector2(-1, -1)
		]

		for n in neighbors:
			var next = current + n
			if not visited.has(next) and grid_data.has(next):
				visited[next] = true
				queue.append(next)

	return Vector2.ZERO  # Fallback (shouldn't happen on valid map)


func update_tile_state(
	coord: Vector2, walkable: bool, cover_height: float = 0.0, type: int = TileType.GROUND
):
	if not grid_data.has(coord):
		return

	var data = grid_data[coord]
	data["is_walkable"] = walkable
	data["cover_height"] = cover_height
	data["type"] = type

	# Update AStar
	if astar:
		var id = _get_point_id(coord)
		if astar.has_point(id):
			astar.set_point_disabled(id, not walkable)

	# Update Visuals?
	# GridVisualizer usually generates once.
	# We might want to signal this change if we want real-time visual updates of cell colors.
	# For now, gameplay logic is the priority.
	# For now, gameplay logic is the priority.


func is_tile_cover(coord: Vector2) -> bool:
	if not grid_data.has(coord):
		return false
	return grid_data[coord].get("cover_height", 0.0) > 0.0


# Cache for dynamic unit positions (updated in refresh_pathfinding)
var _unit_occupancy = {}

## Updates AStar states based on dynamic unit positions.
## Called at the start of every turn and after every move.
##
## Logic:
## 1. Resets all points to their base static state (Walkable/Blocked).
## 2. Checks for Static Props (Crates) occupying tiles.
## 3. Iterates through all Units:
##    - Marks their tiles as DISABLED (Occupied).
##    - Exception: If 'active_faction' is provided, Friendly units remain TRAVERSABLE (Walkable),
##      but are still not valid Destinations (handled by `is_valid_destination`).
func refresh_pathfinding(units: Array, ignore_unit = null, active_faction: String = ""):
	_unit_occupancy.clear()
	
	# 1. Reset to Base Static State + Check Dynamic Obstacles (Props/Crates)
	for coord in grid_data:
		var d = grid_data[coord]
		var walkable = d.get("is_walkable", false)
		
		# Check if occupied by a prop or unit registered in grid_data (Static/Prop)
		var occupant = d.get("unit")
		if occupant and is_instance_valid(occupant) and occupant != ignore_unit:
			walkable = false

		var id = _get_point_id(coord)
		if astar.has_point(id):
			astar.set_point_disabled(id, not walkable)

	# 2. Mark Units from List (Dynamic Units)
	for u in units:
		if is_instance_valid(u) and u.current_hp > 0:
			_unit_occupancy[u.grid_pos] = u
			
			if u != ignore_unit:
				# Check Faction vs Active Faction
				# If active_faction is set, friendlies (same faction) are WALKABLE (Traversable).
				# Enemies are BLOCKED.
				# If no active_faction (generic update), BLOCK EVERYONE (safe default).
				
				var block_tile = true
				if active_faction != "" and "faction" in u:
					if u.faction == active_faction:
						block_tile = false # Allow traversal through friend
				
				var u_id = _get_point_id(u.grid_pos)
				if astar.has_point(u_id):
					# Only disable if blocking. If not blocking (friend), we leave it as set by step 1 (likely walkable).
					if block_tile:
						astar.set_point_disabled(u_id, true)



func get_random_valid_position() -> Vector2:
	var keys = grid_data.keys()
	keys.shuffle()

	for coord in keys:
		var d = grid_data[coord]
		if d.get("is_walkable", false):
			# Added check against dynamic obstacles (units/crates)
			if not is_tile_blocked(coord) and not d.get("unit"):
				return coord

	return Vector2(-1, -1)



## Returns all tiles reachable from 'start_pos' within 'max_move' cost.
## Uses a BFS Flood Fill algorithm.
##
## Note: Relies on `astar.is_point_disabled` to respect obstacles.
## Warning: High movement ranges (>15) can be expensive.
func get_reachable_tiles(start_pos: Vector2, max_move: int) -> Array[Vector2]:
	var reachable: Array[Vector2] = []
	var queue = [{"pos": start_pos, "cost": 0}]
	var visited = {start_pos: 0}  # Pos -> Cost
	
	# Start pos is always reachable (cost 0)
	reachable.append(start_pos)

	while not queue.is_empty():
		var current = queue.pop_front()
		
		# Get neighbors via AStar logic (connected points)
		var c_id = _get_point_id(current.pos)
		if not astar.has_point(c_id):
			continue
			
		var connections = astar.get_point_connections(c_id)
		for n_id in connections:
			# If disabled (Wall or Enemy), we cannot enter/traverse
			if astar.is_point_disabled(n_id):
				continue
				
			var n_pos = get_grid_coord(astar.get_point_position(n_id))

			# Calculate Cost to neighbor (Uniform Step Cost)
			var move_cost = 1
			var new_cost = current.cost + move_cost
			
			if new_cost <= max_move:
				# If better path or unvisited
				if not visited.has(n_pos) or new_cost < visited[n_pos]:
					visited[n_pos] = new_cost
					queue.append({"pos": n_pos, "cost": new_cost})
					
					# Only add to output if it's a valid STOPPING point (e.g. not occupied)
					# This gives us "Blue Squares" that match the "Line Helper" logic
					if is_valid_destination(n_pos):
						if not reachable.has(n_pos):
							reachable.append(n_pos)
						
	return reachable


func get_units_in_radius_world(center: Vector3, radius: float) -> Array:
	var hit_units = []
	var all_units = get_tree().get_nodes_in_group("Units")
	
	for unit in all_units:
		if is_instance_valid(unit) and "current_hp" in unit and unit.current_hp > 0:
			# Check distance (using global_position to be safe)
			var dist = unit.global_position.distance_to(center)
			# print("GM: Checking unit ", unit.name, " at ", unit.global_position, " Dist to ", center, ": ", dist)
			if dist <= radius:
				hit_units.append(unit)
				
	return hit_units


func get_world_aoe_radius(tile_radius: float) -> float:
	return tile_radius * TILE_SIZE

func get_units_in_radius_cylindrical(center: Vector3, radius: float, height_tolerance: float = 2.0) -> Array:
	var hit_units = []
	var all_units = get_tree().get_nodes_in_group("Units")
	var center_2d = Vector2(center.x, center.z)
	
	for unit in all_units:
		if is_instance_valid(unit) and "current_hp" in unit and unit.current_hp > 0:
			# Check Horizontal Distance
			var unit_2d = Vector2(unit.global_position.x, unit.global_position.z)
			var dist = unit_2d.distance_to(center_2d)
			
			if dist <= radius:
				# Check Vertical
				if abs(unit.global_position.y - center.y) <= height_tolerance:
					hit_units.append(unit)
				
	return hit_units


func get_tiles_in_radius(center_tile: Vector2, radius: float) -> Array[Vector2]:
	var tiles: Array[Vector2] = []
	for tile in grid_data:
		if tile.distance_to(center_tile) <= radius:
			tiles.append(tile)
	return tiles

func get_adjacent_tiles(coord: Vector2) -> Array[Vector2]:
	var neighbors: Array[Vector2] = []
	var offsets = [
		Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0),
		Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)
	]
	
	for n in offsets:
		var next = coord + n
		if grid_data.has(next):
			neighbors.append(next)
			
	return neighbors

func get_best_cover_at(coord: Vector2) -> float:
	# Returns the highest cover value provided by ANY neighbor.
	# Used for UI feedback ("Am I in cover?").
	if not grid_data.has(coord):
		return 0.0
		
	var my_elev = grid_data[coord].get("elevation", 0)
	var max_cover = 0.0
	
	# Check 4 direct neighbors
	var neighbors = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]
	for n in neighbors:
		var n_pos = coord + n
		if grid_data.has(n_pos):
			var n_data = grid_data[n_pos]
			var raw_cover = n_data.get("cover_height", 0.0)
			
			if raw_cover > 0.0:
				var n_elev = n_data.get("elevation", 0)
				# ELEVATION CHECK: Cover must be TALLER than my feet level.
				# Absolute Top of Wall = n_elev + raw_cover.
				# If Top of Wall <= my_elev, it's a floor to me. No cover.
				
				# Actually, cover_height 2.0 (Full) or 1.0 (Half).
				# If my_elev is 1, neighbor is 0. Wall is 1.0 high. Top is 1.0. 
				# My feet are at 1.0. Wall matches feet -> Floor. No cover.
				
				# If Wall is Full (2.0) at elev 0. Top is 2.0. My feet 1.0. 
				# Effective cover = 2.0 - 1.0 = 1.0 (Half Cover).
				
				# Logic: Effective Height = (n_elev + raw_cover) - my_elev
				var effective = (n_elev + raw_cover) - my_elev
				if effective > 0.0:
					# Clamp to valid cover types (0, 1, 2)
					# If effective >= 1.5 -> Full (2), else if >= 0.5 -> Half (1)
					if effective >= 1.5: effective = 2.0
					elif effective >= 0.5: effective = 1.0
					else: effective = 0.0
					
					if effective > max_cover:
						max_cover = effective
				
	return max_cover
