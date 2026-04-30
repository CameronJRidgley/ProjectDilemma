// SaveModels.swift
/*
 Author: Cameron Ridgley
 Worked on this caude while having claude in help with the methods and strutures from time to time
 Also having claude fix bugs when necessary
 */

import Foundation
import SwiftData



@Model
final class ActiveSave {

    // Run progress
    var floor: Int
    var defeatedBosses: [String]
    var befriendedBosses: [String]

    // Player stats
    var maxHP: Int
    var currentHP: Int
    var attack: Int
    var defense: Int
    var gold: Int
    var level: Int
    var soulSpeed: Double
    var items: [String]

    // Upgrade state
    var ownedUpgrades: [String]
    var critChance: Double
    var lifestealFraction: Double
    var actMultiplier: Int
    var allyHealPerTurn: Int
    var hasSecondWind: Bool
    var secondWindAvailable: Bool
    var turnHealAmount: Int

    // Metadata
    var savedAt: Date

    init(
        floor: Int,
        defeatedBosses: [String],
        befriendedBosses: [String],
        maxHP: Int,
        currentHP: Int,
        attack: Int,
        defense: Int,
        gold: Int,
        level: Int,
        soulSpeed: Double,
        items: [String],
        ownedUpgrades: [String],
        critChance: Double,
        lifestealFraction: Double,
        actMultiplier: Int,
        allyHealPerTurn: Int,
        hasSecondWind: Bool,
        secondWindAvailable: Bool,
        turnHealAmount: Int,
        savedAt: Date
    ) {
        self.floor = floor
        self.defeatedBosses = defeatedBosses
        self.befriendedBosses = befriendedBosses
        self.maxHP = maxHP
        self.currentHP = currentHP
        self.attack = attack
        self.defense = defense
        self.gold = gold
        self.level = level
        self.soulSpeed = soulSpeed
        self.items = items
        self.ownedUpgrades = ownedUpgrades
        self.critChance = critChance
        self.lifestealFraction = lifestealFraction
        self.actMultiplier = actMultiplier
        self.allyHealPerTurn = allyHealPerTurn
        self.hasSecondWind = hasSecondWind
        self.secondWindAvailable = secondWindAvailable
        self.turnHealAmount = turnHealAmount
        self.savedAt = savedAt
    }
}



@Model
final class RunRecord {

    enum Outcome: String, Codable {
        case victory
        case death
    }

    var outcomeRaw: String
    var floorReached: Int
    var defeatedBosses: [String]
    var befriendedBosses: [String]
    var endedAt: Date

    var outcome: Outcome {
        Outcome(rawValue: outcomeRaw) ?? .death
    }

    init(outcome: Outcome,
         floorReached: Int,
         defeatedBosses: [String],
         befriendedBosses: [String],
         endedAt: Date)
    {
        self.outcomeRaw = outcome.rawValue
        self.floorReached = floorReached
        self.defeatedBosses = defeatedBosses
        self.befriendedBosses = befriendedBosses
        self.endedAt = endedAt
    }
}
