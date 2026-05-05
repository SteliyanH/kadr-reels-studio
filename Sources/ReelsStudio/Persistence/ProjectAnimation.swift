import Foundation
import CoreGraphics

// MARK: - ProjectAnimation (v0.3 schema v2)

/// On-disk shape for kadr's `Animation<Value>`. Generic over a Codable
/// value type so we can mirror animations of `Transform` / `Double` /
/// `Position` / `Size` without erasing the value type. Bridges to / from
/// `Kadr.Animation<Value>` per concrete value type live in
/// `ProjectAnimation+Bridge.swift`.
///
/// **Not directly Codable through kadr** — kadr's `Animation<Value: Animatable>`
/// uses `CMTime` for keyframe timing and `TimingFunction` (which carries
/// `CGPoint`s for `cubicBezier` and a closure for `custom`). The persisted
/// form drops the `custom` case (closure can't be serialized) and stores
/// times in seconds. Round-tripping a `custom` timing function is impossible
/// — those animations downgrade to `.linear` on load with the rest of the
/// keyframes intact.
struct ProjectAnimation<Value: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    var keyframes: [ProjectKeyframe<Value>]
    var timing: ProjectTimingFunction

    init(keyframes: [ProjectKeyframe<Value>], timing: ProjectTimingFunction = .linear) {
        self.keyframes = keyframes
        self.timing = timing
    }
}

struct ProjectKeyframe<Value: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    /// Clip-relative time in seconds.
    var timeSeconds: Double
    var value: Value

    init(timeSeconds: Double, value: Value) {
        self.timeSeconds = timeSeconds
        self.value = value
    }
}

enum ProjectTimingFunction: Codable, Sendable, Equatable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    /// Cubic Bézier with two control points in `(0...1, 0...1)`. Captures
    /// the `(p1, p2)` pair from kadr's `TimingFunction.cubicBezier(p1, p2)`.
    case cubicBezier(p1x: Double, p1y: Double, p2x: Double, p2y: Double)
}
