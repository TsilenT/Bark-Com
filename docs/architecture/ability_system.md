# Architecture: Ability System

## 1. Overview
B.A.R.K. uses a resource-based Ability system. Everything the unit does, including "Standard Attack" or "Reload", is wrapped as an `Ability`. This decouples the action logic from the Unit class.

## 2. Structure

### `Ability.gd`
The base script (`scripts/resources/Ability.gd`) defines the interface.
-   **Properties**:
    -   `display_name` (String)
    -   `ap_cost` (int)
    -   `cooldown` (int)
    -   `target_type` (Enum: SELF, SINGLE_ENEMY, AOE, etc.)
-   **Key Methods**:
    -   `can_be_used(user, grid_manager)`: Validation check.
    -   `execute(user, target, grid_manager)`: The effect logic.
    -   `get_valid_targets(user, grid_manager)`: Returns a list of targetable Units or Tiles.

### Ability Scripts (`scripts/abilities/`)
Concrete implementations extend `Ability.gd`.
-   **Example**: `GrenadeToss.gd` overrides `execute` to spawn a projectile scene and apply AOE damage via `CombatResolver`.
-   **Example**: `OverwatchAbility.gd` overrides `execute` to set the `is_overwatch_active` state on the user.

## 3. Combat Resolution (`CombatResolver.gd`)

To prevent spaghetti code in Ability scripts, `CombatResolver` handles the math of damage, hit chance, and status application centrally.

-   **Location**: `scripts/core/CombatResolver.gd`
-   **Function**: `resolve_attack(attacker, target, ability_data)`
    -   Calculates Hit Chance (Accuracy - Defense - Cover).
    -   Rolls RNG.
    -   Calculates Damage (Weapon Base + Bonus - Armor).
    -   Applies Status Effects (Panic, Bleed, etc.).
    -   Logs the result.

## 4. Usage Flow
1.  **UI Interaction**: Player selects an Ability Button.
2.  **Targeting**: The ability's `get_valid_targets` highlights grid cells.
3.  **Confirmation**: Player clicks a valid target.
4.  **Execution**: `PlayerMissionController` calls `ability.execute()`.
5.  **Resolution**: The ability calls `CombatResolver` to apply changes to the game state.
