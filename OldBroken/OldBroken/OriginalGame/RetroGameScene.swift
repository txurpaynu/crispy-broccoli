import SpriteKit

struct RetroEntity: Codable {
    let id: String
    let x: Int
    let y: Int
    let dialogue: String
    var sprite: String?
}

struct RetroMapData: Codable {
    let tileSize: Int
    var rows: [String]
    let playerStart: [Int]
    let secretTile: [Int]
    let helperRoomTrigger: [Int]
    let walkable: String
    var entities: [RetroEntity]
}

enum Dir { case up, down, left, right
    var dx: Int { self == .left ? -1 : self == .right ? 1 : 0 }
    var dy: Int { self == .up ? -1 : self == .down ? 1 : 0 }
    var key: String { self == .up ? "player_up" : self == .down ? "player_down" : self == .left ? "player_left" : "player_right" }
}

/// The 1998 original game, top-down, tile based. Logic lives in RetroGameController;
/// the scene only draws, moves and reports what the player bumps into.
@MainActor
final class RetroGameScene: SKScene {
    weak var controller: RetroGameController?
    private(set) var map: RetroMapData
    private var grid: [[Character]]
    private var tiles: [[SKSpriteNode]] = []
    private let world = SKNode()
    let player = SKSpriteNode(texture: RetroArt.texture("player_down"))
    let fox = SKSpriteNode(texture: RetroArt.texture("fox"))
    private var npcNodes: [String: SKSpriteNode] = [:]
    private let cam = SKCameraNode()
    private(set) var px = 0, py = 0
    private(set) var facing: Dir = .down
    private var moving = false
    private var foxTrail: [(Int, Int)] = []
    let ts: CGFloat = 16

    var cols: Int { grid.first?.count ?? 0 }
    var rowsCount: Int { grid.count }

    init(map: RetroMapData) {
        self.map = map
        self.grid = map.rows.map { Array($0) }
        super.init(size: CGSize(width: 240, height: 136))
        scaleMode = .aspectFit
        backgroundColor = .black
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        addChild(world)
        addChild(cam)
        camera = cam
        build()
        px = map.playerStart[0]; py = map.playerStart[1]
        player.position = pos(px, py)
        player.zPosition = 10
        world.addChild(player)
        fox.zPosition = 9
        fox.isHidden = true
        world.addChild(fox)
        cam.position = player.position
    }

    required init?(coder: NSCoder) { fatalError() }

    func pos(_ x: Int, _ y: Int) -> CGPoint {
        CGPoint(x: CGFloat(x) * ts + ts / 2, y: CGFloat(rowsCount - 1 - y) * ts + ts / 2)
    }

    private func build() {
        tiles = []
        for (y, row) in grid.enumerated() {
            var line: [SKSpriteNode] = []
            for (x, c) in row.enumerated() {
                let n = SKSpriteNode(texture: RetroArt.texture(RetroArt.key(forTile: c, x: x, y: y)))
                n.size = CGSize(width: ts, height: ts)
                n.position = pos(x, y)
                world.addChild(n)
                line.append(n)
            }
            tiles.append(line)
        }
        // animate water by swapping textures
        let a = RetroArt.texture("water"), b = RetroArt.texture("water2")
        for (y, row) in grid.enumerated() {
            for (x, c) in row.enumerated() where c == "~" {
                let first = (x + y) % 2 == 0 ? a : b
                let second = first === a ? b : a
                tiles[y][x].run(.repeatForever(.animate(with: [first, second], timePerFrame: 0.6)))
            }
        }
        for e in map.entities {
            guard let s = e.sprite else { continue }
            let n = SKSpriteNode(texture: RetroArt.texture(s))
            n.position = pos(e.x, e.y)
            n.zPosition = 8
            world.addChild(n)
            npcNodes[e.id] = n
            n.run(.repeatForever(.sequence([.moveBy(x: 0, y: 1, duration: 0.5), .moveBy(x: 0, y: -1, duration: 0.5)])))
        }
    }

    func tile(_ x: Int, _ y: Int) -> Character {
        guard y >= 0, y < rowsCount, x >= 0, x < cols else { return "T" }
        return grid[y][x]
    }

