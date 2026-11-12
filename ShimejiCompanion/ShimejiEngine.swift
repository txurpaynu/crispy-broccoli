import SwiftUI
import QuartzCore

/// What the character is doing right now.
enum Behavior: Equatable {
    case idle, walk, sit, sleep, fall, climb, ceiling, dragged, land
}

/// Which edge of the screen the character is standing on.
enum Surface: Equatable {
    case floor, leftWall, rightWall, ceiling, air
}

/// Things the rest of the app may want to react to (speech bubbles, mood changes).
enum ShimejiEvent {
    case pickedUp, thrown, landedHard, landed, petted, startedSleeping, wokeUp, idleThought
}

/// Shimeji-style behaviour + simple physics. Ticks on a CADisplayLink while the app is open.
@MainActor
final class ShimejiEngine: ObservableObject {
    @Published private(set) var position: CGPoint = CGPoint(x: 150, y: -100)
    @Published private(set) var behavior: Behavior = .fall
    @Published private(set) var surface: Surface = .air
    @Published private(set) var facingRight = true
    @Published private(set) var frame = 0

    let size: CGFloat = 112
    /// 0...1, set from the companion's mood. Higher means more naps.
    var sleepiness: Double = 0
    var onEvent: ((ShimejiEvent) -> Void)?

    private var bounds: CGSize = .zero
    private var velocity: CGVector = .zero
    private var direction: CGFloat = 1
    private var timer: Double = 1.5
    private var animTime: Double = 0
    private var target: CGFloat?
    private var displayLink: CADisplayLink?
    private var proxy: DisplayLinkProxy?
    private var lastTimestamp: CFTimeInterval = 0
    private var dragOffset: CGSize = .zero

    // Tunables
    private let gravity: CGFloat = 1900
    private let walkSpeed: CGFloat = 55
    private let climbSpeed: CGFloat = 38
    private let crawlSpeed: CGFloat = 42

    private var minX: CGFloat { size / 2 }
    private var maxX: CGFloat { max(minX, bounds.width - size / 2) }
    private var minY: CGFloat { size / 2 }
    private var floorY: CGFloat { max(minY, bounds.height - size / 2) }

    // MARK: Lifecycle

    func setBounds(_ newSize: CGSize) {
        let first = bounds == .zero
        bounds = newSize
        if first {
            position = CGPoint(x: newSize.width * CGFloat.random(in: 0.3...0.7), y: -size)
            behavior = .fall
            surface = .air
            velocity = .zero
        } else {
            position.x = min(max(position.x, minX), maxX)
            position.y = min(position.y, floorY)
            if surface == .floor { position.y = floorY }
            if surface == .rightWall { position.x = maxX }
            if surface == .ceiling { position.y = minY }
        }
    }

    func start() {
        guard displayLink == nil else { return }
        let proxy = DisplayLinkProxy { [weak self] link in self?.step(link) }
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
        link.add(to: .main, forMode: .common)
        self.proxy = proxy
        displayLink = link
        lastTimestamp = 0
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        proxy = nil
    }

    private func step(_ link: CADisplayLink) {
        let now = link.timestamp
        defer { lastTimestamp = now }
        guard lastTimestamp > 0 else { return }
        tick(dt: now - lastTimestamp)
    }

    // MARK: Pose for rendering

    var pose: SpritePose {
        let alt = frame == 1
        switch behavior {
        case .idle: return .stand
        case .walk: return alt ? .walk2 : .walk1
        case .sit: return .sit
        case .sleep: return .sleep
        case .fall: return velocity.dy < 0 ? .jump : .fall
        case .climb: return alt ? .climb2 : .climb1
        case .ceiling: return alt ? .hang2 : .hang1
        case .dragged: return .dragged
        case .land: return .land
        }
    }

    /// Rotation for the drawn (non-image) sprite so its feet point at the surface.
    var rotationDegrees: Double {
        switch surface {
        case .leftWall: return 90
        case .rightWall: return -90
        case .ceiling: return 180
        default: return 0
        }
    }

