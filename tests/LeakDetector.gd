class_name LeakDetector
extends Node

var start_orphan_count: int = 0
var tracking: bool = false

func _ready():
	start_tracking()

func start_tracking():
	# Force garbage collection/flush to get a stable baseline if possible
	# (GDScript doesn't expose robust GC control, but checking monitor helps)
	start_orphan_count = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	tracking = true
	print("LeakDetector: Tracking started. Baseline Orphans: ", start_orphan_count)

func check_leaks(tolerance: int = 0):
	if not tracking:
		print("LeakDetector WARNING: check_leaks called but tracking not started.")
		return

	var end_count = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var diff = end_count - start_orphan_count
	
	print("LeakDetector: Check Complete. Baseline: ", start_orphan_count, " Current: ", end_count, " Diff: ", diff)
	
	if diff > tolerance:
		print("LeakDetector: !!! POSSIBLE LEAK DETECTED !!! (", diff, " new orphans, allowed: ", tolerance, ")")
		print("--- ORPHAN NODES DUMP ---")
		print_orphan_nodes()
		print("-------------------------")
	else:
		print("LeakDetector: No new orphan nodes detected.")
