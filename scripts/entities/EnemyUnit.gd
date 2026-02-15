extends Unit
class_name EnemyUnit

signal action_complete
const AI_LOG = "EnemyAI: "

# const EnemyDataScript - Removed, using Global Class EnemyData directly


enum State { IDLE, CHASE, ATTACK }

const DEBUG_AI = false

var state = State.IDLE
var target_unit = null
var victim_log: Array[String] = []

# Data & config
var enemy_data: EnemyData
var attack_range: int = 4
var behavior_resource: Resource # AIBehaviorBase



func _ready():
	super._ready()
	faction = "Enemy"
	name = "Eldritch Beast"
	
	# Auto-detect class from script name (e.g. "SniperEnemy")
	if unit_class == "Recruit":
		# Defaults to script name, ensuring icons load correctly
		# e.g. "SniperEnemy.gd" -> "SniperEnemy" -> Icons recognize "Enemy" suffix
		var script_name = get_script().resource_path.get_file().get_basename()
		unit_class = script_name

	# Visuals: Red Cube (Only if no mesh exists from Scene)
	# Visuals: Procedural Horror
	if not has_node("ModelRoot") and not has_node("Mesh"):
		var Factory = preload("res://scripts/utils/EnemyModelFactory.gd")
		var model = Factory.create_model(self)
		add_child(model)

	# Debug Label
	var label = Label3D.new()
	label.name = "Label3D"
	label.text = "BEAST"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.8
	label.font_size = 32
	add_child(label)

	# Collider (For Mouse Interaction)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	col.shape = shape
	col.position.y = 0.5
	add_child(col)


func initialize_from_data(data: EnemyData):
	enemy_data = data
	enemy_data = data
	name = data.display_name
	
	# Set Class for Icons
	if data.archetype_name != "Generic":
		unit_class = data.archetype_name + "Enemy" # e.g. "SniperEnemy"
	else:
		unit_class = "EnemyRecruit" # Fallback

	# Apply Stats
	max_hp = data.max_hp
	current_hp = data.max_hp
	mobility = data.mobility
	
	# Apply Action Points
	max_ap = data.action_points
	current_ap = data.action_points

	if data.primary_weapon:
		primary_weapon = data.primary_weapon
		attack_range = primary_weapon.weapon_range
	else:
		attack_range = 4  # Default

	# Apply Visuals
	var old_root = get_node_or_null("ModelRoot")
	if old_root:
		old_root.queue_free()
		
	# Re-generate with correct data
	var Factory = preload("res://scripts/utils/EnemyModelFactory.gd")
	var model = Factory.create_model(self)
	add_child(model)


	var label = get_node_or_null("Label3D")
	if label:
		label.text = data.display_name.to_upper()
		label.modulate = data.visual_color

	# Apply Abilities
	for script_res in data.abilities:
		if script_res:
			# Prevent Duplicates
			var is_duplicate = false
			for existing in abilities:
				if existing.get_script() == script_res:
					is_duplicate = true
					break
			
			if not is_duplicate:
				abilities.append(script_res.new())

	# 3. Load AI Behavior
	_load_behavior(data.ai_behavior)

	if DEBUG_AI:
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.log(AI_LOG, "Initialized ", name, " with behavior ", data.ai_behavior)
		else:
			print(AI_LOG, "Initialized ", name, " with behavior ", data.ai_behavior)


func _load_behavior(type: int):
	match type:
		0: # RUSHER
			behavior_resource = load("res://scripts/ai/RusherBehavior.gd").new()
		1: # SNIPER
			behavior_resource = load("res://scripts/ai/SniperBehavior.gd").new()
		3: # AREA_DENIAL
			behavior_resource = load("res://scripts/ai/AreaDenialBehavior.gd").new()
		4: # CONTROLLER
			behavior_resource = load("res://scripts/ai/ControllerBehavior.gd").new()
		5: # EXPLODER
			behavior_resource = load("res://scripts/ai/ExploderBehavior.gd").new()
		6: # TANK
			behavior_resource = load("res://scripts/ai/TankBehavior.gd").new()
		7: # FLYING
			behavior_resource = load("res://scripts/ai/FlyingBehavior.gd").new()
		8: # INFILTRATOR
			behavior_resource = load("res://scripts/ai/InfiltratorBehavior.gd").new()
		9: # BOSS
			behavior_resource = load("res://scripts/ai/BossBehavior.gd").new()
		_: # GENERIC (2) and others default
			behavior_resource = load("res://scripts/ai/GenericBehavior.gd").new()

