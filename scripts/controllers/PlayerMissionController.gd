extends Node
class_name PlayerMissionController

## PlayerMissionController
##
## Handles all Player inputs during the MISSION state.
## Acts as the primary interface between the user (Mouse/Keyboard) and the Game Logic.
##
## Core Responsibilities:
## 1. Input State Machine: Manages modes like MOVING, TARGETING, SELECTING.
## 2. Selection: Tracks the currently selected Unit and Ability.
## 3. Visualization: Updates GridVisualizer (Overlays, Paths, Hit Chances).
## 4. Input Routing: Determines if a click is a Move, Attack, or Interaction.

const LOG_PREFIX = "PMC: "

const StandardAttack = preload("res://scripts/abilities/StandardAttack.gd")
# Explicit preload to avoid cyclic dependency/cache issues with Global Class
const GridVisualizerScript = preload("res://scripts/ui/GridVisualizer.gd")

var default_attack: StandardAttack

# Input States
enum InputState {
	## Default state. Selecting units or inspecting the field.
	SELECTING,
	## Unit selected, waiting for movement destination click.
	MOVING,
	## Ability/Attack selected, waiting for target selection.
	TARGETING,        # Standard Attack
	ABILITY_TARGETING,
	ITEM_TARGETING,
	CINEMATIC
}

# Dependencies (Injected)
var main_node: Node
var grid_manager
var turn_manager # TurnManager
var game_ui      # GameUI
var _signal_bus  # SignalBus (Injected)

# State
var current_input_state: int = InputState.SELECTING
var selected_unit = null
var selected_ability = null # Ability Resource/Script
var pending_item_action = null
var pending_item_slot: int = -1
var _last_debug_hover: Vector2 = Vector2(-999, -999)
var _last_hovered_object: Node = null
var _tactical_view_active: bool = false
var _alt_held: bool = false
var _last_threat_target = null # For cleaning up Visual Threat Contexts

func _can_set_threat(obj):
	if is_instance_valid(obj) and "status_ui" in obj and obj.status_ui and obj.status_ui.has_method("set_threat_context"):
		return true
	return false

# Signals (To update UI/Visuals)
signal input_state_changed(new_state)
signal selection_changed(unit)

func initialize(entry_main, entry_gm, entry_tm, entry_ui, entry_sb):
	main_node = entry_main
	grid_manager = entry_gm
	turn_manager = entry_tm
	game_ui = entry_ui
	_signal_bus = entry_sb
	_signal_bus = entry_sb
	default_attack = StandardAttack.new()
	GameManager.log(LOG_PREFIX, "Initialized.")

func _process(_delta):
	# Handle Global Inputs (Tactical View) here to be frame-perfect
	_handle_tactical_view_input()

func _handle_tactical_view_input():
	# Allow action "ui_tactical_view_toggle" or generic ALT key
	# Note: If Input Map doesn't have the action, is_action_pressed returns false safely.
	var alt_pressed = Input.is_key_pressed(KEY_ALT) 
	if InputMap.has_action("ui_tactical_view_toggle"):
		if Input.is_action_pressed("ui_tactical_view_toggle"):
			alt_pressed = true

	if GameManager and GameManager.settings.get("tactical_view_toggle", false) == true:
		# TOGGLE MODE
		if alt_pressed and not _alt_held:
			_alt_held = true 
			_tactical_view_active = not _tactical_view_active
			_toggle_tactical_view(_tactical_view_active)
		elif not alt_pressed:
			_alt_held = false
	else:
		# HOLD MODE
		# Only update if state changed to prevent spamming the visualizer
		if alt_pressed != _tactical_view_active:
			_tactical_view_active = alt_pressed
			_toggle_tactical_view(_tactical_view_active)

