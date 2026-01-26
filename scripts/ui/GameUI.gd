extends CanvasLayer
class_name GameUI
const FieldManual = preload("res://scripts/ui/FieldManual.gd")

# References
var turn_manager
var selected_unit

# UI Elements
var turn_banner_overlay: ColorRect
var turn_banner_label: Label

# Overlay Elements
var objective_panel: PanelContainer
var objective_label: RichTextLabel
var menu_button: Button
var pause_menu: Control

var hp_bar: ProgressBar
var hp_label: Label
var ap_bar: ProgressBar
var ap_label: Label
var sanity_bar: ProgressBar
var sanity_label: Label

var hit_chance_panel: PanelContainer
var hit_chance_breakdown: VBoxContainer

# Restored References
var top_bar_label: Label
var unit_card_panel: PanelContainer
var unit_name_label: Label
var action_bar_container: HBoxContainer
# var status_log_label: RichTextLabel # Removed
var mission_end_panel: Panel
var hit_chance_label: Label

# Phase 57: Squad List

var squad_panel: PanelContainer
var squad_container: VBoxContainer
var squad_list_container: VBoxContainer
var glossary_window: PanelContainer
var squad_frames: Array = []  # List of SquadMemberFrame

var options_panel: OptionsPanel
var squad_detail_panel: SquadDetailPanel

signal action_requested(action_name)
signal ability_requested(ability)
signal item_requested(item, slot_index)
signal end_turn_requested


