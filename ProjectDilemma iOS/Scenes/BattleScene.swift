// BattleScene.swift
/*
 Author: Cameron Ridgley
 Worked on this caude while having claude in help with the methods and strutures from time to time
 Also having claude fix bugs when necessary
 */
import SpriteKit
import GameplayKit

final class BattleScene: SKScene {

    // MARK: - Init

    private let bossConfig: BossConfig
    private let turnSystem = TurnSystem()

    private var bossEntity: GKEntity!
    private var soulEntity: GKEntity!

    // Nodes
    private var bossNode: SKSpriteNode!
    private var soulNode: SKSpriteNode!
    private var battleBox: SKShapeNode!   // the dodge arena
    private var hpBar: SKShapeNode!
    private var hpBarFill: SKShapeNode!
    private var friendBar: SKShapeNode!
    private var friendBarFill: SKShapeNode!
    private var dialogueLabel: SKLabelNode!
    private var menuNode: SKNode!
    private var bulletLayer: SKNode!

    // State
    private var soulInput: CGVector = .zero
    private var befriendProgress: Int = 0

    private var befriendTarget: Int {
        switch bossConfig.befriendCondition {
        case .actUsed(_, let times):           return times
        case .hpBelow(let fraction):           return Int((1 - fraction) * 10)  // arbitrary visual scale
        case .turnsWithoutAttack(let n):       return n
        case .itemUsed:                        return 1
        }
    }
    private var isDodging: Bool = false
    private var lastTime: TimeInterval = 0

    // MARK: - Init

    init(size: CGSize, bossConfig: BossConfig) {
        self.bossConfig = bossConfig
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.05, alpha: 1)
        bulletLayer = SKNode()
        addChild(bulletLayer)

