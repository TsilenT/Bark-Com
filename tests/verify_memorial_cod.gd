extends SceneTree

const LOG_PREFIX = "VerifyMemorialCOD: "

var signal_bus = null

func _init():
	print(LOG_PREFIX, "Starting Memorial COD Verification with Permutations...")
	# Defer run to ensure tree is ready
	var timer = create_timer(0.1)
	timer.timeout.connect(_run_test)

func _run_test():
	var root = get_root()
	
	# -1. Add TestSafeGuard (Prevent Hangs)
	var safeguard = load("res://tests/TestSafeGuard.gd").new()
	safeguard.name = "TestSafeGuard"
	safeguard.timeout = 20.0 # 20s timeout
	root.add_child(safeguard)
	
	# 0. Setup SignalBus
	if not root.has_node("SignalBus"):
		var sb_script = load("res://scripts/managers/SignalBus.gd")
		signal_bus = sb_script.new()
		signal_bus.name = "SignalBus"
		root.add_child(signal_bus)
	else:
		signal_bus = root.get_node("SignalBus")
	
	# 1. Setup GameManager 
	if not root.has_node("GameManager"):
		var gm_script = load("res://scripts/core/GameManager.gd")
		var gm = gm_script.new()
		gm.name = "GameManager"
		root.add_child(gm)
		gm.fallen_heroes = [] 
		gm.missions_completed = 5 
	
	var gm = root.get_node("GameManager")
	gm.fallen_heroes.clear()
	
	# 2. Setup MissionManager Mock
	var mission_manager_mock = Node.new()
	mission_manager_mock.set_script(load("res://scripts/managers/MissionManager.gd"))
	mission_manager_mock.name = "MissionManagerMock"
	root.add_child(mission_manager_mock)
	_allocated_nodes.append(mission_manager_mock)
	if not signal_bus.on_unit_died.is_connected(mission_manager_mock._on_unit_died):
		signal_bus.on_unit_died.connect(mission_manager_mock._on_unit_died)
		
	# 3. Setup Test Units
	var unit_script = load("res://scripts/entities/Unit.gd")
	var wpn_script = load("res://scripts/resources/WeaponData.gd")
	
	# --- Scenario A: Enemy Kill (Claws) ---
	var victim_a = _create_unit("Victim A", "Scout")
	var enemy = _create_unit("Mean Rusher", "Rusher", "Enemy")
	# Give Enemy Claws
	var claws = wpn_script.new()
	claws.display_name = "Claws"
	enemy.primary_weapon = claws
	
	print(LOG_PREFIX, "--- Scenario A: Enemy Kill ---")
	if victim_a.has_method("take_damage_from"):
		# Simulate CombatResolver mapping: Claws -> Melee
		victim_a.take_damage_from(100, enemy, gm.DMG_TYPE_MELEE) 
	else:
		victim_a.take_damage(100) # Baseline
	await _wait_for_death()
	
	
	# --- Scenario B: Friendly Fire (Grenade) ---
	var victim_b = _create_unit("Victim B", "Heavy")
	var friend = _create_unit("Boomer", "Grenadier", "Player")
	
	print(LOG_PREFIX, "--- Scenario B: Friendly Fire ---")
	if victim_b.has_method("take_damage_from"):
		# Simulate CombatResolver mapping: Grenade -> Explosion
		victim_b.take_damage_from(100, friend, gm.DMG_TYPE_EXPLOSION)
	else:
		victim_b.take_damage(100)
	await _wait_for_death()

	# --- Scenario C: Barrel Explosion ---
	var victim_c = _create_unit("Victim C", "Sniper")
	# Mock Barrel (Can just pass a Node with a name)
	var barrel = Node.new()
	barrel.name = "Explosive Barrel"
	_allocated_nodes.append(barrel)
	
	print(LOG_PREFIX, "--- Scenario C: Barrel ---")
	if victim_c.has_method("take_damage_from"):
		victim_c.take_damage_from(100, barrel, gm.DMG_TYPE_EXPLOSION)
	else:
		victim_c.take_damage(100)
	await _wait_for_death()

	# --- Scenario D: Poison ---
	var victim_d = _create_unit("Victim D", "Paramedic")
	
	print(LOG_PREFIX, "--- Scenario D: Poison ---")
	if victim_d.has_method("take_damage_from"):
		victim_d.take_damage_from(100, null, gm.DMG_TYPE_POISON)
	else:
		victim_d.take_damage(100)
	await _wait_for_death()

	
	# 4. Verify Results
	var heroes = gm.fallen_heroes
	print(LOG_PREFIX, "Total Heroes in Memorial: ", heroes.size())
	
	if heroes.size() < 4:
		print(LOG_PREFIX, "FAILURE: Not all heroes registered.")
	else:
		_check_hero(heroes[0], "Mauled by Mean Rusher")
		_check_hero(heroes[1], "Blown up by Boomer") 
		_check_hero(heroes[2], "Blown up by Explosive Barrel")
		_check_hero(heroes[3], "Succumbed to Poison")

	print(LOG_PREFIX, "Test Teardown")
	_cleanup()
	quit()

var _allocated_nodes = []

func _create_unit(u_name, u_class, faction="Player"):
	var u = load("res://scripts/entities/Unit.gd").new()
	u.name = u_name
	u.unit_class = u_class
	u.faction = faction
	u.max_hp = 10
	u.current_hp = 10
	get_root().add_child(u)
	_allocated_nodes.append(u)
	return u

func _cleanup():
	# 1. Free Logic Nodes (Units, Mocks)
	for n in _allocated_nodes:
		if is_instance_valid(n):
			# Use free() to ensure they are gone before LeakDetector runs
			# Check if they are in tree?
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()
			
	_allocated_nodes.clear() # Prevent double free if called twice

	# 2. Free Managers (Reverse Order of creation usually)
	var mm_mock = get_root().get_node_or_null("MissionManagerMock")
	if is_instance_valid(mm_mock):
		if mm_mock.get_parent(): mm_mock.get_parent().remove_child(mm_mock)
		mm_mock.free()

	# GameManager
	var gm = get_root().get_node_or_null("GameManager")
	if is_instance_valid(gm):
		if gm.get_parent(): gm.get_parent().remove_child(gm)
		gm.free()

	# SignalBus
	if is_instance_valid(signal_bus): 
		if signal_bus.get_parent(): signal_bus.get_parent().remove_child(signal_bus)
		signal_bus.free()
	
	# 3. Trigger SafeGuard Check/Exit
	var sg = get_root().get_node_or_null("TestSafeGuard")
	if sg: 
		# If we free/queue_free SG, it runs check.
		# Since we freed everything else, it should be clean.
		sg.queue_free()

func _wait_for_death():
	await create_timer(1.6).timeout

func _check_hero(entry, expected_substr):
	if expected_substr in entry["cause"]:
		print(LOG_PREFIX, "SUCCESS: ", entry["name"], " -> ", entry["cause"])
	else:
		print(LOG_PREFIX, "WARNING: ", entry["name"], " -> Expected '", expected_substr, "', got '", entry["cause"], "'")