func _setup_ui():
	# 0. ROOT CONTROL (Anchor Reference)
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through empty space
	
	# Apply Global Theme
	var g_theme = load("res://resources/GameTheme.tres")
	if g_theme:
		root.theme = g_theme
		
	add_child(root)

	# 1. TURN BANNER (FullScreen Overlay)
	turn_banner_overlay = ColorRect.new()
	turn_banner_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	turn_banner_overlay.color = Color(0, 0, 0, 0.0)
	turn_banner_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(turn_banner_overlay)

	turn_banner_label = Label.new()
	# Center Horizontally, start above top screen
	turn_banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	turn_banner_label.text = "MISSION START"
	turn_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_banner_label.add_theme_font_size_override("font_size", 64)
	turn_banner_label.add_theme_color_override("font_outline_color", Color.BLACK)
	turn_banner_label.add_theme_constant_override("outline_size", 10)
	turn_banner_label.modulate.a = 0.0
	turn_banner_overlay.add_child(turn_banner_label)

	# 1.5. SQUAD LIST (Left HUD)
	var squad_panel = PanelContainer.new()
	# Anchor Top Left (shifted down)
	squad_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	squad_panel.offset_left = 20
	squad_panel.offset_top = 100  # Leave room for header/terminal
	squad_panel.grow_horizontal = Control.GROW_DIRECTION_END
	# Make it transparent bg
	var sp_style = StyleBoxEmpty.new()
	squad_panel.add_theme_stylebox_override("panel", sp_style)
	root.add_child(squad_panel)

	squad_container = VBoxContainer.new()
	squad_container.add_theme_constant_override("separation", 10)
	squad_panel.add_child(squad_container)
	
	# NEW: Cycle Dog Button (Top of Squad List)
	var btn_cycle = Button.new()
	btn_cycle.text = "NEXT DOG [TAB]"
	btn_cycle.add_theme_color_override("font_color", Color.YELLOW)
	btn_cycle.custom_minimum_size.y = 40
	btn_cycle.focus_mode = Control.FOCUS_NONE # Prevent Tab hijacking
	btn_cycle.pressed.connect(func():
		var im = get_node_or_null("/root/InputManager")
		if im and im.has_signal("on_next_unit"):
			im.on_next_unit.emit()
	)
	squad_container.add_child(btn_cycle)

	
	var squad_header_btn = Button.new()
	squad_header_btn.text = "FULL SQUAD DETAILS"
	squad_header_btn.custom_minimum_size = Vector2(150, 30)
	squad_header_btn.focus_mode = Control.FOCUS_NONE
	squad_header_btn.pressed.connect(_on_squad_detail_pressed)

	# Status Glossary Button
	var glossary_btn = Button.new()
	glossary_btn.text = "?"
	glossary_btn.tooltip_text = "Status Glossary"
	glossary_btn.custom_minimum_size = Vector2(30, 30)
	glossary_btn.focus_mode = Control.FOCUS_NONE
	glossary_btn.pressed.connect(_on_glossary_pressed)
	
	# Container for Header + Glossary
	var header_hbox = HBoxContainer.new()
	header_hbox.add_child(squad_header_btn)
	header_hbox.add_child(glossary_btn)
	
	squad_container.add_child(header_hbox)

	# Dynamic List Container (So we don't clear the button)
	squad_list_container = VBoxContainer.new()
	squad_list_container.add_theme_constant_override("separation", 10)
	squad_container.add_child(squad_list_container)


	
	# Sync Signals
	if SignalBus:
		if SignalBus.has_signal("on_ui_select_unit"):
			if not SignalBus.on_ui_select_unit.is_connected(_on_external_unit_selection):
				SignalBus.on_ui_select_unit.connect(_on_external_unit_selection)
			
	# Init Overlay Logic
	_setup_overlay_elements()

	# 2. BOTTOM LAYOUT (Container for Button + Actions)
	var bottom_layout = VBoxContainer.new()
	bottom_layout.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_layout.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# bottom_layout.alignment = BoxContainer.ALIGNMENT_END # Push everything down
	bottom_layout.add_theme_constant_override("separation", 0) # Gap between button and panel
	root.add_child(bottom_layout)

	# 2A. END TURN BUTTON AREA (Row above panel)
	var end_turn_row = HBoxContainer.new()
	end_turn_row.alignment = BoxContainer.ALIGNMENT_END # Right Aligned
	# Add slight padding or margin right?
	var et_margin = MarginContainer.new()
	et_margin.add_theme_constant_override("margin_right", 20)
	et_margin.add_theme_constant_override("margin_bottom", 10) # Gap above panel
	end_turn_row.add_child(et_margin)
	
	# Create Button Early
	var end_turn_btn = Button.new()
	end_turn_btn.text = "END TURN"
	end_turn_btn.modulate = Color(1.0, 0.8, 0.2)  # Gold
	end_turn_btn.custom_minimum_size = Vector2(150, 60)
	end_turn_btn.focus_mode = Control.FOCUS_NONE
	end_turn_btn.pressed.connect(_on_end_turn_clicked)
	et_margin.add_child(end_turn_btn)
	bottom_layout.add_child(end_turn_row)

	# 2B. BOTTOM PANEL (Card + Actions)
	var bottom_panel = PanelContainer.new()
	# Size flags to fill width, but height based on content
	bottom_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom_layout.add_child(bottom_panel)

	var h_split = HBoxContainer.new()
	h_split.custom_minimum_size.y = 110 # Reduced from 140
	bottom_panel.add_child(h_split)

	# Unit Card (Left)
	unit_card_panel = PanelContainer.new()
	unit_card_panel.custom_minimum_size = Vector2(300, 110) # Reduced from 140
	h_split.add_child(unit_card_panel)

	var v_card = VBoxContainer.new()
	v_card.add_theme_constant_override("separation", 4) # Add breathing room
	unit_card_panel.add_child(v_card)
	
	# Name
	unit_name_label = Label.new()
	unit_name_label.text = "No Selection"
	
	# Initial Font Set
	unit_name_label.add_theme_font_size_override("font_size", current_font_size + 4)
	
	unit_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_card.add_child(unit_name_label)

	# Bars
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size.y = 18 # Reduced from 24
	hp_bar.show_percentage = false
	var hp_style_bg = StyleBoxFlat.new()
	hp_style_bg.bg_color = Color(0.2, 0.2, 0.2)
	var hp_style_fill = StyleBoxFlat.new()
	hp_style_fill.bg_color = Color(0.8, 0.2, 0.2)
	hp_bar.add_theme_stylebox_override("background", hp_style_bg)
	hp_bar.add_theme_stylebox_override("fill", hp_style_fill)
	v_card.add_child(hp_bar)

	hp_label = Label.new()
	hp_label.text = "HP 10/10"
	hp_label.add_theme_font_size_override("font_size", max(10, current_font_size - 2))
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_bar.add_child(hp_label)
	hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Compact Row: AP | Sanity
	var bars_row = HBoxContainer.new()
	bars_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars_row.add_theme_constant_override("separation", 8) # Gap between bars
	v_card.add_child(bars_row)

	ap_bar = ProgressBar.new()
	ap_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ap_bar.custom_minimum_size.y = 12 
	ap_bar.show_percentage = false
	var ap_style_fill = StyleBoxFlat.new()
	ap_style_fill.bg_color = Color(0.2, 0.6, 0.8)
	ap_bar.add_theme_stylebox_override("fill", ap_style_fill)
	bars_row.add_child(ap_bar)

	ap_label = Label.new()
	ap_label.text = "AP 2/2"
	ap_label.add_theme_font_size_override("font_size", max(10, current_font_size - 4))
	ap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ap_bar.add_child(ap_label)
	ap_label.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Sanity Bar (Purple)
	sanity_bar = ProgressBar.new()
	sanity_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sanity_bar.custom_minimum_size.y = 12 
	sanity_bar.show_percentage = false
	var san_style_fill = StyleBoxFlat.new()
	san_style_fill.bg_color = Color(0.6, 0.2, 0.8)  # Purple
	sanity_bar.add_theme_stylebox_override("fill", san_style_fill)
	bars_row.add_child(sanity_bar)

	sanity_label = Label.new()
	sanity_label.text = "SAN 100/100"
	sanity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sanity_label.add_theme_font_size_override("font_size", max(10, current_font_size - 4))
	sanity_bar.add_child(sanity_label)
	sanity_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	

	# Action Bar (Center)
	action_bar_container = HBoxContainer.new()
	action_bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_bar_container.alignment = BoxContainer.ALIGNMENT_CENTER
	h_split.add_child(action_bar_container)

	# 2C. DETAILS PANEL (Right) - Replaces Status Log
	# Structure: VBox -> [Weapon Slot | Status Icons] (Top Row), [Bonds] (Bottom Row)
	var details_panel = PanelContainer.new()
	details_panel.name = "DetailsPanel"
	details_panel.custom_minimum_size = Vector2(300, 110)
	details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_split.add_child(details_panel)
	
	var v_details = VBoxContainer.new()
	v_details.name = "DetailsVBox"
	v_details.add_theme_constant_override("separation", 8)
	details_panel.add_child(v_details)
	
	# Top Row: Weapon + Status
	var d_top_row = HBoxContainer.new()
	d_top_row.name = "TopRow"
	d_top_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v_details.add_child(d_top_row)
	
	# Weapon Slot Container (Will be populated in update)
	var weapon_cont = PanelContainer.new()
	weapon_cont.name = "WeaponContainer"
	weapon_cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_top_row.add_child(weapon_cont)
	
	# Status Container (Will be populated in update)
	var status_cont = HBoxContainer.new()
	status_cont.name = "StatusContainer"
	status_cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_top_row.add_child(status_cont)
	
	# Bottom Row: Bonds
	var bond_label_node = Label.new()
	bond_label_node.name = "BondLabel"
	bond_label_node.text = "" # Dynamic
	bond_label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bond_label_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v_details.add_child(bond_label_node)

	# 3. HIT CHANCE BREAKDOWN PANEL (SPIFFY REFACTOR)
	hit_chance_panel = PanelContainer.new()
	hit_chance_panel.visible = false
	hit_chance_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hit_chance_panel)

	hit_chance_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# hit_chance_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN # Not needed if position is manual
	hit_chance_panel.custom_minimum_size = Vector2(240, 0)
	# Offsets irrelevant if position set manually, but reset to 0 to be safe
	hit_chance_panel.offset_top = 0
	hit_chance_panel.offset_right = 0
	
	# Style for the panel
	var hc_style = StyleBoxFlat.new()
	hc_style.bg_color = Color(0.05, 0.05, 0.05, 0.9)
	hc_style.border_width_left = 2
	hc_style.border_width_top = 2
	hc_style.border_width_right = 2
	hc_style.border_width_bottom = 2
	hc_style.border_color = Color(0.3, 0.3, 0.3)
	hc_style.corner_radius_top_left = 4
	hc_style.corner_radius_top_right = 4
	hc_style.corner_radius_bottom_right = 4
	hc_style.corner_radius_bottom_left = 4
	hc_style.expand_margin_left = 5
	hc_style.expand_margin_right = 5
	hc_style.expand_margin_top = 5
	hc_style.expand_margin_bottom = 5
	hit_chance_panel.add_theme_stylebox_override("panel", hc_style)

	var v_main = VBoxContainer.new()
	v_main.add_theme_constant_override("separation", 5)
	hit_chance_panel.add_child(v_main)
	
	# -- HEADER (Always Visible) --
	var h_header = HBoxContainer.new()
	v_main.add_child(h_header)
	
	# Big Label "85%"
	hit_chance_label = Label.new()
	hit_chance_label.text = "0%"
	hit_chance_label.add_theme_font_size_override("font_size", 32)
	hit_chance_label.add_theme_constant_override("outline_size", 4)
	hit_chance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_header.add_child(hit_chance_label)
	
	# Toggle Button - REPLACED by ALT Key
	# var btn_details = Button.new()
	# ...
	
	# Help Label
	var help_lbl = Label.new()
	help_lbl.text = "[Hold ALT]"
	help_lbl.add_theme_font_size_override("font_size", 10)
	help_lbl.modulate = Color(1, 1, 1, 0.5)
	h_header.add_child(help_lbl)
	
	# -- DETAILS (Collapsible) --
	hit_chance_breakdown = VBoxContainer.new()
	hit_chance_breakdown.visible = false # Hidden default
	v_main.add_child(hit_chance_breakdown)
	
	# Button connection removed. Logic moved to _process.

	# 4. TOP RIGHT: OBJECTIVE PANEL & MENU
	var top_right_container = VBoxContainer.new()
	top_right_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_right_container.offset_top = 20
	top_right_container.offset_right = -20
	top_right_container.add_theme_constant_override("separation", 10)
	root.add_child(top_right_container)

	# HEADER ROW (Msg + Menu)
	var tr_header = HBoxContainer.new()
	tr_header.alignment = BoxContainer.ALIGNMENT_END
	top_right_container.add_child(tr_header)

	# Objective Panel
	objective_panel = PanelContainer.new()
	tr_header.add_child(objective_panel)
	var obj_margin = MarginContainer.new()
	obj_margin.add_theme_constant_override("margin_left", 10)
	obj_margin.add_theme_constant_override("margin_right", 10)
	objective_panel.add_child(obj_margin)
	
	objective_label = RichTextLabel.new()
	objective_label.text = "Obj: Unknown"
	objective_label.fit_content = true
	objective_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	# "EVEN BIGGER" visibility (User Request)
	objective_label.custom_minimum_size = Vector2(400, 0)
	objective_label.add_theme_font_size_override("normal_font_size", 36) # MASSIVE
	objective_label.add_theme_constant_override("outline_size", 6) # Bold outline
	objective_label.add_theme_color_override("font_outline_color", Color.BLACK)
	objective_label.modulate = Color.GOLD # "Eye catching" (User Request)
	obj_margin.add_child(objective_label)

	# Menu Button (Beside Objective)
	menu_button = Button.new()
	menu_button.text = "MENU"
	menu_button.custom_minimum_size = Vector2(80, 0)
	menu_button.focus_mode = Control.FOCUS_NONE
	tr_header.add_child(menu_button)
	menu_button.pressed.connect(toggle_pause_menu)

	# Shift Abort Button to be managed here or removed?
	# Existing ABORT BUTTON (Modified placement)

	# ABORT BUTTON (Moved to Container)
	var abort_btn = Button.new()
	abort_btn.text = "ABORT"
	abort_btn.modulate = Color(1, 0.4, 0.4)
	abort_btn.custom_minimum_size = Vector2(80, 0)
	abort_btn.focus_mode = Control.FOCUS_NONE
	# Align Right
	abort_btn.size_flags_horizontal = Control.SIZE_SHRINK_END 
	top_right_container.add_child(abort_btn)
	abort_btn.pressed.connect(func(): action_requested.emit("Abort"))
	
	# SETUP PAUSE MENU
	_setup_pause_menu(root)
	_setup_overlay_elements() # Call this last or merge? We just did overlay elements above.

	abort_btn.pressed.connect(func(): action_requested.emit("Abort"))
	# print("GameUI: Abort Button Created.")

	# END TURN BUTTON (Anchored to Top-Right of Bottom Panel)
	# end_turn_btn creation logic MOVED to Step 2A (Wrapped in layout)

	# MISSION END
	mission_end_panel = Panel.new()
	mission_end_panel.visible = false
	root.add_child(mission_end_panel)
	
	# Centering Logic (Robust)
	mission_end_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	mission_end_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mission_end_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	mission_end_panel.custom_minimum_size = Vector2(1200, 450)

	var end_center = VBoxContainer.new()
	end_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_center.alignment = BoxContainer.ALIGNMENT_CENTER
	mission_end_panel.add_child(end_center)

	var end_label = Label.new()
	end_label.name = "Title"
	end_label.text = "MISSION COMPLETE"
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 96)
	end_label.add_theme_constant_override("outline_size", 16)
	end_label.add_theme_color_override("font_outline_color", Color.BLACK)
	end_label.modulate = Color(1.0, 0.8, 0.2) # Gold
	end_center.add_child(end_label)

	var sub_label = Label.new()
	sub_label.name = "Sub"
	sub_label.text = "Press SPACE to Return"
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 48)
	sub_label.add_theme_constant_override("outline_size", 8)
	sub_label.add_theme_color_override("font_outline_color", Color.BLACK)
	end_center.add_child(sub_label)


