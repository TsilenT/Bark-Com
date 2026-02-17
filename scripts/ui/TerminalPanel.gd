extends PanelContainer
class_name TerminalPanel

var output_label: RichTextLabel
var input_field: LineEdit

func _ready():
	_setup_ui()

func _setup_ui():
	# Visuals: Make it look like an overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Background Styling (Opaque Dark)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.05, 0.95)
	add_theme_stylebox_override("panel", sb)
	
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# --- CLICK CATCHER (Transparent background to catch missed clicks) ---
	var catcher = Control.new()
	catcher.name = "ClickCatcher"
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(ev): 
		if ev is InputEventMouseButton and ev.pressed:
			input_field.grab_focus()
	)
	add_child(catcher)
	
	# Content Container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.gui_input.connect(func(ev): 
		if ev is InputEventMouseButton and ev.pressed:
			input_field.grab_focus()
	)
	
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.gui_input.connect(func(ev): 
		if ev is InputEventMouseButton and ev.pressed:
			input_field.grab_focus()
	)
	margin.add_child(vbox)
	
	# Output Log
	output_label = RichTextLabel.new()
	output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_label.scroll_following = true
	output_label.bbcode_enabled = true
	output_label.text = "[color=green]Welcome to B.A.R.K. Command Terminal v0.2.2[/color]\n[color=yellow]Press ~ (Tilde) to Toggle this Window[/color]\nType 'help' for commands.\n"
	
	# Ensure it catches clicks to focus input
	output_label.mouse_filter = Control.MOUSE_FILTER_PASS 
	output_label.gui_input.connect(_on_output_gui_input)
	vbox.add_child(output_label)
	
	vbox.add_child(HSeparator.new())
	
	# Input Line
	input_field = LineEdit.new()
	input_field.placeholder_text = "Enter command... (~ to close)"
	
	# MANUAL INPUT HANDLING TO BYPASS DEFAULT SUBMIT BEHAVIOR
	input_field.gui_input.connect(_on_input_field_gui_input)
	
	vbox.add_child(input_field)
	
	# Panel Self Input (Backup)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_panel_gui_input)

func _on_panel_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		input_field.grab_focus()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_QUOTELEFT:
		visible = !visible
		if visible:
			input_field.grab_focus()
		get_viewport().set_input_as_handled()

func _on_output_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		input_field.grab_focus()

func _on_input_field_gui_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		# Consume the event so LineEdit doesn't "submit" and drop focus
		get_viewport().set_input_as_handled()
		
		var text = input_field.text
		if text.strip_edges() != "":
			println("> " + text, Color.GRAY)
			_process_command(text.to_lower().strip_edges())
		
		input_field.clear()
		# We never lost focus, so we don't need to grab it back.
		# But just in case:
		input_field.grab_focus()

func println(msg: String, color: Color = Color.WHITE):
	var color_hex = color.to_html()
	output_label.text += "[color=#" + color_hex + "]" + msg + "[/color]\n"

