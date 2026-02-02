# Bond System Architecture

The Bond System represents relationships between units that provide passive gameplay bonuses. These relationships persist across missions but must be maintained.

## Core Concepts

- **Identity**: Bonds are tracked by **Unit Name**. If a unit is renamed, the bond key must theoretically change (though renaming is not fully supported yet).
- **Storage**: Bonds are stored in `GameManager.relationships` as a Dictionary `{"Name1_Name2": Score}`.
- **Key Generation**: Keys are always alphabetical to ensure bidirectional consistency: `min(A, B) + "_" + max(A, B)`.

## Bond Lifecycle

### 1. Creation & Growth
- **Trigger**: Occurs when units participate in missions together or via specific events.
- **Hook**: `Unit.trigger_bond_growth(other_unit, amount)` calls `GameManager.modify_bond`.
- **Level Up**: Scores translate to Levels (1: Buddy, 2: Packmate, 3: Soul Pup).

### 2. Effects
- **Bonuses**: `Unit.get_active_bond_bonuses()` checks for *adjacent* bond partners.
- **Death Trigger**: If a partner dies during a mission, `Unit.die()` checks `GameManager` for Level 3 bonds ("Soul Pups") to trigger the **Berserk** state on the survivor.

### 3. Clearing on Death
> [!IMPORTANT]
> To prevent "Ghost Bonds" (bonds with dead units) from polluting the save file, they must be cleared when a unit dies.

- **Timing**: Bonds are NOT cleared immediately upon `Unit.die()`. This allows the Berserk trigger to function correctly during the mission.
- **Purge**: Bonds are cleared in `GameManager.complete_mission()` *after* mission results are processed but *before* the save file is updated.
- **Logic**: The function `clear_unit_bonds(unit_name)` removes any key in `relationships` that contains the dead unit's name.

## Persistence Rules

- **Save File**: `relationships` is saved efficiently as a dictionary in `game.squad`.
- **Roster Purge**: When `GameManager` detects a unit in `fallen_heroes` (Dead), it calls `clear_unit_bonds` before removing them from `roster`.

## Debugging

- **Verify Bonds**: Use `GameManager.get_bond_score(u1, u2)`.
- **Test Script**: `tests/verify_bond_clearing.gd` simulates death and checks for persistence leaks.
