// SaveManager.swift
/*
 Author: Cameron Ridgley
 Worked on this caude while having claude in help with the methods and strutures from time to time
 Also having claude fix bugs when necessary
 */
import Foundation
import SwiftData



final class SaveManager {

    static let shared = SaveManager()

    private var container: ModelContainer?
    private var context: ModelContext? {
        guard let container else { return nil }
        return ModelContext(container)
    }

    private init() {
        do {
            container = try ModelContainer(for: ActiveSave.self, RunRecord.self)
        } catch {
            print("[SaveManager] Failed to create ModelContainer: \(error)")
        }
    }



    var hasSave: Bool {
        loadActive() != nil
    }

    func savePreview() -> (floor: Int, savedAt: Date)? {
        guard let active = loadActive() else { return nil }
        return (active.floor, active.savedAt)
    }

    private func loadActive() -> ActiveSave? {
        guard let context else { return nil }
        let descriptor = FetchDescriptor<ActiveSave>()
        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            print("[SaveManager] Failed to fetch ActiveSave: \(error)")
            return nil
        }
    }

//Save / Load
    //copilot helped me a ton wtih this
    /// Capture current state into ActiveSave (overwrites any existing one).
    func save() {
        guard let context else { return }

        // Wipe any existing active save first (we only keep one)
        deleteActive(in: context)

        let stats = PlayerStats.shared
        let game = GameManager.shared

        let active = ActiveSave(
            floor: game.currentFloor,
            defeatedBosses: Array(game.defeatedBosses),
            befriendedBosses: Array(game.befriendedBosses),
            maxHP: stats.maxHP,
            currentHP: stats.currentHP,
            attack: stats.attack,
            defense: stats.defense,
            gold: stats.gold,
            level: stats.level,
            soulSpeed: Double(stats.soulSpeed),
            items: stats.items.map { $0.rawValue },
            ownedUpgrades: Array(stats.ownedUpgrades),
            critChance: Double(stats.critChance),
            lifestealFraction: Double(stats.lifestealFraction),
            actMultiplier: stats.actMultiplier,
            allyHealPerTurn: stats.allyHealPerTurn,
            hasSecondWind: stats.hasSecondWind,
            secondWindAvailable: stats.secondWindAvailable,
            turnHealAmount: stats.turnHealAmount,
            savedAt: Date()
        )

        context.insert(active)
        do {
            try context.save()
            print("[SaveManager] Saved run at floor \(active.floor)")
        } catch {
            print("[SaveManager] Failed to save: \(error)")
        }
    }

    @discardableResult
    func loadIntoSession() -> Bool {
        guard let active = loadActive() else { return false }

        PlayerStats.shared.applyActiveSave(active)
        GameManager.shared.applyActiveSave(active)

        print("[SaveManager] Loaded run from floor \(active.floor)")
        return true
    }

    func deleteSave() {
        guard let context else { return }
        deleteActive(in: context)
        do {
            try context.save()
            print("[SaveManager] Save deleted")
        } catch {
            print("[SaveManager] Failed to delete save: \(error)")
        }
    }

    private func deleteActive(in context: ModelContext) {
        let descriptor = FetchDescriptor<ActiveSave>()
        if let existing = try? context.fetch(descriptor) {
            for save in existing {
                context.delete(save)
            }
        }
    }

    // MARK: - Run History

    /// Log a completed run (victory or death). Auto-deletes the active save.
    func recordRunEnd(outcome: RunRecord.Outcome) {
        guard let context else { return }

        let game = GameManager.shared
        let record = RunRecord(
            outcome: outcome,
            floorReached: game.currentFloor,
            defeatedBosses: Array(game.defeatedBosses),
            befriendedBosses: Array(game.befriendedBosses),
            endedAt: Date()
        )
        context.insert(record)

        // Wipe active save — run is over either way
        deleteActive(in: context)

        do {
            try context.save()
            print("[SaveManager] Recorded \(outcome.rawValue) at floor \(record.floorReached)")
        } catch {
            print("[SaveManager] Failed to record run: \(error)")
        }
    }

    /// Fetch recent runs, newest first.
    func recentRuns(limit: Int = 5) -> [RunRecord] {
        guard let context else { return [] }
        var descriptor = FetchDescriptor<RunRecord>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        do {
            return try context.fetch(descriptor)
        } catch {
            print("[SaveManager] Failed to fetch run history: \(error)")
            return []
        }
    }

    /// Aggregate stats across all logged runs.
    func aggregateStats() -> (totalRuns: Int, victories: Int, highestFloor: Int) {
        guard let context else { return (0, 0, 0) }
        do {
            let all = try context.fetch(FetchDescriptor<RunRecord>())
            let victories = all.filter { $0.outcome == .victory }.count
            let highest = all.map { $0.floorReached }.max() ?? 0
            return (all.count, victories, highest)
        } catch {
            return (0, 0, 0)
        }
    }
}

// MARK: - PlayerStats restore helper

extension PlayerStats {
    func applyActiveSave(_ save: ActiveSave) {
        maxHP = save.maxHP
        currentHP = save.currentHP
        attack = save.attack
        defense = save.defense
        gold = save.gold
        level = save.level
        soulSpeed = CGFloat(save.soulSpeed)
        items = save.items.compactMap { ItemType(rawValue: $0) }

        setOwnedUpgrades(Set(save.ownedUpgrades))
        setCritChance(CGFloat(save.critChance))
        setLifestealFraction(CGFloat(save.lifestealFraction))
        setActMultiplier(save.actMultiplier)
        setAllyHealPerTurn(save.allyHealPerTurn)
        setSecondWind(has: save.hasSecondWind, available: save.secondWindAvailable)
        setTurnHealAmount(save.turnHealAmount)
    }
}

// MARK: - GameManager restore helper

extension GameManager {
    func applyActiveSave(_ save: ActiveSave) {
        setRunState(
            floor: save.floor,
            defeated: Set(save.defeatedBosses),
            befriended: Set(save.befriendedBosses)
        )
    }
}
