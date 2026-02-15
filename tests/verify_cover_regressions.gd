extends Node

# Regression Test: Cover Material Isolation
# Verifies that highlighting or damaging one cover does NOT affect others 
# when using shared cached materials.

func _spawn_crate(parent, pos):
	var c = load("res://scripts/entities/DestructibleCover.gd").new()
	parent.add_child(c)
	c.set_variant(DestructibleCover.Variant.CRATE)
	c.position = Vector3(pos.x, 0, pos.y)
	return c

func _get_mat(cover) -> Material:
	if not cover.mesh: return null
	if cover.mesh is MeshInstance3D:
		return cover.mesh.material_override
	else:
		# Composite Prop Root (Node3D)
		for child in cover.mesh.get_children():
			if child is MeshInstance3D:
				return child.material_override
	return null

func _ready():
	print("--- VERIFYING: DestructibleCover Material Isolation ---")
	
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)
	
	var root = Node3D.new()
	add_child(root)
	
	# 1. Spawn two identical crates (Should share material initially)
	var crate1 = _spawn_crate(root, Vector2(0,0))
	var crate2 = _spawn_crate(root, Vector2(1,0))
	
	# Force _ready and setup
	crate1._ready()
	crate2._ready()
	
	var mat1 = _get_mat(crate1)
	var mat2 = _get_mat(crate2)
	
	# PRE-CHECK: They should be the SAME resource instance thanks to cache
	if mat1 == mat2:
		print("PASS: Crates share material initially (Cache working).")
	else:
		print("FAIL: Crates have unique materials initially! Cache broken/inactive.")
		
	# 2. Trigger Highlight on Crate 1 (Should trigger Copy-on-Write)
	print("Action: Highlighting Crate 1...")
	crate1._mouse_enter()
	
	# Check isolation
	var mat1_new = _get_mat(crate1)
	var mat2_new = _get_mat(crate2)
	
	# Crate 1 should have a NEW material (Duplicate)
	if mat1_new != mat1:
		print("PASS: Crate 1 created unique material instance on interaction (COW working).")
	else:
		print("FAIL: Crate 1 modified shared material directly! (Regression)")
		
	# Crate 2 should still have the ORIGINAL shared material
	if mat2_new == mat2:
		print("PASS: Crate 2 retains original shared material.")
	else:
		print("FAIL: Crate 2 material changed inappropriately.")
		
	# Verify Properties
	if mat1_new.emission_enabled == true:
		print("PASS: Crate 1 is showing emission (Highlight active).")
	else:
		print("FAIL: Crate 1 emission failed.")
		
	if mat2_new.emission_enabled == false:
		print("PASS: Crate 2 is NOT showing emission (Isolation successful).")
	else:
		print("FAIL: Crate 2 is glowing! (Shared state pollution)")

	# 3. Test Damage Isolation
	print("Action: Damaging Crate 2...")
	crate2.take_damage_from(1, null, "Generic") # Should COW Crate 2 now
	
	# Crate 2 should now have its OWN, unique material (different from Crate 1's unique one)
	if _get_mat(crate2) != mat2 and _get_mat(crate2) != _get_mat(crate1):
		print("PASS: Crate 2 created its own unique material on damage.")
	else:
		print("FAIL: Crate 2 material state unexpected check.")

	# Cleanup
	root.queue_free()
	
	# Flush Cache
	load("res://scripts/entities/DestructibleCover.gd").flush_cache()
	
	print("--- VERIFICATION COMPLETE ---")
	get_tree().quit()