func set_input_state(new_state: int):
	current_input_state = new_state
	emit_signal("input_state_changed", new_state)
	
	# Clear visuals on state change
	_clear_overlays()
	
	# Show Visuals for New State
	if new_state == InputState.MOVING and selected_unit:
		var gv = _get_grid_visualizer()
		if gv and grid_manager:
			# FIX: Ensure pathfinding is fresh so "ignore_unit" logic works for current tile
			if turn_manager and "units" in turn_manager:
				grid_manager.refresh_pathfinding(turn_manager.units, selected_unit)

			# Only show reachable tiles if unit has AP to move
			if _can_unit_move():
				var reachable = grid_manager.get_reachable_tiles(selected_unit.grid_pos, selected_unit.mobility)
				gv.show_highlights(reachable, GridVisualizerScript.VisualType.MOVE)
			else:
				# Feedback handled by enter_movement_mode or suppressed
				pass
			
	if new_state == InputState.ABILITY_TARGETING and selected_unit and selected_ability:
		var gv = _get_grid_visualizer()
		if gv and grid_manager:
			var valid = selected_ability.get_valid_tiles(grid_manager, selected_unit)
			gv.show_highlights(valid, GridVisualizerScript.VisualType.ATTACK)
			
	if new_state == InputState.ITEM_TARGETING and pending_item_action:
		var gv = _get_grid_visualizer()
		if gv and grid_manager:
			var item = pending_item_action
			var valid = []
			
			if item.get("ability_ref"):
				# Ability-based Item
				var ability_res = item.ability_ref
				if ability_res is Script or ability_res is Resource:
					var ability = ability_res.new()
					if selected_unit and ability.has_method("update_stats"):
						ability.update_stats(selected_unit)
					valid = ability.get_valid_tiles(grid_manager, selected_unit)
					# Deduplicate
					var unique = {}
					var clean_valid = []
					for t in valid:
						if not unique.has(t):
							unique[t] = true
							clean_valid.append(t)
					valid = clean_valid
			else:
				# Simple Range Item
				var range_val = 1
				if "range_tiles" in item: range_val = item.range_tiles
				elif "range" in item: range_val = item.range
				elif "ability_range" in item: range_val = item.ability_range
				
				# Calc circle
				if selected_unit:
					valid = grid_manager.get_tiles_in_range(selected_unit.grid_pos, range_val)

			# Use Item Visual Type (Yellow)
			gv.show_highlights(valid, GridVisualizerScript.VisualType.ITEM)

func _clear_overlays():
	if main_node.has_method("_clear_targeting_visuals"):
		main_node._clear_targeting_visuals()
	else:
		# Fallback until Main refactor is complete
		var gv = main_node.get_node_or_null("GridVisualizer")
		if gv:
			gv.clear_highlights()
			gv.clear_preview_path()
			gv.clear_preview_aoe()
			gv.clear_predictive_cover_icon()
			gv.clear_hover_cursor()
		
		# Atomic Cleanup
		_hide_attack_feedback(gv)
		
		# Clear Threat Context
		if _last_threat_target and is_instance_valid(_last_threat_target):
			if _can_set_threat(_last_threat_target):
				_last_threat_target.status_ui.clear_threat_context()
			_last_threat_target = null

## Central Input Router for 3D Tile Clicks.
## Called by InputManager via Raycast.
##
## Dispatches logic based on `current_input_state`:
## - MOVING: Validates and executes movement.
## - TARGETING: Validates and executes attacks.
## - SELECTING: Handles Unit Selection or Interacting with world props.
func handle_tile_clicked(grid_pos: Vector2, button_index: int):
	# print("PMC: handle_tile_clicked at ", grid_pos, " Btn: ", button_index, " State: ", current_input_state)
# ... (Lines 59-109 Unchanged)

	# Validation
	if not main_node or not grid_manager:
		return

	# Cancel / Back
	if button_index == MOUSE_BUTTON_RIGHT:
		cancel_action()
		return

	match current_input_state:
		InputState.MOVING:
			# Preview execution happens in handle_mouse_hover
			_handle_move_click(grid_pos)
		
		InputState.ABILITY_TARGETING:
			_handle_ability_click(grid_pos)
			
		InputState.TARGETING:
			# Now standardized!
			_handle_ability_click(grid_pos)
		
		InputState.ITEM_TARGETING:
			_handle_item_click(grid_pos)
			
		InputState.SELECTING:
			_handle_selection_click(grid_pos)
			
		_:
			_hide_attack_feedback()


