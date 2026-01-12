extends Node
class_name TestUtils

# Standardized cleanup to prevent ObjectDB Leaks on exit
# Usage: await TestUtils.finalize_and_quit(get_tree(), exit_code)
static func finalize_and_quit(tree: SceneTree, exit_code: int = 0):
	# Wait for pending thread/node deletions
	# queue_free() needs at least 1 idle frame (process_frame)
	# Physics nodes might need physics_frame
	
	if exit_code == 0:
		print("TestUtils: Cleaning up before exit...")
	else:
		print("TestUtils: FAILED (Code " + str(exit_code) + "). Cleaning up...")
	
	# Flush the deferred delete queue
	# Flush the deferred delete queue
	# Use a timer to ensure enough time passes (safer than process_frame in some CI envs)
	# Args: time, process_always(true), process_in_physics(false), ignore_time_scale(true)
	await tree.create_timer(0.1, true, false, true).timeout
	
	# Optional: Force garbage collection?
	# GC is automatic in GDScript usually.
	
	tree.quit(exit_code)
