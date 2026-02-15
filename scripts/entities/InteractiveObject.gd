extends Node3D
class_name InteractiveObject

var grid_pos: Vector2
var grid_manager: Node


func initialize(pos: Vector2, gm: Node, _arg3 = null, _arg4 = null):
	grid_pos = pos
	grid_manager = gm
	if gm.has_method("get_world_position"):
		position = gm.get_world_position(pos)


func interact(_unit):
	print("Interacted with generic object.")


func take_damage_from(_amount: int, _source = null, _dmg_type: String = GameManager.DMG_TYPE_GENERIC):
	pass
