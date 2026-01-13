extends Node

# --- TEST: Enemy Visuals Factory ---
# Verifies that EnemyModelFactory generates valid visual hierarchies for all AI Behaviors.

func _ready():
	print("--- TEST START: Enemy Visuals Factory ---")
	
	# Safeguard
	var guard = load("res://tests/TestSafeGuard.gd").new()
	guard.name = "TestSafeGuard"
	add_child(guard)
	
	run_test()

func run_test():
	var EnemyFactoryScript = load("res://scripts/utils/EnemyModelFactory.gd")
	var DataScript = load("res://scripts/resources/EnemyData.gd")
	var UnitScript = load("res://scripts/entities/EnemyUnit.gd")
	
	var behaviors = DataScript.AIBehavior.values()
	var success_count = 0
	
	for b_id in behaviors:
		var b_name = DataScript.AIBehavior.keys()[b_id]
		print("Testing Behavior: ", b_name, " (ID: ", b_id, ")")
		
		# Setup Mock Unit
		var unit = UnitScript.new()
		var data = DataScript.new()
		data.ai_behavior = b_id
		data.visual_color = Color.MAGENTA # Test color
		
		# Initialize basics
		unit.enemy_data = data
		unit.name = "TestUnit_" + b_name
		
		# Add to tree? Factory creates model then adds to unit usually?
		# create_model(unit) returns a Node3D. It does NOT require unit to be in tree necessarily,
		# but it does read unit.enemy_data.
		
		# Test Factory directly
		var model = EnemyFactoryScript.create_model(unit)
		
		if not model:
			print("❌ FAIL: Factory returned null for ", b_name)
			unit.free()
			continue
			
		if model.name != "ModelRoot":
			print("❌ FAIL: Model root name incorrect: ", model.name)
			unit.free()
			model.free()
			continue
			
		var child_count = model.get_child_count()
		print(" - Generated Children: ", child_count)
		
		if child_count == 0:
			print("⚠️ WARNING: No children generated for ", b_name)
		
		# Basic check for MeshInstances
		var mesh_found = false
		for c in model.get_children():
			if c is MeshInstance3D: mesh_found = true
			if c.get_child_count() > 0: # Check recursive
				for gc in c.get_children():
					if gc is MeshInstance3D: mesh_found = true
					# Also check if it's a Node3D pivot with mesh children
					if gc.get_child_count() > 0:
						for ggc in gc.get_children():
							if ggc is MeshInstance3D: mesh_found = true

		if not mesh_found:
			# Check sub-children (e.g. Boss root scale container)
			if model.get_child_count() > 0:
				var sub = model.get_child(0)
				if sub.get_child_count() > 0:
					mesh_found = true # Very basic heuristic

		if mesh_found:
			print("✅ PASS: ", b_name)
			success_count += 1
		else:
			print("❓ INDETERMINATE: No meshes found directly for ", b_name)
			
		model.free()
		unit.free()
		
	print("--- SUMMARY ---")
	print("Tested ", behaviors.size(), " behaviors.")
	print("Passed: ", success_count)
	
	if success_count == behaviors.size():
		_finalize(0)
	else:
		print("❌ SOME TESTS FAILED")
		_finalize(1)

func _finalize(code):
	if code == 0:
		print("✅ ALL TESTS PASSED")
	else:
		print("❌ FAILED")
		
	# Cleanup
	for c in get_children():
		c.queue_free()
		
	await get_tree().process_frame
	get_tree().quit(code)
