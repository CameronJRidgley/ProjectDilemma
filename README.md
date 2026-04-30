# ProjectDilemma

> *fight them. or make friends.*

A top-down turn-based roguelike for iPhone, built in Swift with SpriteKit, GameplayKit, and SwiftData. Every boss can be defeated **or** befriended — and the path you choose changes which upgrades you get.

Built by Cameron Ridgley for my CSC-291 Swift app development class.

---

## What is it?

You explore a procedurally-generated dungeon, fight (or talk to) the boss at the end, pick an upgrade, and move to the next floor. Survive 4 bosses to win. Die at any point and the run ends.

- 4 unique bosses, each with their own attack patterns and dialogue
- 21 upgrades across combat, social, and universal categories
- Path-aware reward system (fight bias vs. befriend bias)
- Persistent saves between sessions
- Run history tracked across all attempts

---

## Tech stack

- **Swift** — language
- **SpriteKit** — rendering, animation, scenes
- **GameplayKit** — entity-component system
- **SwiftData** — persistent saves and run history
- **UIKit** — app lifecycle and root view controller

No third-party dependencies. iOS 17 or later.

---

## How to build

1. Open `ProjectDilemma.xcodeproj` in Xcode 15+
2. Select an iPhone simulator (landscape orientation recommended)
3. Press **⌘R** to run

The game launches straight to the main menu.

---

## Project structure

```
ProjectDilemma/
├── Core/
│   ├── GameViewController.swift   — root UIKit view controller
│   ├── GameManager.swift           — state machine for screen transitions
│   ├── PlayerStats.swift           — live stats during a run
│   ├── SaveManager.swift           — SwiftData wrapper
│   └── SaveModels.swift            — @Model classes (ActiveSave, RunRecord)
├── Components/
│   └── Components.swift            — VisualComponent, HealthComponent, etc.
├── Systems/
│   └── TurnSystem.swift            — turn cycle controller
├── Generation/
│   └── DungeonGenerator.swift      — procgen floor builder
├── Data/
│   ├── BossConfig.swift            — boss definitions
│   ├── Upgrade.swift               — upgrade pool
│   └── ItemType.swift              — inventory items
└── Scenes/
    ├── StubScenes.swift            — Menu, GameOver, Victory
    ├── OverworldScene.swift        — exploration
    ├── BattleScene.swift           — turn-based combat
    └── UpgradeScene.swift          — post-boss reward picker
```

---

## How a run flows

```
Main Menu
   ↓
Floor 1 Overworld  →  Boss Door  →  Battle  →  Upgrade  →  Floor 2
                                       ↓
                                  Game Over (on death)
                                       ↓
                                   Main Menu

(repeat through Floor 4 → Victory)
```

Save fires after every upgrade pick. Death wipes the save.

---

## Controls

**Overworld**
- D-pad (lower-left) to move
- Walk into objects to interact (chests, fountains, enemies)
- MENU button (top-right) to save and quit

**Battle**
- FIGHT — deal damage
- ACT — befriend through dialogue
- ITEM — use an inventory item
- SPARE — attempt to befriend (only succeeds when condition is met)
- During boss attacks, drag the soul D-pad to dodge bullets

---

## Bosses

| Floor | Boss | Befriend by |
|-------|------|-------------|
| 1 | Sir Mudwick | Compliment his mud 3 times |
| 2 | Glimmerbell | Listen to her sing 4 times |
| 3 | Thornvex | Don't attack for 5 turns |
| 4 | Dr. Muhammad | Befriend all 3 prior bosses first |

---

## Resources I used

- Apple SpriteKit, GameplayKit, and SwiftData documentation
- Viktor Gordienko's blog post: *How (and why) I made a game in Swift*
- YouTube SpriteKit tutorials
- AI assistance for debugging hard issues

