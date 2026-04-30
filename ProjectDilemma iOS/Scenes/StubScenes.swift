// StubScenes.swift
// MenuScene (with save support), GameOverScene, VictoryScene.
/*
 Author: Cameron Ridgley
 Worked on this caude while having claude in help with the methods and strutures from time to time
 Also having claude fix bugs when necessary
 */
import SpriteKit

// MARK: - MenuScene

final class MenuScene: SKScene {

    private var continueBtn: SKLabelNode?
    private var newGameBtn: SKLabelNode!
    private var savePreviewLabel: SKLabelNode?
    private var confirmOverlay: SKNode?

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.05, alpha: 1)

        // Title
        let title = SKLabelNode(fontNamed: "Courier-Bold")
        title.text = "DUNGEON PALS"
        title.fontSize = 36
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.78)
        addChild(title)

        let subtitle = SKLabelNode(fontNamed: "Courier")
        subtitle.text = "fight them. or make friends."
        subtitle.fontSize = 14
        subtitle.fontColor = SKColor(white: 0.55, alpha: 1)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.71)
        addChild(subtitle)

        setupMenuButtons()
        setupRunHistory()
    }

    private func setupRunHistory() {
        let recent = SaveManager.shared.recentRuns(limit: 5)
        let stats = SaveManager.shared.aggregateStats()

        guard stats.totalRuns > 0 else { return }

        // Stats line
        let statsLine = SKLabelNode(fontNamed: "Courier")
        statsLine.text = "RUNS: \(stats.totalRuns)   WINS: \(stats.victories)   BEST: FLOOR \(stats.highestFloor)"
        statsLine.fontSize = 11
        statsLine.fontColor = SKColor(white: 0.55, alpha: 1)
        statsLine.position = CGPoint(x: size.width / 2, y: size.height * 0.18)
        addChild(statsLine)

        // Recent runs header
        let header = SKLabelNode(fontNamed: "Courier-Bold")
        header.text = "— recent runs —"
        header.fontSize = 10
        header.fontColor = SKColor(white: 0.4, alpha: 1)
        header.position = CGPoint(x: size.width / 2, y: size.height * 0.13)
        addChild(header)

        // Each recent run as a single line
        for (i, run) in recent.enumerated() {
            let icon = run.outcome == .victory ? "✓" : "✗"
            let color: SKColor = run.outcome == .victory ? .systemGreen : .systemRed
            let line = SKLabelNode(fontNamed: "Courier")
            line.text = "\(icon) floor \(run.floorReached)  ·  befriended \(run.befriendedBosses.count)  ·  defeated \(run.defeatedBosses.count)"
            line.fontSize = 10
            line.fontColor = color
            line.position = CGPoint(x: size.width / 2, y: size.height * 0.10 - CGFloat(i) * 14)
            line.alpha = max(0.3, 1.0 - CGFloat(i) * 0.15)  // fade older entries
            addChild(line)
        }
    }

    private func setupMenuButtons() {
        let hasSave = SaveManager.shared.hasSave

        var buttonY: CGFloat = size.height * 0.55

        if hasSave, let preview = SaveManager.shared.savePreview() {
            // Continue button
            let cont = SKLabelNode(fontNamed: "Courier-Bold")
            cont.text = "[ CONTINUE ]"
            cont.name = "continue"
            cont.fontSize = 22
            cont.fontColor = .systemYellow
            cont.position = CGPoint(x: size.width / 2, y: buttonY)
            addChild(cont)
            continueBtn = cont

            // Save preview label
            let preview_ = SKLabelNode(fontNamed: "Courier")
            preview_.text = "Floor \(preview.floor) — \(timeString(preview.savedAt))"
            preview_.fontSize = 11
            preview_.fontColor = SKColor(white: 0.55, alpha: 1)
            preview_.position = CGPoint(x: size.width / 2, y: buttonY - 22)
            addChild(preview_)
            savePreviewLabel = preview_

            buttonY -= 60
        }

        // New Game button
        newGameBtn = SKLabelNode(fontNamed: "Courier-Bold")
        newGameBtn.text = "[ NEW GAME ]"
        newGameBtn.name = "newgame"
        newGameBtn.fontSize = hasSave ? 18 : 22
        newGameBtn.fontColor = hasSave ? SKColor(white: 0.7, alpha: 1) : .systemYellow
        newGameBtn.position = CGPoint(x: size.width / 2, y: buttonY)
        addChild(newGameBtn)

        // Blink the primary button
        let primary: SKLabelNode = hasSave ? (continueBtn ?? newGameBtn) : newGameBtn
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.55, duration: 0.55),
            SKAction.fadeAlpha(to: 1.0,  duration: 0.55)
        ])
        primary.run(SKAction.repeatForever(blink), withKey: "blink")
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }

  

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let loc = touches.first?.location(in: self) else { return }

        // If confirm overlay is up, route touches there only
        if confirmOverlay != nil {
            handleConfirmTouch(at: loc)
            return
        }

        let nodes = self.nodes(at: loc)
        for node in nodes {
            switch node.name {
            case "continue":
                GameManager.shared.continueGame()
            case "newgame":
                if SaveManager.shared.hasSave {
                    showConfirmNewGame()
                } else {
                    GameManager.shared.startNewGame()
                }
            default:
                break
            }
        }
    }

    // MARK: - Confirm New Game (when save exists)

    private func showConfirmNewGame() {
        let overlay = SKNode()
        overlay.zPosition = 100

        let bg = SKShapeNode(rectOf: size)
        bg.fillColor = SKColor(white: 0, alpha: 0.85)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(bg)

        let warn = SKLabelNode(fontNamed: "Courier-Bold")
        warn.text = "START A NEW RUN?"
        warn.fontSize = 22
        warn.fontColor = .systemRed
        warn.position = CGPoint(x: size.width / 2, y: size.height * 0.6)
        overlay.addChild(warn)

        let detail = SKLabelNode(fontNamed: "Courier")
        detail.text = "This will erase your current save."
        detail.fontSize = 13
        detail.fontColor = .white
        detail.position = CGPoint(x: size.width / 2, y: size.height * 0.52)
        overlay.addChild(detail)

        let yes = makeConfirmButton(label: "[ YES, NEW RUN ]", color: .systemRed)
        yes.name = "confirm_yes"
        yes.position = CGPoint(x: size.width / 2 - 110, y: size.height * 0.38)
        overlay.addChild(yes)

        let no = makeConfirmButton(label: "[ CANCEL ]", color: .white)
        no.name = "confirm_no"
        no.position = CGPoint(x: size.width / 2 + 110, y: size.height * 0.38)
        overlay.addChild(no)

        addChild(overlay)
        confirmOverlay = overlay
    }

    private func makeConfirmButton(label: String, color: SKColor) -> SKLabelNode {
        let n = SKLabelNode(fontNamed: "Courier-Bold")
        n.text = label
        n.fontSize = 14
        n.fontColor = color
        return n
    }

    private func handleConfirmTouch(at loc: CGPoint) {
        let nodes = self.nodes(at: loc)
        for node in nodes {
            switch node.name {
            case "confirm_yes":
                GameManager.shared.startNewGame()
            case "confirm_no":
                confirmOverlay?.removeFromParent()
                confirmOverlay = nil
            default:
                break
            }
        }
    }
}

