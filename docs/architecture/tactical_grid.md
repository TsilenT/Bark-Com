# Architecture: Tactical Grid System

## 1. Overview
The Tactical Grid is the foundation of gameplay. It manages movement, cover, line-of-sight, and object placement. It acts as the bridge between 3D world coordinates and abstract 2D grid logic.

## 2. Core Components

### `GridManager.gd`
The central singleton/manager.
-   **Grid Coordinates**: `Vector2(x, z)`.
-   **World Coordinates**: `Vector3(x, y, z)`.
-   **Key Responsibilities**:
    -   `get_path(start, end)`: AStar pathfinding.
    -   `get_cover_value(unit, target)`: Calculates cover (Low/High/None) based on adjacent objects.
    -   `is_tile_occupied(pos)`: Collision checking.

### `TacticalMap` (Scene)
The visual representation.
-   **GridMap Node**: Godot's built-in `GridMap` is often used for rendering the floor/walls, but `GridManager` maintains the logical data.

## 3. Pathfinding Logic
1.  **AStar Initialization**: On level load, `GridManager` scans the map.
2.  **Passability**: Tiles are marked Walkable or Blocked. Blocked tiles (Walls, Props) are excluded from the AStar graph.
3.  **Dynamic Updates**: When a Unit moves or an obstacle is destroyed, the grid occupancy is updated. (Optimized to avoid full graph rebuilds).

## 4. Cover System
Cover is directional.
-   **Logic**: A raycast or adjacent check is performed from the Target towards the Attacker.
-   **Types**:
    -   **High Cover**: Walls, High Props. Provides significant Defense bonus.
    -   **Low Cover**: Low walls, Crates. Provides moderate Defense bonus.
    -   **Flanking**: If the attack angle bypasses the cover object (i.e., attacker is 90 degrees or more to the side), cover is negated.

## 5. Line of Sight (Fog of War)
Implemented via `VisionManager` (often coupled with `GridManager`).
-   Raycasts determine visibility from Unit Head Position to Target Head Position.
-   Fog of War obscures unseen tiles visually.
