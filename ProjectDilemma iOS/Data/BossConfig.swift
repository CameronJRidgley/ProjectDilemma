// BossConfig.swift
/*
 Author: Cameron Ridgley
 Worked on this caude while having claude in help with the methods and strutures from time to time
 Also having claude fix bugs when necessary
 */

import Foundation

// MARK: - Befriend Condition

enum BefriendCondition {
    case actUsed(String, times: Int)   // use a named Act N times
    case hpBelow(fraction: CGFloat)    // spare when boss HP < X%
    case turnsWithoutAttack(Int)       // don't attack for N turns
    case itemUsed(ItemType)            // use a specific item
}

// MARK: - Attack Pattern Types

enum AttackPatternType {
    case spreadShot(count: Int, speed: CGFloat)
    case chaseWave(speed: CGFloat)
    case ringBurst(count: Int, speed: CGFloat)
    case lineBarrage(lanes: Int, speed: CGFloat)
    case randomBounce(count: Int, speed: CGFloat)
    case homingShot(count: Int, speed: CGFloat)        // tracks soul over time
    case delayedRing(count: Int, speed: CGFloat)       // marks then fires after delay
    case crossFire(speed: CGFloat)                     // bullets from all 4 box edges
}

// MARK: - BossConfig

struct BossConfig {
    let id: String
    let name: String
    let subtitle: String
    let maxHP: Int
    let attackPatterns: [AttackPatternType]
    let befriendCondition: BefriendCondition
    let flavorText: String                 // shown in battle intro
    let fightVictoryDialogue: [String]     // lines after defeat
    let befriendVictoryDialogue: [String]  // lines after befriending
    let actOptions: [ActOption]            // choices in ACT menu

    // MARK: - All Bosses Registry

    static let all: [BossConfig] = [
        mudwick,
        glimmerbell,
        thornvex,
        drMuhammad
    ]

    static func config(for id: String) -> BossConfig? {
        all.first { $0.id == id }
    }
}

// MARK: - Act Option

struct ActOption {
    let name: String           // e.g. "Compliment", "Taunt", "Listen"
    let description: String    // shown in HUD
    let effect: ActEffect
}

enum ActEffect {
    case progressBefriend(amount: Int)   // moves toward befriend condition
    case heal(amount: Int)               // heals player
    case weakenBoss(turnsRemaining: Int) // boss skips N turns
    case revealInfo                      // reveals befriend hint
}

// MARK: - Boss Definitions

extension BossConfig {

    // Floor 1 — Sir Mudwick
    static let mudwick = BossConfig(
        id: "mudwick",
        name: "Sir Mudwick",
        subtitle: "The Earl of Swamp",
        maxHP: 60,
        attackPatterns: [
            .spreadShot(count: 5, speed: 120),
            .randomBounce(count: 3, speed: 100),
            .ringBurst(count: 6, speed: 110),
            .chaseWave(speed: 130),
            .lineBarrage(lanes: 3, speed: 140),
            .delayedRing(count: 5, speed: 120)
        ],
        befriendCondition: .actUsed("Compliment", times: 3),
        flavorText: "A muddy knight who guards the first dungeon. Deeply insecure about his appearance.",
        fightVictoryDialogue: [
            "Splat... you bested me...",
            "The mud... returns to mud..."
        ],
        befriendVictoryDialogue: [
            "You... you think my mud is beautiful?",
            "No one has ever said that before.",
            "Fine. I'll let you pass. But don't tell anyone I cried."
        ],
        actOptions: [
            ActOption(name: "Compliment", description: "Compliment Sir Mudwick's mud.", effect: .progressBefriend(amount: 1)),
            ActOption(name: "Taunt",      description: "Mock the mud. Probably a bad idea.", effect: .weakenBoss(turnsRemaining: 1)),
            ActOption(name: "Inspect",    description: "Study his attack patterns.", effect: .revealInfo)
        ]
    )

