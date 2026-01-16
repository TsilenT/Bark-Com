extends Node

func _ready():
	print("Verifying compilation of ability scripts (Scene Mode)...")
	var err_count = 0
	
	var scripts = [
		"res://scripts/abilities/GoForAnklesAbility.gd",
		"res://scripts/abilities/RunAndGunAbility.gd"
	]
	
	for s in scripts:
		var script = load(s)
		if script:
			print("✅ Payload loaded: " + s)
			var instance = script.new()
			if instance:
				print("   Instance created successfully.")
				# Check if description property can be set (inherited)
				instance.description = "Test Description"
			else:
				print("❌ Failed to instantiate: " + s)
				err_count += 1
		else:
			print("❌ Failed to load: " + s)
			err_count += 1
			
	if err_count == 0:
		print("All scripts verified successfully.")
		get_tree().quit(0)
	else:
		print("Verification failed with " + str(err_count) + " errors.")
		get_tree().quit(1)
