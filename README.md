# 🚀 Project Guppi – Deep Space Strategy  
> Turn-based 3D space strategy prototype built with Godot 4 (GDScript · procedural systems · resource simulation)

<p align="left">
  <img alt="Godot" title="Godot 4 Engine" height="34" style="margin-right:22px;"
       src="https://raw.githubusercontent.com/github/explore/main/topics/godot/godot.png" />
  <img alt="Game Development" title="Game Development" height="34" style="margin-right:22px;"
       src="https://raw.githubusercontent.com/github/explore/main/topics/game-development/game-development.png" />
</p>

---

## 📖 Overview

**Project Guppi** is a turn-based 3D space strategy prototype developed using **Godot 4** and **GDScript**.

The project focuses on:

- Procedural galaxy generation  
- Turn-based gameplay architecture  
- Resource simulation systems  
- Modular drone production  
- Automated combat resolution  

It demonstrates scalable system design, gameplay loop architecture and engine-level structuring within Godot.

---

## 🖼 Gameplay Preview

### 🌌 Procedural Galaxy Generation

<img
  alt="Procedural Galaxy"
  src="https://github.com/user-attachments/assets/daafca8f-2579-4811-aa5f-6acf54eecbbc"
  width="900"
/>

- Each session generates a unique 3D star map  
- Dynamic resource distribution  
- Connected star systems with range validation  
- Scan-based discovery mechanics  

---

### ⛏ Resource Simulation & Drone Production

<img
  alt="Resource Simulation"
  src="https://github.com/user-attachments/assets/26a2d56f-8c36-4d6c-a7f5-732629a64329"
  width="900"
/>

- Iron (FE), Titanium (TI), Uranium (U)  
- Energy as strategic constraint  
- Two-turn production cycle  
- Passive resource extraction per round  

---

### ⚔ Tactical Combat System

<img
  alt="Combat System"
  src="https://github.com/user-attachments/assets/f3f1d5bc-375c-44f5-b0e0-1a8149f44643"
  width="900"
/>

- Automated combat resolution  
- Multiple enemy archetypes (Swarm, Corsair, Fortress)  
- Defender-first strike mechanic  
- Hull integrity (HP) as survival core variable  

---

## ✨ Core Systems

### 🗺 Galaxy System
- Procedural 3D map generation  
- Energy-based scan mechanic  
- Jump range validation (~800 units)  
- Star system graph connections  

### 🏗 Production System
- Fabricator with production queue  
- Specialized drone units:
  - **Scouts** (exploration)
  - **Miners** (resource extraction)
  - **Defenders** (combat units)

### 🔄 Turn-Based Game Loop
On **End Turn**:
1. Resource extraction phase  
2. Production completion  
3. Combat resolution  
4. XP evaluation & level check  

### 📈 Progression System
- XP gained from scans and combat  
- Level-ups increase energy capacity  
- Energy reset on level-up  

---

## 🧠 Technical Architecture

```
GameManager
  ├── GalaxyGenerator
  ├── TurnManager
  ├── CombatResolver
  ├── FabricatorSystem
  ├── ResourceManager
  └── XPSystem
```

### Architectural Principles

- Node-based modular structure  
- Single-responsibility system components  
- Centralized turn-state control  
- Data-driven enemy configuration  
- Designed for scalability (future sectors & factions)

---

## 🛠 Tech Stack

| Area | Technology |
|------|------------|
| Engine | Godot 4.x |
| Language | GDScript |
| Architecture | Node-based Scene System |
| Rendering | 3D |
| Gameplay Model | Turn-Based Strategy |
| Assets | Kenney Space Kit (CC0) |

---

## 🚀 Getting Started

1. Install Godot 4.x  
   https://godotengine.org  

2. Clone repository

```bash
git clone https://github.com/Codenix-1349/Project_Guppi.git
```

3. Open the project in Godot  
4. Run the main scene  

---

## 🎯 What This Project Demonstrates

- Turn-based gameplay architecture  
- Procedural content generation  
- Resource simulation systems  
- Combat resolution logic  
- Modular system design  
- Scalable game framework design  

---

## 📦 Planned Evolution

- Sector-based difficulty scaling  
- Faction diplomacy system  
- Visual ship module upgrades  
- Advanced enemy AI  
- Save/Load system  
- Steam build preparation  

---

## 👨‍💻 Author

Patrick Neumann  

GitHub: https://github.com/Codenix-1349  
LinkedIn: https://linkedin.com/in/patrick-neumann-532367276  