func handle_mouse_hover(grid_pos: Vector2):
	var gv = _get_grid_visualizer()
	if not gv: return

	# Delegate Global Hover Logic (Cursor Shape, etc) to Main
	if main_node and main_node.has_method("_on_mouse_hover"):
		main_node._on_mouse_hover(grid_pos)

	# --- NEW: Propagate Hover to Objects (Highlighting) ---
	var hovered_obj = _resolve_target_at(grid_pos)
	if not hovered_obj:
		hovered_obj = _get_interactive_at(grid_pos)
		
	if hovered_obj != _last_hovered_object:
		if is_instance_valid(_last_hovered_object) and _last_hovered_object.has_method("_mouse_exit"):
			_last_hovered_object._mouse_exit()
		
		if is_instance_valid(hovered_obj) and hovered_obj.has_method("_mouse_enter"):
			hovered_obj._mouse_enter()
			
		_last_hovered_object = hovered_obj
	# -----------------------------------------------------

	# Prevent hover updates during execution
	if turn_manager and turn_manager.is_handling_action:
		_hide_attack_feedback(gv)
		gv.clear_predictive_cover_icon() # Ensure stale icon is gone
		return

	match current_input_state:
		InputState.MOVING:
			_preview_movement(grid_pos, gv)
		
		InputState.ABILITY_TARGETING:
			_preview_ability(grid_pos, gv)
			
		InputState.TARGETING:
			_preview_attack(grid_pos)
			
		InputState.ITEM_TARGETING:
			# Reuse Ability Preview? Items mostly AOE or Single Target.
			# But selected_ability is likely null. We need pending_item_action (Item Resource).
			_preview_item(grid_pos, gv)
			
		InputState.SELECTING:
			# Restore Legacy UX: Show hit chance if hovering enemy
			var unit = _get_unit_at(grid_pos)
			if unit and unit != selected_unit and unit.get("faction") == "Enemy":
				_preview_attack(grid_pos)
			else:
				# Show Volatile Range if hovering explosive
				var vol = _resolve_volatile_at(grid_pos)
				if vol:
					var radius = 2 # Default
					if "explosion_range" in vol: radius = vol.explosion_range
					var r_tiles = _get_aoe_tiles(grid_pos, radius)
					gv.preview_aoe(r_tiles, Color(1, 0.5, 0, 0.4)) # Orange Warning
				else:
					gv.clear_preview_aoe()
				
				gv.clear_preview_path()
				_hide_attack_feedback(gv)

		_:
			gv.clear_preview_path()
			gv.clear_preview_aoe()
			_hide_attack_feedback(gv)

	# 6. Tactical View Toggle Logic Moved to _process for responsiveness 

# ...

func _toggle_tactical_view(active: bool):
	var gv = _get_grid_visualizer()
	if not gv: return
	
	if active:
		if not grid_manager: return
		
		# Collect Cover Tiles
		var cover_data = {}
		
		var vm = null
		if main_node and "vision_manager" in main_node:
			vm = main_node.vision_manager
			
		for coord in grid_manager.grid_data:
			# Check Visibility
			if vm and not vm.is_tile_explored(coord):
				continue
				
			# Check Occupancy (Avoid double indicator with UnitStatusUI)
			if _get_unit_at(coord):
				continue
				
			var tile = grid_manager.grid_data[coord]
			var type = tile.get("type", 0)
			if type == GridManager.TileType.COVER_FULL or type == GridManager.TileType.COVER_HALF:
				cover_data[coord] = type
				
		gv.update_cover_icons(cover_data)
	else:
		gv.clear_cover_icons()


# --- Internal Helper for Atomic Cleanup ---
func _hide_attack_feedback(gv = null):
	if not gv: gv = _get_grid_visualizer()
	if gv: gv.clear_lof()
	if _signal_bus: _signal_bus.on_hide_hit_chance.emit()

# --- Handlers ---

func _handle_selection_click(grid_pos: Vector2):
	var target_unit = _get_unit_at(grid_pos)
	GameManager.log(LOG_PREFIX, "Attempting Select at ", grid_pos, ". Found: ", target_unit)
	
	# Friendly Switching
	if target_unit and target_unit.get("faction") == "Player" and target_unit != selected_unit:
		select_unit(target_unit)
		return

	# Select Unit (if nothing selected or clicking valid target)
	if target_unit and target_unit.get("faction") != "Neutral":
		select_unit(target_unit)
	elif target_unit and target_unit.get("faction") == "Neutral":
		# Special Interaction (Smart Click)
		# If clicking a Neutral Interactable (LootCrate), try to interact
		if target_unit.is_in_group("Interactive") or target_unit.is_in_group("Objectives"):
			GameManager.log(LOG_PREFIX, "Clicked Neutral Interactive. Delegating to Main.")
			if main_node.has_method("_process_move_or_interact"):
				main_node._process_move_or_interact(grid_pos)

	
	# Deselect if clicking empty ground? (Optional)
	if not target_unit:
		# Check for Generic Interactive (Door)
		var interactive = _get_interactive_at(grid_pos)
		if interactive and interactive.is_in_group("Interactive"):
			GameManager.log(LOG_PREFIX, "Clicked Generic Interactive (Door). Delegating to Main.")
			if main_node.has_method("_process_move_or_interact"):
				main_node._process_move_or_interact(grid_pos)
			return
			
		# select_unit(null) ? 
		pass