func check_los(tile: Vector2, target, gm: GridManager) -> bool:
	var my_eye = gm.get_world_position(tile) + Vector3(0, 1.5, 0)
	var target_center = target.position + Vector3(0, 1.0, 0)
	var space = get_viewport().world_3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(my_eye, target_center)
	# query.exclude = [self] # Self is excluded by default usually? Better safely exclude self RID.
	query.exclude = [self.get_rid()] 
	
	var result = space.intersect_ray(query)
	if result:
		if result.collider == target:
			return true
		return false # Blocked by something else
	return true # No hit? Usually means clear if ray goes to target, but physics ray stops at target.
	# If NO collision, it means ray didn't hit anything? Or infinite?
	# Using 'create(from, to)' : if it returns empty, it means no collision.
	# But we WANT to hit the target.
	# If we hit nothing, it means target is also not hit? 
	# Actually, intersect_ray hits the FIRST object.
	# If result is empty, we clearly didn't hit the target (unless target has no collision).
	# So result empty = Blocked? No, result empty = clear line to infinity? 
	# The 'to' point is target_center.
	# Standard Godot: If nothing sits between 'from' and 'to', it returns empty?
	# No, intersect_ray checks line segment. 
	# If it returns empty, it means the line segment is clear.
	# BUT we want to know if WE SEE THE TARGET.
	# If target has a collider, we should hit IT.
	# If we don't hit it, did we stop short? No.
	# If we hit nothing, it implies the ray reached 'to' without obstruction.
	# So actually, if result is empty, we DO have LOS?
	# But usually targets have colliders. We expect to hit them.
	# If we hit a wall first, result.collider != target.
	# If we hit target, result.collider == target.
	# If we hit nothing, it means target collider didn't catch the ray (maybe disabled?).
	# Let's assume hitting nothing means "Clear to point", so yes LOS.
	# But strictly, usually we check `if result and result.collider != target: return false`.
	return true



func _end_action():
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.log(AI_LOG, name, " _end_action() called. Emitting action_complete.")
	action_complete.emit()


# AI Logic
# AI Logic
func decide_action(_all_units: Array, grid_manager: GridManager):
	# ASYNC GUARD
	# await get_tree().process_frame
	
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.log(AI_LOG, name, " decide_action START. AP: ", current_ap)

	if DEBUG_AI:
		if gm:
			gm.log(AI_LOG, name, " starting turn. AP: ", current_ap)
	
	var actions_taken = 0
	const MAX_ACTIONS = 5 # Infinite loop guard
	
	while current_ap > 0 and actions_taken < MAX_ACTIONS:
		# 1. Acquire Target
		_acquire_target(_all_units, grid_manager)
		
		# If no target, Idle
		if not target_unit:
			state = State.IDLE
			if DEBUG_AI and gm: gm.log(AI_LOG, "- No valid targets. Spending AP to end turn.")
			spend_ap(current_ap) 
			break
			
		if DEBUG_AI and gm:
			gm.log(AI_LOG, "- Target: ", target_unit.name, " AP: ", current_ap)

		# 2. Evaluate Actions (Abilities vs Weapon)
		var best_action = null
		var best_score = -100.0
		
		# A. Check Abilities
		for abil in abilities:
			# Check basic availability
			if abil.current_cooldown <= 0 and abil.ap_cost <= current_ap:
				# Score it
				var score = abil.get_ai_score(self, target_unit, grid_manager)
				# Only consider positive scores as valid "conscious" choices
				if score > best_score and score > 0:
					best_score = score
					best_action = { "type": "ability", "ref": abil }

		# B. Check Weapon Attack
		if _can_attack_target(grid_pos, target_unit, grid_manager):
			var weapon_score = 15.0 # Base preference
			if primary_weapon:
				weapon_score += (primary_weapon.damage * 2.0)
			
			# If weapon score beats ability score, switch
			if weapon_score > best_score:
				best_score = weapon_score
				best_action = { "type": "attack" }
		


		# 3. Execute or Move
		if best_action:
			if gm: gm.log(AI_LOG, "Chose action: ", best_action.type, " Score: ", best_score)
			
			# REVEAL ON ACTION (Muzzle Flash)
			reveal_position()
			
			if best_action.type == "ability":
				var abil = best_action.ref
				# Spend AP
				spend_ap(abil.ap_cost)
				# Execute (Target Tile is usually target's position)
				abil.execute(self, target_unit, target_unit.grid_pos, grid_manager)
				# Visual Wait
				await get_tree().create_timer(1.0).timeout
				actions_taken += 1
				
				# Some abilities kill the user (Exploder)
				if not is_instance_valid(self) or is_queued_for_deletion():
					break

			elif best_action.type == "attack":
				await _perform_attack(target_unit, grid_manager)
				actions_taken += 1
		else:
			# No offensive action valid from here? MOVE.
			var did_move = await _perform_move(grid_manager, _all_units)
			if did_move:
				actions_taken += 1
				# Loop continues to see if we can attack/ability now
			else:
				# Stuck or no valid moves
				if DEBUG_AI and gm: gm.log(AI_LOG, "- No valid moves or decided to wait.")
				spend_ap(current_ap) # End turn
				break
	
	_end_action()


# --- FOG OF WAR LOGIC ---
var detection_range: int = 12 # Default Vision
var hearing_range: int = 5    # Wall-hack range (Footsteps)

