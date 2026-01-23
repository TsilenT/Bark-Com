extends PanelContainer
class_name OptionsPanel

@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var text_size_slider: HSlider = %TextSizeSlider
@onready var text_size_value_label: Label = %TextSizeValue
@onready var fs_check: CheckBox = %FullscreenCheck
@onready var close_btn: Button = %CloseButton

func _ready():
	visible = false
	_connect_signals()
	
	# Initial Text Size Setup
	var current_theme = ThemeDB.get_project_theme()
	var scene = get_tree().current_scene
	if scene and "theme" in scene and scene.theme:
		current_theme = scene.theme
	
	text_size_slider.value = 18 
	if current_theme:
		text_size_slider.value = current_theme.default_font_size
		
	# Dynamic Injection of Debug Checkbox to avoid TSCN edit risk
	call_deferred("_inject_debug_checkbox")

func _inject_debug_checkbox():
	if not fs_check: return
	
	var container = fs_check.get_parent()
	if container:
		var debug_check = CheckBox.new()
		debug_check.text = "Enable Debug Logging"
		debug_check.name = "DebugLogCheck"
		debug_check.tooltip_text = "Toggle verbose logging to console (for troubleshooting)."
		
		# Insert after Fullscreen check if possible
		container.add_child(debug_check) 
		container.move_child(debug_check, fs_check.get_index() + 1)
		
		# Init State
		if GameManager:
			debug_check.set_pressed_no_signal(GameManager.settings.get("debug_logging", false))
			
		# Connect
		debug_check.toggled.connect(func(toggled):
			if GameManager:
				GameManager.settings["debug_logging"] = toggled
				# Debug Log the change itself (meta!)
				if toggled: print("[LOG] Debug Logging Enabled.")
		)
		
		# --- TACTICAL VIEW TOGGLE ---
		var tac_check = CheckBox.new()
		tac_check.text = "Tactical View Toggle"
		tac_check.tooltip_text = "If checked, ALT toggles Tactical View ON/OFF. If unchecked, hold ALT to view."
		container.add_child(tac_check)
		container.move_child(tac_check, debug_check.get_index() + 1)
		
		if GameManager:
			tac_check.set_pressed_no_signal(GameManager.settings.get("tactical_view_toggle", false))
			
		tac_check.toggled.connect(func(toggled):
			if GameManager:
				GameManager.settings["tactical_view_toggle"] = toggled
		)

func _connect_signals():
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	fs_check.toggled.connect(_on_fullscreen_toggled)
	text_size_slider.value_changed.connect(_on_text_size_changed)
	close_btn.pressed.connect(func(): visible = false)

func _on_music_volume_changed(val: float):
	if GameManager:
		GameManager.settings["music_vol"] = val
		GameManager._apply_audio_settings()

func _on_sfx_volume_changed(val: float):
	if GameManager:
		GameManager.settings["sfx_vol"] = val
		GameManager._apply_audio_settings()

func _on_fullscreen_toggled(toggled_on: bool):
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
	if GameManager:
		GameManager.settings["fullscreen"] = toggled_on
		# We might want to save immediately, or wait for auto-save.
		# Since display settings are important, forcing a save or relying on System->Save is choice.
		# Let's verify if 'Close' or 'System' trigger save.
		# System->Save does.
		# We'll just update the runtime dictionary for now.
		pass

func _on_text_size_changed(val: float):
	if text_size_value_label:
		text_size_value_label.text = "(" + str(int(val)) + ")"
	
	var theme_node = self
	var theme_res : Theme = null
	
	var p = get_parent()
	while p:
		if "theme" in p and p.theme:
			theme_res = p.theme
			break
		p = p.get_parent()
	
	if not theme_res:
		theme_res = load("res://resources/GameTheme.tres")
		
	if theme_res:
		var s = int(val)
		theme_res.default_font_size = s
		theme_res.set_font_size("font_size", "Label", s)
		theme_res.set_font_size("font_size", "Button", s)
		theme_res.set_font_size("normal_font_size", "RichTextLabel", s)
		theme_res.set_font_size("bold_font_size", "RichTextLabel", s)
		theme_res.set_font_size("italics_font_size", "RichTextLabel", s)
		theme_res.set_font_size("mono_font_size", "RichTextLabel", s)
		theme_res.set_font_size("font_size", "ProgressBar", max(10, s - 4))
		
		if GameManager:
			GameManager.settings["text_size"] = s
			if SignalBus:
				SignalBus.on_text_size_changed.emit(s)

func open():
	# Refresh values on open
	if GameManager:
		music_slider.value = GameManager.settings.get("music_vol", 0.5)
		sfx_slider.value = GameManager.settings.get("sfx_vol", 0.5)
		if "text_size" in GameManager.settings:
			text_size_slider.value = GameManager.settings["text_size"]
			if text_size_value_label:
				text_size_value_label.text = "(" + str(GameManager.settings["text_size"]) + ")"
			
	# Refresh Fullscreen Checkbox
	if fs_check:
		var is_fs = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		fs_check.set_pressed_no_signal(is_fs)
		
	visible = true
