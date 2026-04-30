// Components.swift
/*
 Author: Cameron Ridgley
 Worked on this caude while having claude in help with the methods and strutures from time to time
 Also having claude fix bugs when necessary
 */

import SpriteKit
import GameplayKit



final class VisualComponent: GKComponent {
    let node: SKNode

    init(node: SKNode) {
        self.node = node
        super.init()
    }

    required init?(coder: NSCoder) { fatalError() }
}



final class MovementComponent: GKComponent {
    var speed: CGFloat
    var tileSize: CGFloat = 32
    var isMoving: Bool = false

    init(speed: CGFloat) {
        self.speed = speed
        super.init()
    }

    required init?(coder: NSCoder) { fatalError() }

 
    func move(direction: Direction, in scene: OverworldScene) {
        guard !isMoving,
              let visual = entity?.component(ofType: VisualComponent.self)
        else { return }

        let delta = direction.vector(tileSize: tileSize)
        let target = visual.node.position + delta

        guard scene.isWalkable(at: target) else { return }

        isMoving = true
        let move = SKAction.move(to: target, duration: 0.12)
        move.timingMode = .easeInEaseOut
        visual.node.run(move) { [weak self] in
            self?.isMoving = false
        }
    }
}



final class HealthComponent: GKComponent {
    private(set) var current: Int
    let maximum: Int
    var onDeath: (() -> Void)?

    var fraction: CGFloat { CGFloat(current) / CGFloat(maximum) }
    var isDead: Bool { current <= 0 }

    init(hp: Int) {
        self.current = hp
        self.maximum = hp
        super.init()
    }

    required init?(coder: NSCoder) { fatalError() }

    func takeDamage(_ amount: Int) {
        current = max(0, current - amount)
        if isDead { onDeath?() }
    }

    func heal(_ amount: Int) {
        current = min(maximum, current + amount)
    }
}



final class RelationshipComponent: GKComponent {
    enum RelationshipState {
        case hostile
        case warming
        case befriended
    }

    private(set) var state: RelationshipState = .hostile
    private(set) var actProgress: [String: Int] = [:]
    private(set) var turnsWithoutPlayerAttack: Int = 0

    var onBefriended: (() -> Void)?

    required init?(coder: NSCoder) { fatalError() }
    override init() { super.init() }

    func recordAct(named name: String) {
        actProgress[name, default: 0] += 1
        if state == .hostile { state = .warming }
    }

    func recordPlayerSkippedAttack() {
        turnsWithoutPlayerAttack += 1
    }

    func resetAttackStreak() {
        turnsWithoutPlayerAttack = 0
    }

    func evaluate(against condition: BefriendCondition) -> Bool {
        switch condition {
        case .actUsed(let name, let times):
            return (actProgress[name] ?? 0) >= times

        case .hpBelow(let fraction):
            guard let hp = entity?.component(ofType: HealthComponent.self) else { return false }
            return hp.fraction <= fraction && state == .warming

        case .turnsWithoutAttack(let needed):
            return turnsWithoutPlayerAttack >= needed

        case .itemUsed:
            return false
        }
    }
}



final class AttackPatternComponent: GKComponent {
    let patterns: [AttackPatternType]
    private var index: Int = 0

    init(patterns: [AttackPatternType]) {
        self.patterns = patterns
        super.init()
    }

    required init?(coder: NSCoder) { fatalError() }

    var currentPattern: AttackPatternType { patterns[index] }

    func advance() {
        index = (index + 1) % patterns.count
    }
}



final class SoulComponent: GKComponent {
    var speed: CGFloat
    var velocity: CGVector = .zero

    init(speed: CGFloat) {
        self.speed = speed
        super.init()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func update(deltaTime: TimeInterval) {
        guard let visual = entity?.component(ofType: VisualComponent.self) else { return }
        let dt = CGFloat(deltaTime)
        visual.node.position.x += velocity.dx * dt
        visual.node.position.y += velocity.dy * dt
    }
}



enum Direction: CaseIterable {
    case up, down, left, right

    func vector(tileSize: CGFloat) -> CGPoint {
        switch self {
        case .up:    return CGPoint(x: 0,         y: tileSize)
        case .down:  return CGPoint(x: 0,         y: -tileSize)
        case .left:  return CGPoint(x: -tileSize, y: 0)
        case .right: return CGPoint(x: tileSize,  y: 0)
        }
    }
}



func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}
