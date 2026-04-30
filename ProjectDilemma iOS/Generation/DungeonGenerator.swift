// DungeonGenerator.swift
// Procedural dungeon: 5 main rooms in a line, with optional side branches
// (33% chance each, off rooms 2-4). Side rooms can be Shop, Treasure,
// Fountain, or Mini-Encounter.
/*
 Author: Cameron Ridgley
 Worked on this caude while having claude in help with the methods and strutures from time to time
 Also having claude fix bugs when necessary
 */

import SpriteKit

// MARK: - Tile Type

enum TileType: Equatable {
    case floor
    case wall
    case bossDoor(bossID: String)
    case chest(id: String)
    case spikes
    case arrowTrap(direction: Direction)
    case campfire(id: String)
    case gold(id: String, amount: Int)

    // Side room tiles
    case shopkeeper(id: String)
    case fountain(id: String)
    case treasureChest(id: String)
    case enemy(id: String, type: EnemyType)

    case empty
}

// MARK: - Enemy Type

enum EnemyType: String, Equatable {
    case slime    // weak, slow
    case bat      // medium, fast
    case goblin   // tough, drops more gold

    var maxHP: Int {
        switch self {
        case .slime:  return 12
        case .bat:    return 18
        case .goblin: return 28
        }
    }

    var damage: Int {
        switch self {
        case .slime:  return 2
        case .bat:    return 3
        case .goblin: return 4
        }
    }

    var goldReward: Int {
        switch self {
        case .slime:  return 5
        case .bat:    return 8
        case .goblin: return 15
        }
    }

    var displayName: String {
        switch self {
        case .slime:  return "Slime"
        case .bat:    return "Bat"
        case .goblin: return "Goblin"
        }
    }

    var displaySymbol: String {
        switch self {
        case .slime:  return "◉"
        case .bat:    return "ᗒ"
        case .goblin: return "Ω"
        }
    }
}

// MARK: - Side Room Type

enum SideRoomKind: CaseIterable {
    case shop
    case treasure
    case fountain
    case miniEncounter
}

// MARK: - Room

struct Room {
    let id: String
    let rect: CGRect
    var bossID: String?

    var center: CGPoint {
        CGPoint(x: rect.midX, y: rect.midY)
    }
}

// MARK: - DungeonGenerator

final class DungeonGenerator {

    let tileSize: CGFloat = 32
    let mapWidth: Int = 50
    let mapHeight: Int = 24

    private(set) var rooms: [Room] = []
    private(set) var tileGrid: [[TileType]] = []
    private(set) var bossRoomID: String = ""

    private var sideBranchChance: Double = 0.33

    // MARK: - Generate

    func generate(floor: Int, bossID: String) -> [[TileType]] {
        bossRoomID = bossID
        tileGrid = Array(repeating: Array(repeating: .wall, count: mapWidth), count: mapHeight)
        rooms = []

        // Build 5 main rooms in a horizontal chain with vertical jitter
        let mainRooms = buildMainRooms()
        rooms.append(contentsOf: mainRooms)

        // Connect each main room to the next
        for i in 0..<(mainRooms.count - 1) {
            connectRooms(mainRooms[i], mainRooms[i + 1])
        }

        // For rooms 2-4 (indices 1, 2, 3), maybe spawn a side room
        for i in 1...3 {
            guard Double.random(in: 0..<1) < sideBranchChance else { continue }
            if let side = spawnSideRoom(off: mainRooms[i], floor: floor) {
                rooms.append(side)
            }
        }

        // Place chest/campfire/gold/hazards in main rooms
        if let secondRoom = mainRooms[safe: 1] {
            placeChest(in: secondRoom, id: "chest_floor\(floor)")
        }
        if let lastBeforeBoss = mainRooms[safe: mainRooms.count - 2] {
            placeCampfire(in: lastBeforeBoss, floor: floor)
        }
        // Gold scattered through middle rooms
        for i in 1..<(mainRooms.count - 1) {
            placeGoldPiles(in: mainRooms[i], floor: floor, index: i)
        }
        // Wandering enemies in main rooms 2-4
        for i in 1...3 {
            placeWanderingEnemies(in: mainRooms[i], floor: floor, index: i)
        }

        scatterHazards(floor: floor, avoiding: [mainRooms[0]])

        // Boss door wall
        if let bossRoom = mainRooms.last {
            placeBossDoorWall(in: bossRoom, bossID: bossID)
        }

        return tileGrid
    }

    // MARK: - Main Room Layout