    func setTile(_ x: Int, _ y: Int, _ c: Character) {
        guard y >= 0, y < rowsCount, x >= 0, x < cols else { return }
        grid[y][x] = c
        tiles[y][x].removeAllActions()
        tiles[y][x].texture = RetroArt.texture(RetroArt.key(forTile: c, x: x, y: y))
    }

    func entity(at x: Int, _ y: Int) -> RetroEntity? {
        map.entities.first { $0.x == x && $0.y == y }
    }

    func removeEntity(_ id: String) { map.entities.removeAll { $0.id == id } }

    private func walkable(_ x: Int, _ y: Int) -> Bool {
        if let e = entity(at: x, y), e.sprite != nil { return false }
        if !fox.isHidden, let last = foxTrail.last, last == (x, y) { return true }
        return map.walkable.contains(tile(x, y))
    }

    func face(_ d: Dir) {
        facing = d
        player.texture = RetroArt.texture(d.key)
    }

    /// One tile step. Returns immediately if a step is already in progress.
    func step(_ d: Dir) {
        guard !moving else { return }
        face(d)
        let nx = px + d.dx, ny = py + d.dy
        guard walkable(nx, ny) else {
            AudioManager.shared.play(.retroBump)
            moving = true
            run(.wait(forDuration: 0.18)) { [weak self] in
                self?.moving = false
                self?.controller?.onBump(x: nx, y: ny, dir: d)
            }
            return
        }
        moving = true
        let prev = (px, py)
        px = nx; py = ny
        AudioManager.shared.play(.retroStep)
        player.run(.move(to: pos(nx, ny), duration: 0.15)) { [weak self] in
            guard let self else { return }
            self.moving = false
            self.controller?.onStep(x: nx, y: ny)
        }
        if !fox.isHidden {
            foxTrail.append(prev)
            if foxTrail.count > 1 { foxTrail.removeFirst() }
            if let t = foxTrail.first {
                fox.run(.move(to: pos(t.0, t.1), duration: 0.18))
                fox.xScale = t.0 < nx ? 1 : (t.0 > nx ? -1 : fox.xScale)
            }
        }
    }

    func showFox() {
        guard fox.isHidden else { return }
        let behind = (px - facing.dx, py - facing.dy)
        let spot = map.walkable.contains(tile(behind.0, behind.1)) ? behind : (px + 1, py)
        fox.position = pos(spot.0, spot.1)
        foxTrail = [spot]
        fox.isHidden = false
        fox.alpha = 0
        fox.run(.sequence([.repeat(.sequence([.fadeAlpha(to: 1, duration: 0.05), .fadeAlpha(to: 0.2, duration: 0.05)]), count: 6),
                           .fadeAlpha(to: 1, duration: 0.1)]))
        fox.run(.repeatForever(.sequence([.moveBy(x: 0, y: 1, duration: 0.35), .moveBy(x: 0, y: -1, duration: 0.35)])), withKey: "bob")
    }

    func glitchWorld() {
        world.run(.sequence([.moveBy(x: 3, y: 0, duration: 0.03), .moveBy(x: -6, y: 1, duration: 0.03),
                             .moveBy(x: 3, y: -1, duration: 0.03)]))
        for _ in 0..<12 {
            let x = Int.random(in: 0..<cols), y = Int.random(in: 0..<rowsCount)
            let t = tiles[y][x]
            let orig = t.texture
            t.texture = RetroArt.texture("missing")
            t.run(.sequence([.wait(forDuration: Double.random(in: 0.08...0.35)), .run { t.texture = orig }]))
        }
    }

    var facingTile: (Int, Int) { (px + facing.dx, py + facing.dy) }

    override func update(_ currentTime: TimeInterval) {
        if let c = controller, c.canMove, let d = c.held {
            step(d)
        }
        let target = player.position
        cam.position = CGPoint(x: cam.position.x + (target.x - cam.position.x) * 0.2,
                               y: cam.position.y + (target.y - cam.position.y) * 0.2)
    }
}