var grid_manager
var current_font_size: int = 14


func initialize(tm, gm):
	turn_manager = tm
	grid_manager = gm
	# Old direct connection removed
	# turn_manager.turn_changed.connect(_on_turn_changed)


func _ready():
	# Connect SignalBus
	SignalBus.on_text_size_changed.connect(_on_text_size_changed)
	
	# Initial Font Sync
	if GameManager and "text_size" in GameManager.settings:
		current_font_size = GameManager.settings["text_size"]
	
	_setup_ui()
	_setup_panels()
	# Connect SignalBus
	SignalBus.on_unit_stats_changed.connect(_on_sb_unit_udpate)
	SignalBus.on_unit_health_changed.connect(_on_sb_health_update)
	SignalBus.on_turn_changed.connect(_on_sb_turn_changed)
	SignalBus.on_combat_log_event.connect(_on_sb_log_event)
	SignalBus.on_mission_ended.connect(_on_sb_mission_ended)
	SignalBus.on_ui_select_unit.connect(_on_sb_select_unit) # Added from instruction
	SignalBus.on_cinematic_mode_changed.connect(_on_cinematic_mode) # Kept from original

	# Decoupling Phase 74.3
	SignalBus.on_squad_list_initialized.connect(initialize_squad_list)
	SignalBus.on_objectives_updated.connect(update_objectives)
	SignalBus.on_request_pause.connect(toggle_pause_menu)


	SignalBus.on_show_hit_chance.connect(show_hit_chance)
	SignalBus.on_hide_hit_chance.connect(hide_hit_chance)
	SignalBus.on_turn_banner_finished.connect(func(): pass)
	SignalBus.on_request_floating_text.connect(_queue_floating_text)
	
	# Fix: Refresh UI after combat action (consumes AP/Cooldowns)
	SignalBus.on_combat_action_finished.connect(func(_user): 
		if is_instance_valid(selected_unit):
			_update_unit_card()
			_refresh_action_bar(selected_unit)
	)
	# SignalBus.on_cinematic_mode_changed.connect(_on_cinematic_mode) # Already connected above



func _on_cinematic_mode(active: bool):
	visible = !active
	if not active:
		hide_hit_chance()


func select_unit(unit):
	# No more local connection management needed for stats
	selected_unit = unit

	if selected_unit:
		_update_unit_card()
		_refresh_action_bar(selected_unit)
	else:
		unit_name_label.text = "No Unit Selected"
		hp_label.text = ""
		ap_label.text = ""
		hp_bar.value = 0
		ap_bar.value = 0
		sanity_bar.value = 0
		# Clear buttons
		for child in action_bar_container.get_children():
			child.queue_free()


func _on_sb_unit_udpate(unit):
	if unit == selected_unit:
		_update_unit_card()
		_refresh_action_bar(selected_unit)
	
	# Update Squad List
	if turn_manager and turn_manager.units:
		update_squad_overlay(turn_manager.units)


func _on_sb_health_update(unit, _old, _new):
	if unit == selected_unit:
		_update_unit_card()
	
	# Update Squad List
	if turn_manager and turn_manager.units:
		update_squad_overlay(turn_manager.units)


func _on_sb_turn_changed(phase_name: String, turn_number: int):
	# top_bar_label REMOVED, use animated banner
	_show_turn_banner(phase_name, turn_number)

	# Detect Player Turn Start to refresh ability cooldown visuals
	if "PLAYER" in phase_name:
		if selected_unit:
			_update_unit_card()
			_refresh_action_bar(selected_unit)


func _on_sb_log_event(text: String, color: Color = Color.WHITE):
	log_message(text)