    private func buildMainRooms() -> [Room] {
        // 5 rooms arranged left → right with vertical variation
        let count = 5
        var result: [Room] = []
        let spacing = (mapWidth - 6) / (count - 1)

        for i in 0..<count {
            let baseX = 2 + i * spacing
            let w = Int.random(in: 5...7)
            let h = Int.random(in: 4...6)
            // Vertical jitter: rooms 2-4 can be higher or lower than the spine
            let jitter = (i == 0 || i == count - 1) ? 0 : Int.random(in: -3...3)
            let centerY = mapHeight / 2 + jitter
            let y = max(2, min(mapHeight - h - 2, centerY - h / 2))
            let id = (i == 0) ? "start" : (i == count - 1 ? "boss" : "main_\(i)")

            let room = carveRoom(id: id, x: baseX, y: y, w: w, h: h,
                                  bossID: i == count - 1 ? bossRoomID : nil)
            result.append(room)
        }
        return result
    }

    // MARK: - Side Room

    private func spawnSideRoom(off main: Room, floor: Int) -> Room? {
        // Place a side room above or below the main room
        let above = Bool.random()
        let w = 5
        let h = 4

        let x = Int(main.center.x) - w / 2
        let y = above
            ? Int(main.rect.maxY) + 2
            : Int(main.rect.minY) - h - 2

        guard y >= 1, y + h < mapHeight - 1, x >= 1, x + w < mapWidth - 1 else { return nil }

        let kind = SideRoomKind.allCases.randomElement()!
        let id = "side_\(main.id)_\(kind)"
        let room = carveRoom(id: id, x: x, y: y, w: w, h: h)

        // Connect side room to main room with a short corridor
        let corridorX = Int(main.center.x)
        let mainEdgeY = above ? Int(main.rect.maxY) : Int(main.rect.minY) - 1
        let sideEdgeY = above ? y - 1 : y + h
        let yMin = min(mainEdgeY, sideEdgeY)
        let yMax = max(mainEdgeY, sideEdgeY)
        for row in yMin...yMax {
            guard row < mapHeight, corridorX < mapWidth else { continue }
            tileGrid[row][corridorX] = .floor
        }

        // Populate the side room based on kind
        let cx = Int(room.center.x)
        let cy = Int(room.center.y)
        guard cy < mapHeight, cx < mapWidth else { return room }

        switch kind {
        case .shop:
            tileGrid[cy][cx] = .shopkeeper(id: "shop_f\(floor)_\(main.id)")
        case .treasure:
            tileGrid[cy][cx] = .treasureChest(id: "treasure_f\(floor)_\(main.id)")
        case .fountain:
            tileGrid[cy][cx] = .fountain(id: "fountain_f\(floor)_\(main.id)")
        case .miniEncounter:
            // Two enemies in the room
            let types: [EnemyType] = [.slime, .bat, .goblin]
            tileGrid[cy][cx] = .enemy(id: "mini_\(main.id)_a", type: types.randomElement()!)
            if cx + 1 < mapWidth {
                tileGrid[cy][cx + 1] = .enemy(id: "mini_\(main.id)_b", type: types.randomElement()!)
            }
        }

        return room
    }

    // MARK: - Carving

    @discardableResult
    private func carveRoom(id: String, x: Int, y: Int, w: Int, h: Int, bossID: String? = nil) -> Room {
        for row in y..<(y + h) {
            for col in x..<(x + w) {
                guard row < mapHeight, col < mapWidth, row >= 0, col >= 0 else { continue }
                tileGrid[row][col] = .floor
            }
        }
        let rect = CGRect(x: x, y: y, width: w, height: h)
        return Room(id: id, rect: rect, bossID: bossID)
    }

    private func connectRooms(_ a: Room, _ b: Room) {
        let startX = Int(a.center.x)
        let startY = Int(a.center.y)
        let endX   = Int(b.center.x)
        let endY   = Int(b.center.y)

        let minX = min(startX, endX)
        let maxX = max(startX, endX)
        for col in minX...maxX {
            guard startY < mapHeight, col < mapWidth, startY >= 0 else { continue }
            tileGrid[startY][col] = .floor
        }

        let minY = min(startY, endY)
        let maxY = max(startY, endY)
        for row in minY...maxY {
            guard row < mapHeight, endX < mapWidth, endX >= 0 else { continue }
            tileGrid[row][endX] = .floor
        }
    }

    // MARK: - Special Tiles

    private func placeChest(in room: Room, id: String) {
        let cx = Int(room.center.x) + 1
        let cy = Int(room.center.y)
        guard cy < mapHeight, cx < mapWidth else { return }
        tileGrid[cy][cx] = .chest(id: id)
    }

    private func placeGoldPiles(in room: Room, floor: Int, index: Int) {
        let target = Int.random(in: 1...2)
        var placed = 0
        var attempts = 0
        while placed < target && attempts < 10 {
            attempts += 1
            let col = Int.random(in: Int(room.rect.minX)..<Int(room.rect.maxX))
            let row = Int.random(in: Int(room.rect.minY)..<Int(room.rect.maxY))
            guard col < mapWidth, row < mapHeight else { continue }
            if case .floor = tileGrid[row][col] {
                let amount = Int.random(in: 5...12)
                tileGrid[row][col] = .gold(id: "gold_f\(floor)_\(index)_\(placed)", amount: amount)
                placed += 1
            }
        }
    }

