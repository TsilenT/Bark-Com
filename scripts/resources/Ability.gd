extends Resource
class_name Ability

@export var display_name: String = "Ability"
@export var description: String = ""
@export var icon_path: String = ""
@export var ap_cost: int = 1
@export var ability_range: int = 1
@export var cooldown_turns: int = 0
var current_cooldown: int = 0


# Returns a list of valid target tiles (Vector2 grid coordinates)
# Override in subclasses
func get_valid_tiles(_grid_manager: GridManager, _user) -> Array[Vector2]:
	return []


# Execute the ability effect
# Override in subclasses
# target_unit: The unit clicked on (optional)
# target_tile: The grid tile clicked on (required)
func execute(_user, _target_unit, _target_tile: Vector2, _grid_manager: GridManager) -> String:
	return "Base ability executed."


# Returns hit chance and breakdown for UI (Optional)
# Override in subclasses if ability uses hit/miss logic
# Return format: { "hit_chance": int, "breakdown": Dictionary/String }
# Return empty dictionary if not applicable.
func get_hit_chance_breakdown(_grid_manager: GridManager, _user, _target) -> Dictionary:
	return {} 



@export var uses_charges: bool = false
@export var max_charges: int = 1
var charges: int = 1

func can_use() -> bool:
	if current_cooldown > 0:
		return false
	if uses_charges and charges <= 0:
		return false
	return true


func start_cooldown():
	current_cooldown = cooldown_turns


func on_turn_start(_user):
	if current_cooldown > 0:
		current_cooldown -= 1


# AI Scoring (Optional Override)
# Returns a score for the AI to decide whether to use this ability.
# > 0.0 means "Consider using". Higher is better.
# < 0.0 means "Do not use".
func get_ai_score(_user, _target, _grid_manager) -> float:
	return -1.0 # Default: AI does not use base abilities
