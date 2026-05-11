import Foundation
import Combine

/// App-wide preferences. UserDefaults-backed; separate from
/// ``ProjectDocument`` because these are device-environment scoped, not
/// project-scoped (per the v0.5 RFC — haptic preference travels with the
/// user, not with the file).
///
/// Owned at the app root via ``ReelsStudioApp``'s `@StateObject`; reached
/// from any screen via `@EnvironmentObject`. ``HapticEngine`` reads the
/// process-global ``shared`` instance directly so gating doesn't need to
/// thread state through every call site.
@MainActor
final class AppSettings: ObservableObject {

    /// Process-global instance. ``HapticEngine`` reads from this so haptic
    /// fires gate on the current intensity without per-call dependency
    /// injection. Production code uses `.shared`; tests build a fresh
    /// instance with a sandboxed `UserDefaults` suite.
    static let shared = AppSettings()

    @Published var hapticIntensity: HapticIntensity {
        didSet { defaults.set(hapticIntensity.rawValue, forKey: Keys.hapticIntensity) }
    }

    private let defaults: UserDefaults

    /// - Parameter defaults: Injectable for tests (pass a sandboxed
    ///   `UserDefaults(suiteName:)`); production uses `.standard`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Keys.hapticIntensity),
           let parsed = HapticIntensity(rawValue: raw) {
            self.hapticIntensity = parsed
        } else {
            // Default matches the v0.4 hardcoded behavior — light impact on
            // every fire — so the upgrade from v0.4 to v0.5 doesn't change
            // anyone's feel without explicit consent.
            self.hapticIntensity = .light
        }
    }

    private enum Keys {
        static let hapticIntensity = "reels-studio.hapticIntensity"
    }
}

/// User-facing haptic strength. Wired into ``HapticEngine`` so every
/// `snap` / `thud` / `success` call respects the current intensity.
enum HapticIntensity: String, Codable, CaseIterable, Sendable {
    case off
    case light
    case medium

    /// User-facing label for the segmented picker.
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .light: return "Light"
        case .medium: return "Medium"
        }
    }
}
