# XP & Progression System

## Overview
Units gain Experience Points (XP) through combat actions and surviving missions. Accumulating XP allows units to level up, increasing stats and unlocking perks.

## XP Sources

| Source | XP Amount | Notes |
| :--- | :--- | :--- |
| **Kill Enemy** | **50 XP** | Awarded to the unit that deals the killing blow. <br> *(Applies to Weapon Attacks, Grenades, Abilities)* |
| **Mission Victory** | **20 XP** | Awarded to **all surviving** squad members upon successful mission completion. |
| **Mission Loss** | **0 XP** | XP is retained, but no bonus is awarded for a failed mission. |

*(Note: XP is not currently split. Kills are purely individual.)*

## Level Thresholds

Units start at **Rank 1**.

| Rank | Total XP Required | Reward |
| :--- | :--- | :--- |
| **1** (Rookie) | 0 | Starting Rank |
| **2** (Squaddie) | **100** | +2 HP, Unlock Tier 1 Perk |
| **3** (Corporal) | **300** | +2 HP, Unlock Tier 2 Perk |
| **4** (Sergeant) | **600** | +2 HP, Unlock Tier 3 Perk |
| **5** (Lieutenant)| **1000** | +2 HP, Unlock Tier 4 Perk |

## Mechanics

*   **Level Up Checks**: Occur immediately after gaining XP.
*   **Stat Growth**: Currently, leveling up grants a flat **+2 Max HP** and fully heals the unit (+2 Current HP).
*   **Perks**: Unlocking a new Rank allows the unit to learn a talent from the BarkTree (Skill Tree).

## Debugging
*   **XP Log**: `Unit.gd` prints debug logs when XP is gained if `DEBUG_UNIT` is true.
*   **signals**: `SignalBus.on_xp_gained(unit_name, amount)` is emitted for UI updates.