func select_unit(unit):
	# Clear previous state/overlays before switching
	set_input_state(InputState.SELECTING)
	
	selected_unit = unit
	emit_signal("selection_changed", unit)
	
	# Update Pathfinding for this unit (Allow moving through friends)
	if grid_manager and turn_manager and unit:
		grid_manager.refresh_pathfinding(turn_manager.units, unit, unit.faction)
	
	# Sync Main? Main uses signals mostly now.
	if _signal_bus:
		_signal_bus.on_ui_select_unit.emit(unit)
	# Main._set_selected_unit(unit) # Legacy call if needed
	
func select_next_unit():
	GameManager.log(LOG_PREFIX, "Cycle Next Unit Requested.")
	# 1. Get List of Player Units (Sorted by ID or Index)
	# TurnManager.units is reliable list
	if not turn_manager:
		return
		
	var units = turn_manager.units.filter(func(u): 
		return is_instance_valid(u) and u.get("faction") == "Player" and u.current_hp > 0
	)
	
	if units.is_empty():
		return
		
	# 2. Find Current Index
	var current_idx = -1
	if selected_unit in units:
		current_idx = units.find(selected_unit)
	
	# 3. Find Next Candidate (Prioritize Active)
	var next_unit = null
	
	# Loop twice: First pass looks for AP > 0. Second pass accepts any.
	# Actually, smart cycle: Start from current+1, loop around. 
	# If we find AP > 0, pick it. If we return to start, pick next index regardless?
	
	# Simple strategy: Cycle to next available unit. 
	# If that unit has 0 AP, continue... unless ALL have 0 AP.
	
	var start_idx = (current_idx + 1) % units.size()
	var check_idx = start_idx
	var fallback_unit = null
	
	for i in range(units.size()):
		var u = units[check_idx]
		if u.current_ap > 0:
			next_unit = u
			break
		
		# Allow selecting 0 AP unit if it's the specific "Next" one and no others are active?
		# Or just cache it.
		if fallback_unit == null:
			fallback_unit = u
			
		check_idx = (check_idx + 1) % units.size()
		
	if next_unit:
		select_unit(next_unit)
	elif fallback_unit:
		# Everyone is tired, just cycle to next in list
		# Ensure we don't just reselect current if size > 1
		if units.size() > 1:
			select_unit(units[start_idx])
		else:
			# Only 1 unit, reselect to center camera/feedback
			select_unit(units[0])


func _handle_move_click(grid_pos: Vector2):
	GameManager.log(LOG_PREFIX, "_handle_move_click. Unit: ", selected_unit)
	if not selected_unit: return

	# CHECK AP
	if not _can_unit_move():
		GameManager.log(LOG_PREFIX, "Unit has 0 AP. Ignoring Move Click.")
		cancel_action()
		return

	# 0. Friendly Unit Switching (Overriding Move)
	var clicked_unit = _get_unit_at(grid_pos)
	if clicked_unit and clicked_unit.get("faction") == "Player" and clicked_unit != selected_unit:
		GameManager.log(LOG_PREFIX, "Clicked Friendly Unit in Move Mode. Switching Selection to ", clicked_unit.name)
		select_unit(clicked_unit)
		return

	# 1. Validate Path for Movement (Priority: Walk if possible)
	if grid_manager.is_valid_destination(grid_pos):
		# Move Logic
		var path = grid_manager.get_move_path(selected_unit.grid_pos, grid_pos)
		GameManager.log(LOG_PREFIX, "Path size: ", path.size())
		if path.size() > 0:
			var cost = grid_manager.calculate_path_cost(path)
			if cost > selected_unit.mobility:
				GameManager.log(LOG_PREFIX, "Selected move invalid. Too far. Cost: ", cost, " > ", selected_unit.mobility)
				if _signal_bus:
					_signal_bus.on_combat_log_event.emit("Too Far!", Color.ORANGE)
				return

			# Delegate execution to Main
			_clear_overlays()
			if main_node.has_method("_process_move_or_interact"):
				main_node._process_move_or_interact(grid_pos)
			
			set_input_state(InputState.SELECTING)
			return

	# 2. If blocked, Check Interaction (e.g. Closed Door)
	var interactive = _get_interactive_at(grid_pos)
	if interactive:
		GameManager.log(LOG_PREFIX, "Interactive object clicked (Blocked Tile). Delegating to Main.")
		if main_node.has_method("_process_move_or_interact"):
			main_node._process_move_or_interact(grid_pos)
		return
	
	# 3. Invalid Destination Feedback
	if not grid_manager.is_valid_destination(grid_pos):
		GameManager.log(LOG_PREFIX, "Invalid destination (Blocked or LADDER).")
		if _signal_bus:
			_signal_bus.on_combat_log_event.emit("Cannot Stop Here", Color.RED)
		return

