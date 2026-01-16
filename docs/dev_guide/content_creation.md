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
