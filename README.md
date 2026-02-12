# Project Guppi - Deep Space Strategy

Ein rundenbasiertes Strategiespiel entwickelt mit der Godot Engine. Übernimm das Kommando über ein Mutterschiff, erkunde die Galaxie und überlebe in den Tiefen des Alls.

## 🚀 Features

*   **Galaxien-Erkundung**: Navigiere durch ein vernetztes System von Sternen in 2D- oder 3D-Ansichten.
*   **Ressourcen-Management**: Sammle Eisen (FE), Titan (TI) und Uran (U) sowie Forschungsdaten. Verwalte deine Energie für Jumps und Scans.
*   **Drohnen-Fabrikator**: Baue spezialisierte Einheiten:
    *   **Scouts**: Sonden für die Fernerkundung entfernter Systeme.
    *   **Miner**: Einheiten zur automatisierten Ressourcengewinnung auf Planeten.
    *   **Defenders**: Kampfstarke Drohnen zum Schutz deiner Flotte.
*   **Kampfsystem**: Automatische Gefechtsabwicklung gegen verschiedene Gegnertypen (Swarm, Corsair, Fortress).
*   **Fortschritt**: Steige im Level auf, um deine Energiekapazität zu erhöhen und neue Möglichkeiten freizuschalten.
*   **Überlebenskampf**: Achte auf die Integrität deiner Schiffshülle (HP). Ohne Schutz zerfällt dein Schiff unter feindlichem Beschuss.

## 📖 Spielanleitung

### 1. Die erste Erkundung
Wähle ein System auf der Karte aus. Ist es noch unbekannt, kannst du es direkt scannen (verbraucht Energie) oder einen **Scout** dorthin schicken, falls das System in Reichweite deines Mutterschiffs (~800 Einheiten) liegt. Ein Scan enthüllt Ressourcenmengen auf Planeten und potenzielle Bedrohungen.

### 2. Bergbau & Produktion
Um zu überleben, brauchst du Ressourcen.
*   Gehe zum **Fabricator** am unteren Bildschirmrand und baue einen Miner.
*   Wähle nach Abschluss der Produktion (2 Runden) einen Planeten in einem gescannten System aus und klicke auf **"Assign Miner"**.
*   Miner sammeln jede Runde passiv Ressourcen für dich.

### 3. Fortbewegung
Klicke auf ein verbundenes System und nutze den **"Jump"**-Button. Jumps verbrauchen Energie, bringen dich aber zu neuen Rohstoffen und Zielen.

### 4. Rundenabschluss & Kampf
Klicke auf **"End Turn"**, um die aktuelle Runde zu beenden. In dieser Phase geschehen drei Dinge:
1.  Deine Miner sammeln Ressourcen.
2.  Dein Fabricator stellt Drohnen fertig.
3.  **Kampf**: Befindest du dich in einem System mit Gegnern, findet ein Gefecht statt. Deine Defenders greifen zuerst an. Besitzt du keine Drohnen, erleidet dein Mutterschiff direkt massiven Schaden an der Hülle!

### 5. XP & Level Up
Erfolgreiche Scans und gewonnene Kämpfe bringen dir XP. Bei einem Level-Up wird dein Energiespeicher erweitert und vollständig aufgefüllt.

---

## 🛠️ Entwicklung & Voraussetzungen

### Godot Engine
Das Spiel benötigt die Godot Engine (getestet mit Version 4.x).
*   [Godot Homepage](https://godotengine.org)
*   [Download für Windows](https://godotengine.org/download/windows/)
*   [Godot auf Steam](https://store.steampowered.com/app/404790/Godot_Engine/?l=german)


## 📚 Documentation

- [Strategic Roadmap](docs/roadmap/Strategic_Roadmap.md)
- [Game Design Document](docs/design/GDD.md)
- [Technical Architecture](docs/technical/Technical_Architecture.md)


---
*Viel Erfolg beim Überleben im Sektor, Commander!*
