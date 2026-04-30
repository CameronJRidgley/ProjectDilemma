// Upgrade.swift
/*
 Author: Cameron Ridgley
 Worked on this caude while having claude in help with the methods and strutures from time to time
 Also having claude fix bugs when necessary
 */

import Foundation



enum UpgradeCategory {
    case combat     // weighted toward fight-victory players
    case social     // weighted toward befriend-victory players
    case universal  // appears for both
}

// MARK: - Upgrade Effect

enum UpgradeEffect {
    case attackBonus(Int)
    case maxHPBonus(Int)
    case defenseBonus(Int)
    case soulSpeedBonus(CGFloat)
    case actMultiplier(Int)              // ACT progress counts as N
    case critChance(CGFloat)             // 0.0–1.0 chance to deal double damage
    case lifesteal(CGFloat)              // fraction of damage healed
    case allyHealPerTurn(Int)            // befriended allies heal per turn next battle
    case secondWind                      // survive lethal damage once at 1 HP
    case allStatsBonus(Int)              // +N to attack, defense, max HP

    // New combo effects
    case berserker                       // +4 atk, -1 def
    case bloodPact                       // +5 atk, +5 max hp
    case gentleSoul                      // +50 soul speed, +3 def
    case turnHeal(Int)                   // heal N HP every battle turn
    case goldBonus(Int)                  // gain N gold immediately
    case luckySeven                      // +7 max hp + full heal
}

// MARK: - Upgrade Definition

struct Upgrade {
    let id: String
    let name: String
    let description: String
    let category: UpgradeCategory
    let effect: UpgradeEffect

    // MARK: All Upgrades

    static let all: [Upgrade] = [
        // --- Combat ---
        Upgrade(
            id: "sharper_blade",
            name: "Sharper Blade",
            description: "+2 Attack",
            category: .combat,
            effect: .attackBonus(2)
        ),
        Upgrade(
            id: "iron_will",
            name: "Iron Will",
            description: "+5 Max HP",
            category: .combat,
            effect: .maxHPBonus(5)
        ),
        Upgrade(
            id: "critical_eye",
            name: "Critical Eye",
            description: "20% chance to deal double damage",
            category: .combat,
            effect: .critChance(0.20)
        ),
        Upgrade(
            id: "vampiric_edge",
            name: "Vampiric Edge",
            description: "Heal 25% of damage dealt",
            category: .combat,
            effect: .lifesteal(0.25)
        ),
        Upgrade(
            id: "stone_skin",
            name: "Stone Skin",
            description: "+2 Defense",
            category: .combat,
            effect: .defenseBonus(2)
        ),
        Upgrade(
            id: "berserker",
            name: "Berserker",
            description: "+4 Attack, -1 Defense",
            category: .combat,
            effect: .berserker
        ),
        Upgrade(
            id: "deadly_aim",
            name: "Deadly Aim",
            description: "+15% crit chance",
            category: .combat,
            effect: .critChance(0.15)
        ),
        Upgrade(
            id: "blood_pact",
            name: "Blood Pact",
            description: "+5 Attack, +5 Max HP",
            category: .combat,
            effect: .bloodPact
        ),

        // --- Social ---
        Upgrade(
            id: "silver_tongue",
            name: "Silver Tongue",
            description: "ACT progress counts double",
            category: .social,
            effect: .actMultiplier(2)
        ),
        Upgrade(
            id: "quick_heart",
            name: "Quick Heart",
            description: "+30 Soul speed (dodge faster)",
            category: .social,
            effect: .soulSpeedBonus(30)
        ),
        Upgrade(
            id: "empath",
            name: "Empath",
            description: "Befriended allies heal you +5 HP per turn",
            category: .social,
            effect: .allyHealPerTurn(5)
        ),
        Upgrade(
            id: "warm_aura",
            name: "Warm Aura",
            description: "+10 Max HP",
            category: .social,
            effect: .maxHPBonus(10)
        ),
        Upgrade(
            id: "diplomat",
            name: "Diplomat",
            description: "ACT progress counts triple",
            category: .social,
            effect: .actMultiplier(3)
        ),
        Upgrade(
            id: "gentle_soul",
            name: "Gentle Soul",
            description: "+50 Soul speed and +3 Defense",
            category: .social,
            effect: .gentleSoul
        ),
        Upgrade(
            id: "kind_words",
            name: "Kind Words",
            description: "Heal 3 HP after every battle turn",
            category: .social,
            effect: .turnHeal(3)
        ),

        // --- Universal ---
        Upgrade(
            id: "lucky_charm",
            name: "Lucky Charm",
            description: "+1 to all stats",
            category: .universal,
            effect: .allStatsBonus(1)
        ),
        Upgrade(
            id: "second_wind",
            name: "Second Wind",
            description: "Survive lethal damage once per run",
            category: .universal,
            effect: .secondWind
        ),
        Upgrade(
            id: "treasure_hunter",
            name: "Treasure Hunter",
            description: "Gain 25 gold immediately",
            category: .universal,
            effect: .goldBonus(25)
        ),
        Upgrade(
            id: "wanderers_boots",
            name: "Wanderer's Boots",
            description: "+3 to all stats",
            category: .universal,
            effect: .allStatsBonus(3)
        ),
        Upgrade(
            id: "lucky_seven",
            name: "Lucky Seven",
            description: "+7 Max HP and full heal",
            category: .universal,
            effect: .luckySeven
        )
    ]

    // MARK: - Selection

    /// Returns 3 upgrades weighted by the boss outcome.
    static func selectChoices(for outcome: BossOutcome, alreadyOwned: Set<String>) -> [Upgrade] {
        let available = all.filter { !alreadyOwned.contains($0.id) }
        guard !available.isEmpty else { return [] }

        // Build weighted pool
        var weighted: [(Upgrade, Int)] = []
        for upgrade in available {
            let weight: Int
            switch (outcome, upgrade.category) {
            case (.defeated, .combat):    weight = 5
            case (.defeated, .social):    weight = 1
            case (.defeated, .universal): weight = 3
            case (.befriended, .combat):  weight = 1
            case (.befriended, .social):  weight = 5
            case (.befriended, .universal): weight = 3
            }
            weighted.append((upgrade, weight))
        }

        var picks: [Upgrade] = []
        var pool = weighted
        for _ in 0..<min(3, pool.count) {
            let total = pool.reduce(0) { $0 + $1.1 }
            guard total > 0 else { break }
            var roll = Int.random(in: 0..<total)
            for (i, entry) in pool.enumerated() {
                roll -= entry.1
                if roll < 0 {
                    picks.append(entry.0)
                    pool.remove(at: i)
                    break
                }
            }
        }
        return picks
    }
}