func _on_sb_mission_ended(victory: bool, rewards: int):
	# SPECIAL CASE: Base Defense Victory
	var parent = get_parent()
	if parent and "is_base_defense" in parent and parent.is_base_defense:
		if victory:
			# Do not show standard victory screen, wait for scene switch
			return

	if victory:
		show_victory(rewards)
	else:
		show_defeat()


func _refresh_action_bar(unit):
	# Clear existing buttons
	for child in action_bar_container.get_children():
		child.queue_free()

	# Always add basic Move/Attack/Wait
	if unit and "faction" in unit and unit.faction == "Player":
		_create_action_button("Move\n(1 AP)", func(): emit_signal("action_requested", "Move"))
		_create_action_button("Attack\n(1 AP)", func(): emit_signal("action_requested", "Attack"))

		# Dynamic Abilities
		for ability in unit.abilities:
			if ability:
				# HACK: Context Check for Hack Ability
				if ability.display_name == "Hack":
					var valid_tiles = ability.get_valid_tiles(grid_manager, unit)
					if valid_tiles.size() == 0:
						continue  # Hide button if no valid targets

				var btn_text = ability.display_name
				if ability.ap_cost > 0:
					btn_text += "\n(" + str(ability.ap_cost) + " AP)"

				if "uses_charges" in ability and ability.uses_charges:
					btn_text += "\n(Ammo: " + str(ability.charges) + ")"

				var btn = _create_action_button(btn_text, func(): _on_ability_clicked(ability))

				if ability.current_cooldown > 0:
					btn.text += "\n(CD: %d)" % ability.current_cooldown
				
				if not ability.can_use():
					btn.disabled = true
					if "uses_charges" in ability and ability.uses_charges and ability.charges <= 0:
						btn.text += "\n(Empty)"

		# Context Action: Retrieve
		_check_retrieve_action(unit)

		# Inventory
		if "inventory" in unit:
			for i in range(unit.inventory.size()):
				var item = unit.inventory[i]
				if item:
					var btn_text = item.display_name + " (Item)\n(1 AP)"
					var btn = _create_action_button(btn_text, func(): _on_item_clicked(item, i))
					if unit.current_ap < 1:
						btn.disabled = true

		_create_action_button("Wait", func(): _on_wait_clicked())


func _check_retrieve_action(unit):
	# Check for "Treat Bag" or "Lost Human" adjacent
	var objs = get_tree().get_nodes_in_group("Objectives")
	for obj in objs:
		if is_instance_valid(obj) and (obj.name == "Treat Bag" or obj.name == "Lost Human"):
			var dist = unit.grid_pos.distance_to(obj.grid_pos)
			if dist <= 1.5:  # Adjacent or Diagonal
				# Use generic "Interact" label? Or specific?
				var label = "Retrieve"
				if obj.name == "Lost Human":
					label = "Rescue"
				_create_action_button(
					label + "\n(1 AP)", func(): emit_signal("action_requested", "Interact")
				)
				return


func on_ability_cancelled():
	log_message("Ability Cancelled.")
	# Maybe reset button states if they were highlighted?
	# Currently no visual state for "Selected Ability" on buttons other than disabled.
	pass


func _on_ability_clicked(ability: Ability):
	if selected_unit and selected_unit.faction == "Player":
		if selected_unit.is_moving:
			log_message("Unit is moving!")
			return

		if selected_unit.current_ap >= ability.ap_cost:
			emit_signal("ability_requested", ability)
		else:
			log_message("Not enough AP!")


func _on_item_clicked(item, slot_index):
	if selected_unit and selected_unit.faction == "Player":
		if selected_unit.is_moving:
			return
		if selected_unit.current_ap >= 1:
			emit_signal("item_requested", item, slot_index)
		else:
			log_message("Not enough AP!")


func update_unit_info(unit):
	selected_unit = unit
	_update_unit_card()
	_refresh_action_bar(unit)


func _update_unit_card():
	if not is_instance_valid(selected_unit):
		return

	unit_name_label.text = selected_unit.name
	
	# Class Icon Update
	var v_card = unit_card_panel.get_child(0)
	var icon_node = v_card.get_node_or_null("ClassIcon")
	if not icon_node:
		icon_node = TextureRect.new()
		icon_node.name = "ClassIcon"
		icon_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_node.custom_minimum_size = Vector2(32, 32) # Reduced from 48
		icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Insert at top
		v_card.add_child(icon_node)
		v_card.move_child(icon_node, 0)
		
	var cls = "Object"
	if "unit_class" in selected_unit:
		cls = selected_unit.unit_class
	elif "variant_type" in selected_unit: # DestructibleCover
		cls = selected_unit.variant_type
		
	# Check for Enemy Faction
	if "faction" in selected_unit and selected_unit.faction == "Enemy":
		# Maybe enemy class logic matches their name or type?
		# Assuming Enemy units have 'unit_class' or we derive from name?
		# Fallback to name if class missing
		if not "unit_class" in selected_unit:
			# Try to deduce from name or skip
			# Actually, Enemy classes (Rusher, Spitter) are usually their "unit_class" or "corgi_class" (now unit_class)
			pass
			
	# Determine Icon
	if selected_unit.is_in_group("Destructible"):
		# Use generic "Shield" or "Box" icon? or reuse valid class if mapped.
		# For now, maybe just "Recruit" default or specific if manager supports it.
		pass 
		
	icon_node.texture = ClassIconManager.get_class_icon(cls)

	# Update Bars
	hp_bar.max_value = selected_unit.max_hp
	hp_bar.value = selected_unit.current_hp
	hp_label.text = "HP: %d/%d" % [selected_unit.current_hp, selected_unit.max_hp]

	# AP Bar
	if "max_ap" in selected_unit and selected_unit.max_ap > 0:
		ap_bar.visible = true
		ap_bar.max_value = selected_unit.max_ap
		ap_bar.value = selected_unit.current_ap
		ap_label.text = "AP: %d/%d" % [selected_unit.current_ap, selected_unit.max_ap]
	else:
		ap_bar.visible = false

	if "max_sanity" in selected_unit and selected_unit.max_sanity > 0:
		sanity_bar.visible = true
		sanity_bar.max_value = selected_unit.max_sanity
		sanity_bar.value = selected_unit.current_sanity
		sanity_label.text = "SAN: %d/%d" % [selected_unit.current_sanity, selected_unit.max_sanity]
	else:
		sanity_bar.visible = false
	# --- RIGHT PANEL POPULATION ---
	
	# Find Details Panel Components
	# h_split is hard to find from here without reference.
	# We know structure: root -> bottom_layout -> bottom_panel -> h_split -> [unit_card, action_bar, details_panel]
	# But better to just find by name if we named them?
	# Or store reference in _setup_ui?
	# Let's assume we can get it via finding the node if we didn't store it.
	# BUT efficient way is to store "details_node" class var. 
	# Since I didn't add the class var in the first hunk, I must find it via path or store it now.
	# HACK: Iterate children of bottom_panel's split.
	
	var details_panel_node = null
	if unit_card_panel:
		var parent_split = unit_card_panel.get_parent()
		if parent_split:
			details_panel_node = parent_split.get_node_or_null("DetailsPanel")
	
	if not details_panel_node: return

	var v_details = details_panel_node.get_node("DetailsVBox")
	var d_top = v_details.get_node("TopRow")
	var d_status = d_top.get_node("StatusContainer")
	var d_weapon = d_top.get_node("WeaponContainer")
	var d_bond = v_details.get_node("BondLabel")

	# 1. STATUS ICONS
	for child in d_status.get_children():
		child.queue_free()

	if "active_effects" in selected_unit:
		for eff in selected_unit.active_effects:
			var rect = TextureRect.new()
			# Scale size with font? 
			var s_size = max(24, current_font_size + 10)
			rect.custom_minimum_size = Vector2(s_size, s_size)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			if "icon" in eff and eff.icon:
				rect.texture = eff.icon
			else:
				# Fallback
				var placeholder = GradientTexture2D.new()
				placeholder.width = s_size
				placeholder.height = s_size
				placeholder.fill = GradientTexture2D.FILL_SQUARE
				var grad = Gradient.new()
				if "type" in eff and eff.type == 1:
					grad.colors = [Color.RED, Color.DARK_RED]
				else:
					grad.colors = [Color.GREEN, Color.DARK_GREEN]
				placeholder.gradient = grad
				rect.texture = placeholder
			
			d_status.add_child(rect)

	# 2. WEAPON SLOT
	for child in d_weapon.get_children():
		child.queue_free()
		
	var slot_script = load("res://scripts/ui/UnitWeaponSlot.gd")
	if slot_script:
		var w_slot = slot_script.new()
		w_slot.read_only = true
		w_slot.custom_minimum_size = Vector2(100, 30) # Fixed-ish size?
		d_weapon.add_child(w_slot)
		w_slot.setup(selected_unit)

	# 3. BONDS
	var bond_text = ""
	if GameManager:
		if is_instance_valid(turn_manager) and "units" in turn_manager:
			for other in turn_manager.units:
				if (
					is_instance_valid(other)
					and other != selected_unit
					and "faction" in other
					and other.faction == "Player"
				):
					var lvl = GameManager.get_bond_level(selected_unit.name, other.name)
					if lvl > 0:
						var rank_char = "♥"
						if lvl == 2: rank_char = "♥♥"
						if lvl == 3: rank_char = "♥♥♥"
						
						var dist = selected_unit.grid_pos.distance_to(other.grid_pos)
						if dist <= 1.5:
							bond_text += "[ON] " + other.name + " " + rank_char + "\n"
						else:
							bond_text += other.name + " " + rank_char + "\n"
	
	d_bond.text = bond_text
	d_bond.add_theme_font_size_override("font_size", max(10, current_font_size - 4))


