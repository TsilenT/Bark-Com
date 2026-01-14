extends TextureRect
class_name DraggableItemIcon

var item_data
var source_type
var extra_data: Dictionary = {}

func setup(item, source: String):
	item_data = item
	source_type = source
	extra_data = {}
	
	# Visual Setup
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	custom_minimum_size = Vector2(48, 48)
	mouse_filter = MOUSE_FILTER_PASS # Ensure drops propagate to parent slot container
	
	# Load Icon
	if item is Object and "icon" in item:
		if item.icon is Texture2D:
			texture = item.icon
		elif item.icon is String and item.icon != "":
			texture = load(item.icon)
	elif item is Dictionary and item.get("icon"):
		texture = load(item.icon)
	else:
		# Fallback color block if no icon
		var placeholder = GradientTexture2D.new()
		placeholder.width = 48
		placeholder.height = 48
		placeholder.fill = 0 # Linear
		placeholder.fill_from = Vector2(0,0)
		placeholder.fill_to = Vector2(1,1)
		var grad = Gradient.new()
		grad.colors = [Color.TEAL]
		placeholder.gradient = grad
		texture = placeholder
		
	# Tooltip
	var d_name = item.display_name if "display_name" in item else "Item"
	tooltip_text = d_name

func _get_drag_data(_at_position):
	var data = {
		"type": "item",
		"item_data": item_data,
		"source": source_type
	}
	
	for k in extra_data:
		data[k] = extra_data[k]
	
	# Preview
	var preview = TextureRect.new()
	preview.texture = texture
	preview.expand_mode = EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(48, 48)
	preview.modulate = Color(1, 1, 1, 0.8)
	
	set_drag_preview(preview)
	
	return data