    // MARK: Interaction

    func beginDrag(at point: CGPoint) {
        dragOffset = CGSize(width: position.x - point.x, height: position.y - point.y)
        behavior = .dragged
        surface = .air
        velocity = .zero
        target = nil
        onEvent?(.pickedUp)
    }

    func drag(to point: CGPoint) {
        if behavior != .dragged { beginDrag(at: point) }
        let p = CGPoint(x: point.x + dragOffset.width, y: point.y + dragOffset.height)
        if p.x < position.x - 1 { facingRight = false } else if p.x > position.x + 1 { facingRight = true }
        position = CGPoint(x: min(max(p.x, minX), maxX), y: min(max(p.y, minY), floorY))
    }

    func endDrag(velocity v: CGSize) {
        let limit: CGFloat = 1600
        velocity = CGVector(dx: min(max(v.width, -limit), limit), dy: min(max(v.height, -limit), limit))
        behavior = .fall
        surface = .air
        if hypot(velocity.dx, velocity.dy) > 900 { onEvent?(.thrown) }
    }

    /// Tap on the character: a happy hop.
    func pet() {
        if behavior == .sleep { onEvent?(.wokeUp) }
        onEvent?(.petted)
        guard surface == .floor else { return }
        velocity = CGVector(dx: 0, dy: -520)
        behavior = .fall
        surface = .air
    }

    /// Tap on empty floor: the character walks over (if it's on the floor).
    func walk(toX x: CGFloat) {
        guard surface == .floor, behavior != .dragged else { return }
        if behavior == .sleep { onEvent?(.wokeUp) }
        target = min(max(x, minX), maxX)
        set(.walk, for: 30)
    }

    // MARK: Simulation

    private func tick(dt raw: Double) {
        guard bounds.width > size, bounds.height > size else { return }
        let dt = CGFloat(min(raw, 1.0 / 20.0))
        animTime += Double(dt)
        timer -= Double(dt)

        switch behavior {
        case .dragged: break
        case .fall: physics(dt)
        case .walk: walk(dt)
        case .climb: climb(dt)
        case .ceiling: crawl(dt)
        case .idle, .sit, .sleep, .land:
            if timer <= 0 { decideNext() }
        }

        let fps: Double
        switch behavior {
        case .sleep: fps = 1
        case .dragged: fps = 8
        default: fps = 5
        }
        let f = Int(animTime * fps) % 2
        if f != frame { frame = f }
    }

    private func set(_ b: Behavior, for seconds: Double) {
        behavior = b
        timer = seconds
    }

    private func physics(_ dt: CGFloat) {
        velocity.dy += gravity * dt
        var p = position
        p.x += velocity.dx * dt
        p.y += velocity.dy * dt
        if abs(velocity.dx) > 20 { facingRight = velocity.dx > 0 }

        if p.x <= minX {
            p.x = minX
            if p.y < floorY - size, abs(velocity.dx) < 700, Double.random(in: 0..<1) < 0.5 {
                position = p
                grabWall(.leftWall)
                return
            }
            velocity.dx = abs(velocity.dx) * 0.4
        } else if p.x >= maxX {
            p.x = maxX
            if p.y < floorY - size, abs(velocity.dx) < 700, Double.random(in: 0..<1) < 0.5 {
                position = p
                grabWall(.rightWall)
                return
            }
            velocity.dx = -abs(velocity.dx) * 0.4
        }

        if p.y < minY {
            p.y = minY
            velocity.dy = abs(velocity.dy) * 0.3
        }

        if p.y >= floorY {
            p.y = floorY
            if velocity.dy > 950 {
                velocity.dy = -velocity.dy * 0.32
                velocity.dx *= 0.6
                position = p
                onEvent?(.landedHard)
                return
            }
            velocity = .zero
            position = p
            surface = .floor
            set(.land, for: 0.35)
            onEvent?(.landed)
            return
        }
        position = p
    }

    private func grabWall(_ wall: Surface) {
        surface = wall
        velocity = .zero
        direction = -1 // up
        set(.climb, for: Double.random(in: 2...6))
    }

