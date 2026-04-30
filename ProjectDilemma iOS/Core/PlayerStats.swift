// PlayerStats.swift
/*
 Author: Cameron Ridgley
 Worked on this caude while having claude in help with the methods and strutures from time to time
 Also having claude fix bugs when necessary
 */

import Foundation

final class PlayerStats {

    static let shared = PlayerStats()
    private init() {}

   

    var maxHP: Int = 20
    var currentHP: Int = 20
    var attack: Int = 5
    var defense: Int = 2
    var gold: Int = 0
    var level: Int = 1

    // Inventory

    var items: [ItemType] = []

    // Soul battle self

    var soulSpeed: CGFloat = 180

    //Upgrade State

    private(set) var ownedUpgrades: Set<String> = []
    private(set) var critChance: CGFloat = 0
    private(set) var lifestealFraction: CGFloat = 0
    private(set) var actMultiplier: Int = 1
    private(set) var allyHealPerTurn: Int = 0
    private(set) var hasSecondWind: Bool = false
    private(set) var secondWindAvailable: Bool = false
    private(set) var turnHealAmount: Int = 0   // heals N HP per battle turn



    var isAlive: Bool { currentHP > 0 }

    var hpFraction: CGFloat {
        CGFloat(currentHP) / CGFloat(maxHP)
    }

    

    /// Returns true if the player would die from this damage but Second Wind saves them.
    @discardableResult
    func takeDamage(_ amount: Int) -> Bool {
        let reduced = max(1, amount - defense)
        let predictedHP = currentHP - reduced

        if predictedHP <= 0 && secondWindAvailable {
            currentHP = 1
            secondWindAvailable = false
            return true
        }
        currentHP = max(0, predictedHP)
        return false
    }

    func heal(_ amount: Int) {
        currentHP = min(maxHP, currentHP + amount)
    }

    func lifestealHeal(damageDealt: Int) {
        guard lifestealFraction > 0 else { return }
        let healed = max(1, Int(CGFloat(damageDealt) * lifestealFraction))
        heal(healed)
    }



    func apply(_ upgrade: Upgrade) {
        ownedUpgrades.insert(upgrade.id)

        switch upgrade.effect {
        case .attackBonus(let v):
            attack += v
        case .maxHPBonus(let v):
            maxHP += v
            currentHP += v
        case .defenseBonus(let v):
            defense += v
        case .soulSpeedBonus(let v):
            soulSpeed += v
        case .actMultiplier(let v):
            actMultiplier = max(actMultiplier, v)
        case .critChance(let v):
            critChance = min(1.0, critChance + v)
        case .lifesteal(let v):
            lifestealFraction = min(1.0, lifestealFraction + v)
        case .allyHealPerTurn(let v):
            allyHealPerTurn += v
        case .secondWind:
            hasSecondWind = true
            secondWindAvailable = true
        case .allStatsBonus(let v):
            attack  += v
            defense += v
            maxHP   += v
            currentHP += v

        
        case .berserker:
            attack += 4
            defense = max(0, defense - 1)
        case .bloodPact:
            attack += 5
            maxHP += 5
            currentHP += 5
        case .gentleSoul:
            soulSpeed += 50
            defense += 3
        case .turnHeal(let v):
            turnHealAmount += v
        case .goldBonus(let v):
            gold += v
        case .luckySeven:
            maxHP += 7
            heal(maxHP)  // full heal
        }
    }

    // MARK: - Reset (on death)

    func reset() {
        maxHP = 20
        currentHP = 20
        attack = 5
        defense = 2
        gold = 0
        level = 1
        items = []
        soulSpeed = 180

        ownedUpgrades = []
        critChance = 0
        lifestealFraction = 0
        actMultiplier = 1
        allyHealPerTurn = 0
        hasSecondWind = false
        secondWindAvailable = false
        turnHealAmount = 0
    }

    // MARK: - Save Restoration (internal setters)

    func setOwnedUpgrades(_ value: Set<String>) { ownedUpgrades = value }
    func setCritChance(_ value: CGFloat) { critChance = value }
    func setLifestealFraction(_ value: CGFloat) { lifestealFraction = value }
    func setActMultiplier(_ value: Int) { actMultiplier = value }
    func setAllyHealPerTurn(_ value: Int) { allyHealPerTurn = value }
    func setSecondWind(has: Bool, available: Bool) {
        hasSecondWind = has
        secondWindAvailable = available
    }
    func setTurnHealAmount(_ value: Int) { turnHealAmount = value }
}
