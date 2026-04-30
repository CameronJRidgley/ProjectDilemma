// TurnSystem.swift
// Manages the player ↔ boss turn cycle in BattleScene.
/*
 Author: Cameron Ridgley
 Worked on this caude while having claude in help with the methods and strutures from time to time
 Also having claude fix bugs when necessary
 */
import Foundation

// MARK: - Turn Phase

enum TurnPhase: Equatable {
    case playerChoosing
    case playerAction
    case bossAttacking
    case resolution
    case dialogue                
}

// MARK: - Player Action Choice

enum PlayerAction {
    case fight
    case act(ActOption)
    case item(ItemType)
    case spare
}



final class TurnSystem {

  

    private(set) var phase: TurnPhase = .playerChoosing
    private(set) var turnNumber: Int = 0
    private(set) var bossSkipTurns: Int = 0

   
    var onPhaseChanged: ((TurnPhase) -> Void)?
    var onPlayerFight: (() -> Void)?
    var onPlayerAct: ((ActOption) -> Void)?
    var onPlayerItem: ((ItemType) -> Void)?
    var onPlayerSpare: (() -> Void)?
    var onBossAttack: ((AttackPatternType) -> Void)?
    var onBefriendCheck: (() -> Void)?
    var onDefeatCheck: (() -> Void)?

    // MARK: - Player Input

    func playerChose(_ action: PlayerAction) {
        guard phase == .playerChoosing else { return }
        transition(to: .playerAction)

        switch action {
        case .fight:
            onPlayerFight?()

        case .act(let option):
            onPlayerAct?(option)
           
            if case .weakenBoss(let t) = option.effect {
                bossSkipTurns += t
            }

        case .item(let item):
            onPlayerItem?(item)

        case .spare:
            onPlayerSpare?()
        }
    }

   
    func playerActionFinished(bossAttackPattern: AttackPatternType) {
        guard phase == .playerAction else { return }

        if bossSkipTurns > 0 {
            bossSkipTurns -= 1
            
            transition(to: .resolution)
            onBefriendCheck?()
            onDefeatCheck?()
        } else {
            transition(to: .bossAttacking)
            onBossAttack?(bossAttackPattern)
        }
    }

  
    func bossAttackFinished() {
        guard phase == .bossAttacking else { return }
        turnNumber += 1
        transition(to: .resolution)
        onBefriendCheck?()
        onDefeatCheck?()
    }

   
    func beginNextTurn() {
        transition(to: .playerChoosing)
    }



    private func transition(to newPhase: TurnPhase) {
        print(">>> TurnSystem: \(phase) → \(newPhase)")
        phase = newPhase
        onPhaseChanged?(newPhase)
    }
}
