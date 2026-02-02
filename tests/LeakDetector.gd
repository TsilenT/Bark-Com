class_name LeakDetector
extends Node

var start_orphan_count: int = 0
var start_object_count: int = 0
var start_resource_count: int = 0
var tracking: bool = false

func _ready():
	start_tracking()

func start_tracking():
	# Capture baselines
	start_orphan_count = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	start_object_count = Performance.get_monitor(Performance.OBJECT_COUNT)
	start_resource_count = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	tracking = true
	
	GameManager.log("LeakDetector", "Tracking started. Baseline - Orphans: %d | Objects: %d | Resources: %d" % [start_orphan_count, start_object_count, start_resource_count])

func check_leaks(tolerance: int = 0):
	if not tracking:
		print("LeakDetector WARNING: check_leaks called but tracking not started.")
		return

	var end_orphan = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var end_object = Performance.get_monitor(Performance.OBJECT_COUNT)
	var end_resource = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	
	var diff_orphan = end_orphan - start_orphan_count
	var diff_object = end_object - start_object_count
	var diff_resource = end_resource - start_resource_count
	
	var msg = "LeakDetector: Check Complete.\n"
	msg += "  Orphans:   %d -> %d (Diff: %d)\n" % [start_orphan_count, end_orphan, diff_orphan]
	msg += "  Objects:   %d -> %d (Diff: %d)\n" % [start_object_count, end_object, diff_object]
	msg += "  Resources: %d -> %d (Diff: %d)" % [start_resource_count, end_resource, diff_resource]
	
	print(msg)
	
	# Primary detection is Orphan Nodes, but warn about others
	if diff_orphan > 0:
		var severity = "WARNING" if diff_orphan > tolerance else "INFO"
		print("LeakDetector: [%s] Orphan Nodes Detected (%d). Valid Tolerance: %d" % [severity, diff_orphan, tolerance])
		print("--- ORPHAN NODES DUMP ---")
		print_orphan_nodes()
		print("-------------------------")
	else:
		print("LeakDetector: No new orphan nodes detected.")

	if diff_object > tolerance + 10: # Objects fluctuate more (internal), tolerance higher
		print("LeakDetector: NOTICE - High Object Count Delta (%d). Possible Object/Resource leak." % diff_object)
