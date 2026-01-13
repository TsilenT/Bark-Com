extends Node

signal debug_overlay_requested(unit, data)

var enabled: bool = true
var decision_history: Dictionary = {}

func _ready():
	process_priority = 100 # Low priority

func log_decision(unit_name: String, action_name: String, score: float, context: Dictionary = {}):
	if not enabled: return
	
	if not decision_history.has(unit_name):
		decision_history[unit_name] = []
		
	var entry = {
		"timestamp": Time.get_ticks_msec(),
		"action": action_name,
		"score": score,
		"context": context
	}
	
	decision_history[unit_name].append(entry)
	# Keep history small
	if decision_history[unit_name].size() > 20:
		decision_history[unit_name].pop_front()
		
	print("[AI_DEBUG] ", unit_name, " chosen: ", action_name, " (", score, ") ", JSON.stringify(context))

func emit_debug_overlay(unit, grid_scores: Dictionary):
	if not enabled: return
	debug_overlay_requested.emit(unit, grid_scores)