## Validates and executes an ability attack at the given position.
## - Checks if target is valid for the selected ability.
## - Checks if target is within Range / Valid Tiles.
## - Delegates execution to Main (which calls CombatResolver).
func _handle_ability_click(grid_pos: Vector2):
	var target = _resolve_target_at(grid_pos)
	
	# Determine ability (Standardize Legacy)
	var ability = selected_ability
	if not ability and current_input_state == InputState.TARGETING:
		ability = default_attack
	
	# 1. Validation Logic
	if ability:
		var valid_tiles = ability.get_valid_tiles(grid_manager, selected_unit)
		if not valid_tiles.has(grid_pos):
			GameManager.log(LOG_PREFIX, "Clicked Tile ", grid_pos, " is out of range/invalid.")
			# Optional: Feedback UI
			if _signal_bus:
				_signal_bus.on_combat_log_event.emit("Out of Range", Color.RED)
			return

	# Execute
	if main_node.has_method("_execute_ability"):
		main_node._execute_ability(ability, selected_unit, target, grid_pos)
	
	# Reset
	cancel_action()

func _handle_item_click(grid_pos: Vector2):
	if not pending_item_action:
		GameManager.log(LOG_PREFIX, "No item pending.")
		cancel_action()
		return
		
	var item = pending_item_action
	var target = _get_unit_at(grid_pos)
	
	# Robust Ability-Based Validation (Matches _preview_item)
	var is_valid_range = false
	
	if item.get("ability_ref"):
		var ability_res = item.ability_ref
		if ability_res is Script or ability_res is Resource:
			var ability = ability_res.new()
			if selected_unit and ability.has_method("update_stats"):
				ability.update_stats(selected_unit)
				
			var valid_tiles = ability.get_valid_tiles(grid_manager, selected_unit)
			if valid_tiles.has(grid_pos):
				is_valid_range = true
			else:
				GameManager.log(LOG_PREFIX, "Tile ", grid_pos, " not in ability valid tiles.")
	
	if not is_valid_range:
		# Fallback: Simple Range Check (for non-ability items)
		var range_val = 1
		if "range_tiles" in item: # Standard ConsumableData property
			range_val = item.range_tiles
		elif "range" in item:
			range_val = item.range
		elif "ability_range" in item:
			range_val = item.ability_range
			
		if selected_unit.grid_pos.distance_to(grid_pos) <= range_val:
			is_valid_range = true
			
	if not is_valid_range:
		GameManager.log(LOG_PREFIX, "Item Out of Range.")
		if _signal_bus:
			_signal_bus.on_combat_log_event.emit("Out of Range", Color.RED)
		return

	# Execute via Main (Legacy wrapper around Unit.use_item)
	if main_node.has_method("_execute_item"):
		main_node._execute_item(selected_unit, item, pending_item_slot, target, grid_pos)
		
	# Reset
	cancel_action()
# ... (Rest of Handlers Unchanged) ...