    private func letGo() {
        let from = surface
        surface = .air
        behavior = .fall
        switch from {
        case .leftWall: velocity = CGVector(dx: 90, dy: 0)
        case .rightWall: velocity = CGVector(dx: -90, dy: 0)
        default: velocity = .zero
        }
    }

    private func walk(_ dt: CGFloat) {
        if let t = target {
            if abs(t - position.x) < 3 {
                target = nil
                set(.idle, for: Double.random(in: 1.5...3))
                return
            }
            direction = t > position.x ? 1 : -1
        }
        facingRight = direction > 0
        position.x += direction * walkSpeed * dt

        if position.x <= minX || position.x >= maxX {
            position.x = min(max(position.x, minX), maxX)
            if target == nil, Double.random(in: 0..<1) < 0.55 {
                grabWall(position.x <= minX ? .leftWall : .rightWall)
            } else {
                direction *= -1
                target = nil
            }
            return
        }
        if timer <= 0, target == nil { decideNext() }
    }

    private func climb(_ dt: CGFloat) {
        position.y += direction * climbSpeed * dt
        facingRight = (surface == .leftWall) == (direction < 0)

        if position.y <= minY {
            position.y = minY
            if Bool.random() {
                direction = surface == .leftWall ? 1 : -1
                surface = .ceiling
                set(.ceiling, for: Double.random(in: 3...8))
            } else {
                direction = 1
            }
            return
        }
        if position.y >= floorY {
            position.y = floorY
            surface = .floor
            set(.idle, for: 1)
            return
        }
        if timer <= 0 {
            if Double.random(in: 0..<1) < 0.35 {
                letGo()
            } else {
                direction = Bool.random() ? 1 : -1
                timer = Double.random(in: 2...5)
            }
        }
    }

    private func crawl(_ dt: CGFloat) {
        position.x += direction * crawlSpeed * dt
        position.y = minY
        facingRight = direction < 0 // view is upside down on the ceiling

        if position.x <= minX {
            position.x = minX
            surface = .leftWall
            direction = 1
            set(.climb, for: Double.random(in: 2...5))
            return
        }
        if position.x >= maxX {
            position.x = maxX
            surface = .rightWall
            direction = 1
            set(.climb, for: Double.random(in: 2...5))
            return
        }
        if timer <= 0 {
            if Double.random(in: 0..<1) < 0.5 {
                letGo()
            } else {
                timer = Double.random(in: 2...5)
            }
        }
    }

    private func decideNext() {
        guard surface == .floor else { return }
        let wasSleeping = behavior == .sleep
        if wasSleeping, Double.random(in: 0..<1) < sleepiness * 0.6 {
            timer = Double.random(in: 6...12)
            return
        }
        if wasSleeping { onEvent?(.wokeUp) }

        let r = Double.random(in: 0..<1)
        let sleepChance = 0.04 + sleepiness * 0.4
        if r < sleepChance {
            set(.sleep, for: Double.random(in: 8...16))
            onEvent?(.startedSleeping)
        } else if r < sleepChance + 0.45 {
            direction = Bool.random() ? 1 : -1
            set(.walk, for: Double.random(in: 2...7))
        } else if r < sleepChance + 0.62 {
            set(.idle, for: Double.random(in: 1.5...4))
            if Double.random(in: 0..<1) < 0.3 { onEvent?(.idleThought) }
        } else if r < sleepChance + 0.85 {
            set(.sit, for: Double.random(in: 3...8))
        } else {
            direction = Bool.random() ? 1 : -1
            velocity = CGVector(dx: direction * 140, dy: -620)
            surface = .air
            behavior = .fall
        }
    }
}

/// CADisplayLink needs an Objective-C target; this forwards ticks to a closure.
@MainActor
private final class DisplayLinkProxy: NSObject {
    let handler: (CADisplayLink) -> Void
    init(_ handler: @escaping (CADisplayLink) -> Void) { self.handler = handler }
    @objc func tick(_ link: CADisplayLink) { handler(link) }
}
