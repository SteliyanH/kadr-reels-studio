import Foundation
import CoreMedia
import CoreGraphics
import Kadr

// MARK: - Document → kadr Animation

extension ProjectDocument {

    /// Reconstruct a kadr `Animation<Double>` (used for opacity, filter
    /// scalars, speed curves) from its persisted form.
    nonisolated static func runtimeDoubleAnimation(
        from data: ProjectAnimation<Double>
    ) -> Kadr.Animation<Double> {
        Kadr.Animation<Double>.keyframes(
            data.keyframes.map { kf in
                Kadr.Animation<Double>.Keyframe.at(kf.timeSeconds, value: kf.value)
            },
            timing: runtimeTiming(from: data.timing)
        )
    }

    /// Reconstruct a kadr `Animation<Transform>`.
    nonisolated static func runtimeTransformAnimation(
        from data: ProjectAnimation<ProjectTransform>
    ) -> Kadr.Animation<Transform> {
        Kadr.Animation<Transform>.keyframes(
            data.keyframes.map { kf in
                Kadr.Animation<Transform>.Keyframe.at(
                    kf.timeSeconds,
                    value: runtimeTransform(from: kf.value)
                )
            },
            timing: runtimeTiming(from: data.timing)
        )
    }

    nonisolated static func runtimeTiming(from data: ProjectTimingFunction) -> TimingFunction {
        switch data {
        case .linear:     return .linear
        case .easeIn:     return .easeIn
        case .easeOut:    return .easeOut
        case .easeInOut:  return .easeInOut
        case .cubicBezier(let p1x, let p1y, let p2x, let p2y):
            return .cubicBezier(
                CGPoint(x: p1x, y: p1y),
                CGPoint(x: p2x, y: p2y)
            )
        }
    }
}

// MARK: - kadr Animation → Document

extension ProjectDocument {

    nonisolated static func documentDoubleAnimation(
        from animation: Kadr.Animation<Double>
    ) -> ProjectAnimation<Double> {
        ProjectAnimation<Double>(
            keyframes: animation.keyframes.map { kf in
                ProjectKeyframe(
                    timeSeconds: CMTimeGetSeconds(kf.time),
                    value: kf.value
                )
            },
            timing: documentTiming(from: animation.timing)
        )
    }

    nonisolated static func documentTransformAnimation(
        from animation: Kadr.Animation<Transform>
    ) -> ProjectAnimation<ProjectTransform> {
        ProjectAnimation<ProjectTransform>(
            keyframes: animation.keyframes.map { kf in
                ProjectKeyframe(
                    timeSeconds: CMTimeGetSeconds(kf.time),
                    value: documentTransform(from: kf.value)
                )
            },
            timing: documentTiming(from: animation.timing)
        )
    }

    /// Map a kadr `TimingFunction` to its persisted form. `.custom` (closure-
    /// backed) downgrades to `.linear` — closures aren't serializable, and
    /// dropping the timing function entirely would silently change the
    /// animation's shape.
    nonisolated static func documentTiming(from timing: TimingFunction) -> ProjectTimingFunction {
        switch timing {
        case .linear:    return .linear
        case .easeIn:    return .easeIn
        case .easeOut:   return .easeOut
        case .easeInOut: return .easeInOut
        case .cubicBezier(let p1, let p2):
            return .cubicBezier(
                p1x: Double(p1.x), p1y: Double(p1.y),
                p2x: Double(p2.x), p2y: Double(p2.y)
            )
        case .custom:
            // Closure can't round-trip — downgrade with the keyframes intact.
            // Consumers wanting custom timing rebuild it from primitives.
            return .linear
        }
    }
}