func _preview_movement(grid_pos: Vector2, gv: Node):
	if not selected_unit: return
	
	if not _can_unit_move():
		gv.clear_preview_path()
		return
	
	var path = grid_manager.get_move_path(selected_unit.grid_pos, grid_pos)
	
	# Validate Destination Occupancy (Match Blue Squares logic)
	if not grid_manager.is_valid_destination(grid_pos):
		gv.clear_preview_path()
		return
		
	if path.size() > 0:
		var color = Color.CYAN
		# Check Mobility
		var cost = grid_manager.calculate_path_cost(path)
		if cost > selected_unit.mobility:
			color = Color.ORANGE
		
		gv.preview_path(path, color)
		
		# Predictive Cover Icon
		if grid_manager:
			var best_cover = grid_manager.get_best_cover_at(grid_pos)
			var type = 0
			if best_cover >= 2.0: type = 4 # COVER_FULL (Magic Number from GridManager enum? Need constant)
			elif best_cover >= 1.0: type = 5 # COVER_HALF
			
			# Map to GridManager.TileType values:
			# GROUND=0, OBSTACLE=1, COVER_HALF=2, COVER_FULL=3, RAMP=4, LADDER=5 ???
			# Wait, let's check GridManager definitions.
			# TileType { GROUND, OBSTACLE, COVER_HALF, COVER_FULL, RAMP, LADDER }
			# Default Enum: GROUND=0, OBSTACLE=1, COVER_HALF=2, COVER_FULL=3, RAMP=4, LADDER=5
			# But LevelGenerator uses specific values. 
			# Let's use GridManager.TileType.COVER_FULL if available.
			
			if best_cover >= 2.0:
				gv.show_predictive_cover_icon(grid_pos, GridManager.TileType.COVER_FULL)
			elif best_cover >= 1.0:
				gv.show_predictive_cover_icon(grid_pos, GridManager.TileType.COVER_HALF)
			else:
				gv.clear_predictive_cover_icon()
				
	else:
		gv.clear_preview_path()
		gv.clear_predictive_cover_icon()

	# Ensure Attack Visuals are hidden
	_hide_attack_feedback(gv)

func _preview_ability(grid_pos: Vector2, gv: Node):
	# 1. Path Clearing
	gv.clear_preview_path()
	
	# 2. AOE Preview
	# 2. AOE Preview
	if selected_ability and "aoe_radius" in selected_ability:
		var r = selected_ability.aoe_radius
		var aoe_tiles = _get_aoe_tiles(grid_pos, r)
		gv.preview_aoe(aoe_tiles, Color(1, 0.4, 0.4, 0.4))
	else:
		gv.clear_preview_aoe()
	
	# 3. Hit Chance Logic (Delegated to unified handler)
	_preview_attack(grid_pos)

func _preview_attack(grid_pos: Vector2):
	# Replaces Main._handle_hover logic for hit chance display
	var gv = _get_grid_visualizer()
	var is_valid_target = false
	var target_obj = null
	
	# 1. Resolve potential target (Unit, Prop, Terminal, or generic position)
	target_obj = _resolve_target_at(grid_pos)
	
	# THREAT CONTEXT SYNC (Visuals mismatch fix)
	# Clear previous contexts first (global cleanup might be messy, so just check last target?)
	# Ideally, clear ALL contexts on all units, but that's slow.
	# We rely on 'handle_mouse_hover' calling clear when we move away? No.
	# We need a tracker for the last unit we modified.
	
	# NOTE: We need to inject this tracking into PMC to avoid stale states.
	if _last_threat_target and is_instance_valid(_last_threat_target) and _last_threat_target != target_obj:
		if _can_set_threat(_last_threat_target):
			_last_threat_target.status_ui.clear_threat_context()
		_last_threat_target = null

	if target_obj and _can_set_threat(target_obj) and selected_unit:
		target_obj.status_ui.set_threat_context(selected_unit.grid_pos)
		_last_threat_target = target_obj
	
	# NEW: Show Barrel AOE if Targeting
	var show_barrel_aoe = false
	if current_input_state == InputState.TARGETING:
		var vol = _resolve_volatile_at(grid_pos)
		if vol:
			var radius = 2
			if "explosion_range" in vol: radius = vol.explosion_range
			var tiles = _get_aoe_tiles(grid_pos, radius)
			if gv: gv.preview_aoe(tiles, Color(1, 0.5, 0, 0.4))
			show_barrel_aoe = true
			
	if not show_barrel_aoe and gv:
		# Don't clear if coming from Ability Preview (which sets its own AOE)
		if current_input_state != InputState.ABILITY_TARGETING:
			gv.clear_preview_aoe()
	
	# 2. Identify Ability
	var ability_to_check = selected_ability
	if not ability_to_check and current_input_state == InputState.TARGETING:
		ability_to_check = default_attack
		
	# 3. Check Validity based on Ability's own rules
	if ability_to_check:
		# Check if tile itself is valid for this ability
		var valid_tiles = ability_to_check.get_valid_tiles(grid_manager, selected_unit)
		if grid_pos in valid_tiles:
			# Ability says "YES, I can target this tile."
			is_valid_target = true
			
			# Edge Case: StandardAttack usually needs an Enemy Unit.
			# But get_valid_tiles usually returns ONLY enemy locations.
			# So if it's in valid_tiles, it should be fine.
			
	# Fallback legacy check (if ability validation fails or isn't perfect)
	if not is_valid_target and is_instance_valid(target_obj) and ("visible" in target_obj and target_obj.visible):
		# Fallback Faction/Interaction Logic
		if is_instance_valid(selected_unit) and "faction" in target_obj and "faction" in selected_unit:
			if target_obj.faction != selected_unit.faction:
				is_valid_target = true
		elif target_obj.has_method("take_damage_from"):
			# SAFEGUARD: Prevent targeting Objectives
			if selected_unit.faction == "Player" and (target_obj.is_in_group("Objectives") or target_obj.is_in_group("TreatBags")):
				is_valid_target = false
			else:
				is_valid_target = true
			
	if is_valid_target and ability_to_check:
		# print("PMC DEBUG: Checking ability hit chance for ", ability_to_check.display_name)
		var info = ability_to_check.get_hit_chance_breakdown(grid_manager, selected_unit, target_obj)
		if not info.is_empty() and info.has("hit_chance"):
			# ... Continue display logic ...
			
				# Parse Breakdown Dictionary to String
				var breakdown_str = ""
				if info.has("breakdown") and info["breakdown"] is Dictionary:
					for key in info["breakdown"]:
						var val = info["breakdown"][key]
						var sign_str = "+" if val >= 0 else ""
						breakdown_str += "%s: %s%d\n" % [key, sign_str, val]
				elif info.has("breakdown") and info["breakdown"] is String:
					breakdown_str = info["breakdown"]

				if _signal_bus:
					var pos = Vector3.ZERO
					if target_obj and "position" in target_obj:
						pos = target_obj.position
					elif grid_manager:
						pos = grid_manager.get_world_position(grid_pos)
						
					_signal_bus.on_show_hit_chance.emit(info["hit_chance"], breakdown_str, pos + Vector3(0, 1.8, 0))
					
					# DRAW LINE OF FIRE
					if gv:
						# Start from Unit (Chest Height?)
						var start_pos = selected_unit.global_position + Vector3(0, 0.8, 0)
						var end_pos = pos + Vector3(0, 0.8, 0)
						var color = Color.RED
						if info["hit_chance"] > 50: color = Color.GREEN
						elif info["hit_chance"] > 0: color = Color.YELLOW
						
						gv.draw_lof(start_pos, end_pos, color)
						
	else:
		_hide_attack_feedback(gv)


