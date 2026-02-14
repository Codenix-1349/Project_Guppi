# Project Guppi - Deep Space Strategy

Ein rundenbasiertes Strategiespiel entwickelt mit der Godot Engine. Übernimm das Kommando über ein Mutterschiff, erkunde die Galaxie auf einer 3D Karte und überlebe in den Tiefen des Alls.

## 🖼️ Screenshots


#### Prozedurale Galaxie-Erkundung
Jede neue Partie erschafft eine einzigartige dreidimensionale Sternenkarte mit unterschiedlichen Systemen, 
Ressourcenverteilungen und Gefahren.
Plane deine Route strategisch
und entscheide, wohin dein Mutterschiff als Nächstes springt.

<img
  alt="Prozedurale Galaxie-Erkundung"
  src="https://github.com/user-attachments/assets/daafca8f-2579-4811-aa5f-6acf54eecbbc"
  width="900"
/>

---

#### Ressourcenabbau und Flottenausbau
Schicke Miner auf Planeten, sichere Eisen, Titan und Uran und halte deine
Produktionsketten am Laufen. Effizientes Ressourcenmanagement ist der
Schlüssel zum Überleben im All.

<img
  alt="Ressourcenabbau"
  src="https://github.com/user-attachments/assets/26a2d56f-8c36-4d6c-a7f5-732629a64329"
  width="900"
/>

---

#### Kampf gegen feindliche Alien-Fraktionen
Feindkontakt. Stelle dich unterschiedlichen Gegnertypen und Schiffsklassen.
Jede Begegnung fordert taktische Entscheidungen – kämpfen oder fliehen?

<img
  alt="Kampf gegen Aliens"
  src="https://github.com/user-attachments/assets/f3f1d5bc-375c-44f5-b0e0-1a8149f44643"
  width="900"
/>



## 🚀 Features

*   **Galaxien-Erkundung**: Navigiere durch ein vernetztes System von Sternen in einer 3D-Ansicht.
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


## 🎨 Grafik-Assets (Kenney Space Kit)

Dieses Projekt nutzt das kostenlose **Kenney – Space Kit (CC0)**.

Download (offizielle Quelle):
https://kenney.nl/assets/space-kit

### Installation

1. Lade das Paket von Kenney herunter.
2. Entpacke es.
3. Lege die entpackten Asset-Dateien in diesen Ordner im Projekt:

   `res://kenney_space-kit/`

4. Godot neu öffnen (oder im Dateisystem einmal “Reload”).





## 📚 Documentation

- [Strategic Roadmap](docs/roadmap/Strategic_Roadmap.md)
- [Game Design Document](docs/design/GDD.md)
- [Technical Architecture](docs/technical/Technical_Architecture.md)


---
*Viel Erfolg beim Überleben im Sektor, Commander!*
