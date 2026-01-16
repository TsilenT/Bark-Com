# Dev Guide: Coding Standards

## 1. GDScript Style
Follow the official Godot Style Guide with these project-specific enforcements:

### Typing (Strict Recommendation)
Use static typing wherever possible to prevent runtime errors.
```gdscript
# Good
var health: int = 100
func take_damage(amount: int) -> bool:
    return true

# Avoid
var health = 100
func take_damage(amount):
```

### Naming
- **Classes/Files**: PascalCase (`Unit.gd`, `GameManager`)
- **Variables/Functions**: snake_case (`current_hp`, `calculate_damage`)
- **Constants**: SCREAMING_SNAKE_CASE (`MAX_SPEED`, `LOG_PREFIX`)
- **Private/Protected**: Prefix with `_` (`_update_ui()`)

## 2. Infrastructure Patterns

### Logging
**DO NOT** use `print()`, `print_debug()`, or `printerr()`.
Use the centralized `GameManager` logging system.
1.  Define a constant at the top of your class:
    ```gdscript
    const LOG_PREFIX = "MyClassName: "
    ```
2.  Log events:
    ```gdscript
    GameManager.log(LOG_PREFIX, "Something happened.")
    ```

### Unit Instantiation
We use a **Code-First** approach for Units.
- The `Unit` scene (`Unit.tscn`) is rarely used directly for logic.
- Most logic (including tests) instantiates the script directly:
  ```gdscript
  var unit = load("res://scripts/entities/Unit.gd").new()
  ```
- Visuals are attached dynamically via `CorgiModelFactory` or `EnemyModelFactory`.

## 3. Directory Structure
- `scripts/`: Logic files only. Mirrors scene structure where possible.
- `scenes/`: `.tscn` files. `scenes/ui`, `scenes/entities`, `scenes/levels`.
- `assets/`: Raw assets (models, textures, data resources).
- `tests/`: Regression and Unit tests.
- `docs/`: Architecture and Dev Guide documentation.