func can_detect(target_u, gm: GridManager) -> bool:
	if not is_instance_valid(target_u):
		return false
		
	var dist = grid_pos.distance_to(target_u.grid_pos)
	
	# 1. Hearing Check (Proximity ignores walls)
	if dist <= hearing_range:
		return true
		
	# 2. Vision Check (Raycast)
	if dist <= detection_range:
		# Check Line of Sight
		# We use the unit's own check_los helper if available, or raycast manually
		if has_method("check_los"):
			return check_los(grid_pos, target_u, gm)
		else:
			# Fallback Raycast (Similar to VisionManager)
			var space = get_world_3d().direct_space_state
			var from = position + Vector3(0, 1.5, 0)
			var to = target_u.position + Vector3(0, 1.0, 0) # Target Chest/Head
			var query = PhysicsRayQueryParameters3D.create(from, to)
			query.exclude = [self]
			var result = space.intersect_ray(query)
			if result:
				# If we hit the target or something very close
				if result.collider == target_u:
					return true
				if result.position.distance_to(to) < 1.5:
					return true
	
	return false

func reveal_position():
	# Muzzle Flash Mechanic: Force visibility if attacking
	if not visible:
		visible = true
		set_visual_mode("NORMAL")
		GameManager.log(AI_LOG, name, " REVEALED by Action!")
		SignalBus.on_request_floating_text.emit(self, "REVEALED!", Color.RED)


func _acquire_target(units: Array, gm: GridManager):
	# Smart Target Acquisition: Only target what we can detect!
	target_unit = null
	var best_score = -9999.0
	var candidates = []
	
	for u in units:
		if is_instance_valid(u) and u.faction == "Player" and u.current_hp > 0:
			# Ignore specific units logic (Treat Bag)
			if u.name == "Treat Bag" or u.name == "Lost Human":
				continue
				
			# FOG OF WAR CHECK
			if not can_detect(u, gm):
				# Cannot see/hear this player. Ignore.
				continue

			var score = 0.0
			# Distance prioritization (Closer is usually better/threat)
			var dist = grid_pos.distance_to(u.grid_pos)
			score -= dist
			
			# Low HP Priority
			if u.current_hp <= 4:
				score += 5.0
				
			if score > best_score:
				best_score = score
				candidates = [u]
			elif score == best_score:
				candidates.append(u)
				
	if candidates.size() > 0:
		target_unit = candidates.pick_random()
	else:
		# No targets detected.
		# Ideally: Stay IDLE or Patrol.
		pass


func _perform_move(gm: GridManager, all_units: Array) -> bool:
	if not behavior_resource:
		if enemy_data:
			_load_behavior(enemy_data.ai_behavior)
		else:
			_load_behavior(2) # GENERIC
	
	# 1. Get Reachable Tiles
	# Unit.mobility is range.
	var tiles = gm.get_reachable_tiles(grid_pos, mobility)
	
	var best_tile = grid_pos
	var best_score = -9999.0
	var debug_scores = {}
	
	for tile in tiles:
		# Check occupancy manually if GridManager doesn't filter perfectly
		if tile != grid_pos:
			# Check Unit Occupancy
			var occupied = false
			for u in all_units:
				if not is_instance_valid(u): continue
				if u.grid_pos == tile and u != self and u.current_hp > 0:
					occupied = true; break
			if occupied: continue
			
		var score = behavior_resource.evaluate_position(self, tile, target_unit, gm)
		debug_scores[tile] = score
		
		if score > best_score:
			best_score = score
			best_tile = tile
			
	# Send Debug overlay
	var debugger = get_node_or_null("/root/AIDebugger")
	if debugger:
		debugger.emit_debug_overlay(self, debug_scores)
		debugger.log_decision(name, "Move Calculation", best_score, {"target": target_unit.name, "best_tile": best_tile})
	
	if best_tile != grid_pos:
		# Execute Move
		var path = gm.get_move_path(grid_pos, best_tile)
		if path.size() > 0:
			var world_path: Array[Vector3] = []
			var grid_subset: Array[Vector2] = []
			for i in range(1, path.size()):
				world_path.append(gm.get_world_position(path[i]))
				grid_subset.append(path[i])
				
			move_along_path(world_path, grid_subset)
			
			# Calculate Cost
			var cost = gm.calculate_path_cost(path)
			spend_ap(1) # Moving costs 1 AP usually in this system (or scaled?)
			# For now, 1 Move Action = 1 AP.
			
			await movement_finished
			return true
	
	return false


func _perform_attack(target, gm: GridManager):
	if spend_ap(1):
		# CombatResolver handles hit/miss logic
		CombatResolver.execute_attack(self, target, gm)
		
		# Wait for visual
		await get_tree().create_timer(1.0).timeout


func _can_attack_target(from_pos: Vector2, target, gm: GridManager) -> bool:
	# 1. Range Check
	var dist = from_pos.distance_to(target.grid_pos)
	if dist > attack_range:
		return false
		
	# 2. LOS Check
	if not check_los(from_pos, target, gm):
		return false
		
	return true
