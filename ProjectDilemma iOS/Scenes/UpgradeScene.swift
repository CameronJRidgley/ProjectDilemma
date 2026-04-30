// UpgradeScene.swift
/*
 Author: Cameron Ridgley
 Worked on this caude while having claude in help with the methods and strutures from time to time
 Also having claude fix bugs when necessary
 */
// Choices are weighted by how the boss was resolved (fight vs befriend). after each boss

import SpriteKit

final class UpgradeScene: SKScene {

    // MARK: - Init

    private let outcome: BossOutcome
    private let bossID: String
    private var choices: [Upgrade] = []
    private var cardNodes: [SKNode] = []

    init(size: CGSize, bossID: String, outcome: BossOutcome) {
        self.outcome = outcome
        self.bossID = bossID
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError() }



    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.05, alpha: 1)

        choices = Upgrade.selectChoices(
            for: outcome,
            alreadyOwned: PlayerStats.shared.ownedUpgrades
        )

        setupHeader()
        setupCards()

        // Edge case: no upgrades available (player owns all)
        if choices.isEmpty {
            let msg = SKLabelNode(fontNamed: "Courier-Bold")
            msg.text = "No new upgrades available — pressing on!"
            msg.fontSize = 16
            msg.fontColor = .white
            msg.position = CGPoint(x: size.width / 2, y: size.height * 0.4)
            addChild(msg)
            run(SKAction.wait(forDuration: 1.5)) {
                GameManager.shared.advanceFromUpgrade()
            }
        }
    }

   

    private func setupHeader() {
        let title = SKLabelNode(fontNamed: "Courier-Bold")
        title.text = "CHOOSE A REWARD"
        title.fontSize = 24
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.85)
        addChild(title)

        let outcomeText: String
        let outcomeColor: SKColor
        switch outcome {
        case .defeated:
            outcomeText = "Path of Power"
            outcomeColor = .systemRed
        case .befriended:
            outcomeText = "Path of Friendship"
            outcomeColor = .systemGreen
        }

        let subtitle = SKLabelNode(fontNamed: "Courier")
        subtitle.text = outcomeText
        subtitle.fontSize = 14
        subtitle.fontColor = outcomeColor
        subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.79)
        addChild(subtitle)
    }

    // MARK: - Cards

    private func setupCards() {
        let cardW: CGFloat = 180
        let cardH: CGFloat = 220
        let spacing: CGFloat = 20
        let totalW = CGFloat(choices.count) * cardW + CGFloat(choices.count - 1) * spacing
        let startX = (size.width - totalW) / 2 + cardW / 2
        let centerY = size.height * 0.45

        for (i, upgrade) in choices.enumerated() {
            let x = startX + CGFloat(i) * (cardW + spacing)
            let card = makeCard(for: upgrade, size: CGSize(width: cardW, height: cardH))
            card.position = CGPoint(x: x, y: centerY)
            card.name = "card_\(upgrade.id)"
            addChild(card)
            cardNodes.append(card)

            // Entrance animation
            card.alpha = 0
            card.setScale(0.85)
            card.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.1 * Double(i)),
                SKAction.group([
                    SKAction.fadeIn(withDuration: 0.3),
                    SKAction.scale(to: 1.0, duration: 0.3)
                ])
            ]))
        }
    }

    private func makeCard(for upgrade: Upgrade, size: CGSize) -> SKNode {
        let container = SKNode()

        let bg = SKShapeNode(rectOf: size, cornerRadius: 8)
        bg.fillColor = SKColor(white: 0.12, alpha: 1)
        bg.strokeColor = colorForCategory(upgrade.category)
        bg.lineWidth = 2
        container.addChild(bg)

        // Category badge
        let badge = SKLabelNode(fontNamed: "Courier-Bold")
        badge.text = badgeText(for: upgrade.category)
        badge.fontSize = 10
        badge.fontColor = colorForCategory(upgrade.category)
        badge.position = CGPoint(x: 0, y: size.height / 2 - 20)
        container.addChild(badge)

        // Name
        let name = SKLabelNode(fontNamed: "Courier-Bold")
        name.text = upgrade.name
        name.fontSize = 16
        name.fontColor = .white
        name.preferredMaxLayoutWidth = size.width - 20
        name.numberOfLines = 2
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: 30)
        container.addChild(name)

        // Description
        let desc = SKLabelNode(fontNamed: "Courier")
        desc.text = upgrade.description
        desc.fontSize = 12
        desc.fontColor = SKColor(white: 0.8, alpha: 1)
        desc.preferredMaxLayoutWidth = size.width - 20
        desc.numberOfLines = 4
        desc.verticalAlignmentMode = .center
        desc.position = CGPoint(x: 0, y: -20)
        container.addChild(desc)

        // Tap hint
        let hint = SKLabelNode(fontNamed: "Courier")
        hint.text = "[ TAP ]"
        hint.fontSize = 11
        hint.fontColor = SKColor(white: 0.5, alpha: 1)
        hint.position = CGPoint(x: 0, y: -size.height / 2 + 20)
        container.addChild(hint)

        return container
    }

    private func colorForCategory(_ cat: UpgradeCategory) -> SKColor {
        switch cat {
        case .combat:    return .systemRed
        case .social:    return .systemGreen
        case .universal: return .systemYellow
        }
    }

    private func badgeText(for cat: UpgradeCategory) -> String {
        switch cat {
        case .combat:    return "COMBAT"
        case .social:    return "SOCIAL"
        case .universal: return "UNIVERSAL"
        }
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let loc = touches.first?.location(in: self) else { return }
        let nodes = self.nodes(at: loc)

        for node in nodes {
            // Check both the node and its parent (since name is on container)
            let nameToCheck = node.name ?? node.parent?.name ?? ""
            if nameToCheck.hasPrefix("card_") {
                let upgradeID = String(nameToCheck.dropFirst(5))
                if let upgrade = choices.first(where: { $0.id == upgradeID }) {
                    selectUpgrade(upgrade)
                    return
                }
            }
        }
    }

    private func selectUpgrade(_ upgrade: Upgrade) {
        // Disable further taps
        isUserInteractionEnabled = false

        PlayerStats.shared.apply(upgrade)

        // Highlight chosen card, fade others
        for card in cardNodes {
            if card.name == "card_\(upgrade.id)" {
                card.run(SKAction.sequence([
                    SKAction.scale(to: 1.1, duration: 0.2),
                    SKAction.wait(forDuration: 0.3),
                    SKAction.scale(to: 1.0, duration: 0.15)
                ]))
            } else {
                card.run(SKAction.fadeAlpha(to: 0.2, duration: 0.3))
            }
        }

        // Confirmation message
        let confirm = SKLabelNode(fontNamed: "Courier-Bold")
        confirm.text = "✓ \(upgrade.name) acquired!"
        confirm.fontSize = 18
        confirm.fontColor = .systemGreen
        confirm.position = CGPoint(x: size.width / 2, y: size.height * 0.18)
        confirm.alpha = 0
        addChild(confirm)
        confirm.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.4),
            SKAction.fadeIn(withDuration: 0.3)
        ]))

        run(SKAction.wait(forDuration: 1.8)) {
            GameManager.shared.advanceFromUpgrade()
        }
    }
}
