# 🚀 Project Guppi – Deep Space Strategy 
 -=under construction=-
> Turn-based 3D space strategy prototype built with Godot 4 (GDScript · procedural systems · modular game architecture)

<p align="left">
  <img alt="Godot" title="Godot 4 Engine" height="34" style="margin-right:22px;"
	   src="https://raw.githubusercontent.com/github/explore/main/topics/godot/godot.png" />
  <img alt="Game Development" title="Game Development" height="34"
	   src="https://raw.githubusercontent.com/github/explore/main/topics/game-development/game-development.png" />
</p>

---

## 📖 Overview

**Project Guppi** is a turn-based 3D strategy prototype developed with **Godot 4** and **GDScript**.

The project emphasizes:

- Procedural galaxy generation  
- Modular manager-based architecture  
- Turn-based orchestration  
- Resource simulation  
- Drone production systems  
- Automated combat resolution  
- Integrated battle logging  

It demonstrates scalable game system design and structured scene architecture within Godot.

---

## 🖼 Gameplay Preview

### 🌌 Procedural Galaxy

<img
  alt="Procedural Galaxy"
  src="https://github.com/user-attachments/assets/daafca8f-2579-4811-aa5f-6acf54eecbbc"
  width="900"
/>

- Dynamic 3D star map generation  
- Connected star systems  
- Energy-based scanning  
- Jump range validation  

---

### ⛏ Resource & Production Systems

<img
  alt="Resource Simulation"
  src="https://github.com/user-attachments/assets/26a2d56f-8c36-4d6c-a7f5-732629a64329"
  width="900"
/>

- Iron (FE), Titanium (TI), Uranium (U)  
- Energy management as core constraint  
- Fabricator production queue  
- Miner assignment to planets  
- Passive resource accumulation per turn  

---

### ⚔ Combat & Battle Log

<img
  alt="Combat System"
  src="https://github.com/user-attachments/assets/f3f1d5bc-375c-44f5-b0e0-1a8149f44643"
  width="900"
/>

- Automated encounter resolution  
- Multiple enemy archetypes  
- Defender-first strike mechanic  
- Hull integrity (HP) system  
- Dedicated **BattleLog UI component**

---

## ✨ Core Gameplay Systems

## 🔄 Turn-Based Orchestration

Each turn progresses through a structured four-phase pipeline:

### 1️⃣ Planning Phase
The player issues commands (movement, production, system interactions) and confirms the turn.

### 2️⃣ Execution Phase
Currently a structural placeholder reserved for action sequencing and animation playback  
(e.g., mothership travel between systems, drone deployment, scouting operations, Fog-of-War reveal).

### 3️⃣ Resolve Phase
Core deterministic turn mechanics are processed:

- Resource extraction (MiningManager)
- Production completion (PrinterManager)
- Energy regeneration (level-scaled cap)
- Enemy encounter detection
- Combat initiation (if hostile presence exists)

If combat is triggered, the turn flow pauses until the encounter is resolved.

### 4️⃣ Event Phase
Post-resolution effects are processed:

- Event / anomaly handling
- XP calculation
- Level progression
- Turn counter increment

The game then transitions back to the Planning Phase.


### Progression System
- XP gained from scans and victories  
- Level-ups increase:
  - Maximum energy capacity  
  - Maximum hull integrity (HP)  
- Energy restored on level-up  

---

## 🧠 Technical Architecture

### Scene Structure (Godot Node-Based)

```
Main3D
 ├── Managers
 │    ├── TurnManager
 │    ├── CombatManager
 │    ├── MiningManager
 │    ├── ScanManager
 │    ├── PrinterManager
 │    └── GalaxyMap3D
 │
 ├── UI
 │    ├── ResourceBar
 │    ├── TurnInfo
 │    ├── ActionButtons
 │    └── CombatLog
```

### Script-Based System Separation

- `TurnManager.gd`
- `CombatManager.gd`
- `MiningManager.gd`
- `ScanManager.gd`
- `PrinterManager.gd`
- `GalaxyMap3D.gd`

Architecture Principles:

- Single-responsibility systems  
- Centralized turn-state control  
- Expandable modular design  
- Data-driven enemy logic  

---

## 🛠 Tech Stack

| Area | Technology |
|------|------------|
| Engine | Godot 4.x |
| Language | GDScript |
| Architecture | Node-based Scene System |
| Rendering | 3D |
| Assets | Kenney Space Kit (CC0) |
| Model Format | GLTF |

---

## 🚀 Getting Started

### Install Godot 4

Official website:  
https://godotengine.org  

Steam version:  
https://store.steampowered.com/app/404790/Godot_Engine/

---

### Clone Repository

```bash
git clone https://github.com/Codenix-1349/Project_Guppi.git
```

Open the project in Godot and run the main scene.

---

## 🎨 Asset Integration

This project uses **Kenney – Space Kit (CC0)**.

Download:  
https://kenney.nl/assets/space-kit

Place assets inside:

```
res://kenney_space-kit/
```
The folder `res://kenney_space-kit/` is already included in the project.
Simply extract the asset pack into this directory.

Example structure:

```
res/
 ├── assets/
 ├── audio/
 ├── data/
 ├── docs/
 ├── kenney_space-kit/
 └── scenes/
```

---

## 🛣 Planned Features / Roadmap

### 🌍 Factions & Diplomacy
- Multiple alien factions with distinct traits
- Diplomatic states (Neutral, Allied, Hostile)
- Trade & negotiation systems
- Reputation-based interactions

### 🏗 Colonization System
- Planet colonization mechanics
- Surface building placement:
  - Factory
  - Mine
  - Research Station
- Production bonuses per planet type

### 🔬 Technology Tree
- Unlockable upgrades
- Branching research paths
- Weapon and ship module progression
- Strategic specialization

### 🔫 Advanced Weapon Systems
- Different weapon classes
- Offensive vs defensive builds
- Ship module customization
- Tactical loadout decisions

### 🎮 3D Tactical Combat Mode
- Optional real-time or tactical combat scene
- Camera-controlled battle arena
- Unit positioning mechanics
- Visual combat feedback

---

## 🎯 What This Project Demonstrates

- Modular system-driven architecture  
- Turn-based gameplay orchestration  
- Procedural generation systems  
- Resource simulation mechanics  
- Combat resolution logic  
- Expandable long-term design vision  

---

## 👨‍💻 Author

Patrick Neumann  

GitHub: https://github.com/Codenix-1349  
LinkedIn: https://linkedin.com/in/patrick-neumann-532367276  
