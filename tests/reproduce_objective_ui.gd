extends Node

func _ready():
    # Wait for Autoloads? Usually ready is fine.
    
    add_child(load("res://tests/TestSafeGuard.gd").new())
    
    var om_script = load("res://scripts/managers/ObjectiveManager.gd")
    var om = om_script.new()
    add_child(om) # Add to tree so it can access tree/groups
    
    print("--- REPRODUCING OBJECTIVE UI TEXT ---")
    
    # CASE 1: DEFENSE
    print("\n--- CASE 1: DEFENSE (Limit 5) ---")
    # initialize(mission_type, turn_manager, count_override)
    # Defense = 4 (MissionType.DEFENSE)
    om.initialize(4, null, 0)
    om.turn_limit = 5
    
    # Simulation
    # Turn 0 (Start)
    om.check_status([], 0)
    print("Turn 0: ", om.get_objective_text())
    
    # Turn 1
    om.check_status([], 1)
    print("Turn 1: ", om.get_objective_text())
    
    # Turn 4
    om.check_status([], 4)
    print("Turn 4: ", om.get_objective_text())
    
    # Turn 5
    om.check_status([], 5)
    print("Turn 5: ", om.get_objective_text())


    # CASE 2: RESCUE
    print("\n--- CASE 2: RESCUE (Secure Loop) ---")
    # Rescue = 1
    om.initialize(1, null, 0)
    om.rescue_secured = true
    om.rescue_win_turn = 5 # Win if current_turn >= 5
    
    # If I secure on Turn 2.
    # Turn 2
    om.check_status([], 2)
    print("Turn 2: ", om.get_objective_text())
    
    # Turn 3
    om.check_status([], 3)
    print("Turn 3: ", om.get_objective_text())
    
    # Turn 4
    om.check_status([], 4)
    print("Turn 4: ", om.get_objective_text())
    
    # Turn 5
    om.check_status([], 5)
    print("Turn 5: ", om.get_objective_text())

    get_tree().quit()

