extends PanelContainer
class_name UnitWeaponSlot

var unit_data
var current_weapon
var style_box: StyleBoxFlat
var is_highlighted: bool = false
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
	style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.2)
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.4, 0.4, 0.5)
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	add_theme_stylebox_override("panel", style_box)
	
	custom_minimum_size = Vector2(180, 70) # Wider and taller for easier drop
	
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



var is_drag_target_valid: bool = false

func _notification(what):
	if what == NOTIFICATION_DRAG_BEGIN:
		var data = get_viewport().gui_get_drag_data()
		if _is_valid_drop_data(data):
			is_drag_target_valid = true
			_update_visual_state(false) # Hint state
			
	elif what == NOTIFICATION_DRAG_END:
		if is_drag_target_valid:
			is_drag_target_valid = false
			_update_visual_state(false)

func _can_drop_data(_at_position, data):
	if read_only: return false
	
	if _is_valid_drop_data(data):
		_set_highlight(true)
		return true
	return false

func _is_valid_drop_data(data):
	if typeof(data) == TYPE_DICTIONARY:
		if data.get("type") == "item":
			var item = data.get("item_data")
			# Check Class - Only Weapons allowed
			if item and item is WeaponData:
				return true
	return false

func _drop_data(_at_position, data):
	_set_highlight(false)
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
			
func _set_highlight(hovering: bool):
	if hovering == is_highlighted: return
	is_highlighted = hovering
	_update_visual_state(hovering)

func _update_visual_state(hovering: bool):
	if hovering:
		# Hovering State (Gold)
		style_box.border_color = Color(0.9, 0.8, 0.2)
		style_box.bg_color = Color(0.25, 0.25, 0.3)
	elif is_drag_target_valid:
		# Global Drag Hint (Cyan)
		style_box.border_color = Color(0.2, 0.6, 1.0, 0.8)
		style_box.bg_color = Color(0.15, 0.2, 0.25)
	else:
		# Idle
		style_box.border_color = Color(0.4, 0.4, 0.5)
		style_box.bg_color = Color(0.15, 0.15, 0.2) 
