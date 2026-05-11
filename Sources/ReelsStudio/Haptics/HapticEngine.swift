import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Single-instance facade over `UIImpactFeedbackGenerator` /
/// `UINotificationFeedbackGenerator` for the editor's snap / delete / export
/// haptics. v0.4 Tier 3 surfaces three call patterns:
/// - ``snap()`` — pinch-zoom or drag-snap-to-adjacent-clip crossing.
/// - ``thud()`` — destructive action (delete clip / overlay).
/// - ``success()`` — long-running task completed (export).
///
/// **Why an actor instead of a per-call generator.** Each
/// `UIImpactFeedbackGenerator` does setup work on first `prepare()`. A pinch-
/// zoom gesture firing 3-4 snap callbacks per second creates a fresh
/// generator each call would burn that prep cost on every fire. The shared
/// instance prepares once and re-fires cheaply.
///
/// **macOS / visionOS.** No `UIFeedbackGenerator` on those platforms — every
/// call no-ops. The `.shared` singleton is `Sendable` so it can be used from
/// the main actor or from background tasks; the underlying generators are
/// touched only on the main actor (UIKit requirement) via the `@MainActor`
/// annotation.
@MainActor
final class HapticEngine {

    /// Process-wide instance. The editor reaches for this directly rather
    /// than threading it through every initializer — haptics are environment-
    /// level concerns, not per-screen state.
    static let shared = HapticEngine()

    #if canImport(UIKit)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()
    #endif

    private init() {
        #if canImport(UIKit)
        lightImpact.prepare()
        mediumImpact.prepare()
        notification.prepare()
        #endif
    }

    /// Light tap. Wired to `TimelineView.onZoomSnap` (pinch-zoom threshold
    /// crossing) and `onClipDragSnap` (drag-to-reorder boundary crossing) in
    /// `TimelineArea`. v0.5 routes the fire through ``AppSettings/shared``'s
    /// `hapticIntensity`: `off` returns early; `light` keeps the v0.4 feel;
    /// `medium` upgrades the impact style so power users who like a stronger
    /// snap can opt in without us redefining what "snap" means call-side.
    func snap() {
        #if canImport(UIKit)
        switch AppSettings.shared.hapticIntensity {
        case .off:
            return
        case .light:
            lightImpact.impactOccurred()
            lightImpact.prepare()
        case .medium:
            mediumImpact.impactOccurred()
            mediumImpact.prepare()
        }
        #endif
    }

    /// Medium thud. Reserved for delete actions (toolbar trash button, swipe-
    /// to-delete in `LayersSheet`); v0.4 Tier 4 wires the call sites. v0.5
    /// gates on `hapticIntensity == .off`; otherwise unchanged (a "medium"
    /// upgrade has nowhere to go from medium without a heavy style).
    func thud() {
        #if canImport(UIKit)
        guard AppSettings.shared.hapticIntensity != .off else { return }
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
        #endif
    }

    /// Success notification. Reserved for export completion; v0.4 Tier 4
    /// wires the call site after `Exporter.run()` resolves. Off intensity
    /// silences; everything else fires the system success pattern unchanged
    /// (a three-tap "ta-da" is its own feel; light/medium don't apply).
    func success() {
        #if canImport(UIKit)
        guard AppSettings.shared.hapticIntensity != .off else { return }
        notification.notificationOccurred(.success)
        notification.prepare()
        #endif
    }
}