    // Floor 2 — Glimmerbell (rebalanced — befriend by listening, not by HP)
    static let glimmerbell = BossConfig(
        id: "glimmerbell",
        name: "Glimmerbell",
        subtitle: "The Radiant Hermit",
        maxHP: 90,
        attackPatterns: [
            .ringBurst(count: 8, speed: 140),
            .lineBarrage(lanes: 3, speed: 160),
            .spreadShot(count: 7, speed: 150),
            .delayedRing(count: 8, speed: 130),
            .chaseWave(speed: 150),
            .crossFire(speed: 140)
        ],
        befriendCondition: .actUsed("Listen", times: 4),
        flavorText: "A lantern spirit who hasn't spoken to anyone in 200 years. She attacks out of loneliness.",
        fightVictoryDialogue: [
            "The light... finally fades...",
            "Perhaps this is a relief."
        ],
        befriendVictoryDialogue: [
            "You stayed. Even when I was awful to you.",
            "I've been alone for so long I forgot how to ask for company.",
            "Will you... visit again?"
        ],
        actOptions: [
            ActOption(name: "Listen",  description: "Just listen to her quietly.", effect: .progressBefriend(amount: 1)),
            ActOption(name: "Sing",    description: "Hum a tune. She seems to soften.", effect: .progressBefriend(amount: 1)),
            ActOption(name: "Endure",  description: "Show her you won't run away.", effect: .weakenBoss(turnsRemaining: 2))
        ]
    )

    // Floor 3 — Thornvex
    static let thornvex = BossConfig(
        id: "thornvex",
        name: "Thornvex",
        subtitle: "The Briar Warlord",
        maxHP: 130,
        attackPatterns: [
            .chaseWave(speed: 170),
            .spreadShot(count: 12, speed: 150),
            .ringBurst(count: 16, speed: 130),
            .randomBounce(count: 6, speed: 140),
            .homingShot(count: 3, speed: 100),
            .crossFire(speed: 160)
        ],
        befriendCondition: .turnsWithoutAttack(5),
        flavorText: "An ancient beast of thorns. He respects only those who show restraint.",
        fightVictoryDialogue: [
            "STRENGTH... was not enough.",
            "The thorns wither."
        ],
        befriendVictoryDialogue: [
            "Five turns. You did not strike.",
            "You understand. Power is not cruelty.",
            "Walk with me, then. Not behind me."
        ],
        actOptions: [
            ActOption(name: "Bow",      description: "Show respect without speaking.", effect: .progressBefriend(amount: 1)),
            ActOption(name: "Provoke",  description: "A risky gambit — weakens him but delays befriend.", effect: .weakenBoss(turnsRemaining: 1)),
            ActOption(name: "Offer",    description: "Offer an item as tribute.", effect: .progressBefriend(amount: 2))
        ]
    )

    // Floor 4 — Dr. Muhammad (final boss, 2 phases)
    // Befriend condition: must have befriended ALL 3 prior bosses.
    // This is checked specially in BattleScene since the condition is meta-state.
    static let drMuhammad = BossConfig(
        id: "drMuhammad",
        name: "Dr. Muhammad",
        subtitle: "Your Teacher",
        maxHP: 150,  // phase 1 — drops to 100 max in phase 2
        attackPatterns: [
            .lineBarrage(lanes: 4, speed: 180),
            .spreadShot(count: 8, speed: 170),
            .ringBurst(count: 12, speed: 160),
            .homingShot(count: 4, speed: 110),
            .delayedRing(count: 10, speed: 170),
            .crossFire(speed: 180)
        ],
        befriendCondition: .actUsed("Apologize", times: 999), // sentinel — real check is in BattleScene
        flavorText: "Dr. Muhammad. Your teacher. She is calm. You feel a fear you cannot name.",
        fightVictoryDialogue: [
            "Hmph.",
            "I expected nothing less.",
            "...you may go."
        ],
        befriendVictoryDialogue: [
            "I see you have learned.",
            "Strength without kindness is just noise.",
            "You have not just survived, you have grown.",
            "...class dismissed."
        ],
        actOptions: [
            ActOption(name: "Apologize",  description: "Whatever you did, apologize for it.", effect: .progressBefriend(amount: 1)),
            ActOption(name: "Stand Tall", description: "Refuse to be intimidated. Risky.", effect: .weakenBoss(turnsRemaining: 1)),
            ActOption(name: "Listen",     description: "Listen carefully to her words.", effect: .revealInfo)
        ]
    )
}
