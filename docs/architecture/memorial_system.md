# Memorial System Architecture

## Overview
The Memorial System tracks fallen units (Perma-death) and preserves their legacy. It ensures that when a unit dies during a mission, their data is serialized, including the Cause of Death (COD), and displayed in the Base's Memorial Wall.

## Data Structure
Fallen heroes are stored in `GameManager.fallen_heroes`, an Array of Dictionaries.
Each entry contains:

```gdscript
{
    "name": String,          # Unit Name
    "class": String,         # Class Name (e.g. "Ranger")
    "level": int,            # Rank Level at death
    "perks": Array,          # List of unlocked perk IDs
    "cause": String,         # Descriptive Cause of Death
    "date": String           # Real-world date of death (YYYY-MM-DD)
}
```

## Cause of Death (COD) Tracking
The system tracks the specific source of lethal damage to generate narrative death descriptions.

### 1. Centralized Damage Types (`GameManager.gd`)
Damage types are defined as constants in `GameManager` to ensure consistency:
- `DMG_TYPE_GENERIC`: "Generic"
- `DMG_TYPE_BALLISTIC`: "Ballistic" (Guns)
- `DMG_TYPE_EXPLOSION`: "Explosion" (Grenades, Rockets, Barrels)
- `DMG_TYPE_MELEE`: "Melee" (Claws, Bites)
- `DMG_TYPE_ACID`: "Acid" (Spitters)
- `DMG_TYPE_POISON`: "Poison" (Status)
- `DMG_TYPE_BLEED`: "Bleed" (Status)
- `DMG_TYPE_PSYCHIC`: "Psychic"
- `DMG_TYPE_FIRE`: "Fire"

### 2. Death Registration (`MissionManager.gd`)
When a player unit dies (`_on_unit_died`), the manager uses `GameManager.COD_MAP` to translate the damage type into a narrative verb:

- **Ballistic**: "Shot by [Source]"
- **Explosion**: "Blown up by [Source]"
- **Melee**: "Mauled by [Source]"
- **Acid**: "Melted by [Source]"
- **Poison**: "Succumbed to Poison" (Source optional)
- **Fire**: "Incinerated by [Source]"
- **Bleed**: "Bled out from [Source]"
- **Generic**: "Killed by [Source]"

### 3. Damage Injection
Gameplay systems must correctly pass source information via `Unit.take_damage_from(amount, source, type)` using `GameManager` constants:

- **CombatResolver**: Maps weapon names ("Claws", "Grenade") to constants (`DMG_TYPE_MELEE`, `DMG_TYPE_EXPLOSION`).
- **ExplosiveBarrel**: Passes `DMG_TYPE_EXPLOSION`.
- **Status Effects**: Pass specific types (e.g., `DMG_TYPE_POISON`).

## UI Implementation
`BaseScene.gd` renders the Memorial list (`_show_memorial`), creating a card for each fallen hero displaying their stats and the calculated `cause` string.

## Persistence
`GameManager.save_game()` serializes the `fallen_heroes` array to `savegame.dat`, ensuring the memorial persists across sessions.
