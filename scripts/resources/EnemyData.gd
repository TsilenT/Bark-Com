extends Resource
class_name EnemyData

@export var display_name: String = "Enemy"
@export var archetype_name: String = "Generic"
@export var max_hp: int = 10
@export var mobility: int = 5
@export var armor: int = 0
@export var visual_color: Color = Color.RED

@export var action_points: int = 2
@export var primary_weapon: WeaponData

enum AIBehavior { 
	RUSHER, 
	SNIPER, 
	GENERIC, 
	AREA_DENIAL, 
	CONTROLLER, 
	EXPLODER, 
	TANK, 
	FLYING, 
	INFILTRATOR, 
	BOSS 
}
@export var ai_behavior: AIBehavior = AIBehavior.GENERIC


@export var min_skills: int = 0
@export var max_skills: int = 1

@export var abilities: Array[Script] = []  # List of Ability scripts to attach
