extends Resource
class_name EnemyData

@export var display_name: String = "Enemy"
# CONSTANTS
const ARCHETYPE_GENERIC = "Generic"
const ARCHETYPE_RUSHER = "Rusher"
const ARCHETYPE_SNIPER = "Sniper"
const ARCHETYPE_SPITTER = "Spitter"
const ARCHETYPE_WHISPERER = "Whisperer"
const ARCHETYPE_EXPLODER = "Exploder"
const ARCHETYPE_TANK = "Tank"
const ARCHETYPE_FLYING = "Flying"
const ARCHETYPE_INFILTRATOR = "Infiltrator"
const ARCHETYPE_BOSS = "Boss"
const ARCHETYPE_NEMESIS = "Nemesis"

@export var archetype_name: String = ARCHETYPE_GENERIC
@export var max_hp: int = 10
@export var mobility: int = 5
@export var armor: int = 0
@export var visual_color: Color = Color.RED
@export var visual_model_path: String = ""

@export var action_points: int = 2
@export var accuracy: int = 65
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