var active_banner_tween: Tween


func _show_turn_banner(phase: String, turn: int):
	if active_banner_tween:
		active_banner_tween.kill()

	turn_banner_label.text = "TURN %d\n%s" % [turn, phase]
	# Color Logic
	if "PLAYER" in phase:
		turn_banner_label.modulate = Color(0.2, 0.8, 1.0)  # Cyan
	elif "ENEMY" in phase:
		turn_banner_label.modulate = Color(1.0, 0.2, 0.2)  # Red
	else:
		turn_banner_label.modulate = Color(0.6, 1.0, 0.6)  # Greenish for Environ

	# Animation (Tween)
	active_banner_tween = create_tween()
	var tw = active_banner_tween
	tw.set_parallel(true)

	# Reset state first
	turn_banner_overlay.color.a = 0.0
	turn_banner_label.position.y = -100
	turn_banner_label.modulate.a = 0.0

	# Fade In Background
	tw.tween_property(turn_banner_overlay, "color:a", 0.5, 0.5)
	# Slide Text
	(
		tw
		. tween_property(turn_banner_label, "position:y", 300, 0.5)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tw.tween_property(turn_banner_label, "modulate:a", 1.0, 0.3)

	# Wait
	tw.chain().tween_interval(1.5)

	# Fade Out
	tw.chain().tween_property(turn_banner_overlay, "color:a", 0.0, 0.5)
	tw.parallel().tween_property(turn_banner_label, "modulate:a", 0.0, 0.5)

	# Signal Finished
	tw.chain().tween_callback(func(): SignalBus.on_turn_banner_finished.emit())


func _on_turn_changed(state):
	var state_name = "UNKNOWN"
	match state:
		0:
			state_name = "PLAYER PHASE"
		1:
			state_name = "ENEMY PHASE"
		2:
			state_name = "ENVIRONMENT PHASE"

	top_bar_label.text = "TURN %d: %s" % [turn_manager.turn_count, state_name]


func _create_action_button(text: String, callback: Callable):
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(100, 60)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(callback)
	# Audio Hook
	btn.pressed.connect(
		func():
			if GameManager and GameManager.audio_manager:
				GameManager.audio_manager.play_sfx("SFX_Menu")
	)
	action_bar_container.add_child(btn)
	return btn


func _on_wait_clicked():
	if selected_unit and is_instance_valid(selected_unit) and selected_unit.faction == "Player":
		if selected_unit.is_moving:
			log_message("Unit is moving!")
			return

		selected_unit.spend_ap(selected_unit.current_ap)  # End turn effectively
		log_message(selected_unit.name + " waits.")
		# Check Auto End
		if turn_manager and turn_manager.has_method("check_auto_end_turn"):
			turn_manager.check_auto_end_turn()


func _on_end_turn_clicked():
	log_message("Player requested End Turn.")
	emit_signal("action_requested", "EndTurn")


func log_message(msg: String):
	print("UI LOG: ", msg)  # Debug to console only
	# status_log_label removed per user request


func show_victory(rewards: int = 50):
	# Color: Gold/Cyan Mix
	_show_end_screen("MISSION SUCCESS", "Rewards: " + str(rewards) + " Kibble\nPress SPACE to Return", Color(1.0, 0.8, 0.2))


func show_defeat():
	_show_end_screen("MISSION FAILED", "Your squad has fallen.\nPress SPACE to Return", Color(1.0, 0.2, 0.2))


func _show_end_screen(title: String, subtitle: String, color: Color = Color.WHITE):
	if not mission_end_panel: return
	
	mission_end_panel.visible = true
	mission_end_panel.get_parent().move_child(mission_end_panel, -1)
	
	# Structure is Panel -> VBox -> Labels
	var container = mission_end_panel.get_child(0)
	var t_lbl = container.get_node("Title")
	t_lbl.text = title
	t_lbl.modulate = color
	
	container.get_node("Sub").text = subtitle



var hit_chance_target_pos: Vector3 = Vector3.ZERO
var hit_chance_active: bool = false

# Dictionary mapping Unit (or Object ID) -> { "queue": Array, "timer": float }
var active_text_queues: Dictionary = {}
const FLOATING_TEXT_DELAY: float = 0.5

func _process(delta):
	# Process All Queues
	var empty_keys = []
	
	for unit in active_text_queues.keys():
		var data = active_text_queues[unit]
		
		if data["queue"].size() > 0:
			data["timer"] -= delta
			if data["timer"] <= 0:
				var msg = data["queue"].pop_front()
				_spawn_floating_text_for_unit(unit, msg["pos"], msg["text"], msg["color"])
				data["timer"] = FLOATING_TEXT_DELAY
		
		# Cleanup empty queues to save memory
		if data["queue"].is_empty() and data["timer"] <= 0:
			empty_keys.append(unit)
			
	for k in empty_keys:
		active_text_queues.erase(k)

	# Update Floating UI Positions (Hit Chance)
	if hit_chance_active and hit_chance_panel.visible:
		var cam = get_viewport().get_camera_3d()
		if cam:
			var screen_pos = cam.unproject_position(hit_chance_target_pos)
			# Center the panel above the target
			hit_chance_panel.position = screen_pos - Vector2(hit_chance_panel.size.x / 2, hit_chance_panel.size.y + 20)

			
			
			
			# Check for ALT key to show details
			if hit_chance_breakdown:
				var details_open = Input.is_key_pressed(KEY_ALT)
				if hit_chance_breakdown.visible != details_open:
					hit_chance_breakdown.visible = details_open
					# Force shrink to minimum size when content changes
					hit_chance_panel.size.y = 0


func show_hit_chance(percent: int, breakdown: String, target_pos: Vector3 = Vector3.ZERO):
	hit_chance_active = true
	hit_chance_target_pos = target_pos
	
	hit_chance_panel.visible = true
	hit_chance_label.text = "HIT CHANCE: %d%%" % percent
	
	# Color Code Title
	if percent >= 80:
		hit_chance_label.modulate = Color.GREEN
	elif percent >= 50:
		hit_chance_label.modulate = Color.YELLOW
	else:
		hit_chance_label.modulate = Color.RED
		
	# Breakdown Parsing
	for child in hit_chance_breakdown.get_children():
		child.queue_free()
		
	var lines = breakdown.split("\n")
	for line in lines:
		if line.strip_edges() == "": continue
		var lbl = Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 14)
		if line.begins_with("Base"):
			lbl.modulate = Color.GRAY
		elif line.contains("+"):
			lbl.modulate = Color.GREEN
		elif line.contains("-"):
			lbl.modulate = Color.RED
		hit_chance_breakdown.add_child(lbl)

	# Force initial position update immediately so it doesn't flicker at old pos
	_process(0)


