# Agent Behavior & Project Guidelines

This document serves as the central hub for AI agents and developers working on the BARK-COM (Tactical Corgi Strategy) codebase. Adhering to these guidelines is mandatory to prevent regression and maintain save data integrity.

## 1. Project Context

**BARK-COM** is a tactical turn-based strategy game (similar to XCOM) where players command a squad of genetically enhanced Corgis against Eldritch horrors ("The Whispers", "The Sprawling").

### Key Pillars
-   **Tactical Depth**: Cover, Flanking, Overwatch, and Action Points (AP).
-   **Base Management**: A detailed HQ ("The Kennel") with Barracks, Research, and Mission Control (Geoscape).
-   **Persistent Roster**: Units have persistent stats, injuries, and progression. Losing a unit is permanent (Perma-death).
-   **Visuals**: High-fidelity procedural Corgi models and distinct Enemy visual identities.

## 2. Core Architecture Rules (Strict)

> [!IMPORTANT]
> **Safety First**: Never risk corrupting the user's save data.

This project enforces strict rules for Testing, Persistence, and State Management. Failure to follow these leads to subtle regressions (e.g., units resetting to "Recruit").

-   **Persistence**: [View detailed rules](docs/architecture/persistence_rules.md).
    -   *Rule*: `unit_class` string is the Source of Truth. Never rely on Resources for identity.
    -   *Rule*: Restore Class Data `apply_class_stats()` BEFORE recalculating stats.
-   **Testing Protocols**: [View detailed rules](docs/architecture/testing_protocols.md).
    -   *Rule*: ALL tests must set `GameManager.TEST_MOCK_ENABLED = true` and use `test_savegame.dat`.
    -   *Rule*: Use `run_tests.ps1` for execution.

## 3. Coding Standards (GDScript)

> [!NOTE]
> Consistent style minimizes cognitive load.

-   **Logging**: Use `GameManager.log(LOG_PREFIX, ...)` instead of `print()`.
-   **Typing**: Strict static typing is preferred.
-   **Instantiation**: Prefer `Code-First` instantiation (`Unit.gd` script via `.new()`) over Scene instantiation (`.tscn`) for logic.

[View full Coding Standards](docs/dev_guide/coding_standards.md).

## 4. Documentation Deep Dive

For agents engaging in heavy implementation, consult these system-specific guides:

-   **[Content Creation Guide](docs/dev_guide/content_creation.md)**: **START HERE** if adding new Classes, Enemies, or Items.
-   **[AI Architecture](docs/architecture/ai_system.md)**: Details `EnemyUnit`, the State Machine, and Behavior selection.
-   **[Ability System](docs/architecture/ability_system.md)**: Explains Resource-based abilities and `CombatResolver`.
-   **[Tactical Grid](docs/architecture/tactical_grid.md)**: Covers Pathfinding, Cover, and Grid Logic.
-   **[Signal Bus](docs/architecture/signal_bus.md)**: Details the Event-Driven architecture used to decouple logic, UI, and Audiovisuals.

## 5. Key Systems & Managers

-   **GameManager** (Autoload): Global state machine (Base vs Mission), Save/Load orchestration.
-   **SignalBus** (Autoload): Central event hub.
-   **InputManager** (Autoload): Handles Raycasting (`on_tile_clicked`) and Camera Controls. Only processes input during `MISSION` or `BASE` states.
-   **GridManager**: Singleton managing the AStar graph and Cover calculations.
-   **BarkTreeManager**: Manages the Skill Tree (Perks) persistence.

## 6. Current Tech Stack

-   **Engine**: Godot 4.5.1 (Stable).
-   **Language**: GDScript 2.0.
