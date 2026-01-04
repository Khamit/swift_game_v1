# Nighty Tales 🎮

A SwiftUI merge-and-battle game prototype
## Overview
Nighty Tales is a simple yet system-driven SwiftUI game focused on merging, dragging, bouncing projectiles, and defending territory against waves of enemies.
The screen is split into two dynamic zones: Player Territory (bottom) and Enemy Territory (top). Enemies actively pressure the player by expanding their zone and stealing money, while the player fights back using merged stars and an economic tower system.
---
The project is designed as a gameplay prototype with clean architecture and readable systems for experimentation and further expansion. (not sure)

## Core Gameplay Features
### ⭐ Merge & Launch System

Drag stars in the player zone.
Merge identical stars to increase their level and damage.
Release to launch stars with physics-based movement and bouncing.
Higher-level stars deal more damage to enemies.

### ⚔️ Enemy Combat
Enemies spawn in waves from the enemy zone.
Stars collide with enemies and deal damage.
Defeating enemies rewards money and territory control.
Enemies can steal player money if not controlled.

### 🌊 Wave System
Progressive waves with scaling difficulty.
Increasing enemy count and pressure over time.
Countdown timer to the next wave.
Territory shifts toward enemies at the start of each wave.

### 🧱 Tower Economy
Towers generate passive income.
Towers can be purchased and upgraded.
Income scales with tower level and production speed.
UI includes progress bars and upgrade states.

### 🧭 Dynamic Screen Split
The screen is vertically divided into two zones:
Top: Enemy territory
Bottom: Player territory
The divider dynamically moves:
Toward enemies when they are defeated
Toward the player when enemies steal money or apply pressure
Losing condition occurs when the enemy zone fills most of the screen.

## Architecture Overview

The game follows a state-driven SwiftUI architecture using ObservableObject and @Published properties.

Key Components
Component	Responsibility
GameManager	Core game loop, wave logic, merging, combat, economy
GameScreen	Main SwiftUI view, rendering zones, HUD, and entities
EnemyManager	Enemy spawning, updating, and removal
ScreenDividerModel	Controls player/enemy territory ratio
PlayerModel	Currency, score, towers, progression
StarModel	Merge logic, physics, damage
TowerModel	Production, upgrades, UI state
ParticleSystem	Visual feedback for hits and merges
Example: Wave System (Simplified)
```
private func spawnWave(in bounds: CGRect) {
    let baseEnemies = 3
    let scaling = currentWave / 2
    let waveEnemiesCount = min(baseEnemies + scaling, 20)

    for i in 0..<waveEnemiesCount {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.8) {
            self.enemyManager.spawnWaveEnemy(
                level: min(self.currentWave, 5),
                in: bounds,
                enemyZoneHeight: self.screenSplit.enemyRatio
            )
        }
    }

    currentWave += 1
    timeToNextWave = 10
}
```
Example: Star Merge Logic
```
private func checkForMerges() {
    for i in 0..<stars.count {
        for j in (i+1)..<stars.count {
            if stars[i].canMerge(with: stars[j]) &&
               stars[i].intersects(stars[j]) {
                performMerge(star1: stars[i], star2: stars[j])
                return
            }
        }
    }
}
```
### HUD Features

Score and currency display
Passive income per second
Current wave and countdown
Threat level indicator

### Active buffs
Game speed control (1x / 2x / 4x)
Game Over Conditions
Enemy territory exceeds ~95% of the screen
Player currency reaches zero due to enemy stealing

### Tech Stack
Language: Swift
UI Framework: SwiftUI
Architecture: MV-style with ObservableObject
Platform: iOS
Rendering: Native SwiftUI views
State Management: Combine

### Project Goals
Demonstrate clean SwiftUI game architecture
Explore territory-control mechanics
Prototype merge-based combat systems
Serve as a foundation for future content (skills, bosses, meta-progression)

## Status

🚧 Prototype / In-Development
This project focuses on gameplay systems and architecture clarity rather than production polish.

### Author
Created by Khamit
SwiftUI Game Prototype – 2025
