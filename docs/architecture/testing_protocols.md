# Architecture: Testing Protocols

## 1. Safety First (The "Mock" Flag)

You are working in a persistent game environment. Running a test should **NEVER** overwrite the developer's or user's actual save file.

### Required Setup
All integration tests (and unit tests that touch `GameManager`) MUST include this setup block:

```gdscript
var gm = get_node_or_null("/root/GameManager")
if gm:
    gm.TEST_MOCK_ENABLED = true
    gm.save_file_path = "user://test_savegame.dat"
```
**Why?**: `GameManager.gd` intercepts `save_game()` calls. If `TEST_MOCK_ENABLED` is true, it forces the path to `user://test_savegame.dat`, protecting `user://savegame.dat`.

## 2. Strict Mode Philosophy

The project enforces a **Zero Tolerance** policy for errors during testing. This is enforced by `run_tests_parallel.ps1` (enabled by default).

- **No Errors**: Any log containing `ERROR`, `SCRIPT ERROR`, or `FAIL` will cause the test to fail, even if the exit code is 0.
- **No Leaks**: Resources and Objects must be freed. `TestSafeGuard` helps detect this.
- **No Warnings**: While some engine warnings are benign, we strive to minimize them. Strict mode may flag critical warnings.

**Implication**: If your test passes logic assertions but prints an error (e.g., "Resource not found"), the test RUN is considered a **FAILURE**. Fix the root cause of the error log.

## 3. Test Runners

### Parallel Execution (Recommended)
Use `tests/run_tests_parallel.ps1`.
- **Filters**: Pass `-Filters "Pattern"` to run specific tests (e.g., `-Filters verify_final_mission`).
- **Discovery**: Automatically finds `.tscn` and `.gd` files in `tests/`.
- **Performance**: Spawns multiple worker processes to utilize CPU cores.

### Standards for Test Scripts
1.  **Scene vs. Script**:
    *   **Scene Tests (`*.tscn`)**: Extending `Node`. Must be attached to a `.tscn` file. Best for complex integration tests needing `SceneTree`.
    *   **Script Tests (`*.gd`)**: Extending `SceneTree` or `MainLoop`. Can run standalone if they don't need a scene.
2.  **TestSafeGuard**:
    *   **MANDATORY**: All tests must instantiate `TestSafeGuard` in `_ready()`.
    *   It handles:
        - Watchdog Timeout (30s)
        - `is_test_mode` injection (suppressing Audio/Visuals)
        - Leak Detection on exit
    
    ```gdscript
    func _ready():
        # Standard Compliance
        var safeguard = load("res://tests/TestSafeGuard.gd").new()
        add_child(safeguard)
    ```

## 4. Mocking & Autoloads
The project relies heavily on Autoloads (`GameManager`, `SignalBus`, `InputManager`).
- **Do not Instantiate Autoloads Manually**: If testing a class that depends on `SignalBus`, try to run the test in an environment where `SignalBus` already exists (via Runner Scene) rather than `SignalBus.new()`.
- **Dependency Checks**: Always wrap Autoload access in `if`:
  ```gdscript
  var sb = get_node_or_null("/root/SignalBus")
  if sb: sb.emit_signal(...)
  ```
  This allows classes to be unit-tested in isolation without crashing.
