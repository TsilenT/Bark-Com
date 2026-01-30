class_name MissionInitializer
extends RefCounted

const LOG_PREFIX = "MissionInit: "

## Main Entry Point for Mission Scene Setup
## Returns a Dictionary of critical references { "grid_manager": ..., "turn_manager": ... }
func setup(scene_root: Node3D, is_test_mode: bool) -> Dictionary:
	GameManager.log(LOG_PREFIX, "Beginning Mission Scene Setup...")
	
	var refs = {}

	# 1. GridManager
	var gm = GridManager.new()
	gm.name = "GridManager"
	scene_root.add_child(gm)
	refs["grid_manager"] = gm

	# 2. GridVisualizer (Visuals Only)
	var gv = null
	if not is_test_mode:
		gv = load("res://scripts/ui/GridVisualizer.gd").new()
		gv.name = "GridVisualizer"
		gv.grid_manager = gm
		scene_root.add_child(gv)
		refs["grid_visualizer"] = gv

	# 3. MissionManager
	var mm = MissionManager.new()
	mm.name = "MissionManager"
	scene_root.add_child(mm)
	refs["mission_manager"] = mm

	# 4. TurnManager (Find or Create)
	var tm = _find_or_create_turn_manager(scene_root)
	refs["turn_manager"] = tm

	# 5. VFXManager
	var vfxm = load("res://scripts/managers/VFXManager.gd").new()
	scene_root.add_child(vfxm)

	# 6. Camera & Cinematics
	if not is_test_mode:
		var cam = Camera3D.new()
		cam.set_script(load("res://scripts/core/CameraController.gd"))
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 18
		cam.current = true
		cam.position = Vector3(5.0, 10.0, 10.0)
		cam.rotation_degrees = Vector3(-45, -45, 0)
		scene_root.add_child(cam)
		refs["main_camera"] = cam

		var cam_script = load("res://scripts/systems/CinematicCamera.gd")
		if cam_script:
			var cam_controller = cam_script.new(cam)
			scene_root.add_child(cam_controller)

	# 7. GameUI
	# Needs TM and GM initialized first
	var gui_script = load("res://scripts/ui/GameUI.gd")
	if gui_script:
		var gui = gui_script.new()
		gui.name = "GameUI"
		scene_root.add_child(gui)
		gui.initialize(tm, gm)
		refs["game_ui"] = gui

	# 8. Selection Marker & Lighting
	if not is_test_mode:
		var marker = _create_marker()
		scene_root.add_child(marker)
		refs["selection_marker"] = marker

		var light = DirectionalLight3D.new()
		scene_root.add_child(light)
		light.position = Vector3(10, 20, 15)
		light.look_at(Vector3(10, 0, 10))
		light.shadow_enabled = true

	GameManager.log(LOG_PREFIX, "Setup Complete. Components Localized.")
	return refs

func _find_or_create_turn_manager(root: Node) -> Node:
	var turn_manager = null
	for child in root.get_children():
		if child.has_method("start_game") and child.has_method("register_unit"):
			turn_manager = child
			break
			
	if not turn_manager:
		turn_manager = root.get_node_or_null("TurnManager") 

	if not turn_manager:
		var tm_script = load("res://scripts/managers/TurnManager.gd")
		if tm_script:
			turn_manager = tm_script.new()
			turn_manager.name = "TurnManager"
			root.add_child(turn_manager)
	
	return turn_manager

func _create_marker() -> Node3D:
	var marker_mesh = MeshInstance3D.new()
	marker_mesh.mesh = SphereMesh.new()
	marker_mesh.mesh.radius = 0.22
	marker_mesh.mesh.height = 0.44
	
	var marker_mat = StandardMaterial3D.new()
	marker_mat.albedo_color = Color.CYAN
	marker_mat.emission_enabled = true
	marker_mat.emission = Color.CYAN
	marker_mat.emission_energy_multiplier = 2.0
	marker_mesh.material_override = marker_mat
	
	marker_mesh.set_script(load("res://scripts/ui/BouncingMarker.gd"))
	marker_mesh.visible = false
	return marker_mesh
