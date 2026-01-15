# Combat System Mechanics

## Hit Chance Calculation
The probability of hitting a target (Accuracy) is calculated using the following formula:

**Hit Chance** = `(Attacker Accuracy + Modifiers) - (Target Defense + Cover + Distance Penalty)`

### Modifiers
*   **Weapon Range**: Weapons have an optimal range.
    *   **Penalty**: -5% per tile beyond optimal range.
*   **Elevation**:
    *   **High Ground**: +15 Aim, +10% Crit Chance.
    *   **Low Ground**: -10 Aim.
*   **Reaction Fire (Overwatch)**:
    *   **Penalty**: x0.8 Multiplier to final Hit Chance (or flat penalty depending on perk).
    *   **Vigilance**: Removes reaction penalty.

## Cover System
Cover reduces the chance of being hit and provides damage mitigation in some cases.

| Cover Type | Visual Indicator | Defense Bonus | Notes |
| :--- | :--- | :--- | :--- |
| **Half Cover** | Low Wall / Crate | **-20%** Hit Chance | Standard protection. |
| **Full Cover** | High Wall / Pillar | **-40%** Hit Chance | Significant protection. |

*   **Flanking**: If an attacker steps to the side of cover (90 degrees or more), the cover bonus is **negated** (0%).
*   **Destructible**: Most cover can be destroyed by explosives or heavy weapons.

## Damage & Critical Hits
*   **Base Damage**: Determined by the equipped Weapon.
*   **Critical Hit**:
    *   **Chance**: Unit Crit Stat + Flanking/High Ground bonuses.
    *   **Effect**: Deals **1.5x Damage**.
    *   **Sanity Damage**: Critical hits on players also deal **15 Sanity Damage**.

## Status Effects
*   **Shredded Armor**: Reduces Armor value effectively.
*   **Burning**: Deals damage over time (DoT).
*   **Disoriented**: -30 Aim, -4 Mobility.
