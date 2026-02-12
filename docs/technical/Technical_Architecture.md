# Project Guppi -- Technical Architecture (Godot 4)

## Core Systems

### TurnManager

-   Controls turn phases
-   Handles state transitions
-   Emits signals to subsystems

### EconomyManager

-   Resource tracking
-   Mining resolution
-   Production queues

### CombatManager

-   Battle resolution
-   Damage calculation
-   Combat logging

### EventManager

-   Random event generation
-   Event outcomes
-   Reputation & resource modification

### DiplomacyManager

-   Faction relations
-   Trade & alliance logic
-   Reputation scoring

------------------------------------------------------------------------

## Data-Driven Structure

-   Units as Resources
-   Enemies as configurable archetypes
-   JSON-driven balancing values

------------------------------------------------------------------------

## Scene Structure

-   GalaxyMap
-   SystemView
-   PlanetView
-   UI Layer (Timeline, Logs, HUD)

------------------------------------------------------------------------

## Future Refactor Goals

-   Modular signal-based communication
-   Save/Load serialization
-   Debug overlay
