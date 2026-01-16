extends Node

const LOG_PREFIX = "TestClassIcons: "

func _ready():
	print(LOG_PREFIX, "Starting Class Icon Tests...")
	var success = true
	
	success = success and test_basics()
	success = success and test_enemy_distinction()
	success = success and test_boss_logic()
	
	if success:
		print(LOG_PREFIX, "ALL ICON TESTS PASSED")
		get_tree().quit(0)
	else:
		print(LOG_PREFIX, "ICON TESTS FAILED")
		get_tree().quit(1)

func test_basics() -> bool:
	print(LOG_PREFIX, "Testing Basics...")
	
	# Recruit
	var recruit = ClassIconManager.get_class_icon("Recruit")
	if not recruit:
		print(" - FAIL: Recruit icon missing.")
		return false
	if not "recruit" in recruit.resource_path:
		print(" - FAIL: Recruit path incorrect: ", recruit.resource_path)
		return false
		
	# Scout
	var scout = ClassIconManager.get_class_icon("Scout")
	if not scout:
		print(" - FAIL: Scout icon missing.")
		return false
	if not "scout" in scout.resource_path:
		print(" - FAIL: Scout path incorrect: ", scout.resource_path)
		return false
		
	return true

func test_enemy_distinction() -> bool:
	print(LOG_PREFIX, "Testing Enemy Distinction...")
	
	# Sniper (Player) vs SniperEnemy
	var p_sniper = ClassIconManager.get_class_icon("Sniper")
	var e_sniper = ClassIconManager.get_class_icon("SniperEnemy")
	
	if not p_sniper or not e_sniper:
		print(" - FAIL: Missing Sniper icons.")
		return false
		
	if "enemy" in p_sniper.resource_path:
		print(" - FAIL: Player Sniper using Enemy icon.")
		return false
		
	if not "enemy" in e_sniper.resource_path:
		print(" - FAIL: Enemy Sniper using Player icon.")
		return false
		
	# Tank (Player Heavy) vs TankEnemy
	# "TankEnemy" should map to class_tank_enemy.svg
	var e_tank = ClassIconManager.get_class_icon("TankEnemy")
	
	if not e_tank:
		print(" - FAIL: TankEnemy icon missing.")
		return false
	if not "enemy" in e_tank.resource_path:
		print(" - FAIL: TankEnemy path incorrect: ", e_tank.resource_path)
		return false
		
	return true

func test_boss_logic() -> bool:
	print(LOG_PREFIX, "Testing Boss Logic...")
	
	var boss = ClassIconManager.get_class_icon("Dogthulhu")
	if not boss:
		print(" - FAIL: Boss icon missing.")
		return false
	if not "boss" in boss.resource_path:
		print(" - FAIL: Boss did not map to class_boss.svg. Got: ", boss.resource_path)
		return false
		
	return true
