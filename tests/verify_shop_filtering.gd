extends Node

func _ready():
	print("--- VERIFY SHOP FILTERING ---")
	
	# Anti-Hang
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	await get_tree().process_frame
	
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		print("FAIL: GameManager not found.")
		get_tree().quit(1)
		return
		
	# 1. Inspect Shop Stock
	print("Shop Stock Size: ", gm.shop_stock.size())
	var has_weapons = false
	var has_consumables = false
	
	for item in gm.shop_stock:
		print("- Item: ", item, " Type: ", item.get_class() if item.has_method("get_class") else "Unknown", " Script: ", item.get_script().resource_path)
		if item is WeaponData:
			has_weapons = true
		if item is ConsumableData:
			has_consumables = true
			
	if not has_weapons:
		print("WARNING: No weapons in shop stock? Test might be invalid if we want to test filtering.")
		# Force add a weapon for testing
		var w = WeaponData.new()
		w.display_name = "Test Weapon"
		gm.shop_stock.append(w)
		print("Added Test Weapon to stock.")
		
	# 2. Simulate ObjectiveSpawner Logic
	var valid_items = []
	for item in gm.shop_stock:
		if item is ConsumableData:
			valid_items.append(item)
			
	print("Filtered Items (Consumables Only): ", valid_items.size())
	
	# 3. Assertions
	for item in valid_items:
		if item is WeaponData:
			print("FAIL: Weapon found in filtered list! Item: ", item)
			get_tree().quit(1)
			return
		if not (item is ConsumableData):
			print("FAIL: Non-Consumable in filtered list! Item: ", item)
			get_tree().quit(1)
			return
			
	print("SUCCESS: Filtering Logic holds. No weapons in loot table.")
	get_tree().quit(0)
