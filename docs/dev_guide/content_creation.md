# Dev Guide: Content Creation

## 1. Adding a New Unit Class

Classes in BARK-COM are defined by Resources, not scripts.

1.  **Create Resource**: In FileSystem, Right Click -> New Resource -> `ClassData`.
2.  **Save Path**: `assets/data/classes/MyNewClassData.tres`.
3.  **Configure**:
    -   `Display Name`: "Cyber-Pug"
    -   `Base Stats`: Dictionary `{ "max_hp": 12, "mobility": 5 }`.
    -   `Stat Growth`: Dictionary `{ "max_hp": 2, "accuracy": 2 }` (Per level).
    -   `Starting Abilities`: Array of Scripts (e.g., `res://scripts/abilities/CyberBark.gd`).
4.  **Register**: Actually, no registration needed! The game loads these dynamically if referenced by `Unit.apply_class_stats("Cyber-Pug")`.

## 2. Creating a New Enemy

Enemies require logic (Behavior) and Stats.

1.  **Create Behavior Script**:
    -   Create `scripts/ai/CyberPugBehavior.gd`.
    -   Extend `AIBehaviorBase`.
    -   Implement `decide_action(unit, grid, targets)`.
2.  **Create Unit Script** (Optional, if unique visuals/stats needed):
    -   Usually `EnemyUnit.gd` suffices. The Behavior drives the logic.
    -   To enable the enemy, spawn an `EnemyUnit` and assign `behavior_script = load("res://scripts/ai/CyberPugBehavior.gd")`.
3.  **Visuals**:
    -   Update `EnemyModelFactory.gd` to handle "CyberPug" type and generate appropriate meshes.

## 3. Adding a New Ability

1.  **Create Script**: `scripts/abilities/LaserEyes.gd`.
2.  **Extend**: `Ability`.
3.  **Implement**:
    -   `_init()`: Set `display_name`, `ap_cost`, `cooldown`.
    -   `execute(user, target, grid)`: Call `CombatResolver.resolve_attack(...)`.
    -   `get_valid_targets(...)`: Return array of Units.

## 4. Adding a Weapon

1.  **Create Resource**: `scripts/resources/WeaponData.gd` (or inherit it).
2.  **Asset**: `resources/weapons/LaserRifle.tres`.
3.  **Stats**: Damage, Range, Crit Chance.
4.  **Equip**: Assign to `Unit.primary_weapon`.

## 5. Level Generation Templates

When creating new chunks in `LevelGenerator.gd` (e.g., `CHUNK_PARK`), use the following character codes to define the 5x5 grid layout.

| Code | Name               | Description                                      | Walkable | Elevation | Cover Type   | Destructible |
| :--- | :----------------- | :----------------------------------------------- | :------- | :-------- | :----------- | :----------- |
| `.`  | Ground             | Standard floor tile.                             | Yes      | 0         | None         | No           |
| `#`  | Obstacle           | Indestructible wall (e.g., concrete pillar).     | No       | 0         | Full (2.0)   | No           |
| `H`  | High Cover         | Tall objects (e.g., Fridge, High Wall).          | No       | 0         | Full (2.0)   | No           |
| `L`  | Low Cover          | Short objects (e.g., Flower Bed, Sandbags).      | No       | 0         | Half (1.0)   | **Yes**      |
| `W`  | Destructible Wall  | Bricks/Wood. Breaks onto Ground.                 | No       | 0         | Full (2.0)   | **Yes**      |
| `D`  | Destructible Cover | Crates/Barrels. Breaks onto Ground.              | No       | 0         | Half (1.0)   | **Yes**      |
| `+`  | High Ground        | Elevated platform or 2nd story floor.            | Yes      | 1         | None         | No           |
| `^`  | Ramp               | Connects Elevation 0 to 1.                       | Yes      | 0 / 1     | None         | No           |
| `=`  | Ladder             | Vertical traversal.                              | Yes      | 0 / 1     | None         | No           |

## 6. Chunk Design Rules

When designing new 5x5 chunks, adhere to the following rules to ensure quality and playability:

1.  **Self-Contained**: Chunks must function independently without relying on neighbors for navigation.
2.  **Destructibility**: Utilize Destructible Walls (`W`) and Cover (`D`) to allow terrain modification.
3.  **Verticality**: High Ground (`+`) and Ramps (`^`) are encouraged but must be traversable.
4.  **Accessibility**: **CRITICAL**: If a chunk has High Ground (`+`), it MUST have a way to reach it (Ramp `^` or Ladder `=`) or transition to/from it within the chunk.
5.  **Tactics**: Design for cover, flanking routes, and open fire lanes. Avoid creating unplayable "dead zones".