func _process_command(cmd_str: String):
	var parts = cmd_str.split(" ", false)
	var cmd = parts[0]
	var args = parts.slice(1)
	
	match cmd:
		"help":
			println("Commands (Press ~ to Toggle):", Color.YELLOW)
			println(" - help: Show this list")
			# Context-sensitive help?
			if GameManager.current_state == GameManager.GameState.BASE:
				println(" [BASE] recruit, kibble, mission, start <id>")
			elif GameManager.current_state == GameManager.GameState.MISSION:
				println(" [MISSION] spawn <Type> [x] [y], suicide, extract")
			
		"recruit":
			if _require_context(GameManager.GameState.BASE):
				var target_class = ""
				if args.size() > 0:
					target_class = args[0]
				
				if GameManager.recruit_new_dog(GameManager.RECRUIT_COST, target_class):
					if target_class != "":
						println("Recruitment successful! (Class: " + target_class + ")", Color.GREEN)
					else:
						println("Recruitment successful!", Color.GREEN)
				else:
					println("Not enough Kibble (Need 50).", Color.RED)
		"kibble":
			# Available always?
			if GameManager:
				println("Kibble: " + str(GameManager.kibble), Color.GOLD)
		"clear":
			output_label.text = ""
		"mission":
			if _require_context(GameManager.GameState.BASE):
				var m_list = GameManager.get_available_missions()
				println("Daily Missions:", Color.CYAN)
				for i in range(m_list.size()):
					println(str(i) + ": " + m_list[i].mission_name + " (Lv " + str(m_list[i].difficulty_rating) + ")")
		"start":
			if _require_context(GameManager.GameState.BASE):
				if args.size() > 0:
					var idx = int(args[0])
					if GameManager and idx >= 0 and idx < GameManager.get_available_missions().size():
						println("Launching Mission...", Color.GREEN)
						SignalBus.on_mission_selected.emit(GameManager.get_available_missions()[idx])
					else:
						println("Invalid Mission ID.", Color.RED)
				else:
					println("Usage: start <id>", Color.RED)
		"suicide":
			if _require_context(GameManager.GameState.MISSION):
				# Need access to Selected Unit?
				# TerminalPanel doesn't easily know about Main.selected_unit unless we query Main or SignalBus.
				# SignalBus? "on_kill_selected_unit"?
				println("Command acknowledged. Goodbye cruel world.", Color.RED)
				# We can emit a signal that proper game systems listen to.
				# Or just print for now as a stub.
				# Actually user might want it to work.
				# Let's say "Feature not enabled in v0.2.2"
				println("Error: Neural Link offline (Not implemented).", Color.DARK_GRAY)
				
		# --- HIDDEN COMMANDS ---
		"normal":
			if GameManager:
				GameManager.settings["mascot_style"] = 0
				GameManager.save_game()
				println("Mascot Protocol: Standard Regulations.", Color.LIGHT_SLATE_GRAY)
				SignalBus.on_skin_changed.emit()
		"busty":
			if GameManager:
				GameManager.settings["mascot_style"] = 1
				GameManager.save_game()
				println("Mascot Protocol: Morale Boost Initiated.", Color.PINK)
				SignalBus.on_skin_changed.emit()
		"bustier":
			if GameManager:
				GameManager.settings["mascot_style"] = 2
				GameManager.save_game()
				println("Mascot Protocol: MAXIMUM OVERDRIVE.", Color.MAGENTA)
				SignalBus.on_skin_changed.emit()
		"bustiest":
			if GameManager:
				GameManager.settings["mascot_style"] = 3
				GameManager.save_game()
				println("Mascot Protocol: CRITICAL MASS REACHED.", Color.VIOLET)
				SignalBus.on_skin_changed.emit()
		"rich":
			if GameManager:
				GameManager.kibble += 1000000
				SignalBus.on_kibble_changed.emit(GameManager.kibble)
				println("Infinite wealth granted. Don't spend it all in one place.", Color.GOLD)
		"xp":
			if GameManager:
				var amount = 100
				if args.size() > 0:
					amount = int(args[0])
				
				if amount > 2000:
					amount = 2000
					println("Warning: XP amount capped at 2000.", Color.ORANGE)
				
				var count = 0
				var unit_script = load("res://scripts/entities/Unit.gd")
				
				for i in range(GameManager.roster.size()):
					var member_data = GameManager.roster[i]
					
					# 1. Instantiate temp unit to calculate scaling correctly
					var temp_unit = unit_script.new()
					temp_unit.restore_from_snapshot(member_data)
					
					var old_level = temp_unit.rank_level
					var old_max_hp = temp_unit.max_hp
					var old_current_hp = temp_unit.current_hp
					var damage_taken = max(0, old_max_hp - old_current_hp)
					
					# 2. Add XP
					var current_xp = temp_unit.current_xp + amount
					temp_unit.current_xp = min(current_xp, 9999)
					
					# 3. Recalculate Level (Simple Thresholds)
					var new_level = old_level
					if temp_unit.current_xp >= 1000: new_level = 5
					elif temp_unit.current_xp >= 600: new_level = 4
					elif temp_unit.current_xp >= 300: new_level = 3
					elif temp_unit.current_xp >= 100: new_level = 2
					
					# 4. Apply Changes
					if new_level > old_level:
						temp_unit.rank_level = new_level
						temp_unit.recalculate_stats() # Updates Max HP
						
						# Apply Damage Preservation Logic
						temp_unit.current_hp = max(1, temp_unit.max_hp - damage_taken)
						
						println(temp_unit.unit_name + " leveled up to " + str(new_level) + "! (HP: " + str(temp_unit.current_hp) + "/" + str(temp_unit.max_hp) + ")", Color.CYAN)
						
						# Save back to Roster
						GameManager.roster[i] = temp_unit.get_data_snapshot()
						count += 1
					else:
						# Just save XP
						GameManager.roster[i]["xp"] = temp_unit.current_xp
						
					temp_unit.queue_free()
					
				GameManager.save_game()
				SignalBus.on_skin_changed.emit() # Force UI Refresh
				println("Gave " + str(amount) + " XP to " + str(GameManager.roster.size()) + " units.", Color.GREEN)
		"all_enemies":
			if _require_context(GameManager.GameState.MISSION):
				var mm = get_tree().root.find_child("MissionManager", true, false)
				if mm:
					println("Spawning ALL enemy types for visual inspection...", Color.ORANGE)
					var types = ["Rusher", "Sniper", "Spitter", "Exploder", "Flying", "Tank", "Infiltrator", "Whisperer", "Boss"]
					for t in types:
						if mm.has_method("_spawn_enemy"):
							mm._spawn_enemy(t)
							println("Spawned " + t, Color.GRAY)
				else:
					println("Error: MissionManager not found active.", Color.RED)
		"spawn":
			if _require_context(GameManager.GameState.MISSION):
				if args.size() < 1:
					println("Usage: spawn <EnemyType> [x] [y]", Color.RED)
					return
					
				var type = args[0]
				var mm = get_tree().root.find_child("MissionManager", true, false)
				if not mm:
					println("Error: MissionManager not found.", Color.RED)
					return
					
				# Capitalize first letter strictly? Or lookup safely.
				# Just pass raw and let MissionManager handle or fail.
				
				if args.size() >= 3:
					# Spawn at Coords
					var x = int(args[1])
					var y = int(args[2])
					var pos = Vector2(x, y)
					
					# We need to manually invoke spawn logic with pos
					# MissionManager._spawn_enemy does random pos.
					# But wait, MissionManager has _spawn_enemy(type).
					# I should check if I can modify MissionManager or do manual spawn here.
					# MissionManager._spawn_enemy logic is: instantiate, find pos, setup.
					# I can verify if MM has a "spawn_at" method? No.
					# I will implement `spawn_enemy_at` in MissionManager or hack it.
					# Hack: Call mm._spawn_enemy, then move it? No, initialization runs on spawn.
					
					# Better: Use UnitSpawner directly?
					# UnitSpawner is used by MM.
					# Let's try calling UnitSpawner directly.
					# var spawner = load("res://scripts/builders/UnitSpawner.gd").new()
					# But MM handles tracking `spawned_units`.
					
					if mm.has_method("spawn_enemy_at"):
						var result = mm.spawn_enemy_at(type, pos)
						if result:
							println("Spawned " + type + " at " + str(pos), Color.GREEN)
						else:
							println("Error: Spawn failed (Invalid Type or Position?).", Color.RED)
					else:
						println("Error: MissionManager missing spawn_enemy_at (Update Pending).", Color.RED)
						
				else:
					# Spawn NEAR PLAYER (Default for Debug)
					if mm.has_method("spawn_enemy_near_player"):
						var result = mm.spawn_enemy_near_player(type)
						if result:
							println("Spawned " + type + " near player.", Color.GREEN)
						else:
							println("Error: valid spot not found near player. (Result=NULL, Type='" + type + "')", Color.RED)
							println("Check console logs for 'MissionManager' errors.", Color.ORANGE)
					elif mm.has_method("_spawn_enemy"):
						mm._spawn_enemy(type) # Fallback to random
						println("Spawned " + type + " at random location.", Color.GREEN)
					else:
						println("Error: Cannot spawn.", Color.RED)
		"doomsday":
			if _require_context(GameManager.GameState.BASE):
				GameManager.debug_fill_invasion_meter()
				GameManager.advance_doomsday_clock(0) # Trigger logic
				println("DOOMSDAY CLOCK SET TO MIDNIGHT. INVASION IMMINENT.", Color.RED)
		_:
			println("Unknown command: " + cmd, Color.RED)

func _require_context(required_state) -> bool:
	if not GameManager: return false
	if GameManager.current_state == required_state:
		return true
	
	var state_name = "UNKNOWN"
	match required_state:
		GameManager.GameState.BASE: state_name = "BASE"
		GameManager.GameState.MISSION: state_name = "MISSION"
	
	println("Command available only in " + state_name + " mode.", Color.ORANGE)
	return false
