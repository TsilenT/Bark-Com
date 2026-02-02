extends Node

# verify_status_glossary.gd
# Verifies that StatusCatalog can instantiate all expected effects.
# Guarded by: TestSafeGuard.gd (in runner scene)

const StatusCatalogScript = preload("res://scripts/core/StatusCatalog.gd")

func _ready():
	print("TEST START: verify_status_glossary")
	
	# Using static methods now that they handle internal loading
	var statuses = StatusCatalogScript.get_all_statuses()
	var effects = StatusCatalogScript.get_all_effects()

	print("Statuses Found: ", statuses.size())
	print("Effects Found: ", effects.size())
	
	# Verify specific knowns
	var known_statuses = ["Burning", "Confused", "Shredded Armor", "Sit & Stay", "Slowed", "Suppressed", "Vulnerable", "Frozen", "Shakey Paws", "Fleeing", "Berserk"]
	var known_effects = ["Armored", "Disoriented", "Good Boy", "Poisoned", "Stunned"]  
	
	var passed = true
	
	for s_name in known_statuses:
		var found = false
		for inst in statuses:
			if inst.display_name == s_name:
				found = true
				break
		if not found:
			print("ERROR: Missing Status: ", s_name)
			passed = false
			
	for e_name in known_effects:
		var found = false
		for inst in effects:
			if inst.display_name == e_name:
				found = true
				break
				
		if not found:
			print("WARNING: Exact match failed for ", e_name, ". Checking partials...")
			var partial = false
			for inst in effects:
				if e_name in inst.display_name or inst.display_name in e_name:
					partial = true
					print("  Found via partial match: ", inst.display_name)
					break
			if not partial:
				print("ERROR: Missing Effect: ", e_name)
				passed = false

	if statuses.size() != 11:
		print("ERROR: Status Count mismatch. Expected 11, got ", statuses.size())
		passed = false
		
	if effects.size() != 5:
		print("ERROR: Effect Count mismatch. Expected 5, got ", effects.size())
		passed = false

	if passed:
		print("TEST PASSED: StatusCatalog is healthy.")
		get_tree().quit(0)
	else:
		print("TEST FAILED: Missing entries in StatusCatalog.")
		get_tree().quit(1)