    private func placeWanderingEnemies(in room: Room, floor: Int, index: Int) {
        // 50% chance to place 1 wandering enemy in a main room
        guard Double.random(in: 0..<1) < 0.5 else { return }

        let types: [EnemyType] = [.slime, .bat, .goblin]
        var attempts = 0
        while attempts < 8 {
            attempts += 1
            let col = Int.random(in: Int(room.rect.minX)..<Int(room.rect.maxX))
            let row = Int.random(in: Int(room.rect.minY)..<Int(room.rect.maxY))
            guard col < mapWidth, row < mapHeight else { continue }
            if case .floor = tileGrid[row][col] {
                tileGrid[row][col] = .enemy(id: "wander_f\(floor)_r\(index)", type: types.randomElement()!)
                return
            }
        }
    }

    private func placeCampfire(in room: Room, floor: Int) {
        let cx = Int(room.rect.minX) + 1
        let cy = Int(room.center.y)
        guard cx < mapWidth, cy < mapHeight else { return }
        if case .floor = tileGrid[cy][cx] {
            tileGrid[cy][cx] = .campfire(id: "campfire_f\(floor)")
        }
    }

    private func placeBossDoorWall(in room: Room, bossID: String) {
        let leftX = Int(room.rect.minX) - 1
        let cy = Int(room.center.y)
        guard leftX >= 0, cy < mapHeight else { return }
        tileGrid[cy][leftX] = .bossDoor(bossID: bossID)
    }

    private func scatterHazards(floor: Int, avoiding safeRooms: [Room]) {
        let spikeCount: Int = 3 + floor
        let trapCount:  Int = 1 + floor

        var floorTiles: [(col: Int, row: Int)] = []
        for row in 0..<mapHeight {
            for col in 0..<mapWidth {
                if case .floor = tileGrid[row][col] {
                    let pt = CGPoint(x: col, y: row)
                    if !safeRooms.contains(where: { $0.rect.contains(pt) }) {
                        floorTiles.append((col, row))
                    }
                }
            }
        }
        floorTiles.shuffle()

        var placed = 0
        for (col, row) in floorTiles where placed < spikeCount {
            tileGrid[row][col] = .spikes
            placed += 1
        }

        var trapsPlaced = 0
        for (col, row) in floorTiles.reversed() where trapsPlaced < trapCount {
            if case .spikes = tileGrid[row][col] { continue }
            if case .floor = tileGrid[row][col] {
                let dir = Direction.allCases.randomElement() ?? .right
                tileGrid[row][col] = .arrowTrap(direction: dir)
                trapsPlaced += 1
            }
        }
    }

    // MARK: - Tile Queries

    func worldPosition(col: Int, row: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(col) * tileSize + tileSize / 2,
            y: CGFloat(row) * tileSize + tileSize / 2
        )
    }

    func tileCoord(for worldPos: CGPoint) -> (col: Int, row: Int) {
        let col = Int(worldPos.x / tileSize)
        let row = Int(worldPos.y / tileSize)
        return (col, row)
    }

    func tileType(at worldPos: CGPoint) -> TileType {
        let (col, row) = tileCoord(for: worldPos)
        guard row >= 0, row < mapHeight, col >= 0, col < mapWidth else { return .wall }
        return tileGrid[row][col]
    }

    func isWalkable(at worldPos: CGPoint) -> Bool {
        switch tileType(at: worldPos) {
        case .floor, .chest, .spikes, .arrowTrap, .campfire, .gold,
             .shopkeeper, .fountain, .treasureChest, .enemy:
            return true
        case .bossDoor, .wall, .empty:
            return false
        }
    }

    func consumeTile(at worldPos: CGPoint) {
        let (col, row) = tileCoord(for: worldPos)
        guard row >= 0, row < mapHeight, col >= 0, col < mapWidth else { return }
        tileGrid[row][col] = .floor
    }

    // Convenience deprecated names — kept for OverworldScene callers
    func consumeChest(at p: CGPoint)    { consumeTile(at: p) }
    func consumeCampfire(at p: CGPoint) { consumeTile(at: p) }
    func consumeGold(at p: CGPoint)     { consumeTile(at: p) }

    var totalSize: CGSize {
        CGSize(
            width:  CGFloat(mapWidth)  * tileSize,
            height: CGFloat(mapHeight) * tileSize
        )
    }

    /// Player spawn position (center of start room).
    var playerSpawn: CGPoint {
        if let start = rooms.first {
            return CGPoint(x: start.center.x * tileSize + tileSize / 2,
                           y: start.center.y * tileSize + tileSize / 2)
        }
        return worldPosition(col: 5, row: mapHeight / 2)
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