        setupBoss()
        setupSoul()
        setupBattleBox()
        setupBars()
        setupDialogue()
        setupMenu()
        setupSoulDPad()
        wireTurnSystem()
        showIntro()
    }

    // MARK: - Soul D-Pad

    private func setupSoulDPad() {
        let buttonSize: CGFloat = 44
        // Position D-pad in top-left, away from the menu/dialogue
        let centerX = 70
        let centerY = Int(size.height) - 90

        addSoulButton(label: "▲", name: "soul_up",    x: centerX, y: centerY + Int(buttonSize))
        addSoulButton(label: "▼", name: "soul_down",  x: centerX, y: centerY - Int(buttonSize))
        addSoulButton(label: "◀", name: "soul_left",  x: centerX - Int(buttonSize), y: centerY)
        addSoulButton(label: "▶", name: "soul_right", x: centerX + Int(buttonSize), y: centerY)
    }

    private func addSoulButton(label: String, name: String, x: Int, y: Int) {
        let bg = SKShapeNode(rectOf: CGSize(width: 42, height: 42), cornerRadius: 6)
        bg.fillColor = SKColor(white: 0.15, alpha: 0.7)
        bg.strokeColor = SKColor(white: 0.5, alpha: 0.8)
        bg.lineWidth = 2
        bg.position = CGPoint(x: x, y: y)
        bg.name = name
        bg.zPosition = 100

        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = label
        lbl.fontSize = 18
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.name = name
        bg.addChild(lbl)
        addChild(bg)
    }

    // MARK: - Boss Setup

    private func setupBoss() {
        bossEntity = GKEntity()

        bossNode = SKSpriteNode(color: .systemRed, size: CGSize(width: 80, height: 80))
        bossNode.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        bossNode.zPosition = 5
        addChild(bossNode)

        let nameLabel = SKLabelNode(fontNamed: "Courier-Bold")
        nameLabel.text = bossConfig.name.uppercased()
        nameLabel.fontSize = 18
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.82)
        addChild(nameLabel)

        let healthComp   = HealthComponent(hp: bossConfig.maxHP)
        let patternComp  = AttackPatternComponent(patterns: bossConfig.attackPatterns)
        let relationComp = RelationshipComponent()
        let visualComp   = VisualComponent(node: bossNode)

        healthComp.onDeath = { [weak self] in self?.handleBossDefeated() }
        relationComp.onBefriended = { [weak self] in self?.handleBossBefriended() }

        bossEntity.addComponent(healthComp)
        bossEntity.addComponent(patternComp)
        bossEntity.addComponent(relationComp)
        bossEntity.addComponent(visualComp)
    }

    // MARK: - Soul (dodge heart) Setup

    private func setupSoul() {
        soulEntity = GKEntity()

        soulNode = SKSpriteNode(color: .systemRed, size: CGSize(width: 14, height: 14))
        soulNode.zPosition = 20
        soulNode.position = CGPoint(x: size.width / 2, y: size.height * 0.28)
        addChild(soulNode)

        let visual = VisualComponent(node: soulNode)
        let soul   = SoulComponent(speed: PlayerStats.shared.soulSpeed)
        soulEntity.addComponent(visual)
        soulEntity.addComponent(soul)
    }

    // MARK: - Battle Box

    private func setupBattleBox() {
        let boxSize = CGSize(width: 200, height: 140)
        let boxPos  = CGPoint(x: size.width / 2, y: size.height * 0.28)

        battleBox = SKShapeNode(rectOf: boxSize, cornerRadius: 4)
        battleBox.strokeColor = .white
        battleBox.lineWidth = 3
        battleBox.fillColor = SKColor(white: 0.0, alpha: 0.85)
        battleBox.position = boxPos
        battleBox.zPosition = 2
        addChild(battleBox)

        // Clamp soul inside box
        soulNode.position = boxPos
    }

    // MARK: - Bars

    private func setupBars() {
        let barW: CGFloat = 200
        let barH: CGFloat = 10

        // Boss HP bar (background)
        hpBar = SKShapeNode(rectOf: CGSize(width: barW, height: barH))
        hpBar.fillColor = SKColor(white: 0.25, alpha: 1)
        hpBar.strokeColor = .clear
        hpBar.position = CGPoint(x: size.width / 2, y: size.height * 0.88)
        addChild(hpBar)

        // HP fill — anchored to LEFT edge so it shrinks rightward
        hpBarFill = SKShapeNode(rectOf: CGSize(width: barW, height: barH))
        hpBarFill.fillColor = .systemRed
        hpBarFill.strokeColor = .clear
        // Position the center of the fill bar at the left edge of hpBar, then shift right by half its width
        hpBarFill.position = hpBar.position
        addChild(hpBarFill)

        // Befriend bar
        let friendY = size.height * 0.88 - 18
        friendBar = SKShapeNode(rectOf: CGSize(width: barW, height: barH))
        friendBar.fillColor = SKColor(white: 0.25, alpha: 1)
        friendBar.strokeColor = .clear
        friendBar.position = CGPoint(x: size.width / 2, y: friendY)
        addChild(friendBar)

        friendBarFill = SKShapeNode(rectOf: CGSize(width: barW, height: barH))
        friendBarFill.fillColor = .systemGreen
        friendBarFill.strokeColor = .clear
        friendBarFill.position = friendBar.position
        addChild(friendBarFill)

        let hpL = SKLabelNode(fontNamed: "Courier"); hpL.text = "HP"; hpL.fontSize = 10
        hpL.fontColor = .white
        hpL.position = CGPoint(x: size.width / 2 - barW / 2 - 20, y: hpBar.position.y - 5)
        addChild(hpL)

        let frL = SKLabelNode(fontNamed: "Courier"); frL.text = "FR"; frL.fontSize = 10
        frL.fontColor = .systemGreen
        frL.position = CGPoint(x: size.width / 2 - barW / 2 - 20, y: friendY - 5)
        addChild(frL)
    }

    private func refreshBars() {
        let hp = bossEntity.component(ofType: HealthComponent.self)
        let hpFraction = max(0, min(1, CGFloat(hp?.fraction ?? 1)))
        hpBarFill.run(SKAction.scaleX(to: hpFraction, y: 1.0, duration: 0.2))

        // Compute friendship fraction from actual relationship state
        let fFraction = currentBefriendFraction()
        friendBarFill.run(SKAction.scaleX(to: fFraction, y: 1.0, duration: 0.3))
    }

    /// Returns 0.0–1.0 based on actual progress toward the boss's befriend condition.
    private func currentBefriendFraction() -> CGFloat {
        // Dr. Muhammad: special check based on global meta-state
        if bossConfig.id == "drMuhammad" {
            let befriended = GameManager.shared.befriendedBosses
            let priors: Set<String> = ["mudwick", "glimmerbell", "thornvex"]
            let bondedCount = priors.intersection(befriended).count
            return CGFloat(bondedCount) / CGFloat(priors.count)
        }

        guard let relation = bossEntity.component(ofType: RelationshipComponent.self) else { return 0 }
        switch bossConfig.befriendCondition {
        case .actUsed(let name, let times):
            let progress = relation.actProgress[name] ?? 0
            return min(1, CGFloat(progress) / CGFloat(max(1, times)))
        case .hpBelow(let target):
            let hp = bossEntity.component(ofType: HealthComponent.self)
            let current = hp?.fraction ?? 1
            let progress = (1 - current) / (1 - target)
            return min(1, max(0, progress))
        case .turnsWithoutAttack(let n):
            return min(1, CGFloat(relation.turnsWithoutPlayerAttack) / CGFloat(max(1, n)))
        case .itemUsed:
            return 0
        }
    }

    // MARK: - Dialogue

    private func setupDialogue() {
        let bg = SKShapeNode(rectOf: CGSize(width: size.width - 40, height: 50), cornerRadius: 6)
        bg.fillColor = SKColor(white: 0.1, alpha: 0.9)
        bg.strokeColor = SKColor(white: 0.3, alpha: 1)
        bg.position = CGPoint(x: size.width / 2, y: size.height * 0.10)
        bg.zPosition = 30
        addChild(bg)

        dialogueLabel = SKLabelNode(fontNamed: "Courier")
        dialogueLabel.fontSize = 14
        dialogueLabel.fontColor = .white
        dialogueLabel.preferredMaxLayoutWidth = size.width - 60
        dialogueLabel.numberOfLines = 2
        dialogueLabel.verticalAlignmentMode = .center
        dialogueLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.10)
        dialogueLabel.zPosition = 31
        addChild(dialogueLabel)
    }

    private func showDialogue(_ text: String) {
        dialogueLabel.text = text
    }

    // MARK: - Menu

    private func setupMenu() {
        menuNode = SKNode()
        menuNode.zPosition = 25
        addChild(menuNode)

        let buttons: [(String, CGFloat)] = [("FIGHT", -90), ("ACT", -30), ("ITEM", 30), ("SPARE", 90)]
        for (label, xOff) in buttons {
            let btn = makeMenuButton(label: label)
            btn.position = CGPoint(x: size.width / 2 + xOff, y: size.height * 0.18)
            btn.name = "btn_\(label)"
            menuNode.addChild(btn)
        }
        menuNode.isHidden = true
    }

    private func makeMenuButton(label: String) -> SKNode {
        let bg = SKShapeNode(rectOf: CGSize(width: 55, height: 28), cornerRadius: 4)
        bg.fillColor = SKColor(white: 0.18, alpha: 1)
        bg.strokeColor = .white
        bg.lineWidth = 1.5

        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = label
        lbl.fontSize = 12
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        bg.addChild(lbl)
        return bg
    }

    private func showMenu() {
        menuNode.isHidden = false
        isDodging = false
        soulNode.isHidden = true
    }

    private func hideMenu() {
        menuNode.isHidden = true
    }

    // MARK: - Turn System Wiring

    private func wireTurnSystem() {
        turnSystem.onPhaseChanged = { [weak self] phase in
            guard let self else { return }
            switch phase {
            case .playerChoosing:
                // Apply Kind Words upgrade — heal at the start of the turn
                let healAmount = PlayerStats.shared.turnHealAmount
                if healAmount > 0 && PlayerStats.shared.currentHP < PlayerStats.shared.maxHP {
                    PlayerStats.shared.heal(healAmount)
                }
                self.showMenu()
                self.showDialogue("What will you do?")
            case .playerAction:
                self.hideMenu()
            case .bossAttacking:
                self.beginDodgePhase()
            case .resolution:
                self.checkConditions()
            case .dialogue:
                break
            }
        }

        turnSystem.onPlayerFight = { [weak self] in
            self?.executePlayerFight()
        }

        turnSystem.onPlayerAct = { [weak self] option in
            self?.executeAct(option)
        }

        turnSystem.onPlayerItem = { [weak self] item in
            self?.executeItem(item)
        }

        turnSystem.onPlayerSpare = { [weak self] in
            self?.executeSpare()
        }

        turnSystem.onBossAttack = { [weak self] pattern in
            self?.fireBossPattern(pattern)
        }
    }

    // MARK: - Intro

    private func showIntro() {
        showDialogue(bossConfig.flavorText)
        run(SKAction.wait(forDuration: 2.5)) { [weak self] in
            self?.turnSystem.beginNextTurn()
        }
    }

    // MARK: - Player Actions

    private func executePlayerFight() {
        print(">>> executePlayerFight start")

        // Crit roll
        let isCrit = CGFloat.random(in: 0..<1) < PlayerStats.shared.critChance
        let baseDamage = PlayerStats.shared.attack
        let damage = isCrit ? baseDamage * 2 : baseDamage

        bossEntity.component(ofType: HealthComponent.self)?.takeDamage(damage)
        bossEntity.component(ofType: RelationshipComponent.self)?.resetAttackStreak()

        // Lifesteal
        PlayerStats.shared.lifestealHeal(damageDealt: damage)

        let dmgText = isCrit ? "CRITICAL! \(damage) damage!" : "You dealt \(damage) damage!"
        showDialogue(dmgText)
        shakeBoss()
        refreshBars()

        print(">>> executePlayerFight scheduling wait")
        run(SKAction.wait(forDuration: 1.2)) { [weak self] in
            print(">>> executePlayerFight wait completed")
            guard let self else {
                print(">>> self was nil!")
                return
            }
            let pattern = self.bossEntity.component(ofType: AttackPatternComponent.self)?.currentPattern
            print(">>> calling playerActionFinished with pattern: \(String(describing: pattern))")
            self.turnSystem.playerActionFinished(bossAttackPattern: pattern ?? .spreadShot(count: 4, speed: 100))
        }
    }

    private func executeAct(_ option: ActOption) {
        let relation = bossEntity.component(ofType: RelationshipComponent.self)
        relation?.recordAct(named: option.name)
        relation?.recordPlayerSkippedAttack()

        switch option.effect {
        case .progressBefriend(let amt):
            befriendProgress += amt * PlayerStats.shared.actMultiplier
            showDialogue("[\(option.name)] \(option.description)")
        case .heal(let amt):
            PlayerStats.shared.heal(amt)
            showDialogue("You used \(option.name). +\(amt) HP!")
        case .weakenBoss:
            showDialogue("\(bossConfig.name) seems off-balance!")
        case .revealInfo:
            showBefriendHint()
        }

        refreshBars()

        run(SKAction.wait(forDuration: 1.5)) { [weak self] in
            guard let self else { return }
            let pattern = self.bossEntity.component(ofType: AttackPatternComponent.self)?.currentPattern
            self.turnSystem.playerActionFinished(bossAttackPattern: pattern ?? .spreadShot(count: 4, speed: 100))
        }
    }

    private func executeItem(_ item: ItemType) {
        switch item {
        case .healthPotion:
            PlayerStats.shared.heal(10)
            showDialogue("Used Health Potion. +10 HP!")
        case .shield:
            PlayerStats.shared.defense += 2
            showDialogue("Iron Shield equipped! DEF +2")
        case .charm:
            befriendProgress += 1
            showDialogue("The Friendship Charm glows warmly...")
            refreshBars()
        }

        run(SKAction.wait(forDuration: 1.2)) { [weak self] in
            guard let self else { return }
            let pattern = self.bossEntity.component(ofType: AttackPatternComponent.self)?.currentPattern
            self.turnSystem.playerActionFinished(bossAttackPattern: pattern ?? .spreadShot(count: 4, speed: 100))
        }
    }

    private func executeSpare() {
        let relation = bossEntity.component(ofType: RelationshipComponent.self)
        relation?.recordPlayerSkippedAttack()

        // Special check for Dr. Muhammad: must have befriended all prior bosses
        if bossConfig.id == "drMuhammad" {
            let befriended = GameManager.shared.befriendedBosses
            let priors: Set<String> = ["mudwick", "glimmerbell", "thornvex"]
            if priors.isSubset(of: befriended) {
                handleBossBefriended()
                return
            } else {
                let missing = priors.subtracting(befriended).count
                showDialogue("Dr. Muhammad will not be befriended yet. (\(missing) more bonds needed.)")
                run(SKAction.wait(forDuration: 2.0)) { [weak self] in
                    guard let self else { return }
                    let pattern = self.bossEntity.component(ofType: AttackPatternComponent.self)?.currentPattern
                    self.turnSystem.playerActionFinished(bossAttackPattern: pattern ?? .spreadShot(count: 4, speed: 100))
                }
                return
            }
        }

        if relation?.evaluate(against: bossConfig.befriendCondition) == true {
            handleBossBefriended()
        } else {
            showDialogue("\(bossConfig.name) doesn't seem ready to be spared yet...")
            run(SKAction.wait(forDuration: 1.5)) { [weak self] in
                guard let self else { return }
                let pattern = self.bossEntity.component(ofType: AttackPatternComponent.self)?.currentPattern
                self.turnSystem.playerActionFinished(bossAttackPattern: pattern ?? .spreadShot(count: 4, speed: 100))
            }
        }
    }

    private func showBefriendHint() {
        var hint = ""

        // Special hint for Dr. Muhammad
        if bossConfig.id == "drMuhammad" {
            let befriended = GameManager.shared.befriendedBosses
            let priors: Set<String> = ["mudwick", "glimmerbell", "thornvex"]
            let missing = priors.subtracting(befriended)
            if missing.isEmpty {
                hint = "Hint: She is ready to be spared. Press SPARE."
            } else {
                hint = "Hint: This run cannot befriend her. (\(missing.count) prior bonds missing.)"
            }
            showDialogue(hint)
            return
        }

        switch bossConfig.befriendCondition {
        case .actUsed(let name, let times):
            hint = "Hint: Use \(name) \(times) time(s)."
        case .hpBelow(let f):
            hint = "Hint: Spare when HP is below \(Int(f * 100))%."
        case .turnsWithoutAttack(let n):
            hint = "Hint: Don't attack for \(n) turns."
        case .itemUsed(let item):
            hint = "Hint: Use \(item.rawValue) in battle."
        }
        showDialogue(hint)
    }

    // MARK: - Boss Attack / Dodge Phase

    private func beginDodgePhase() {
        print(">>> beginDodgePhase")
        isDodging = true
        soulNode.isHidden = false
        // Respawn the soul at the center of the battle box each dodge phase
        soulNode.position = battleBox.position
        soulInput = .zero
        showDialogue("\(bossConfig.name) attacks!")
    }

    private func fireBossPattern(_ pattern: AttackPatternType) {
        print(">>> fireBossPattern: \(pattern)")
        switch pattern {
        case .spreadShot(let count, let speed):
            fireSpread(count: count, speed: speed)
        case .chaseWave(let speed):
            fireChaseWave(speed: speed)
        case .ringBurst(let count, let speed):
            fireRingBurst(count: count, speed: speed)
        case .lineBarrage(let lanes, let speed):
            fireLineBarrage(lanes: lanes, speed: speed)
        case .randomBounce(let count, let speed):
            fireRandomBounce(count: count, speed: speed)
        case .homingShot(let count, let speed):
            fireHomingShot(count: count, speed: speed)
        case .delayedRing(let count, let speed):
            fireDelayedRing(count: count, speed: speed)
        case .crossFire(let speed):
            fireCrossFire(speed: speed)
        }

        bossEntity.component(ofType: AttackPatternComponent.self)?.advance()

        // Dodge window: 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            print(">>> dodge timer fired, calling endDodgePhase")
            self?.endDodgePhase()
        }
    }

    private func endDodgePhase() {
        isDodging = false
        bulletLayer.removeAllChildren()
        soulNode.isHidden = true
        soulInput = .zero
        turnSystem.bossAttackFinished()
    }

    // MARK: - Bullet Patterns

    /// Spread of bullets aimed downward toward the battle box.
    /// Spreads across an arc centered on the direction from boss to box center.
    private func fireSpread(count: Int, speed: CGFloat) {
        let origin = bossNode.position
        let target = battleBox.position
        let baseAngle = atan2(target.y - origin.y, target.x - origin.x)
        // Arc spread: total of ~80° centered on baseAngle
        let arcRadians: CGFloat = .pi / 2.25  // ~80°
        for i in 0..<count {
            let t = count == 1 ? 0.5 : CGFloat(i) / CGFloat(count - 1)
            let angle = baseAngle - arcRadians / 2 + t * arcRadians
            let dx = cos(angle) * speed
            let dy = sin(angle) * speed
            spawnBullet(at: origin, velocity: CGVector(dx: dx, dy: dy))
        }
    }

    private func fireChaseWave(speed: CGFloat) {
        let origin = bossNode.position
        let target = soulNode.position
        let diff   = CGPoint(x: target.x - origin.x, y: target.y - origin.y)
        let len    = sqrt(diff.x * diff.x + diff.y * diff.y)
        guard len > 0 else { return }
        let norm   = CGVector(dx: diff.x / len * speed, dy: diff.y / len * speed)
        spawnBullet(at: origin, velocity: norm)
    }

    /// Ring burst — spawns bullets in a ring AROUND the battle box, all flying inward.
    /// This guarantees every bullet enters the play area where the soul is.
    private func fireRingBurst(count: Int, speed: CGFloat) {
        let center = battleBox.position
        let radius: CGFloat = 110  // just outside the box edges
        for i in 0..<count {
            let angle = CGFloat(i) / CGFloat(count) * 2 * .pi
            let spawnPos = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            // Velocity points inward (opposite of radial direction)
            let velocity = CGVector(
                dx: -cos(angle) * speed,
                dy: -sin(angle) * speed
            )
            spawnBullet(at: spawnPos, velocity: velocity)
        }
    }

    /// Vertical lanes of bullets falling straight down through the battle box.
    private func fireLineBarrage(lanes: Int, speed: CGFloat) {
        let center = battleBox.position
        let boxHalfW: CGFloat = 95
        let boxHalfH: CGFloat = 65
        let boxLeft = center.x - boxHalfW
        let boxWidth = boxHalfW * 2

        for i in 0..<lanes {
            let t = lanes == 1 ? 0.5 : CGFloat(i) / CGFloat(lanes - 1)
            let x = boxLeft + t * boxWidth
            // Spawn above the top of the box and travel down through it
            let start = CGPoint(x: x, y: center.y + boxHalfH + 30)
            spawnBullet(at: start, velocity: CGVector(dx: 0, dy: -speed))
        }
    }

    /// Random shots aimed at random points within the battle box (so they all enter the play area).
    private func fireRandomBounce(count: Int, speed: CGFloat) {
        let origin = bossNode.position
        let center = battleBox.position
        let boxHalfW: CGFloat = 95
        let boxHalfH: CGFloat = 65

        for _ in 0..<count {
            // Pick a random target inside the box
            let target = CGPoint(
                x: center.x + CGFloat.random(in: -boxHalfW...boxHalfW),
                y: center.y + CGFloat.random(in: -boxHalfH...boxHalfH)
            )
            let dx = target.x - origin.x
            let dy = target.y - origin.y
            let len = max(1, hypot(dx, dy))
            let velocity = CGVector(dx: dx / len * speed, dy: dy / len * speed)
            spawnBullet(at: origin, velocity: velocity, bouncing: true)
        }
    }

    /// Homing bullets — each bullet tracks the soul's position and turns toward it gradually.
    private func fireHomingShot(count: Int, speed: CGFloat) {
        let origin = bossNode.position
        for i in 0..<count {
            let stagger = TimeInterval(i) * 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + stagger) { [weak self] in
                guard let self else { return }
                let target = self.soulNode.position
                let dx = target.x - origin.x
                let dy = target.y - origin.y
                let len = max(1, hypot(dx, dy))
                let velocity = CGVector(dx: dx / len * speed, dy: dy / len * speed)
                self.spawnBullet(at: origin, velocity: velocity, homing: true)
            }
        }
    }

    /// Marks ring positions around the battle box, then 0.6s later fires bullets inward from those points.
    private func fireDelayedRing(count: Int, speed: CGFloat) {
        let center = battleBox.position
        let radius: CGFloat = 110

        // Show warning markers around the box edge
        var markers: [SKNode] = []
        var spawnPoints: [(pos: CGPoint, vel: CGVector)] = []
        for i in 0..<count {
            let angle = CGFloat(i) / CGFloat(count) * 2 * .pi
            let pos = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            let velocity = CGVector(dx: -cos(angle) * speed, dy: -sin(angle) * speed)
            spawnPoints.append((pos, velocity))

            let marker = SKShapeNode(circleOfRadius: 4)
            marker.fillColor = .systemRed
            marker.strokeColor = .clear
            marker.alpha = 0.5
            marker.position = pos
            marker.zPosition = 7
            addChild(marker)
            markers.append(marker)
        }

        // After delay, remove markers and fire bullets inward
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            markers.forEach { $0.removeFromParent() }
            for sp in spawnPoints {
                self.spawnBullet(at: sp.pos, velocity: sp.vel)
            }
        }
    }

    /// Bullets fired from all 4 edges of the battle box, aimed at the center.
    private func fireCrossFire(speed: CGFloat) {
        let boxCenter = battleBox.position
        let boxHalfW: CGFloat = 95
        let boxHalfH: CGFloat = 65

        // Top edge → down
        for i in 0..<3 {
            let x = boxCenter.x - boxHalfW + CGFloat(i + 1) * (boxHalfW * 2 / 4)
            spawnBullet(at: CGPoint(x: x, y: boxCenter.y + boxHalfH + 15),
                        velocity: CGVector(dx: 0, dy: -speed))
        }
        // Bottom edge → up
        for i in 0..<3 {
            let x = boxCenter.x - boxHalfW + CGFloat(i + 1) * (boxHalfW * 2 / 4)
            spawnBullet(at: CGPoint(x: x, y: boxCenter.y - boxHalfH - 15),
                        velocity: CGVector(dx: 0, dy: speed))
        }
        // Left edge → right
        for i in 0..<2 {
            let y = boxCenter.y - boxHalfH + CGFloat(i + 1) * (boxHalfH * 2 / 3)
            spawnBullet(at: CGPoint(x: boxCenter.x - boxHalfW - 15, y: y),
                        velocity: CGVector(dx: speed, dy: 0))
        }
        // Right edge → left
        for i in 0..<2 {
            let y = boxCenter.y - boxHalfH + CGFloat(i + 1) * (boxHalfH * 2 / 3)
            spawnBullet(at: CGPoint(x: boxCenter.x + boxHalfW + 15, y: y),
                        velocity: CGVector(dx: -speed, dy: 0))
        }
    }

    private func spawnBullet(at pos: CGPoint, velocity: CGVector, bouncing: Bool = false, homing: Bool = false) {
        let bullet = SKShapeNode(circleOfRadius: 5)
        bullet.fillColor = homing ? .systemPurple : .systemOrange
        bullet.strokeColor = .clear
        bullet.position = pos
        bullet.zPosition = 8
        bullet.name = "bullet"

        // Store velocity as userData so update() can move it
        bullet.userData = NSMutableDictionary()
        bullet.userData?["vx"] = velocity.dx
        bullet.userData?["vy"] = velocity.dy
        bullet.userData?["homing"] = homing

        bulletLayer.addChild(bullet)

        // Auto-remove after 4s so off-screen bullets don't accumulate
        bullet.run(SKAction.sequence([
            SKAction.wait(forDuration: 4.0),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Collision (Soul vs Bullet)

    private func checkBulletCollisions() {
        guard isDodging else { return }
        bulletLayer.children.forEach { bulletNode in
            guard let bullet = bulletNode as? SKShapeNode else { return }
            let dist = hypot(bullet.position.x - soulNode.position.x,
                             bullet.position.y - soulNode.position.y)
            if dist < 12 {
                let savedBySecondWind = PlayerStats.shared.takeDamage(4)
                flashSoul()
                bullet.removeFromParent()

                if savedBySecondWind {
                    showSecondWindFlash()
                }

                if !PlayerStats.shared.isAlive {
                    handlePlayerDeath()
                }
            }
        }
    }

    private func showSecondWindFlash() {
        let label = SKLabelNode(fontNamed: "Courier-Bold")
        label.text = "SECOND WIND!"
        label.fontSize = 22
        label.fontColor = .systemYellow
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.5)
        label.zPosition = 100
        addChild(label)
        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(by: 1.4, duration: 0.4),
                SKAction.fadeOut(withDuration: 0.4)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Condition Checks

    private func checkConditions() {
        let relation = bossEntity.component(ofType: RelationshipComponent.self)
        let hp       = bossEntity.component(ofType: HealthComponent.self)

        if hp?.isDead == true { return }  // already handled

        if relation?.evaluate(against: bossConfig.befriendCondition) == true {
            // Show spare prompt
            showDialogue("* \(bossConfig.name) could be spared now...")
        }

        run(SKAction.wait(forDuration: 0.5)) { [weak self] in
            self?.turnSystem.beginNextTurn()
        }
    }

    // MARK: - Resolution

    private var drMuhammadPhase: Int = 1

    private func handleBossDefeated() {
        // Dr. Muhammad has two phases — first "death" triggers transformation
        if bossConfig.id == "drMuhammad" && drMuhammadPhase == 1 {
            drMuhammadPhase = 2
            transformDrMuhammad()
            return
        }

        let lines = bossConfig.fightVictoryDialogue
        showDialogueSequence(lines) { [weak self] in
            guard let self else { return }
            GameManager.shared.resolveBoss(id: self.bossConfig.id, outcome: .defeated)
        }
    }

    private func transformDrMuhammad() {
        // Replace HP component with phase 2 stats
        bossEntity.removeComponent(ofType: HealthComponent.self)
        let phase2HP = HealthComponent(hp: 100)
        phase2HP.onDeath = { [weak self] in self?.handleBossDefeated() }
        bossEntity.addComponent(phase2HP)

        // Visually transform: change color and shake
        bossNode.run(SKAction.sequence([
            SKAction.colorize(with: .systemPurple, colorBlendFactor: 0.6, duration: 0.4),
            SKAction.scale(to: 1.2, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.2)
        ]))

        showDialogueSequence([
            "...",
            "I see. You are not what I thought.",
            "Then I will not hold back."
        ]) { [weak self] in
            self?.refreshBars()
            self?.turnSystem.beginNextTurn()
        }
    }

    private func handleBossBefriended() {
        bossNode.run(SKAction.colorize(with: .systemGreen, colorBlendFactor: 0.7, duration: 0.5))
        let lines = bossConfig.befriendVictoryDialogue
        showDialogueSequence(lines) { [weak self] in
            guard let self else { return }
            GameManager.shared.resolveBoss(id: self.bossConfig.id, outcome: .befriended)
        }
    }

    private func handlePlayerDeath() {
        isDodging = false
        bulletLayer.removeAllChildren()
        let fade = SKAction.fadeOut(withDuration: 1.0)
        soulNode.run(fade) {
            GameManager.shared.handleDeath()
        }
    }

    // MARK: - Dialogue Sequence

    private func showDialogueSequence(_ lines: [String], completion: @escaping () -> Void) {
        isDodging = false
        hideMenu()
        bulletLayer.removeAllChildren()

        var remaining = lines
        func showNext() {
            if remaining.isEmpty {
                run(SKAction.wait(forDuration: 0.5)) { completion() }
                return
            }
            let line = remaining.removeFirst()
            showDialogue(line)
            run(SKAction.wait(forDuration: 2.2)) { showNext() }
        }
        showNext()
    }

    // MARK: - Animations

    private func shakeBoss() {
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -6, y: 0, duration: 0.05),
            SKAction.moveBy(x: 12, y: 0, duration: 0.05),
            SKAction.moveBy(x: -6, y: 0, duration: 0.05)
        ])
        bossNode.run(shake)
    }

    private func flashSoul() {
        let flash = SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 1, duration: 0.05),
            SKAction.colorize(with: .systemRed, colorBlendFactor: 1, duration: 0.1)
        ])
        soulNode.run(flash)
    }

   

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : currentTime - lastTime
        lastTime = currentTime

        if isDodging {
            moveSoul(dt: dt)
            moveBullets(dt: dt)
            checkBulletCollisions()
        }

        updatePlayerHP()
    }

    private func moveBullets(dt: TimeInterval) {
        let dtFloat = CGFloat(dt)
        for bullet in bulletLayer.children {
            guard let userData = bullet.userData,
                  var vx = userData["vx"] as? CGFloat,
                  var vy = userData["vy"] as? CGFloat else { continue }

            let isHoming = (userData["homing"] as? Bool) ?? false
            if isHoming {
                // Slowly turn toward soul
                let dx = soulNode.position.x - bullet.position.x
                let dy = soulNode.position.y - bullet.position.y
                let len = max(1, hypot(dx, dy))
                let speed = hypot(vx, vy)
                let targetVx = dx / len * speed
                let targetVy = dy / len * speed
                let turn: CGFloat = 0.04  // lerp factor — lower = harder to evade
                vx += (targetVx - vx) * turn
                vy += (targetVy - vy) * turn
                userData["vx"] = vx
                userData["vy"] = vy
            }

            bullet.position.x += vx * dtFloat
            bullet.position.y += vy * dtFloat
        }
    }

    private func moveSoul(dt: TimeInterval) {
        guard let soul = soulEntity.component(ofType: SoulComponent.self) else { return }
        let speed = soul.speed
        let newX  = soulNode.position.x + soulInput.dx * speed * CGFloat(dt)
        let newY  = soulNode.position.y + soulInput.dy * speed * CGFloat(dt)

        // Clamp inside battle box
        let boxHalfW: CGFloat = 95
        let boxHalfH: CGFloat = 65
        let boxCenter = battleBox.position
        soulNode.position = CGPoint(
            x: max(boxCenter.x - boxHalfW, min(boxCenter.x + boxHalfW, newX)),
            y: max(boxCenter.y - boxHalfH, min(boxCenter.y + boxHalfH, newY))
        )
    }

    private var playerHPLabel: SKLabelNode?
    private func updatePlayerHP() {
        if playerHPLabel == nil {
            let lbl = SKLabelNode(fontNamed: "Courier")
            lbl.fontSize = 12
            lbl.fontColor = .white
            lbl.position = CGPoint(x: size.width / 2, y: size.height * 0.055)
            lbl.zPosition = 30
            addChild(lbl)
            playerHPLabel = lbl
        }
        playerHPLabel?.text = "Your HP: \(PlayerStats.shared.currentHP) / \(PlayerStats.shared.maxHP)"
    }

    // MARK: - Touch Input (menu + soul D-pad)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        if !menuNode.isHidden {
            handleMenuTouch(at: loc)
        } else if isDodging {
            updateSoulInput(from: loc)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDodging, let touch = touches.first else { return }
        let loc = touch.location(in: self)
        updateSoulInput(from: loc)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        soulInput = .zero
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        soulInput = .zero
    }

    /// Determine soul direction from which D-pad button (if any) the touch is over.
    private func updateSoulInput(from loc: CGPoint) {
        let hits = self.nodes(at: loc)
        var dir: CGVector = .zero
        for node in hits {
            switch node.name {
            case "soul_up":    dir = CGVector(dx: 0,  dy: 1);  break
            case "soul_down":  dir = CGVector(dx: 0,  dy: -1); break
            case "soul_left":  dir = CGVector(dx: -1, dy: 0);  break
            case "soul_right": dir = CGVector(dx: 1,  dy: 0);  break
            default: continue
            }
            if dir != .zero { break }
        }
        soulInput = dir
    }

    private func handleMenuTouch(at loc: CGPoint) {
        let nodes = self.nodes(at: loc)
        for node in nodes {
            switch node.name {
            case "btn_FIGHT":
                turnSystem.playerChose(.fight)

            case "btn_ACT":
                showActMenu()

            case "btn_ITEM":
                showItemMenu()

            case "btn_SPARE":
                turnSystem.playerChose(.spare)

            default:
                // Check ACT sub-buttons
                if let name = node.name, name.hasPrefix("act_") {
                    let actName = String(name.dropFirst(4))
                    if let opt = bossConfig.actOptions.first(where: { $0.name == actName }) {
                        turnSystem.playerChose(.act(opt))
                        clearSubMenu()
                    }
                }
                // Check ITEM sub-buttons
                if let name = node.name, name.hasPrefix("item_") {
                    let itemRaw = String(name.dropFirst(5))
                    if let item = PlayerStats.shared.items.first(where: { $0.rawValue == itemRaw }) {
                        turnSystem.playerChose(.item(item))
                        clearSubMenu()
                    }
                }
            }
        }
    }

    // MARK: - Sub Menus

    private func showActMenu() {
        clearSubMenu()
        for (i, opt) in bossConfig.actOptions.enumerated() {
            let btn = makeMenuButton(label: opt.name)
            btn.name = "act_\(opt.name)"
            btn.position = CGPoint(x: size.width / 2 - 80 + CGFloat(i) * 80,
                                   y: size.height * 0.14)
            btn.zPosition = 35
            menuNode.addChild(btn)
        }
    }

    private func showItemMenu() {
        clearSubMenu()
        let items = PlayerStats.shared.items
        if items.isEmpty {
            showDialogue("You have no items.")
            return
        }
        for (i, item) in items.enumerated() {
            let btn = makeMenuButton(label: item.rawValue)
            btn.name = "item_\(item.rawValue)"
            btn.position = CGPoint(x: size.width / 2 - 80 + CGFloat(i) * 80,
                                   y: size.height * 0.14)
            btn.zPosition = 35
            menuNode.addChild(btn)
        }
    }

    private func clearSubMenu() {
        menuNode.children
            .filter { $0.name?.hasPrefix("act_") == true || $0.name?.hasPrefix("item_") == true }
            .forEach { $0.removeFromParent() }
    }
}
