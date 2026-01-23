extends Node3D

# UnitStatusUI
# Displays overhead icons (Sprite3D) for active statuses.

var unit
var sprites: Array[Sprite3D] = []

# Panic Icons
const PANIC_ICONS = {
	1: preload("res://assets/icons/status/panic_freeze.svg"),
	2: preload("res://assets/icons/status/panic_run.svg"),
	3: preload("res://assets/icons/status/panic_berserk.svg")
}

func _ready():
	unit = get_parent()
	if not unit:
		queue_free()
		return

	# Connect Signals
	SignalBus.on_status_applied.connect(_on_status_changed)
	SignalBus.on_status_removed.connect(_on_status_changed)
	# Assuming panic changes triggers stats changed or we might need a specific panic signal?
	# Usually Panic adds a status or we check each turn. 
	# For now, let's hook into stats changed too just in case.
	SignalBus.on_unit_stats_changed.connect(_on_status_changed_wrapper)

	_refresh_full()
	
func _exit_tree():
	if SignalBus:
		if SignalBus.on_status_applied.is_connected(_on_status_changed):
			SignalBus.on_status_applied.disconnect(_on_status_changed)
		if SignalBus.on_status_removed.is_connected(_on_status_changed):
			SignalBus.on_status_removed.disconnect(_on_status_changed)
		if SignalBus.on_unit_stats_changed.is_connected(_on_status_changed_wrapper):
			SignalBus.on_unit_stats_changed.disconnect(_on_status_changed_wrapper)


func _on_status_changed(_u, _id):
	if _u == unit:
		_refresh_full()

func _on_status_changed_wrapper(u):
	if u == unit:
		_refresh_full()

func _refresh_full():
	# Clear existing
	for s in sprites:
		s.queue_free()
	sprites.clear()

	var icons_to_show = []

	# 1. Active Effects
	if "active_effects" in unit:
		for eff in unit.active_effects:
			if "icon" in eff and eff.icon:
				icons_to_show.append(eff.icon)
	
	# 2. Panic State
	if "current_panic_state" in unit and unit.current_panic_state != 0:
		if PANIC_ICONS.has(unit.current_panic_state):
			icons_to_show.append(PANIC_ICONS[unit.current_panic_state])

	# 3. Cover Status
	if unit.has_method("get_node_or_null"):
		# Access GridManager safely
		var gm = unit.get_node_or_null("/root/GridManager")
		if gm and "grid_pos" in unit:
			var cover_h = gm.get_best_cover_at(unit.grid_pos)
			var cover_icon = null
			
			if cover_h >= 2.0:
				# Use loaded SVG or preload - Assuming standard naming
				# Ideally preload constants but dynamic path is easier for now
				if ResourceLoader.exists("res://assets/ui/shield_icon_full.svg"):
					cover_icon = load("res://assets/ui/shield_icon_full.svg")
			elif cover_h >= 1.0:
				if ResourceLoader.exists("res://assets/ui/shield_icon_half.svg"):
					cover_icon = load("res://assets/ui/shield_icon_half.svg")
			
			if cover_icon:
				icons_to_show.append(cover_icon)

	_create_icons(icons_to_show)


func _create_icons(icons: Array):
	if icons.is_empty():
		return

	var count = icons.size()
	var spacing = 0.6 # Adjust based on icon size
	var start_x = -(count - 1) * spacing * 0.5
	
	for i in range(count):
		var tex = icons[i]
		var sprite = Sprite3D.new()
		sprite.texture = tex
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.005
		sprite.position = Vector3(start_x + (i * spacing), 2.5, 0)
		sprite.no_depth_test = true # Ensure visible on top?
		sprite.render_priority = 10 # Draw on top of unit
		add_child(sprite)
		sprites.append(sprite)

