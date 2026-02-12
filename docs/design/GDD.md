# Project Guppi — Game Design Document

> Status: Active Prototype  
> Updated: 2026-02-12  

---

# Core Concept

Turn-based deep space strategy focused on:

- Expansion
- Resource control
- Persistent combat encounters
- Progressive ship evolution

---

# Gameplay Pillars

1. Strategic Decision Weight
2. Meaningful Progression
3. Sector-Based Expansion
4. Tactical but Readable Combat

---

# Core Gameplay Loop

1. Explore
2. Extract resources
3. Upgrade fleet
4. Encounter enemies
5. Expand influence

---

# Combat System (Current Implementation)

## Encounter Model

- Combat triggers in Conflict Phase
- UI locks into combat overlay
- Player chooses:
  - Fight (1 round)
  - Flee (33% success chance)

## Combat Mechanics

- Fleet firepower = sum of drone firepower
- Enemy firepower = sum of enemy units
- Damage randomized (±20%)
- Persistent enemy HP
- Drone durability acts as HP
- Spillover damage to mothership hull

## Combat Outcomes

- Victory → XP gain
- Partial defeat → losses
- Failed flee → next round forced
- Successful flee → enemies remain

---

# Progression

- XP gained via combat & scanning
- Level scaling possible
- Future: module-based ship evolution

---

# Units

## Current

- Scout (low combat value)
- Miner (low combat value)
- Defender (combat focused)

## Future

- Heavy Defender
- EMP Drone
- Support Drone
- Carrier-class unit

---

# Enemy Archetypes

- Drone Swarm
- Rogue Corsair
- Ancient Sentry

Future:
- Carrier
- Tech Faction
- Sector Boss

---

# Economy

Iron (FE) — Base builds  
Titanium (TI) — Structural  
Uranium (U) — Advanced tech  
Data — Research

---

# Victory Conditions (Planned)

- Sector domination
- Diplomatic supremacy
- Technological transcendence

---

# Design Goal

Combat must feel:
- Tactical
- Persistent
- Consequential

Progression must feel:
- Empowering
- Visually evolving
- Mechanically meaningful
