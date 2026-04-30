// OverworldScene.swift
/*
 Author: Cameron Ridgley
 Worked on this caude while having claude in help with the methods and strutures from time to time
 Also having claude fix bugs when necessary
 */

import SpriteKit
import GameplayKit

final class OverworldScene: SKScene {

   

    var floor: Int = 1

    private let generator = DungeonGenerator()
    private var playerEntity: GKEntity!
    private var playerNode: SKSpriteNode!
    private var worldNode: SKNode!
    private var camera_: SKCameraNode!

    // Input state
    private var inputDirection: Direction?
    private var moveCooldown: TimeInterval = 0

    // State tracking
    private var openedChests: Set<String> = []
    private var lastHazardTick: TimeInterval = 0
    private var arrowTraps: [(col: Int, row: Int, direction: Direction)] = []
    private var pendingBossID: String?
    private var isShowingBossPrompt = false
    private var hasBuiltDungeon: Bool = false

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        print(">>> OverworldScene didMove, size: \(size), floor: \(floor), built: \(hasBuiltDungeon)")
        if hasBuiltDungeon {
            // Already built (came back from battle / etc.) — just resume
            return
        }
        hasBuiltDungeon = true
        setupWorld()
        buildDungeon()
        setupPlayer()
        setupCamera()
        setupHUD()
    }

   

    private func setupWorld() {
        backgroundColor = SKColor(red: 0.05, green: 0.04, blue: 0.08, alpha: 1)
        physicsWorld.gravity = .zero
        worldNode = SKNode()
        addChild(worldNode)
    }

    private func buildDungeon() {
        guard let bossID = bossIDForFloor(floor) else { return }

        let grid = generator.generate(floor: floor, bossID: bossID)
        let tileSize = generator.tileSize

        for (row, rowTiles) in grid.enumerated() {
            for (col, tile) in rowTiles.enumerated() {
                let pos = generator.worldPosition(col: col, row: row)
                let node = tileNode(for: tile, at: pos, tileSize: tileSize)
                worldNode.addChild(node)

                // Track arrow trap positions for periodic firing
                if case .arrowTrap(let dir) = tile {
                    arrowTraps.append((col, row, dir))
                }
            }
        }
    }

    private func tileNode(for tile: TileType, at pos: CGPoint, tileSize: CGFloat) -> SKNode {
        let node = SKSpriteNode(color: .clear, size: CGSize(width: tileSize, height: tileSize))
        node.position = pos

        switch tile {
        case .floor:
            node.color = SKColor(red: 0.45, green: 0.40, blue: 0.35, alpha: 1)

        case .wall:
            node.color = SKColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 1)

        case .bossDoor(let bossID):
            // Looks like a wall but with red glow + skull marker
            node.color = SKColor(red: 0.20, green: 0.10, blue: 0.10, alpha: 1)
            node.name = "bossDoor_\(bossID)"

            let glow = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize))
            glow.strokeColor = .systemRed
            glow.lineWidth = 2
            glow.fillColor = .clear
            node.addChild(glow)

            let skull = SKLabelNode(fontNamed: "Courier-Bold")
            skull.text = "☠"
            skull.fontSize = 18
            skull.fontColor = .systemRed
            skull.verticalAlignmentMode = .center
            skull.horizontalAlignmentMode = .center
            node.addChild(skull)

            // Pulsing red glow
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.4, duration: 0.6),
                SKAction.fadeAlpha(to: 1.0, duration: 0.6)
            ])
            glow.run(SKAction.repeatForever(pulse))

        case .chest(let id):
            node.color = .systemOrange
            node.name = "chest_\(id)"

        case .spikes:
            node.color = SKColor(red: 0.45, green: 0.40, blue: 0.35, alpha: 1)  // floor color
            // Add spikes overlay (gray triangles)
            let spike = SKLabelNode(fontNamed: "Courier-Bold")
            spike.text = "▲▲▲"
            spike.fontSize = 12
            spike.fontColor = SKColor(white: 0.7, alpha: 1)
            spike.verticalAlignmentMode = .center
            spike.horizontalAlignmentMode = .center
            node.addChild(spike)

        case .arrowTrap(let direction):
            node.color = SKColor(red: 0.45, green: 0.40, blue: 0.35, alpha: 1)
            // Brown arrow that blends with floor so it's a subtle threat
            let arrow = SKLabelNode(fontNamed: "Courier-Bold")
            switch direction {
            case .up:    arrow.text = "↑"
            case .down:  arrow.text = "↓"
            case .left:  arrow.text = "←"
            case .right: arrow.text = "→"
            }
            arrow.fontSize = 16
            arrow.fontColor = SKColor(red: 0.30, green: 0.22, blue: 0.18, alpha: 1)  // dark brown
            arrow.verticalAlignmentMode = .center
            arrow.horizontalAlignmentMode = .center
            node.addChild(arrow)

        case .campfire(let id):
            node.color = SKColor(red: 0.45, green: 0.40, blue: 0.35, alpha: 1)
            node.name = "campfire_\(id)"
            let fire = SKLabelNode(fontNamed: "Courier-Bold")
            fire.text = "♨"
            fire.fontSize = 22
            fire.fontColor = .systemOrange
            fire.verticalAlignmentMode = .center
            fire.horizontalAlignmentMode = .center
            node.addChild(fire)
            // Flicker animation
            let flicker = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.6, duration: 0.25),
                SKAction.fadeAlpha(to: 1.0, duration: 0.25)
            ])
            fire.run(SKAction.repeatForever(flicker))

        case .gold(let id, _):
            node.color = SKColor(red: 0.45, green: 0.40, blue: 0.35, alpha: 1)
            node.name = "gold_\(id)"
            let coin = SKLabelNode(fontNamed: "Courier-Bold")
            coin.text = "$"
            coin.fontSize = 18
            coin.fontColor = .systemYellow
            coin.verticalAlignmentMode = .center
            coin.horizontalAlignmentMode = .center
            node.addChild(coin)

        case .shopkeeper(let id):
            node.color = SKColor(red: 0.45, green: 0.40, blue: 0.35, alpha: 1)
            node.name = "shop_\(id)"
            let symbol = SKLabelNode(fontNamed: "Courier-Bold")
            symbol.text = "🛒"
            symbol.fontSize = 20
            symbol.verticalAlignmentMode = .center
            symbol.horizontalAlignmentMode = .center
            node.addChild(symbol)
            // Glow border
            let border = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize))
            border.strokeColor = .systemYellow
            border.lineWidth = 1
            border.fillColor = .clear
            node.addChild(border)

        case .fountain(let id):
            node.color = SKColor(red: 0.45, green: 0.40, blue: 0.35, alpha: 1)
            node.name = "fountain_\(id)"
            let symbol = SKLabelNode(fontNamed: "Courier-Bold")
            symbol.text = "✦"
            symbol.fontSize = 24
            symbol.fontColor = .cyan
            symbol.verticalAlignmentMode = .center
            symbol.horizontalAlignmentMode = .center
            node.addChild(symbol)
            let glow = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.5, duration: 0.6),
                SKAction.fadeAlpha(to: 1.0, duration: 0.6)
            ])
            symbol.run(SKAction.repeatForever(glow))

        case .treasureChest(let id):
            node.color = SKColor(red: 0.45, green: 0.40, blue: 0.35, alpha: 1)
            node.name = "treasure_\(id)"
            let symbol = SKLabelNode(fontNamed: "Courier-Bold")
            symbol.text = "♦"
            symbol.fontSize = 22
            symbol.fontColor = .systemPurple
            symbol.verticalAlignmentMode = .center
            symbol.horizontalAlignmentMode = .center
            node.addChild(symbol)

        case .enemy(let id, let type):
            node.color = SKColor(red: 0.45, green: 0.40, blue: 0.35, alpha: 1)
            node.name = "enemy_\(id)"

            // Colored circle by enemy type
            let circle = SKShapeNode(circleOfRadius: 11)
            circle.strokeColor = .white
            circle.lineWidth = 2
            switch type {
            case .slime:  circle.fillColor = .systemGreen
            case .bat:    circle.fillColor = .systemPurple
            case .goblin: circle.fillColor = .systemBrown
            }
            circle.zPosition = 1
            node.addChild(circle)

            // Type symbol on top
            let symbol = SKLabelNode(fontNamed: "Courier-Bold")
            symbol.text = type.displaySymbol
            symbol.fontSize = 14
            symbol.fontColor = .white
            symbol.verticalAlignmentMode = .center
            symbol.horizontalAlignmentMode = .center
            circle.addChild(symbol)

            // Subtle bob animation
            let bob = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 2, duration: 0.5),
                SKAction.moveBy(x: 0, y: -2, duration: 0.5)
            ])
            circle.run(SKAction.repeatForever(bob))

        case .empty:
            node.color = .clear
        }

        return node
    }

    // MARK: - Player

    private func setupPlayer() {
        playerEntity = GKEntity()

        playerNode = SKSpriteNode(color: .systemPink, size: CGSize(width: 22, height: 22))
        playerNode.name = "player"
        playerNode.zPosition = 10

        let outline = SKShapeNode(rectOf: CGSize(width: 22, height: 22))
        outline.strokeColor = .white
        outline.lineWidth = 2
        outline.fillColor = .clear
        playerNode.addChild(outline)

        // Spawn player in center of start room (first room in generator's list)
        if let startRoom = generator.rooms.first {
            playerNode.position = generator.worldPosition(col: Int(startRoom.center.x),
                                                          row: Int(startRoom.center.y))
        } else {
            playerNode.position = generator.worldPosition(col: 5, row: generator.mapHeight / 2)
        }

        worldNode.addChild(playerNode)

        let visualComp   = VisualComponent(node: playerNode)
        let movementComp = MovementComponent(speed: 150)
        movementComp.tileSize = generator.tileSize
        playerEntity.addComponent(visualComp)
        playerEntity.addComponent(movementComp)
    }

    // MARK: - Camera

    private func setupCamera() {
        camera_ = SKCameraNode()
        camera_.position = playerNode.position
        addChild(camera_)
        self.camera = camera_
    }



    private func setupHUD() {
        guard let cam = camera_ else { return }

        let hpLabel = SKLabelNode(fontNamed: "Courier-Bold")
        hpLabel.name = "hpLabel"
        hpLabel.fontSize = 14
        hpLabel.fontColor = .white
        hpLabel.horizontalAlignmentMode = .left
        hpLabel.position = CGPoint(x: -size.width / 2 + 16, y: size.height / 2 - 30)
        cam.addChild(hpLabel)

        let floorLabel = SKLabelNode(fontNamed: "Courier-Bold")
        floorLabel.name = "floorLabel"
        floorLabel.text = "Floor \(floor)"
        floorLabel.fontSize = 14
        floorLabel.fontColor = .systemYellow
        floorLabel.horizontalAlignmentMode = .center
        floorLabel.position = CGPoint(x: 0, y: size.height / 2 - 30)
        cam.addChild(floorLabel)

        let menuBtn = SKLabelNode(fontNamed: "Courier-Bold")
        menuBtn.name = "menuButton"
        menuBtn.text = "[ MENU ]"
        menuBtn.fontSize = 12
        menuBtn.fontColor = SKColor(white: 0.7, alpha: 1)
        menuBtn.horizontalAlignmentMode = .right
        menuBtn.position = CGPoint(x: size.width / 2 - 16, y: size.height / 2 - 30)
        cam.addChild(menuBtn)

        let menuHit = SKShapeNode(rectOf: CGSize(width: 100, height: 40))
        menuHit.fillColor = .clear
        menuHit.strokeColor = .clear
        menuHit.name = "menuButton"
        menuHit.position = CGPoint(x: size.width / 2 - 50, y: size.height / 2 - 26)
        cam.addChild(menuHit)

        setupDPad()
        updateHUD()
    }

    private func setupDPad() {
        guard let cam = camera_ else { return }

        let buttonSize: CGFloat = 50
        let centerX = -size.width / 2 + 90
        let centerY = -size.height / 2 + 90

        addDPadButton(in: cam, label: "▲", name: "dpad_up",    position: CGPoint(x: centerX, y: centerY + buttonSize))
        addDPadButton(in: cam, label: "▼", name: "dpad_down",  position: CGPoint(x: centerX, y: centerY - buttonSize))
        addDPadButton(in: cam, label: "◀", name: "dpad_left",  position: CGPoint(x: centerX - buttonSize, y: centerY))
        addDPadButton(in: cam, label: "▶", name: "dpad_right", position: CGPoint(x: centerX + buttonSize, y: centerY))
    }

    private func addDPadButton(in parent: SKNode, label: String, name: String, position: CGPoint) {
        let bg = SKShapeNode(rectOf: CGSize(width: 48, height: 48), cornerRadius: 6)
        bg.fillColor = SKColor(white: 0.15, alpha: 0.7)
        bg.strokeColor = SKColor(white: 0.5, alpha: 0.8)
        bg.lineWidth = 2
        bg.position = position
        bg.name = name
        bg.zPosition = 100

        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = label
        lbl.fontSize = 22
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.name = name
        bg.addChild(lbl)
        parent.addChild(bg)
    }

    private func updateHUD() {
        let hp = PlayerStats.shared
        if let label = camera_?.childNode(withName: "hpLabel") as? SKLabelNode {
            label.text = "HP: \(hp.currentHP) / \(hp.maxHP)   $: \(hp.gold)"
        }
    }



    override func update(_ currentTime: TimeInterval) {
        guard pauseOverlay == nil, !isShowingBossPrompt else { return }

        // Check player-attempts-to-move-into-boss-door even when no movement happens
        checkBossDoorBump()

        // Handle directional movement
        if let direction = inputDirection {
            moveCooldown -= 1.0 / 60.0
            if moveCooldown <= 0 {
                moveCooldown = 0.14

                let movement = playerEntity.component(ofType: MovementComponent.self)
                movement?.move(direction: direction, in: self)

                checkInteractions()
            }
        }

        // Camera follow (faster, snappier)
        let target = playerNode.position
        camera_.position = CGPoint(
            x: camera_.position.x + (target.x - camera_.position.x) * 0.40,
            y: camera_.position.y + (target.y - camera_.position.y) * 0.40
        )

        // Periodic hazards (arrow traps fire every 1.5s)
        if currentTime - lastHazardTick > 1.5 {
            lastHazardTick = currentTime
            fireArrowTraps()
        }
    }


    private func checkInteractions() {
        let pos = playerNode.position

        switch generator.tileType(at: pos) {
        case .chest(let id):
            openChest(id: id, at: pos)

        case .spikes:
            takeHazardDamage(reason: "Spikes!")

        case .campfire(let id):
            useCampfire(id: id, at: pos)

        case .gold(let id, let amount):
            collectGold(id: id, amount: amount, at: pos)

        case .shopkeeper(let id):
            openShop(id: id, at: pos)

        case .fountain(let id):
            useFountain(id: id, at: pos)

        case .treasureChest(let id):
            openTreasureChest(id: id, at: pos)

        case .enemy(let id, let type):
            engageEnemy(id: id, type: type, at: pos)

        default:
            break
        }
    }



    private func openShop(id: String, at pos: CGPoint) {
        guard !openedChests.contains(id) else { return }
        // Don't permanently remove the shop tile — let player interact again later if they leave
        // For now, simple "buy a heal potion for 10 gold" interaction
        let stats = PlayerStats.shared
        if stats.gold >= 10 {
            stats.gold -= 10
            stats.heal(10)
            updateHUD()
            showFloatingText("Bought potion! +10 HP", color: .systemGreen, at: playerNode.position)
            openedChests.insert(id)
            // Mark visually as used
            if let shopTile = worldNode.children.first(where: { $0.name == "shop_\(id)" }) {
                for child in shopTile.children {
                    child.run(SKAction.fadeAlpha(to: 0.3, duration: 0.3))
                }
                shopTile.name = nil
            }
        } else {
            showFloatingText("Need 10 GOLD", color: .systemRed, at: playerNode.position)
        }
    }

    private func useFountain(id: String, at pos: CGPoint) {
        guard !openedChests.contains(id) else { return }
        openedChests.insert(id)

        let stats = PlayerStats.shared
        let healAmount = 10
        stats.heal(healAmount)
        updateHUD()
        showFloatingText("FOUNTAIN +\(healAmount) HP", color: .cyan, at: playerNode.position)

        if let fTile = worldNode.children.first(where: { $0.name == "fountain_\(id)" }) {
            for child in fTile.children {
                child.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.4),
                    SKAction.removeFromParent()
                ]))
            }
            fTile.name = nil
        }
        generator.consumeTile(at: pos)
    }

    private func openTreasureChest(id: String, at pos: CGPoint) {
        guard !openedChests.contains(id) else { return }
        openedChests.insert(id)

        // Treasure chests give bigger rewards: gold + a stat boost
        let goldAmount = Int.random(in: 20...35)
        PlayerStats.shared.gold += goldAmount
        let bonus = Int.random(in: 1...3)
        let bonusType = ["ATK", "DEF", "MAX HP"].randomElement()!
        switch bonusType {
        case "ATK":    PlayerStats.shared.attack += bonus
        case "DEF":    PlayerStats.shared.defense += bonus
        case "MAX HP":
            PlayerStats.shared.maxHP += bonus
            PlayerStats.shared.heal(bonus)
        default: break
        }

        updateHUD()
        showFloatingText("+\(goldAmount) GOLD, +\(bonus) \(bonusType)", color: .systemPurple, at: playerNode.position)

        if let tile = worldNode.children.first(where: { $0.name == "treasure_\(id)" }) {
            for child in tile.children {
                child.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.3),
                    SKAction.removeFromParent()
                ]))
            }
            tile.name = nil
        }
        generator.consumeTile(at: pos)
    }

    private func engageEnemy(id: String, type: EnemyType, at pos: CGPoint) {
        guard !defeatedEnemyIDs.contains(id) else { return }
        defeatedEnemyIDs.insert(id)

        // Simple combat: take damage, kill enemy, gain gold
        let stats = PlayerStats.shared
        let savedBySecondWind = stats.takeDamage(type.damage)
        stats.gold += type.goldReward
        updateHUD()

        // Show damage and reward popups
        showFloatingText("-\(type.damage) HP", color: .systemRed, at: playerNode.position)
        if savedBySecondWind {
            run(SKAction.wait(forDuration: 0.2)) { [weak self] in
                guard let self else { return }
                self.showFloatingText("SECOND WIND!", color: .systemYellow,
                                      at: self.playerNode.position)
            }
        }
        // Stagger the gold popup so they don't overlap
        run(SKAction.wait(forDuration: 0.4)) { [weak self] in
            guard let self else { return }
            self.showFloatingText("+\(type.goldReward) GOLD", color: .systemYellow,
                                  at: self.playerNode.position)
        }

        flashPlayer()

        // Remove the enemy tile
        let (col, row) = generator.tileCoord(for: pos)
        let enemyPos = generator.worldPosition(col: col, row: row)
        if let enemyTile = worldNode.children.first(where: {
            abs($0.position.x - enemyPos.x) < 1 && abs($0.position.y - enemyPos.y) < 1
            && $0.name?.hasPrefix("enemy_") == true
        }) {
            for child in enemyTile.children {
                child.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.3),
                    SKAction.removeFromParent()
                ]))
            }
            enemyTile.name = nil
        }
        generator.consumeTile(at: pos)

        if !stats.isAlive {
            GameManager.shared.handleDeath()
        }
    }

    private var defeatedEnemyIDs: Set<String> = []



    private func useCampfire(id: String, at pos: CGPoint) {
        let stats = PlayerStats.shared
        let healed = stats.maxHP - stats.currentHP
        stats.heal(healed)
        updateHUD()
        showFloatingText("FULL HEAL (+\(healed) HP)", color: .systemOrange, at: playerNode.position)

        // Remove fire visual, keep tile
        if let campfireTile = worldNode.children.first(where: { $0.name == "campfire_\(id)" }) {
            for child in campfireTile.children {
                child.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.4),
                    SKAction.removeFromParent()
                ]))
            }
            campfireTile.name = nil
        }
        generator.consumeCampfire(at: pos)
    }



    private func collectGold(id: String, amount: Int, at pos: CGPoint) {
        PlayerStats.shared.gold += amount
        updateHUD()
        showFloatingText("+\(amount) GOLD", color: .systemYellow, at: playerNode.position)

        // Remove only the coin label (the $ symbol), keep the floor tile background
        if let goldTile = worldNode.children.first(where: { $0.name == "gold_\(id)" }) {
            for child in goldTile.children {
                child.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.2),
                    SKAction.removeFromParent()
                ]))
            }
            goldTile.name = nil  // prevent re-pickup
        }
        generator.consumeGold(at: pos)
    }

    /// Detect when the player is directly adjacent to a boss-door wall and pressing toward it.
    private func checkBossDoorBump() {
        guard !isShowingBossPrompt, let direction = inputDirection else { return }

        let delta = direction.vector(tileSize: generator.tileSize)
        let target = CGPoint(
            x: playerNode.position.x + delta.x,
            y: playerNode.position.y + delta.y
        )

        if case .bossDoor(let bossID) = generator.tileType(at: target) {
            showBossPrompt(bossID: bossID)
        }
    }



    private func openChest(id: String, at pos: CGPoint) {
        guard !openedChests.contains(id) else { return }
        openedChests.insert(id)

        // Fade out only the chest's contents (keep floor)
        if let chestTile = worldNode.children.first(where: { $0.name == "chest_\(id)" }) {
            chestTile.run(SKAction.colorize(with: SKColor(red: 0.45, green: 0.40, blue: 0.35, alpha: 1),
                                            colorBlendFactor: 1.0, duration: 0.3))
            for child in chestTile.children {
                child.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.3),
                    SKAction.removeFromParent()
                ]))
            }
            chestTile.name = nil
        }
        generator.consumeChest(at: pos)

        let reward = randomChestReward()
        applyReward(reward)
        updateHUD()
        showFloatingText(reward.description, color: .systemGreen, at: playerNode.position)
    }

    private enum ChestReward {
        case heal(Int)
        case maxHPBoost(Int)
        case attackBoost(Int)
        case defenseBoost(Int)

        var description: String {
            switch self {
            case .heal(let n):         return "+\(n) HP"
            case .maxHPBoost(let n):   return "+\(n) MAX HP"
            case .attackBoost(let n):  return "+\(n) ATK"
            case .defenseBoost(let n): return "+\(n) DEF"
            }
        }
    }

    private func randomChestReward() -> ChestReward {
        let stats = PlayerStats.shared
        // If player is at full HP, give them something else
        if stats.currentHP >= stats.maxHP {
            return [.maxHPBoost(3), .attackBoost(1), .defenseBoost(1)].randomElement()!
        }
        return [.heal(8), .maxHPBoost(3), .attackBoost(1), .defenseBoost(1)].randomElement()!
    }

    private func applyReward(_ reward: ChestReward) {
        let stats = PlayerStats.shared
        switch reward {
        case .heal(let n):
            stats.heal(n)
        case .maxHPBoost(let n):
            stats.maxHP += n
            stats.heal(n)  // also fills the new HP
        case .attackBoost(let n):
            stats.attack += n
        case .defenseBoost(let n):
            stats.defense += n
        }
    }


    private func takeHazardDamage(reason: String) {
        let stats = PlayerStats.shared
        let savedBySecondWind = stats.takeDamage(5)
        updateHUD()
        showFloatingText("-5 HP \(reason)", color: .systemRed, at: playerNode.position)

        flashPlayer()

        if savedBySecondWind {
            showFloatingText("SECOND WIND!", color: .systemYellow, at: playerNode.position)
        }

        if !stats.isAlive {
            GameManager.shared.handleDeath()
        }
    }

    private func fireArrowTraps() {
        let playerPos = playerNode.position
        let maxDistance: CGFloat = 320  // ~10 tiles
        for trap in arrowTraps {
            let origin = generator.worldPosition(col: trap.col, row: trap.row)
            let dist = hypot(origin.x - playerPos.x, origin.y - playerPos.y)
            guard dist <= maxDistance else { continue }
            spawnArrow(from: origin, direction: trap.direction)
        }
    }

    private func spawnArrow(from origin: CGPoint, direction: Direction) {
        let arrow = SKShapeNode(circleOfRadius: 4)
        arrow.fillColor = .systemRed
        arrow.strokeColor = .clear
        arrow.position = origin
        arrow.zPosition = 8
        arrow.name = "arrow"
        worldNode.addChild(arrow)

        let velocity: CGVector
        let speed: CGFloat = 200
        switch direction {
        case .up:    velocity = CGVector(dx: 0,      dy: speed)
        case .down:  velocity = CGVector(dx: 0,      dy: -speed)
        case .left:  velocity = CGVector(dx: -speed, dy: 0)
        case .right: velocity = CGVector(dx: speed,  dy: 0)
        }

        let lifetime: TimeInterval = 1.5
        let move = SKAction.move(by: CGVector(dx: velocity.dx * CGFloat(lifetime),
                                              dy: velocity.dy * CGFloat(lifetime)),
                                  duration: lifetime)
        arrow.run(SKAction.sequence([move, SKAction.removeFromParent()]))

        // Damage check via repeated update
        let check = SKAction.customAction(withDuration: lifetime) { [weak self] node, _ in
            guard let self else { return }
            let dist = hypot(node.position.x - self.playerNode.position.x,
                             node.position.y - self.playerNode.position.y)
            if dist < 14 {
                node.removeFromParent()
                self.takeHazardDamage(reason: "Arrow!")
            }
        }
        arrow.run(check)
    }

    private func flashPlayer() {
        let flash = SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.08),
            SKAction.colorize(with: .systemPink, colorBlendFactor: 1.0, duration: 0.12)
        ])
        playerNode.run(flash)
    }

    private func showFloatingText(_ text: String, color: SKColor, at pos: CGPoint) {
        let label = SKLabelNode(fontNamed: "Courier-Bold")
        label.text = text
        label.fontSize = 14
        label.fontColor = color
        label.position = pos + CGPoint(x: 0, y: 30)
        label.zPosition = 30
        worldNode.addChild(label)
        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 24, duration: 0.7),
                SKAction.fadeOut(withDuration: 0.7)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    
    private func showBossPrompt(bossID: String) {
        guard let cam = camera_, !isShowingBossPrompt else { return }
        isShowingBossPrompt = true
        inputDirection = nil
        pendingBossID = bossID

        let overlay = SKNode()
        overlay.name = "bossPrompt"
        overlay.zPosition = 200

        let bg = SKShapeNode(rectOf: CGSize(width: size.width - 80, height: 130), cornerRadius: 8)
        bg.fillColor = SKColor(red: 0.10, green: 0.05, blue: 0.05, alpha: 0.95)
        bg.strokeColor = .systemRed
        bg.lineWidth = 2
        bg.position = .zero
        overlay.addChild(bg)

        guard let config = BossConfig.config(for: bossID) else { return }

        let title = SKLabelNode(fontNamed: "Courier-Bold")
        title.text = "⚠ BOSS ROOM ⚠"
        title.fontSize = 18
        title.fontColor = .systemRed
        title.position = CGPoint(x: 0, y: 38)
        overlay.addChild(title)

        let bossName = SKLabelNode(fontNamed: "Courier-Bold")
        bossName.text = config.name.uppercased()
        bossName.fontSize = 14
        bossName.fontColor = .white
        bossName.position = CGPoint(x: 0, y: 16)
        overlay.addChild(bossName)

        let enter = SKLabelNode(fontNamed: "Courier-Bold")
        enter.text = "[ ENTER ]"
        enter.name = "boss_enter"
        enter.fontSize = 16
        enter.fontColor = .systemRed
        enter.position = CGPoint(x: -70, y: -28)
        overlay.addChild(enter)

        let cancel = SKLabelNode(fontNamed: "Courier-Bold")
        cancel.text = "[ NOT YET ]"
        cancel.name = "boss_cancel"
        cancel.fontSize = 16
        cancel.fontColor = .white
        cancel.position = CGPoint(x: 70, y: -28)
        overlay.addChild(cancel)

        cam.addChild(overlay)
    }

    private func dismissBossPrompt() {
        camera_?.childNode(withName: "bossPrompt")?.removeFromParent()
        isShowingBossPrompt = false
        pendingBossID = nil
    }

    private func handleBossPromptTouch(at camLoc: CGPoint) {
        guard let cam = camera_ else { return }
        let hits = cam.nodes(at: camLoc)
        for node in hits {
            switch node.name {
            case "boss_enter":
                guard let bossID = pendingBossID else { return }
                dismissBossPrompt()
                GameManager.shared.transition(to: .battle(bossID: bossID))
                return
            case "boss_cancel":
                // Bump player back one step from the door
                bumpPlayerAwayFromDoor()
                dismissBossPrompt()
                return
            default:
                continue
            }
        }
    }

    private func bumpPlayerAwayFromDoor() {
        // Move player one tile in the opposite of the last input direction (best guess)
        // For simplicity, try each direction and step away to a walkable tile
        for dir in Direction.allCases {
            let delta = dir.vector(tileSize: generator.tileSize)
            let target = CGPoint(
                x: playerNode.position.x + delta.x,
                y: playerNode.position.y + delta.y
            )
            if generator.isWalkable(at: target),
               case .floor = generator.tileType(at: target) {
                playerNode.position = target
                return
            }
        }
    }



    func isWalkable(at worldPos: CGPoint) -> Bool {
        generator.isWalkable(at: worldPos)
    }

 

    private func bossIDForFloor(_ floor: Int) -> String? {
        let ids = BossConfig.all.map { $0.id }
        guard floor <= ids.count else { return nil }
        return ids[floor - 1]
    }



    private var pauseOverlay: SKNode?

    private func showPauseConfirm() {
        guard pauseOverlay == nil, let cam = camera_ else { return }

        inputDirection = nil

        let overlay = SKNode()
        overlay.zPosition = 200

        let bg = SKShapeNode(rectOf: size)
        bg.fillColor = SKColor(white: 0, alpha: 0.85)
        bg.strokeColor = .clear
        overlay.addChild(bg)

        let title = SKLabelNode(fontNamed: "Courier-Bold")
        title.text = "RETURN TO MENU?"
        title.fontSize = 22
        title.fontColor = .systemYellow
        title.position = CGPoint(x: 0, y: 60)
        overlay.addChild(title)

        let detail = SKLabelNode(fontNamed: "Courier")
        detail.text = "Your progress is saved."
        detail.fontSize = 11
        detail.fontColor = .white
        detail.position = CGPoint(x: 0, y: 28)
        overlay.addChild(detail)

        let yes = SKLabelNode(fontNamed: "Courier-Bold")
        yes.text = "[ YES, MENU ]"
        yes.name = "pause_yes"
        yes.fontSize = 16
        yes.fontColor = .systemYellow
        yes.position = CGPoint(x: -90, y: -30)
        overlay.addChild(yes)

        let no = SKLabelNode(fontNamed: "Courier-Bold")
        no.text = "[ KEEP PLAYING ]"
        no.name = "pause_no"
        no.fontSize = 16
        no.fontColor = .white
        no.position = CGPoint(x: 90, y: -30)
        overlay.addChild(no)

        cam.addChild(overlay)
        pauseOverlay = overlay
    }

    private func handlePauseTouch(at camLoc: CGPoint) -> Bool {
        guard let overlay = pauseOverlay, let cam = camera_ else { return false }
        let hits = cam.nodes(at: camLoc)
        for node in hits {
            switch node.name {
            case "pause_yes":
                overlay.removeFromParent()
                pauseOverlay = nil
                GameManager.shared.returnToMainMenu()
                return true
            case "pause_no":
                overlay.removeFromParent()
                pauseOverlay = nil
                return true
            default:
                continue
            }
        }
        return true
    }

   

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let cam = camera_ else { return }

        let camLoc = touch.location(in: cam)

        // Pause overlay takes priority
        if pauseOverlay != nil {
            _ = handlePauseTouch(at: camLoc)
            return
        }

        // Boss prompt takes priority
        if isShowingBossPrompt {
            handleBossPromptTouch(at: camLoc)
            return
        }

        // Camera-space buttons (Menu + D-pad)
        let hits = cam.nodes(at: camLoc)
        for node in hits {
            switch node.name {
            case "menuButton":
                showPauseConfirm()
                return
            case "dpad_up":    inputDirection = .up;    return
            case "dpad_down":  inputDirection = .down;  return
            case "dpad_left":  inputDirection = .left;  return
            case "dpad_right": inputDirection = .right; return
            default: continue
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isShowingBossPrompt, pauseOverlay == nil else { return }
        guard let touch = touches.first, let cam = camera_ else { return }
        let camLoc = touch.location(in: cam)
        let hits = cam.nodes(at: camLoc)

        var newDirection: Direction? = nil
        for node in hits {
            switch node.name {
            case "dpad_up":    newDirection = .up
            case "dpad_down":  newDirection = .down
            case "dpad_left":  newDirection = .left
            case "dpad_right": newDirection = .right
            default: continue
            }
            if newDirection != nil { break }
        }
        inputDirection = newDirection
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputDirection = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputDirection = nil
    }
}
