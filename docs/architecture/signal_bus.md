# Architecture: Signal Bus Pattern

## 1. Overview
BARK-COM relies on a **Centralized Event Bus** (`SignalBus.gd`) to decouple systems. Instead of nodes checking each other's state directly, or connecting signals manually up and down the tree, they broadcast events to the `SignalBus`.

-   **Location**: `scripts/managers/SignalBus.gd` (Autoload Name: `SignalBus`)
-   **Philosophy**: "Fire and Forget". Publishers don't know who is listening. Listeners don't know who published.

## 2. Key Categories

### Gameplay Triggers
These drive the core loop and often trigger UI refreshes or AI reactions.
-   `on_unit_stats_changed(unit)`: Fired whenever HP, AP, or Status changes. UI cards update automatically.
-   `on_turn_changed(phase_name, turn_number)`: Orchestrates the Player -> Enemy -> Player flow. unit logic resets AP here.

### Visual & Feedback
Use these to request "Juice" without coupling logic to the Visuals system.
-   `on_request_floating_text(pos, text, color)`: Spawns damage numbers or status text.
-   `on_request_vfx(vfx_name, pos, ...)`: Spawns particles (Blood, Explosions).
-   `on_request_camera_focus(pos)`: Tells the camera where to look.

### UI Synchronization
-   `on_roster_updated`: Tells the Barracks/Geoscape to refresh lists.
-   `on_kibble_changed`: Updates the currency display.

## 3. Best Practices

### 1. Listening
Ideally, listen in `_ready()` using a lambda or bound method:
```gdscript
func _ready():
    var sb = get_node_or_null("/root/SignalBus")
    if sb:
        sb.on_unit_health_changed.connect(_on_health_changed)

func _on_health_changed(unit, old, new):
    if unit == my_tracked_unit:
        update_bar(new)
```

### 2. Emitting
Check for existence before emitting (important for unit tests running in isolation):
```gdscript
if SignalBus:
    SignalBus.on_request_floating_text.emit(global_position, "OUCH!", Color.RED)
```

### 3. Separation of Concerns
-   **Logic** (Unit.gd) emits `on_unit_died`.
-   **Audio** (AudioManager.gd) listens and plays a death sound.
-   **UI** (MissionUI.gd) listens and removes the health bar.
-   **Logic** DOES NOT call `AudioManager.play_death_sound()`.
