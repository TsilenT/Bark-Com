extends PanelContainer
class_name UnitInventorySlot

var unit_data
var slot_index
var current_item

signal on_item_dropped(item_data, target_unit, slot_idx)

func setup(unit, idx, item = null):
	unit_data = unit
	slot_index = idx
	current_item = item
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1)
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.3)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	add_theme_stylebox_override("panel", style)
	
	custom_minimum_size = Vector2(50, 50)
	
	# Clear previous children
	for c in get_children():
		c.queue_free()
		
	# Render Content
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

var read_only: bool = false

func _can_drop_data(_at_position, data):
	if read_only: return false
	
	if typeof(data) == TYPE_DICTIONARY:
		if data.get("type") == "item":
			var item = data.get("item_data")
			if item and item is ConsumableData:
				return true
	return false

func _drop_data(_at_position, data):
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
