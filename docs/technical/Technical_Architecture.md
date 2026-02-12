# Project Guppi — Technical Architecture (Godot 4)

> Status: Implemented Core Systems  
> Updated: 2026-02-12  

---

# Core Systems

## TurnManager

- Controls phase transitions
- Emits phase_changed signal
- Triggers execution & resolve
- Calls CombatManager when enemies present

---

## CombatManager

Current Features:

- Encounter start
- Persistent enemy HP
- Drone durability tracking
- Flee system
- Fight round resolution
- XP gain
- Combat overlay signaling
- encounter_started
- encounter_updated
- encounter_ended

Designed to operate as modal state within turn system.

---

## PrinterManager

- 3 fabrication slots
- Resource cost validation
- Turn-based progress
- Inventory tracking

---

## MiningManager

- Drone assignment per planet
- Resource extraction per turn
- Global resource update

---

## GalaxyMap3D

- Procedural system generation
- Star type differentiation
- Persistent planet resources
- Visual orbit system
- Unit indicators

---

# Data-Driven Structure

## JSON Driven

- data/drones.json
- data/enemies.json

Stats configurable:
- firepower
- durability
- speed
- future: shields / armor

---

# UI Architecture

Runtime-created CombatPanel:

- Blocks underlying UI
- Disables interaction behind overlay
- Displays fleet & enemy status
- Controlled via CombatManager signals

---

# Current Limitations

- No Save/Load system
- No EventManager
- No DiplomacyManager
- No Sector partition logic yet

---

# Refactor Goals

- Introduce EconomyManager wrapper
- Extract EventManager
- Extract DiplomacyManager
- Introduce SaveManager
- Improve signal-based decoupling
- Add debug overlay

---

# Architectural Principle

- Modular Managers
- Signal-based communication
- Data-driven balancing
- Scene-minimal runtime UI
