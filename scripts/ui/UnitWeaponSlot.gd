extends PanelContainer
class_name UnitWeaponSlot

var unit_data
var current_weapon
var read_only: bool = false

func setup(unit):
	unit_data = unit
	
	if unit is Object and "primary_weapon" in unit:
		current_weapon = unit.primary_weapon
	elif typeof(unit) == TYPE_DICTIONARY:
		current_weapon = unit.get("primary_weapon")
	else:
		current_weapon = null
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2) # Slightly different bg for weapon
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.5)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	add_theme_stylebox_override("panel", style)
	
	custom_minimum_size = Vector2(150, 50) # Wider for weapon name?
	
	# Clear previous
	for c in get_children():
		c.queue_free()
		
	# Render Content
	var DraggableItemIconScript = load("res://scripts/ui/DraggableItemIcon.gd")
	
	if current_weapon:
		# Use Draggable Icon
		var icon = DraggableItemIconScript.new()
		add_child(icon)
		icon.setup(current_weapon, "unit_weapon")
		icon.extra_data["_unit_ref"] = unit_data
	else:
		# DEFAULT BARK (Visual Only)
		var bark_dummy = {
			"display_name": "Bark",
			"description": "Default melee attack.",
			"icon": "res://assets/icons/weapons/icon_bark.svg"
		}
		
		var icon = DraggableItemIconScript.new()
		add_child(icon)
		# Use a distinct source 'passive' or 'default' to potentially inhibit dragging logic if needed
		# For now, 'unit_weapon' is fine, but dropping it might need safety checks in GameManager
		icon.setup(bark_dummy, "default_weapon") 
		
		# Optional: Add label next to it? Or just Tooltip (handled by Icon)
		# User requested "show that in the weapon slot". Icon is standard.

func _can_drop_data(_at_position, data):
	if read_only: return false
	
	if typeof(data) == TYPE_DICTIONARY:
		if data.get("type") == "item":
			var item = data.get("item_data")
			# Check Class - Only Weapons allowed
			if item and item is WeaponData:
				return true
	return false

func _drop_data(_at_position, data):
	if read_only: return
	
	var item = data.get("item_data")
	var source = data.get("source")
	
	if source == "stash":
		if GameManager:
			GameManager.equip_weapon_from_stash(unit_data, item)
	elif source == "unit_weapon":
		var src_unit = data.get("_unit_ref")
		if GameManager and src_unit:
			GameManager.swap_weapons_between_units(src_unit, unit_data) 
