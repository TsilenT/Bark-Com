extends PanelContainer
class_name UnitInventorySlot

var unit_data
var slot_index
var current_item

signal on_item_dropped(item_data, target_unit, slot_idx)

var style_box: StyleBoxFlat
var is_highlighted: bool = false
var read_only: bool = false
var is_drag_target_valid: bool = false

func setup(unit, idx, item = null):
	unit_data = unit
	slot_index = idx
	current_item = item
	
	# Style
	style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1)
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.3, 0.3, 0.3)
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	add_theme_stylebox_override("panel", style_box)
	
	set_process(false)
	
	custom_minimum_size = Vector2(70, 70) # Increased for better hit area
	
	# Clear previous children
	for c in get_children():
		c.queue_free()
		
	# Render Content
	if current_item:
		var DraggableItemIconScript = load("res://scripts/ui/DraggableItemIcon.gd")
		var icon = DraggableItemIconScript.new()
		icon.setup(current_item, "unit_slot")
		# We add a way to identify WHICH slot this source came from if we want unit-to-unit drag later
		icon.extra_data["_unit_ref"] = unit_data
		icon.extra_data["_slot_idx"] = slot_index
		add_child(icon)
	else:
		var lbl = Label.new()
		lbl.text = "EMPTY"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.modulate = Color(0.5, 0.5, 0.5)
		add_child(lbl)


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
			if item and item is ConsumableData:
				return true
	return false

func _drop_data(_at_position, data):
	_set_highlight(false)
	if read_only: return
	
	var item = data.get("item_data")
	var source = data.get("source")
	
	if source == "stash":
		if GameManager:
			GameManager.transfer_item_from_stash_to_unit(item, unit_data, slot_index)
	elif source == "unit_slot":
		# Extract Source Details
		var src_unit = data.get("_unit_ref")
		var src_idx = data.get("_slot_idx")
		
		# Clean internal metadata before transfer? 
		# No, it's fine, it will be overwritten or ignored.
		
		if GameManager and src_unit != null:
			GameManager.transfer_item_unit_to_unit(item, src_unit, src_idx, unit_data, slot_index)
	
	emit_signal("on_item_dropped", item, unit_data, slot_index)
	
func _set_highlight(hovering: bool):
	if hovering == is_highlighted: return
	is_highlighted = hovering
	set_process(hovering)
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
		style_box.border_color = Color(0.3, 0.3, 0.3)
		style_box.bg_color = Color(0.1, 0.1, 0.1)
