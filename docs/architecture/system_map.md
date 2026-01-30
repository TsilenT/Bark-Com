# System Map

> [!TIP]
> **Lost?** Use this map to find the "Home" of a concept.

## Core Loop & State
| Concept | File Location |
| :--- | :--- |
| **Main Entry Point** | `scripts/core/Main.gd` |
| **Global State (Base/Mission)** | `scripts/core/GameManager.gd` (Autoload) |
| **Event Bus** | `scripts/core/SignalBus.gd` (Autoload) |
| **Input Handling** | `scripts/core/InputManager.gd` (Autoload) |
| **Mission Initialization** | `scripts/builders/MissionInitializer.gd` |
| **Objective Spawning** | `scripts/builders/ObjectiveSpawner.gd` |

## Units & Entities
| Concept | File Location |
| :--- | :--- |
| **Base Unit Logic** | `scripts/entities/Unit.gd` |
| **Enemy Logic** | `scripts/entities/EnemyUnit.gd` |
| **Unit Movement State** | `scripts/fsm/units/UnitMoveState.gd` |
| **Unit Stats (Resource)** | `scripts/resources/UnitClass.gd` |

## Tactical Grid
| Concept | File Location |
| :--- | :--- |
| **Grid Management** | `scripts/managers/GridManager.gd` |
| **Cover Logic** | `scripts/systems/CoverSystem.gd` (or within GridManager) |
| **Pathfinding** | `scripts/utils/AStar_Path.gd` (check specifics) |

## Abilities & Combat
| Concept | File Location |
| :--- | :--- |
| **Ability Definition** | `scripts/resources/Ability.gd` |
| **Combat Resolution** | `scripts/systems/CombatResolver.gd` |
| **Hack Ability** | `scripts/abilities/HackAbility.gd` |

## UI
| Concept | File Location |
| :--- | :--- |
| **Main HUD** | `scripts/ui/GameUI.gd` |
| **Unit Info Panel** | `scripts/ui/UnitInfoPanel.gd` |
| **Mission Control** | `scripts/ui/MissionControl/Geoscape.gd` |

## Data & Persistence
| Concept | File Location |
| :--- | :--- |
| **Save/Load Logic** | `scripts/managers/SaveManager.gd` |
| **Persistence Rules** | `docs/architecture/persistence_rules.md` |
