extends Node3D

var pivot: Node3D
var camera_pivot: Node3D
var current_anim_player: AnimationPlayer
var auto_rotate: bool = false
var rotate_speed: float = 0.5

# UI References
var ui_mode_select: OptionButton
var ui_class_select: OptionButton
var ui_anim_select: OptionButton
var ui_enemy_select: OptionButton
var container_corgi: Control
var container_enemy: Control

const MODE_CORGI = 0
const MODE_ENEMY = 1

const CORGI_CLASSES = ["Recruit", "Scout", "Heavy", "Paramedic", "Sniper", "Grenadier"]
const ENEMY_TYPES = {
	"Rusher": 0,
	"Sniper": 1,
	"Area Denial": 3,
	"Controller": 4, 
	"Exploder": 5,
	"Tank": 6,
	"Flying": 7,
	"Infiltrator": 8,
	"Boss": 9
}

func _ready():
	_setup_scene()
	_setup_ui()
	_on_mode_changed(MODE_CORGI)

func _setup_scene():
	pivot = Node3D.new()
	pivot.name = "ModelPivot"
	add_child(pivot)
	
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	add_child(camera_pivot)
	
	var cam = Camera3D.new()
	cam.look_at_from_position(Vector3(0, 0.8, 2.5), Vector3(0, 0.5, 0))
	camera_pivot.add_child(cam)
	
	var light = DirectionalLight3D.new()
	light.look_at_from_position(Vector3(2, 5, 4), Vector3.ZERO)
	light.shadow_enabled = true
	add_child(light)
	
	var env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.15, 0.15, 0.15)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.3, 0.3)
	env.environment = environment
	add_child(env)

func _setup_ui():
	var canvas = CanvasLayer.new()
	canvas.name = "CanvasLayer"
	add_child(canvas)
	
	var panel = PanelContainer.new()
	panel.position = Vector2(20, 20)
	canvas.add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Model Visualizer"
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())
	
	# Mode Selector
	var hb_mode = HBoxContainer.new()
	vbox.add_child(hb_mode)
	hb_mode.add_child(_create_label("Mode:"))
	
	ui_mode_select = OptionButton.new()
	ui_mode_select.add_item("Corgi (Player)", MODE_CORGI)
	ui_mode_select.add_item("Enemy (AI)", MODE_ENEMY)
	ui_mode_select.item_selected.connect(_on_mode_changed)
	hb_mode.add_child(ui_mode_select)
	
	vbox.add_child(HSeparator.new())
	
	# --- CORGI CONTROLS ---
	container_corgi = VBoxContainer.new()
	vbox.add_child(container_corgi)
	
	container_corgi.add_child(_create_label("Class:"))
	ui_class_select = OptionButton.new()
	for c in CORGI_CLASSES:
		ui_class_select.add_item(c)
	ui_class_select.item_selected.connect(_on_corgi_class_changed)
	container_corgi.add_child(ui_class_select)
	
	container_corgi.add_child(_create_label("Animation:"))
	ui_anim_select = OptionButton.new()
	ui_anim_select.item_selected.connect(_on_anim_changed)
	container_corgi.add_child(ui_anim_select)
	
	# --- ENEMY CONTROLS ---
	container_enemy = VBoxContainer.new()
	vbox.add_child(container_enemy)
	
	container_enemy.add_child(_create_label("Enemy Type:"))
	ui_enemy_select = OptionButton.new()
	for k in ENEMY_TYPES.keys():
		ui_enemy_select.add_item(k)
	ui_enemy_select.item_selected.connect(_on_enemy_type_changed)
	container_enemy.add_child(ui_enemy_select)

	vbox.add_child(HSeparator.new())
	
	var chk_rot = CheckButton.new()
	chk_rot.text = "Auto Rotate"
	chk_rot.toggled.connect(func(t): auto_rotate = t)
	vbox.add_child(chk_rot)
	
	var instr = Label.new()
	instr.text = "Right Click + Drag to Rotate Camera"
	instr.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(instr)

# --- LOGIC ---

func _on_mode_changed(idx):
	var mode = ui_mode_select.get_selected_id()
	container_corgi.visible = (mode == MODE_CORGI)
	container_enemy.visible = (mode == MODE_ENEMY)
	
	if mode == MODE_CORGI:
		_on_corgi_class_changed(ui_class_select.selected)
	else:
		_on_enemy_type_changed(ui_enemy_select.selected)

func _on_corgi_class_changed(idx):
	if idx < 0: return
	var cls = CORGI_CLASSES[idx]
	_spawn_corgi(cls)

func _on_enemy_type_changed(idx):
	if idx < 0: return
	var type_name = ui_enemy_select.get_item_text(idx)
	var type_id = ENEMY_TYPES[type_name]
	_spawn_enemy(type_id)

func _spawn_corgi(cls_name: String):
	_clear_model()
	var Factory = load("res://scripts/utils/CorgiModelFactory.gd")
	var data = Factory.generate_corgi(cls_name, pivot)
	current_anim_player = data["anim_player"]

func _spawn_enemy(type_id: int):
	_clear_model()
	
	# Mock Unit & Data
	var mock_unit = Node.new()
	var mock_data = Node.new() # Using Node as generic object to hold props
	mock_data.set_script(load("res://scripts/resources/EnemyData.gd")) # Use actual script if possible or just mock props
	
	# Actually, EnemyModelFactory expects 'unit.enemy_data.ai_behavior'
	# Creating a real EnemyData resource is safer and lightweight
	var data = load("res://scripts/resources/EnemyData.gd").new()
	data.ai_behavior = type_id
	data.visual_color = Color.RED # Default, factory overrides based on ID mostly
	
	# Mock Unit needs 'enemy_data' property
	var unit = load("res://scripts/entities/EnemyUnit.gd").new()
	unit.enemy_data = data
	
	var Factory = load("res://scripts/utils/EnemyModelFactory.gd")
	var model = Factory.create_model(unit)
	pivot.add_child(model)
	
	# Cleanup mocks
	unit.free() 

func _clear_model():
	for c in pivot.get_children():
		c.free() # immediate free to clear
	current_anim_player = null
	ui_anim_select.clear()

func _update_anim_list():
	ui_anim_select.clear()
	if current_anim_player:
		# ... (kept same)
		var list = current_anim_player.get_animation_list()
		for a in list:
			ui_anim_select.add_item(a)
		var idx = list.find("Idle")
		if idx != -1:
			ui_anim_select.select(idx)
			current_anim_player.play("Idle")

func _on_anim_changed(idx):
	if current_anim_player and idx != -1:
		var anim = ui_anim_select.get_item_text(idx)
		current_anim_player.play(anim)

func _process(delta):
	if auto_rotate and pivot:
		pivot.rotate_y(rotate_speed * delta)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			camera_pivot.rotate_y(-event.relative.x * 0.005)

func _create_label(t: String) -> Label:
	var l = Label.new()
	l.text = t
	return l

# Replace usages in _setup_ui with _create_label(text)
