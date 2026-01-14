extends Node

# --- TEST: Corgi Visuals Factory ---
# Verifies that CorgiModelFactory generates valid models for all classes.

func _ready():
	print("--- TEST START: Corgi Visuals Factory ---")
	
	# Safeguard
	var guard = load("res://tests/TestSafeGuard.gd").new()
	guard.name = "TestSafeGuard"
	add_child(guard)
	
	run_test()

func run_test():
	var Factory = load("res://scripts/utils/CorgiModelFactory.gd")
	
	var classes = ["Recruit", "Scout", "Heavy", "Paramedic", "Sniper", "Grenadier"]
	var success_count = 0
	
	for cls in classes:
		var pivot = Node3D.new()
		add_child(pivot)
		
		var result = Factory.generate_corgi(cls, pivot)
		
		# Check Result Keys
		if not result.has("anim_player"):
			print("❌ FAIL: No anim_player returned for ", cls)
			continue
		if not result.has("sockets"):
			print("❌ FAIL: No sockets returned for ", cls)
			continue
			
		# Check Generated Nodes
		var root = pivot.get_node_or_null("ModelRoot")
		if not root:
			print("❌ FAIL: ModelRoot not found for ", cls)
			continue
			
		# Check Meshes
		var mesh_found = false
		for c in root.get_children():
			if c is MeshInstance3D: mesh_found = true
			# Recursive check
			if c.get_child_count() > 0:
				for gc in c.get_children():
					if gc is MeshInstance3D: mesh_found = true
					
		if mesh_found:
			print("✅ PASS: ", cls)
			success_count += 1
		else:
			print("⚠️ WARNING: No meshes found for ", cls)
			
		# Manual Resource Cleanup to prevent RID leaks
		_clean_node_resources(pivot)
		result = {} # Break references held by script
		
		# Allow engine to process the freed resources
		remove_child(pivot)
		pivot.free()
		
		await get_tree().process_frame
		
	print("--- SUMMARY ---")
	print("Tested ", classes.size(), " classes.")
	print("Passed: ", success_count)
	
	if success_count == classes.size():
		_finalize(0)
	else:
		_finalize(1)

# Helper to deep clean
func _clean_node_resources(node: Node):
	if node is MeshInstance3D:
		node.mesh = null
		node.material_override = null
	
	if node is AnimationPlayer:
		node.stop()
		# Clear libraries to release RefCounted animations
		for lib_name in node.get_animation_library_list():
			node.remove_animation_library(lib_name)

	for c in node.get_children():
		_clean_node_resources(c)
		# Explicitly free children to ensure immediate destruction
		node.remove_child(c)
		c.free()

func _finalize(code):
	# TestUtils handles the wait and flush
	var TestUtils = load("res://tests/TestUtils.gd")
	if TestUtils:
		# Extra wait time for Factory scenarios which are heavy on RIDs
		for i in range(5): await get_tree().process_frame
		await TestUtils.finalize_and_quit(get_tree(), code)
	else:
		get_tree().quit(code)
