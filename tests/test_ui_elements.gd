extends Node
# tests/test_ui_elements.gd
var game_ui
func _ready():
	print("🧪 Test UI Elements")
	add_child(load("res://tests/TestSafeGuard.gd").new())
	game_ui = load("res://scripts/ui/GameUI.gd").new()
	add_child(game_ui)
	
	# Mock SignalBus if needed (usually autoload, but might need checking)
	# Assuming AutoLoad exists in test env.
	
	game_ui._setup_ui()
	
	if game_ui.squad_list_container:
		print("✅ PASS: Squad List Container exists.")
	else:
		print("❌ FAIL: Squad List Container is missing!")
		await TestUtils.finalize_and_quit(get_tree(), 1)
		return
		
	if game_ui.squad_list_container.get_parent():
		print("✅ PASS: Squad List Container is in tree.")
	else:
		print("❌ FAIL: Squad List Container orphaned.")
		await TestUtils.finalize_and_quit(get_tree(), 1)
		
	print("✅ PASS: All UI Elements Verified.")
	await TestUtils.finalize_and_quit(get_tree(), 0)
