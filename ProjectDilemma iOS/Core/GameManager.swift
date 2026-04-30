// GameManager.swift

// Roguelike full reset on death
/*
 Author: Cameron Ridgley
 Worked on this caude while having claude in help with the methods and strutures from time to time
 Also having claude fix bugs when necessary
 */
import SpriteKit



enum GameState: Equatable {
    case mainMenu
    case overworld
    case battle(bossID: String)
    case upgradeSelect(bossID: String, outcome: BossOutcome)
    case dialogue
    case gameOver
    case victory
}

// MARK: - GameManager

final class GameManager {

    static let shared = GameManager()
    private init() {}



    private(set) var state: GameState = .mainMenu
    private(set) var currentFloor: Int = 1
    private(set) var defeatedBosses: Set<String> = []
    private(set) var befriendedBosses: Set<String> = []

    weak var scenePresenter: GameScenePresenter?

    // MARK: - Run lifetime size (avoids UIScreen.main.bounds zero-size issues)

    var sceneSize: CGSize = .zero

    // MARK: State Transitions

    func transition(to newState: GameState) {
        let oldState = state
        state = newState
        print("[GameManager] \(oldState) → \(newState)")
        handleTransition(from: oldState, to: newState)
    }

    private func handleTransition(from old: GameState, to new: GameState) {
        // Use the size set by GameViewController; fall back to a reasonable default
        // for landscape iPhones if not yet initialized.
        let size = sceneSize == .zero ? CGSize(width: 844, height: 390) : sceneSize

        switch new {
        case .mainMenu:
            scenePresenter?.present(scene: MenuScene(size: size))

        case .overworld:
            // Check for victory before showing overworld
            if currentFloor > BossConfig.all.count {
                transition(to: .victory)
                return
            }
            let scene = OverworldScene(size: size)
            scene.floor = currentFloor
            scenePresenter?.present(scene: scene)

        case .battle(let bossID):
            guard let config = BossConfig.config(for: bossID) else {
                print("[GameManager] No config for boss: \(bossID)")
                return
            }
            let scene = BattleScene(size: size, bossConfig: config)
            scenePresenter?.present(scene: scene)

        case .upgradeSelect(let bossID, let outcome):
            let scene = UpgradeScene(size: size, bossID: bossID, outcome: outcome)
            scenePresenter?.present(scene: scene)

        case .dialogue:
            break

        case .gameOver:
            scenePresenter?.present(scene: GameOverScene(size: size))

        case .victory:
            SaveManager.shared.recordRunEnd(outcome: .victory)  // logs + clears active
            scenePresenter?.present(scene: VictoryScene(size: size))
        }
    }

    // MARK: Boss Resolution

    /// Called by BattleScene when the boss is defeated or befriended.
    /// Routes through the upgrade selection scene before the next floor.
    func resolveBoss(id: String, outcome: BossOutcome) {
        switch outcome {
        case .defeated:
            defeatedBosses.insert(id)
        case .befriended:
            befriendedBosses.insert(id)
        }
        transition(to: .upgradeSelect(bossID: id, outcome: outcome))
    }

    /// Called by UpgradeScene after the player picks an upgrade.
    func advanceFromUpgrade() {
        currentFloor += 1
        SaveManager.shared.save()  // checkpoint after upgrade pick
        transition(to: .overworld)
    }

    func isBossResolved(_ id: String) -> Bool {
        defeatedBosses.contains(id) || befriendedBosses.contains(id)
    }

    // MARK: - Run lifecycle

    func startNewGame() {
        currentFloor = 1
        defeatedBosses = []
        befriendedBosses = []
        PlayerStats.shared.reset()
        SaveManager.shared.deleteSave()  // wipe any leftover save
        transition(to: .overworld)
    }

    /// Resume from a saved run.
    func continueGame() {
        guard SaveManager.shared.loadIntoSession() else {
            // No save — fall back to new game
            startNewGame()
            return
        }
        transition(to: .overworld)
    }

    /// Called when the player dies. Full roguelike reset, then back to menu.
    func handleDeath() {
        // Log the death BEFORE resetting — needs floor + boss state intact
        SaveManager.shared.recordRunEnd(outcome: .death)
        currentFloor = 1
        defeatedBosses = []
        befriendedBosses = []
        PlayerStats.shared.reset()
        transition(to: .gameOver)
    }

    /// Called from Overworld's pause/menu button. Returns to menu without losing progress.
    func returnToMainMenu() {
        transition(to: .mainMenu)
    }

    // MARK: - Save Restoration (internal setter)

    func setRunState(floor: Int, defeated: Set<String>, befriended: Set<String>) {
        currentFloor = floor
        defeatedBosses = defeated
        befriendedBosses = befriended
    }
}

// MARK: - Supporting Types

enum BossOutcome: Equatable {
    case defeated
    case befriended
}

// MARK: - Scene Presenter Protocol

protocol GameScenePresenter: AnyObject {
    func present(scene: SKScene)
}
