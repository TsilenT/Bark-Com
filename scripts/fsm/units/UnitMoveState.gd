extends "res://scripts/fsm/State.gd"

var path_points: Array = []
var grid_points: Array = []
var is_moving: bool = false
var active_tween: Tween

const LOG_PREFIX = "UnitMoveState: "

func enter(msg: Dictionary = {}):
	if not msg.has("world_path") or not msg.has("grid_path"):
		state_machine.transition_to("Idle")
		return

	path_points = msg["world_path"]
	grid_points = msg["grid_path"]

	# print(context.name, " [MoveState] Starting movement. Points: ", path_points.size())
	_start_movement()


func _start_movement():
	is_moving = true
	var unit = context
	
	# Prevent synchronous completion race:
	await unit.get_tree().process_frame

	if unit.visuals:
		unit.visuals.play_animation("Run")

	var current_path = path_points # Local Reference to protect against overwrite
	for i in range(current_path.size()):
		if not is_moving:
			# print(unit.name, " [MoveState] Movement interrupted!")
			break  # Interrupted

		# Check for Race Condition (Path Replaced)
		if path_points != current_path:
			GameManager.log(LOG_PREFIX, "DEBUG: Race detected. Stopping old loop. i=", i)
			break

		var point = current_path[i]
		var from_pos = unit.grid_pos

		# Update Grid Pos
		if grid_points.size() > 0 and i < grid_points.size():
			unit.grid_pos = grid_points[i]

		# Reaction Fire Check (Async)
		var tm = unit.get_tree().get_first_node_in_group("TurnManager")
		if tm:
			await tm.handle_reaction_fire(unit, from_pos)

		if unit.current_hp <= 0:
			is_moving = false
			state_machine.transition_to("Dead")
			return

		# Animate
		active_tween = unit.create_tween()
		active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		var world_target = point
		var vertical_move = abs(world_target.y - unit.position.y) > 0.1

		# Footstep Audio
		active_tween.tween_callback(
			func():
				if GameManager and GameManager.audio_manager:
					GameManager.audio_manager.play_sfx("SFX_Footstep")
		)

		if vertical_move:
			# Vertical Traverse (Ladder/Ramp) - Hop arc
			var mid_point = (unit.position + world_target) / 2.0
			mid_point.y = max(unit.position.y, world_target.y) + 1.5  # Arc Height

			active_tween.tween_property(unit, "position", mid_point, 0.15)
			active_tween.tween_property(unit, "position", world_target, 0.15)

			# Fix: Only look_at if we are moving horizontally. 
			# If pure vertical (Ladder), look_at(self) fails.
			var flat_pos = Vector3(unit.position.x, 0, unit.position.z)
			var flat_target = Vector3(world_target.x, 0, world_target.z)
			if flat_pos.distance_squared_to(flat_target) > 0.01:
				unit.look_at(Vector3(world_target.x, unit.position.y, world_target.z), Vector3.UP)

		else:
			# Standard Move
			# Rotate towards target
			var flat_pos = Vector3(unit.position.x, 0, unit.position.z)
			var flat_target = Vector3(world_target.x, 0, world_target.z)
			if flat_pos.distance_squared_to(flat_target) > 0.01:
				unit.look_at(Vector3(world_target.x, unit.position.y, world_target.z), Vector3.UP)


			# Move
			active_tween.tween_property(unit, "position", world_target, 0.25)
			
		# Wait for tween (BOTH paths must wait)
		if active_tween and active_tween.is_valid():
			await active_tween.finished
		active_tween = null
		
		# --- AUTO INTERACT (Smart Looting) ---
		# --- AUTO INTERACT (Smart Looting) ---
		var gm = unit.get_tree().get_first_node_in_group("GridManager")
		var om = unit.get_tree().get_first_node_in_group("ObjectiveManager")
		
		if gm and gm.has_method("get_items_at"):
			var items = gm.get_items_at(unit.grid_pos)
			# Duplicate list because interact might remove them
			for item in items.duplicate():
				if not is_instance_valid(item):
					continue
				GameManager.log(LOG_PREFIX, unit.name, " auto-interacting with ", item.name)
				
				# Delegate to ObjectiveManager if possible (Handles Mission Logic & Cleanup)
				if om and om.has_method("handle_interaction"):
					om.handle_interaction(unit, item)
				elif item.has_method("interact"):
					# Fallback for non-mission items
					item.interact(unit)
		# -------------------------------------

		SignalBus.on_unit_step_completed.emit(unit)

	is_moving = false
	# Done
	# print(unit.name, " [MoveState] Movement finished. Emitting signal.")
	unit.movement_finished.emit()
	state_machine.transition_to("Idle")


func exit():
	is_moving = false
	if active_tween:
		if active_tween.is_valid():
			active_tween.kill()
		active_tween = null
