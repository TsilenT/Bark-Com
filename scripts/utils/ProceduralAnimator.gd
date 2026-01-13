extends Node
class_name ProceduralAnimator

# Animation Types
enum AnimType { NONE, ROTATE, PULSE, JITTER, FLOAT_SINE, ORBIT }

var anim_type: int = AnimType.NONE
var speed: float = 1.0
var amplitude: float = 0.1
var axis: Vector3 = Vector3.UP
var noise_seed: float = 0.0

# State
var _base_scale: Vector3
var _base_pos: Vector3
var _time: float = 0.0

func _ready():
	_base_scale = get_parent().scale
	_base_pos = get_parent().position
	noise_seed = randf() * 100.0

func setup(type: int, _speed: float = 1.0, _amp: float = 0.1, _axis: Vector3 = Vector3.UP):
	anim_type = type
	speed = _speed
	amplitude = _amp
	axis = _axis

func _process(delta):
	_time += delta * speed
	var parent = get_parent()
	if not parent: return

	match anim_type:
		AnimType.ROTATE:
			parent.rotate(axis, delta * speed)
			
		AnimType.PULSE:
			var s = sin(_time) * amplitude
			parent.scale = _base_scale + Vector3(s, s, s)
			
		AnimType.JITTER:
			# Random twitching
			if randf() < 0.1 * speed: # Chance to twitch
				var twitch = Vector3(randf()-0.5, randf()-0.5, randf()-0.5) * amplitude
				parent.position = _base_pos + twitch
			else:
				# Return to base lerped
				parent.position = parent.position.lerp(_base_pos, delta * 5.0)
				
		AnimType.FLOAT_SINE:
			var y_off = sin(_time + noise_seed) * amplitude
			parent.position.y = _base_pos.y + y_off
			
		AnimType.ORBIT:
			# Requires parent to be offset from its own parent (pivot)
			# Actually, simpler: Rotate around the node's LOCAL origin? 
			# Usually we place a pivot node and rotate that.
			# Or we assume this script is on a Pivot container.
			parent.rotate(axis, delta * speed)
