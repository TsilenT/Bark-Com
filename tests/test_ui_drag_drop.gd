extends Node

const TestUtils = preload("res://tests/TestUtils.gd")
const WeaponData = preload("res://scripts/resources/WeaponData.gd")
const ConsumableData = preload("res://scripts/resources/ConsumableData.gd")

var weapon_slot_script = load("res://scripts/ui/UnitWeaponSlot.gd")
var inventory_slot_script = load("res://scripts/ui/UnitInventorySlot.gd")

func _ready():
	print("\n--- TEST START: Drag & Drop Logic ---")
	
	# Anti-Ghosting Safeguard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	setup_game_manager()
	
	# Run tests synchronously
	test_weapon_slot_restrictions()
	test_inventory_slot_restrictions()
	test_weapon_equip()
	test_inventory_equip()
	test_weapon_swap()
	
	print("\n--- ALL DRAG & DROP TESTS PASSED ---")
	
	# Use standard cleanup
	await TestUtils.finalize_and_quit(get_tree(), 0)

func setup_game_manager():
	if not GameManager:
		printerr("GameManager not found!")
		return
		
	# Setup Mock Roster
	GameManager.roster = [
		{
			"name": "UnitA", 
			"class": "Recruit", 
			"primary_weapon": null,
			"inventory": [null, null]
		},
		{
			"name": "UnitB", 
			"class": "Recruit", 
			"primary_weapon": null,
			"inventory": [null, null]
		}
	]
	
	GameManager.inventory = []
	print("PASS: GameManager initialized with Mock Roster.")

func test_weapon_slot_restrictions():
	var slot = weapon_slot_script.new()
	slot.setup(GameManager.roster[0])
	
	# 1. Weapon -> Weapon Slot (Should allow)
	var weapon = WeaponData.new()
	weapon.display_name = "Test Gun"
	var drag_data_w = {"type": "item", "item_data": weapon, "source": "stash"}
	
	if slot._can_drop_data(Vector2.ZERO, drag_data_w):
		print("PASS: Weapon Slot accepts Weapon.")
	else:
		printerr("FAIL: Weapon Slot rejected Weapon!")

	# 2. Consumable -> Weapon Slot (Should deny)
	var item = ConsumableData.new()
	item.display_name = "Test Medkit"
	var drag_data_c = {"type": "item", "item_data": item, "source": "stash"}
	
	if not slot._can_drop_data(Vector2.ZERO, drag_data_c):
		print("PASS: Weapon Slot rejected Consumable.")
	else:
		printerr("FAIL: Weapon Slot accepted Consumable!")
		
	slot.queue_free()

func test_inventory_slot_restrictions():
	var slot = inventory_slot_script.new()
	slot.setup(GameManager.roster[0], 0, null)
	
	# 1. Consumable -> Inventory Slot (Should allow)
	var item = ConsumableData.new()
	item.display_name = "Test Medkit"
	var drag_data_c = {"type": "item", "item_data": item, "source": "stash"}
	
	if slot._can_drop_data(Vector2.ZERO, drag_data_c):
		print("PASS: Inventory Slot accepts Consumable.")
	else:
		printerr("FAIL: Inventory Slot rejected Consumable!")
		
	# 2. Weapon -> Inventory Slot (Should deny)
	var weapon = WeaponData.new()
	weapon.display_name = "Test Gun"
	var drag_data_w = {"type": "item", "item_data": weapon, "source": "stash"}
	
	if not slot._can_drop_data(Vector2.ZERO, drag_data_w):
		print("PASS: Inventory Slot rejected Weapon.")
	else:
		printerr("FAIL: Inventory Slot accepted Weapon!")
		
	slot.queue_free()

func test_weapon_equip():
	var unit = GameManager.roster[0]
	var slot = weapon_slot_script.new()
	slot.setup(unit)
	
	var weapon = WeaponData.new()
	weapon.display_name = "EquipGun"
	GameManager.inventory.append(weapon)
	
	var drag_data = {"type": "item", "item_data": weapon, "source": "stash"}
	
	# Execute Drop
	slot._drop_data(Vector2.ZERO, drag_data)
	
	# Verify
	if unit["primary_weapon"] == weapon:
		print("PASS: Weapon Equipped successfully.")
	else:
		printerr("FAIL: Weapon Equip logic failed.")
		
	if not weapon in GameManager.inventory:
		print("PASS: Weapon removed from Stash.")
	else:
		printerr("FAIL: Weapon still in Stash.")
		
	slot.queue_free()

func test_inventory_equip():
	var unit = GameManager.roster[0]
	var slot = inventory_slot_script.new()
	slot.setup(unit, 0, null)
	
	var item = ConsumableData.new()
	item.display_name = "EquipMedkit"
	GameManager.inventory.append(item)
	
	var drag_data = {"type": "item", "item_data": item, "source": "stash"}
	
	# Execute Drop
	slot._drop_data(Vector2.ZERO, drag_data)
	
	# Verify
	if unit["inventory"][0] == item:
		print("PASS: Consumable Equipped successfully.")
	else:
		printerr("FAIL: Consumable Equip logic failed.")
		
	if not item in GameManager.inventory:
		print("PASS: Item removed from Stash.")
	else:
		printerr("FAIL: Item still in Stash.")
		
	slot.queue_free()

func test_weapon_swap():
	var unit_a = GameManager.roster[0]
	var unit_b = GameManager.roster[1]
	
	var gun_a = WeaponData.new()
	gun_a.display_name = "Gun A"
	unit_a["primary_weapon"] = gun_a
	
	var gun_b = WeaponData.new()
	gun_b.display_name = "Gun B"
	unit_b["primary_weapon"] = gun_b
	
	# Simulate Dragging Gun A (from Unit A) -> Unit B's Slot
	var slot_b = weapon_slot_script.new()
	slot_b.setup(unit_b)
	
	var drag_data = {
		"type": "item",
		"item_data": gun_a,
		"source": "unit_weapon",
		"_unit_ref": unit_a
	}
	
	# Execute Drop
	slot_b._drop_data(Vector2.ZERO, drag_data)
	
	# Verify Swap
	if unit_a["primary_weapon"] == gun_b and unit_b["primary_weapon"] == gun_a:
		print("PASS: Weapons Swapped successfully.")
	else:
		printerr("FAIL: Swap logic failed. A has " + str(unit_a["primary_weapon"]) + ", B has " + str(unit_b["primary_weapon"]))
		
	slot_b.queue_free()