func hide_hit_chance():
	hit_chance_active = false
	if hit_chance_panel:
		hit_chance_panel.visible = false


# --- Phase 57: Squad Selection & Tab Cycling ---
func initialize_squad_list(units: Array):
	# print("GameUI: initialize_squad_list called with ", units.size(), " units.")
	# Clear existing
	for c in squad_container.get_children():
		c.queue_free()
	squad_frames.clear()

	var frame_script = load("res://scripts/ui/SquadMemberFrame.gd")
	if not frame_script:
		return

	for u in units:
		if "faction" in u and u.faction == "Player":
			var frame = frame_script.new()
			squad_container.add_child(frame)
			frame.initialize(u)
			frame.unit_selected.connect(_on_squad_frame_clicked)
			squad_frames.append(frame)
			# print("GameUI: Added frame for ", u.name)

	# print("GameUI: Total frames created: ", squad_frames.size())


func _on_squad_frame_clicked(unit):
	_select_unit(unit)


func _select_unit(unit):
	if selected_unit == unit:
		return

	selected_unit = unit
	update_unit_info(unit)

	# Highlight Frame
	for f in squad_frames:
		f.set_selected(f.unit_ref == unit)

	# Emit signal so Main knows to focus camera / update selection
	emit_signal("unit_selection_changed", unit)
	
	# Update Highlight Visuals
	_update_squad_highlights(unit)


func _update_squad_highlights(sel_unit):
	if squad_list_container:
		for child in squad_list_container.get_children():
			# Robust Access via Metadata
			if child.has_meta("frame_style"):
				var style = child.get_meta("frame_style")
				if child.has_meta("unit_ref") and child.get_meta("unit_ref") == sel_unit:
					# Selected
					style.border_width_left = 2
					style.border_width_top = 2
					style.border_width_right = 2
					style.border_width_bottom = 2
					style.border_color = Color.WHITE
				else:
					# Deselected
					style.border_width_left = 0
					style.border_width_top = 0
					style.border_width_right = 0
					style.border_width_bottom = 0


func _input(event):
	if event.is_action_pressed("ui_focus_next"):  # TAB
		_cycle_unit_selection()


func _cycle_unit_selection():
	if squad_frames.is_empty():
		return

	var current_idx = -1
	for i in range(squad_frames.size()):
		if squad_frames[i].unit_ref == selected_unit:
			current_idx = i
			break

	# Cycle
	for i in range(squad_frames.size()):
		current_idx = (current_idx + 1) % squad_frames.size()
		var n_unit = squad_frames[current_idx].unit_ref
		if n_unit.current_hp > 0:
			_select_unit(n_unit)
			return


signal unit_selection_changed(unit)




# ------------------------------------------------------------------------------
# COMBAT INFO OVERLAY & MENU
# ------------------------------------------------------------------------------

func _setup_overlay_elements():
	# Initial populate of empty squad
	update_squad_overlay([])
	pass


func update_objectives(text: String):
	if objective_label:
		objective_label.text = text


func update_squad_overlay(units: Array):
	if not squad_list_container:
		return
		
	# Check if rebuild needed (Size mismatch or force rebuild)
	# For simplicity, if units size matches children, just refresh. 
	# But units array might be different order or content.
	# Let's rebuild if count differs, otherwise update.
	if squad_list_container.get_child_count() != units.size():
		# Clear existing
		for child in squad_list_container.get_children():
			child.queue_free()
			
		# Populate
		for unit in units:
			if is_instance_valid(unit) and unit.get("faction") == "Player":
				_create_squad_frame(unit)
	else:
		# Just refresh values (Assumes order stable)
		_refresh_squad_overlay_stats()

func _refresh_squad_overlay_stats():
	if not squad_list_container: return
	
	for child in squad_list_container.get_children():
		if child.has_meta("unit_ref"):
			var unit = child.get_meta("unit_ref")
			if is_instance_valid(unit):
				# Find components by hierarchy structure in _create_squad_frame
				# Structure: Frame -> HBox -> VBox (index 2) -> HP (0), San (1), AP (2)
				var hbox = child.get_child(1) # [0] is Overlay Button usually? No, btn added to frame directly.
				# Let's check structure:
				# _create_squad_frame:
				# frame.add_child(hbox) -> Index 0? No, btn added later.
				# frame.add_child(btn).
				# So HBox is Index 0.
				
				# Safer Lookup
				var vbox = null
				if hbox is HBoxContainer:
					for c in hbox.get_children():
						if c is VBoxContainer:
							vbox = c
							break
				
				if vbox:
					# HP
					var hp = vbox.get_child(0)
					if hp is ProgressBar:
						hp.max_value = unit.max_hp
						hp.value = unit.current_hp
					
					# Sanity
					var san = vbox.get_child(1)
					if san is ProgressBar:
						san.max_value = unit.max_sanity
						san.value = unit.current_sanity
						
					# AP
					var ap = vbox.get_child(2)
					if ap is Label:
						ap.text = "AP: " + str(unit.current_ap) + "/" + str(unit.max_ap)



