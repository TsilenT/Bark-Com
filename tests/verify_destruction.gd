extends Node

# Mocks
class MockGridManager extends Node:
	# Keep signal for consistency if accessed, though not used here
	signal grid_generated
	var grid_data = {} # Added missing grid_data
	
	func update_tile_state(coord: Vector2, walkable, height, type):
		print("GridManager: Updated tile ", coord, " Walkable=", walkable)

	func get_world_position(coord: Vector2) -> Vector3:
		return Vector3(coord.x * 2.0, 0, coord.y * 2.0)

func _ready():
	print("Starting DestructibleCover Verification...")
	
	# Anti-Ghosting
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	# We are in the tree now (Autoloads should be ready)
	var root = self
	
	var gm = MockGridManager.new()
	gm.name = "GridManager" # DestructibleCover often looks for GridManager? 
	# Actually DestructibleCover is initialized with gm passed in.
	add_child(gm)
	
	# Instantiate DestructibleCover
	var cover_script = load("res://scripts/entities/DestructibleCover.gd")
	if not cover_script:
		print("FAIL: Could not load DestructibleCover script")
		get_tree().quit(1)
		return
		
	var cover = Node3D.new() 
	cover.set_script(cover_script)
	
	root.add_child(cover)
	
	# 1. Test Generic Crate
	if cover.has_method("initialize"):
		cover.initialize(Vector2(5,5), gm)
	else:
		print("FAIL: DestructibleCover missing initialize method.")
		get_tree().quit(1)
		return
		
	# Check Visuals
	if cover.mesh:
		print("PASS: Crate mesh instantiated.")
	else:
		print("FAIL: Visual mesh missing.")
		get_tree().quit(1)
		return
	
	# 2. Test Wall Variant
	var wall = Node3D.new()
	wall.set_script(cover_script)
	root.add_child(wall)
	wall.initialize(Vector2(6,6), gm)
	wall.set_variant(DestructibleCover.Variant.WALL)
	
	if wall.max_hp == 20: 
		print("PASS: Wall variant initializes with 20 HP.")
	else:
		print("FAIL: Wall has wrong HP: ", wall.max_hp)
		get_tree().quit(1)
		return
		
	if wall.mesh and wall.mesh.mesh is BoxMesh:
		# BoxMesh for Wall (size check optional)
		print("PASS: Wall mesh instantiated.")
	else:
		print("FAIL: Wall mesh invalid.")
		get_tree().quit(1)
		return
		
	# Test Destroy on Crate
		
	# Test Destroy
	print("Testing Destroy...")
	cover.destroy()
	
	# Check for Particles
	# Particles are added to "get_parent()". initializing cover added it to `root` (self).
	# So particles should be children of `root`.
	
	var found_explosion = false
	for child in get_children():
		if child.name.begins_with("CoverExplosion") or (child is GPUParticles3D):
			found_explosion = true
			break
			
	if found_explosion:
		print("PASS: Explosion particles spawned.")
	else:
		print("FAIL: Explosion particles not found in parent.")
		# Note: If CoverExplosion.tscn fails to load or instantiate, this fails.
		
	# 3. Test ExplosiveBarrel Visuals (Fix Check)
	var barrel_script = load("res://scripts/entities/ExplosiveBarrel.gd")
	if barrel_script:
		var barrel = Node3D.new()
		barrel.set_script(barrel_script)
		root.add_child(barrel)
		barrel.initialize(Vector2(7,7), gm)
		
		if barrel.mesh and barrel.mesh.mesh is CylinderMesh:
			print("PASS: ExplosiveBarrel initialized as Cylinder (Correct Visuals).")
		elif barrel.mesh and barrel.mesh.mesh is BoxMesh:
			print("FAIL: ExplosiveBarrel initialized as Box (Crate Overwrite Bug).")
		else:
			print("FAIL: ExplosiveBarrel visual mesh unexpected.")
	else:
		print("SKIP: ExplosiveBarrel script load failed.")

	get_tree().quit()