// MARK: - GameOverScene

final class GameOverScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = .black

        let label = SKLabelNode(fontNamed: "Courier-Bold")
        label.text = "YOU DIED"
        label.fontSize = 40
        label.fontColor = .systemRed
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
        label.alpha = 0
        addChild(label)
        label.run(SKAction.fadeIn(withDuration: 1.2))

        let detail = SKLabelNode(fontNamed: "Courier")
        detail.text = "your run is over. all upgrades lost."
        detail.fontSize = 13
        detail.fontColor = SKColor(white: 0.5, alpha: 1)
        detail.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
        detail.alpha = 0
        addChild(detail)
        detail.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.fadeIn(withDuration: 0.6)
        ]))

        let sub = SKLabelNode(fontNamed: "Courier")
        sub.text = "tap to return to menu"
        sub.fontSize = 14
        sub.fontColor = SKColor(white: 0.45, alpha: 1)
        sub.position = CGPoint(x: size.width / 2, y: size.height * 0.30)
        sub.alpha = 0
        addChild(sub)
        sub.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.8),
            SKAction.fadeIn(withDuration: 0.8)
        ]))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        GameManager.shared.transition(to: .mainMenu)
    }
}

// MARK: - VictoryScene

final class VictoryScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.05, alpha: 1)

        let label = SKLabelNode(fontNamed: "Courier-Bold")
        label.text = "YOU WIN!"
        label.fontSize = 40
        label.fontColor = .systemGreen
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.6)
        addChild(label)

        let stats = SKLabelNode(fontNamed: "Courier")
        let befriended = GameManager.shared.befriendedBosses.count
        let defeated   = GameManager.shared.defeatedBosses.count
        stats.text = "Befriended: \(befriended)  |  Defeated: \(defeated)"
        stats.fontSize = 16
        stats.fontColor = .white
        stats.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
        addChild(stats)

        let restart = SKLabelNode(fontNamed: "Courier")
        restart.text = "tap to return to menu"
        restart.fontSize = 14
        restart.fontColor = SKColor(white: 0.5, alpha: 1)
        restart.position = CGPoint(x: size.width / 2, y: size.height * 0.30)
        addChild(restart)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        GameManager.shared.transition(to: .mainMenu)
    }
}