func _create_squad_frame(unit):
	# Mini Frame: [Name | HP | AP]
	# Or [Avatar] [VBox: Name, Bars]
	var frame = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	frame.add_theme_stylebox_override("panel", style)
	squad_list_container.add_child(frame)
	
	var hbox = HBoxContainer.new()
	frame.add_child(hbox)
	
	# Class Icon
	var icon_tex = ClassIconManager.get_class_icon(unit.unit_class if "unit_class" in unit else "Recruit")
	var icon_rect = TextureRect.new()
	icon_rect.texture = icon_tex
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon_rect)

	# Name (Portrait Placeholder)
	var name_lbl = Label.new()
	name_lbl.text = unit.unit_name.left(3).to_upper() # Abbrev
	name_lbl.custom_minimum_size.x = 40
	hbox.add_child(name_lbl)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	# HP Bar
	var hp = ProgressBar.new()
	hp.custom_minimum_size = Vector2(100, 10)
	hp.show_percentage = false
	var hp_bg = StyleBoxFlat.new(); hp_bg.bg_color = Color(0.2, 0.1, 0.1)
	var hp_fl = StyleBoxFlat.new(); hp_fl.bg_color = Color(0.8, 0.2, 0.2)
	hp.add_theme_stylebox_override("background", hp_bg)
	hp.add_theme_stylebox_override("fill", hp_fl)
	hp.max_value = unit.max_hp
	hp.value = unit.current_hp
	vbox.add_child(hp)
	
	# Sanity Bar (Mini)
	var san = ProgressBar.new()
	san.custom_minimum_size = Vector2(100, 6)
	san.show_percentage = false
	var san_fl = StyleBoxFlat.new(); san_fl.bg_color = Color(0.6, 0.2, 0.8) # Purple
	san.add_theme_stylebox_override("fill", san_fl)
	san.max_value = unit.max_sanity
	san.value = unit.current_sanity
	vbox.add_child(san)
	
	# AP Pips (Text)
	var ap_lbl = Label.new()
	ap_lbl.text = "AP: " + str(unit.current_ap) + "/" + str(unit.max_ap)
	ap_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(ap_lbl)

	# Click Overlay
	var btn = Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.focus_mode = Control.FOCUS_NONE
	frame.add_child(btn)
	btn.pressed.connect(func(): _select_unit(unit))
	
	# Meta Tag for Selection Tracking
	frame.set_meta("unit_ref", unit)
	frame.set_meta("frame_style", style) # Store Update Reference
	
	# Check initial selection state
	if selected_unit == unit:
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color.WHITE


func _on_external_unit_selection(unit):
	selected_unit = unit
	_update_squad_selection_visuals(unit)
	update_unit_info(unit)

func _update_squad_selection_visuals(active_unit):
	if not squad_list_container: return
	
	for child in squad_list_container.get_children():
		if child.has_meta("unit_ref") and child.has_meta("frame_style"):
			var u = child.get_meta("unit_ref")
			var style = child.get_meta("frame_style")
			
			if u == active_unit:
				style.border_width_left = 2
				style.border_width_top = 2
				style.border_width_right = 2
				style.border_width_bottom = 2
				style.border_color = Color.WHITE
			else:
				style.border_width_left = 0
				style.border_width_top = 0
				style.border_width_right = 0
				style.border_width_bottom = 0


# ------------------------------------------------------------------------------
# PAUSE MENU
# ------------------------------------------------------------------------------

var pause_mission_label: Label
var pause_squad_list: VBoxContainer

func _setup_pause_menu(root_node):
	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	root_node.add_child(pause_menu)
	
	# Dim Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	pause_menu.add_child(bg)
	
	# Main Container centered
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(center)
	
	var content = VBoxContainer.new()
	content.custom_minimum_size = Vector2(600, 400)
	center.add_child(content)
	
	# Title
	var title = Label.new()
	title.text = "MISSION PAUSED"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	
	# Tabs
	var tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tabs)
	
	# Tab 1: Mission
	var t_mission = VBoxContainer.new()
	t_mission.name = "Mission"
	tabs.add_child(t_mission)
	pause_mission_label = Label.new()
	pause_mission_label.text = "Current Objectives:"
	t_mission.add_child(pause_mission_label)
	
	
	
	# Tab 3: Field Manual (Help)
	var t_help = TabContainer.new()
	t_help.name = "Field Manual"
	tabs.add_child(t_help)
	
	for topic in FieldManual.TOPICS:
		var lbl = RichTextLabel.new()
		lbl.name = topic
		lbl.text = FieldManual.get_content(topic)
		lbl.bbcode_enabled = true
		lbl.add_theme_font_size_override("normal_font_size", 18)
		t_help.add_child(lbl)
	
	# Buttons (Resume / Quit)
	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 20)
	content.add_child(footer)
	
	var btn_resume = Button.new()
	btn_resume.text = "RESUME"
	btn_resume.custom_minimum_size = Vector2(150, 50)
	btn_resume.focus_mode = Control.FOCUS_NONE
	btn_resume.pressed.connect(toggle_pause_menu)
	footer.add_child(btn_resume)
	
	var btn_opts = Button.new()
	btn_opts.text = "OPTIONS"
	btn_opts.custom_minimum_size = Vector2(150, 50)
	btn_opts.focus_mode = Control.FOCUS_NONE
	btn_opts.pressed.connect(_on_options_pressed)
	footer.add_child(btn_opts)
	
	var btn_quit = Button.new()
	btn_quit.text = "ABORT MISSION"
	btn_quit.custom_minimum_size = Vector2(150, 50)
	btn_quit.modulate = Color(1, 0.4, 0.4)
	btn_quit.focus_mode = Control.FOCUS_NONE
	btn_quit.pressed.connect(func(): 
		toggle_pause_menu()
		action_requested.emit("Abort")
	)
	footer.add_child(btn_quit)


func toggle_pause_menu():
	if pause_menu:
		pause_menu.visible = !pause_menu.visible
		if pause_menu.visible:
			_refresh_pause_menu()


func _refresh_pause_menu():
	# Settings refresh?
	pass
	
	# Update Mission Objectives
	if pause_mission_label:
		var txt = "Current Objectives:\n"
		
		# Fetch from ObjectiveManager via Main -> ObjectiveManager (or singleton if available)
		# Assuming Main is root or we have reference? GameUI -> Main?
		# GameUI doesn't explicitly store Main, but it's a child.
		# Ideally ObjectiveManager should be a Global or passed in.
		# GameUI has 'grid_manager' and 'turn_manager' passed in init.
		# Let's try to get ObjectiveManager via group or parent.
		var objs = get_tree().get_nodes_in_group("ObjectiveManager")
		var om = null
		if objs.size() > 0:
			om = objs[0]
		
		# Fallback: Check parent (Main)
		if not om:
			var main = get_parent()
			if main and main.has_node("ObjectiveManager"):
				om = main.get_node("ObjectiveManager")
		
		if om:
			var txt_sum = om.get_objective_text()
			if txt_sum:
				txt += "- " + txt_sum
			else:
				txt += "[color=green]- Survive[/color]"
		else:
			txt += "Unknown"
			
		pause_mission_label.text = txt

