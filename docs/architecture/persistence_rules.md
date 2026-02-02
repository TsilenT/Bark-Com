# Architecture: Persistence & State Management

## 1. Unit Identity & State

### The "Source of Truth"
The `unit_class` string property on a `Unit` is the definitive identifier for its class identity.
- **DO NOT** rely on `current_class_data` (Resource) to determine the class name in save files. Resources can fail to load.
- **DO NOT** infer class from stats.

### Snapshot Logic (`get_data_snapshot`)
When serializing a Unit to a dictionary (for save games or roster transfers):
1.  **Class Name**: Must be pulled directly from `unit_class`. If empty, default to "Recruit".
2.  **Stats**: Serialize current values (`hp`, `xp`, `level`).
3.  **Validation**: Do not attempt to "correct" data during serialization. Save what is there.

### Restoration Logic (`restore_from_snapshot`)
When restoring a Unit from a dictionary:
1.  **Order Matters**:
    1.  **Identify**: Restore `unit_class` string.
    2.  **Load Data**: Call `apply_class_stats(unit_class)` IMMEDIATELY to load the `ClassData` resource (Abilities, Base Stats).
    3.  **Apply Progression**: Restore values (`level`, `xp`).
    4.  **Recalculate**: Call `recalculate_stats()` to apply level-based growth to Base Stats.
    5.  **Restore State**: Apply `current_hp` (or calculate damage) and `sanity`.

### Damage Preservation
When leveling up or modifying stats (e.g., via Terminal or Promotion):
1.  Calculate `damage_taken = max_hp - current_hp`.
2.  Apply Stat Updates (New Max HP).
3.  Restore Damage: `current_hp = max(1, new_max_hp - damage_taken)`.
*Note: Never heal a unit fully just because they leveled up.*

## 2. Save System (GameManager)

### File Paths
- **Production**: `user://savegame.dat` (Default).
- **Testing**: `user://test_savegame.dat`.

### Safety Intercepts
The `GameManager` contains a `TEST_MOCK_ENABLED` flag.
- **Enabled**: Redirects all save/load operations to the Test Path. Logs a warning.
- **Disabled**: Uses Production Path.
*Critically, this prevents development tests from wiping your personal campaign progress.*

## 3. Relationship (Bond) Storage
- **Location**: `GameManager.relationships` (Dictionary: "Name1_Name2" -> int).
- **Clearing**: Bonds involving a unit are **deleted** when the unit is removed from the roster (Death). See [Bond System](bond_system.md) for details.