func _preview_item(grid_pos: Vector2, gv: Node):
	gv.clear_preview_path()
	
	if pending_item_action:
		var item = pending_item_action
		
		# 1. Ability-Based Items (Grenades) - Match Ability Logic Exactly
		if item.get("ability_ref"):
			var ability_res = item.ability_ref
			if ability_res is Script or ability_res is Resource:
				var ability = ability_res.new()
				
				# Initialize Perks/Stats
				if selected_unit and ability.has_method("update_stats"):
					ability.update_stats(selected_unit)

				# A. Valid Tiles Helper (Now handled in set_input_state)
				# gv.show_highlights(valid, Color(1, 1, 0, 0.1)) 
				
				# B. AOE Helper
				if "aoe_radius" in ability:
					var r = ability.aoe_radius
					var aoe_tiles = _get_aoe_tiles(grid_pos, r)
					gv.preview_aoe(aoe_tiles, Color(1, 0.4, 0.4, 0.4)) # Red Tint
				else:
					gv.clear_preview_aoe()
					
				# C. Hit Chance Helper
				var info = ability.get_hit_chance_breakdown(grid_manager, selected_unit, null)
				if not info.is_empty() and info.has("hit_chance"):
					var breakdown_str = ""
					if info.has("breakdown") and info["breakdown"] is Dictionary:
						for key in info["breakdown"]:
							var val = info["breakdown"][key]
							var sign_str = "+" if val >= 0 else ""
							breakdown_str += "%s: %s%d\n" % [key, sign_str, val]
					
					if _signal_bus:
						var world_target = grid_manager.get_world_position(grid_pos)
						_signal_bus.on_show_hit_chance.emit(info["hit_chance"], breakdown_str, world_target + Vector3(0, 1.0, 0))
				else:
					_hide_attack_feedback(gv)
					
				return # Done handling ability-based item
		
		# 2. Fallback: Simple Radius Items
		var r = 0.0
		if "radius" in item: r = item.radius
		
		# Default Green Highlight for non-aggressive items
		# Default Green Highlight for non-aggressive items
		if r > 0:
			var aoe_tiles = _get_aoe_tiles(grid_pos, r)
			gv.preview_aoe(aoe_tiles, Color(0.2, 1.0, 0.2, 0.4)) 
		else:
			gv.clear_preview_aoe()
		
		_hide_attack_feedback(gv)
			
	else:
		gv.clear_preview_aoe()
		_hide_attack_feedback(gv)


