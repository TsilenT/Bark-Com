extends PanelContainer
class_name StashDropTarget

# Used to determine if we can drop an item here to return it to stash

func _can_drop_data(_at_position, data):
	if typeof(data) == TYPE_DICTIONARY:
		if data.get("type") == "item":
			var source = data.get("source")
			if source == "unit_slot":
				return true
			elif source == "unit_weapon":
				return true
	return false

func _drop_data(_at_position, data):
	var item = data.get("item_data")
	var source = data.get("source")
	
	if GameManager:
		if source == "unit_slot":
			var src_unit = data.get("_unit_ref")
			var src_idx = data.get("_slot_idx")
			if src_unit and src_idx != null:
				GameManager.unequip_item_to_stash(src_unit, src_idx)
				
		elif source == "unit_weapon":
			var src_unit = data.get("_unit_ref")
			if src_unit:
				GameManager.unequip_weapon_to_stash(src_unit)
