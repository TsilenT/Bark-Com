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

## 2. Test Runners

### Logic vs. Scene Tests
- **Logic Tests (`tests/test_*.gd`)**: Extend `Node`. Use `_ready()` to run assertions. Lightweight. Good for verifying math or data structures.
- **Scene Runners (`*.tscn`)**: Small scenes that attach the Logic Test script to a Node in the tree. Required for tests that need `SceneTree` access, `Autoloads` (like `GameManager`), or `await` functionality.

### Execution
Use `tests/run_tests.ps1`.
- It automatically discovers all `.tscn` files in `tests/`.
- It enforces a timeout (30-60s) to prevent hangs.
- It captures exit codes.

## 3. Mocking & Autoloads
The project relies heavily on Autoloads (`GameManager`, `SignalBus`, `InputManager`).
- **Do not Instantiate Autoloads Manually**: If testing a class that depends on `SignalBus`, try to run the test in an environment where `SignalBus` already exists (via Runner Scene) rather than `SignalBus.new()`.
- **Dependency Checks**: Always wrap Autoload access in `if`:
  ```gdscript
  var sb = get_node_or_null("/root/SignalBus")
  if sb: sb.emit_signal(...)
  ```
  This allows classes to be unit-tested in isolation without crashing.