# --- Actions ---

## Resets the controller state to SELECTING.
## Clears selected abilities, items, and UI visualizers.
func cancel_action():
	set_input_state(InputState.SELECTING)
	selected_ability = null
	pending_item_action = null
	if game_ui and game_ui.has_method("log_message"):
		game_ui.log_message("Command Cancelled.")
	# Clear visuals handled by set_input_state -> _clear_overlays


# --- Helpers ---


func _get_grid_visualizer():
	if main_node and main_node.has_node("GridVisualizer"):
		return main_node.get_node("GridVisualizer")
	return null

func _resolve_target_at(grid_pos: Vector2):
	var target = _get_unit_at(grid_pos)
	if not target:
		target = _find_destructible_at(grid_pos)
	if not target:
		target = _find_terminal_at(grid_pos)
	return target

func _find_terminal_at(grid_pos: Vector2):
	if not main_node:
		return null
	var terminals = main_node.get_tree().get_nodes_in_group("Terminals")
	for t in terminals:
		if is_instance_valid(t) and "grid_pos" in t and t.grid_pos == grid_pos:
			return t
	return null

func _get_unit_at(grid_pos: Vector2):
	if not main_node or not main_node.get_tree():
		return null
	var units = main_node.get_tree().get_nodes_in_group("Units")
	for u in units:
		if is_instance_valid(u) and u.grid_pos == grid_pos and u.current_hp > 0:
			return u
	return null

func _find_destructible_at(grid_pos: Vector2):
	if not main_node:
		return null
	var destructibles = main_node.get_tree().get_nodes_in_group("Destructible")
	for d in destructibles:
		# Could be Node3D or StaticBody, need to check if it has grid_pos and take_damage
		# Usually the script is on the parent of the collider, or the collider itself.
		# Let's check the object itself first.
		var obj = d
		if d is StaticBody3D:
			obj = d.get_parent()
			
		if is_instance_valid(obj) and "grid_pos" in obj and obj.grid_pos == grid_pos:
			if obj.has_method("take_damage_from"):
				return obj
	return null

func _get_interactive_at(grid_pos: Vector2):
	if not is_inside_tree(): return null
	var props = get_tree().get_nodes_in_group("Interactive")
	for p in props:
		if is_instance_valid(p) and "grid_pos" in p and p.grid_pos == grid_pos:
			return p
	return null

# --- Public Methods (Called by Main/UI) ---

func _resolve_volatile_at(grid_pos: Vector2):
	if not main_node: return null
	# Check Destructibles/Props for 'Explosive' traits
	var props = main_node.get_tree().get_nodes_in_group("Destructible")
	for p in props:
		var obj = p
		if p is StaticBody3D: obj = p.get_parent()
		if is_instance_valid(obj) and "grid_pos" in obj and obj.grid_pos == grid_pos:
			# Check Class Type
			if obj is VolatileCover:
				return obj
			# Fallback for duck typing if needed (but class check is safer)
			if obj.has_method("detonate") and "explosion_range" in obj:
				return obj
	return null

func _get_aoe_tiles(center: Vector2, radius: float) -> Array:
	var tiles = []
	if not grid_manager: return tiles
	var r_tiles = ceil(radius) + 1
	for x in range(center.x - r_tiles, center.x + r_tiles + 1):
		for y in range(center.y - r_tiles, center.y + r_tiles + 1):
			var t = Vector2(x, y)
			if grid_manager.grid_data.has(t) and center.distance_to(t) <= radius:
				tiles.append(t)
	return tiles

func enter_movement_mode():
	if not selected_unit: return
	
	# Centralized AP Check
	if not _can_unit_move():
		if game_ui and game_ui.has_method("log_message"):
			game_ui.log_message("Units needs at least 1 AP to move.")
		return # Do not switch state
		
	# Pre-Move Logic (Refresh Pathfinding)
	if grid_manager and turn_manager:
		grid_manager.refresh_pathfinding(turn_manager.units, selected_unit)
		
	# Switch State (Visuals handled in set_input_state)
	set_input_state(InputState.MOVING)

func _can_unit_move() -> bool:
	if not selected_unit: return false
	return selected_unit.current_ap >= 1