# --- NEW PANELS ---
func _setup_panels():
	# Options Panel
	var opt_scene = load("res://scenes/ui/OptionsMenu.tscn")
	if opt_scene:
		options_panel = opt_scene.instantiate()
		add_child(options_panel)
		
	# Squad Detail Panel
	var sq_script = load("res://scripts/ui/SquadDetailPanel.gd")
	if sq_script:
		squad_detail_panel = sq_script.new()
		add_child(squad_detail_panel)

func _on_squad_detail_pressed():
	if squad_detail_panel:
		# Gather active squad
		var units = []
		if turn_manager and turn_manager.units:
			units = turn_manager.units.filter(func(u): return is_instance_valid(u) and u.get("faction") == "Player")
		squad_detail_panel.open(units)

func _on_options_pressed():
	if options_panel:
		options_panel.open()

func _queue_floating_text(target, text: String, color: Color):
	var unit_key = target
	var pos_snapshot = Vector3.ZERO
	
	if typeof(target) == TYPE_OBJECT and target is Node3D:
		pos_snapshot = target.global_position
	elif typeof(target) == TYPE_VECTOR3:
		unit_key = "Global" # Consolidate spatial text to single queue to prevent overlap clutter?
		pos_snapshot = target
	elif typeof(target) == TYPE_STRING:
		unit_key = "Global"
		
	if not unit_key: return

	if not active_text_queues.has(unit_key):
		active_text_queues[unit_key] = {"queue": [], "timer": 0.0}
		
	active_text_queues[unit_key]["queue"].append({"pos": pos_snapshot, "text": text, "color": color})

func _spawn_floating_text_for_unit(unit, fixed_pos: Vector3, text: String, color: Color):
	var cam = get_viewport().get_camera_3d()
	if not cam: return
	
	# Determine Position: Use Unit's current position if valid, else use fixed_pos (snapshot)
	var target_pos = fixed_pos
	if is_instance_valid(unit) and unit is Node3D:
		# Auto-offset applied here so emitters don't need to know about it
		target_pos = unit.global_position + GameManager.FLOATING_TEXT_OFFSET 
	elif typeof(unit) == TYPE_STRING and unit == "Global":
		target_pos = fixed_pos + GameManager.FLOATING_TEXT_OFFSET 
	else:
		# Fallback for null unit but valid pos (e.g. Acid Spit)
		target_pos = fixed_pos + GameManager.FLOATING_TEXT_OFFSET

	if cam.is_position_behind(target_pos): return

	var screen_pos = cam.unproject_position(target_pos)
	var lbl = Label.new()
	lbl.text = text
	lbl.modulate = color
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.position = screen_pos
	# Center it approx
	lbl.position -= Vector2(50, 20)
	
	add_child(lbl)
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", screen_pos.y - 100, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lbl.queue_free)



func _on_sb_select_unit(unit):
	update_unit_info(unit)


# --- STATUS GLOSSARY ---
func _on_glossary_pressed():
	if glossary_window:
		glossary_window.visible = not glossary_window.visible
		if glossary_window.visible:
			glossary_window.get_parent().move_child(glossary_window, -1) # Bring to front
		return
	_create_glossary_window()

func _create_glossary_window():
	glossary_window = PanelContainer.new()
	glossary_window.name = "GlossaryWindow"
	# Center Screen
	glossary_window.set_anchors_preset(Control.PRESET_CENTER)
	glossary_window.custom_minimum_size = Vector2(500, 600)
	glossary_window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	glossary_window.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Solid Background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_width_left = 2; style.border_width_top = 2
	style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.4)
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	glossary_window.add_theme_stylebox_override("panel", style)
	
	add_child(glossary_window)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_child(vbox)
	glossary_window.add_child(margin)
	
	# Header
	var header = HBoxContainer.new()
	var title = Label.new()
	title.text = "Status Effect Glossary"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func(): glossary_window.visible = false)
	header.add_child(close_btn)
	vbox.add_child(header)
	
	vbox.add_child(HSeparator.new())
	
	# Scroll List
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var list_vbox = VBoxContainer.new()
	scroll.add_child(list_vbox)
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Populate
	_populate_glossary_list(list_vbox, "res://scripts/resources/statuses")
	_populate_glossary_list(list_vbox, "res://scripts/resources/effects")
	
	if list_vbox.get_child_count() == 0:
		var empty = Label.new()
		empty.text = "No status effects found."
		list_vbox.add_child(empty)

func _populate_glossary_list(container, path):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".gd"):
				var full_path = path + "/" + file_name
				var script_res = load(full_path)
				if script_res:
					# Instantiate to check properties
					# Assuming resource/script has default values
					var inst = script_res.new()
					if "display_name" in inst:
						_add_glossary_row(container, inst)
					# inst is usually RefCounted, auto-freed if not held
			file_name = dir.get_next()

func _add_glossary_row(container, effect_inst):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)
	
	# Icon
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if "icon" in effect_inst and effect_inst.icon:
		icon_rect.texture = effect_inst.icon
	else:
		# Fallback Square
		var ph = GradientTexture2D.new()
		ph.width=48; ph.height=48
		ph.fill = GradientTexture2D.FILL_SQUARE
		var g = Gradient.new()
		if "type" in effect_inst and effect_inst.type == 1: # Debuff
			g.colors = [Color.RED, Color.DARK_RED]
		else:
			g.colors = [Color.GREEN, Color.DARK_GREEN]
		ph.gradient = g
		icon_rect.texture = ph
	
	row.add_child(icon_rect)
	
	# Text Info
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_lbl = Label.new()
	name_lbl.text = effect_inst.display_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	text_vbox.add_child(name_lbl)
	
	var desc_lbl = Label.new()
	var d_text = effect_inst.description if "description" in effect_inst else ""
	if d_text == "": d_text = "(No description)"
	desc_lbl.text = d_text
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.modulate = Color(0.8, 0.8, 0.8)
	text_vbox.add_child(desc_lbl)
	
	row.add_child(text_vbox)
	
	container.add_child(row)
	container.add_child(HSeparator.new())

func _on_text_size_changed(new_size: int):
	current_font_size = new_size
	_refresh_ui_fonts()

func _refresh_ui_fonts():
	# Update persistent labels
	if unit_name_label:
		unit_name_label.add_theme_font_size_override("font_size", current_font_size + 4)
	if hp_label:
		var hp_font_size = max(10, current_font_size - 2)
		hp_label.add_theme_font_size_override("font_size", hp_font_size)
		# Resize bar to fit text
		if hp_bar:
			hp_bar.custom_minimum_size.y = hp_font_size + 8

	if ap_label:
		var ap_font_size = max(10, current_font_size - 4)
		ap_label.add_theme_font_size_override("font_size", ap_font_size)
		if ap_bar:
			ap_bar.custom_minimum_size.y = ap_font_size + 6

	if sanity_label:
		var san_font_size = max(10, current_font_size - 4)
		sanity_label.add_theme_font_size_override("font_size", san_font_size)
		if sanity_bar:
			sanity_bar.custom_minimum_size.y = san_font_size + 6
	if hit_chance_label:
		hit_chance_label.add_theme_font_size_override("font_size", current_font_size + 14)
	
	# Reload dynamic content (Action Bar)
	if selected_unit:
		_refresh_action_bar(selected_unit)
		_update_unit_card() # Force refresh to redraw details panel sized items
