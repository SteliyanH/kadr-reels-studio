import Foundation
import SwiftUI

/// App-wide preferences. UserDefaults-backed; separate from
/// ``ProjectDocument`` because these are device-environment scoped, not
/// project-scoped (per the v0.5 RFC — haptic preference travels with the
/// user, not with the file).
///
/// Owned at the app root via ``ReelsStudioApp``'s `@State`; reached
/// from any screen via `@Environment(AppSettings.self)`. ``HapticEngine`` reads the
/// process-global ``shared`` instance directly so gating doesn't need to
/// thread state through every call site.
@MainActor
@Observable
final class AppSettings {

    /// Process-global instance. ``HapticEngine`` reads from this so haptic
    /// fires gate on the current intensity without per-call dependency
    /// injection. Production code uses `.shared`; tests build a fresh
    /// instance with a sandboxed `UserDefaults` suite.
    static let shared = AppSettings()

    var hapticIntensity: HapticIntensity {
        didSet { defaults.set(hapticIntensity.rawValue, forKey: Keys.hapticIntensity) }
    }

    /// Which appearance the app's chrome follows.
    ///
    /// Device-scoped, like ``hapticIntensity`` — an appearance preference
    /// travels with the person, not with the project, so this is not a
    /// `ProjectDocument` field and needs no schema bump.
    ///
    /// The editor is unaffected: it is dark in both appearances by design.
    var appearance: AppearanceChoice {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    /// Whether to send a diagnostic report when the app crashes.
    ///
    /// Defaults to on. Crash reports carry the stack, the app version, the OS
    /// version and the device model — no media, no project contents, no file
    /// names, and nothing that identifies a person. That is a defensible
    /// default, but "defensible" is not the same as "not asked", and a privacy
    /// policy that says reporting can be turned off has to be true.
    ///
    /// Read at launch by ``CrashReporter/startIfConfigured()``. Turning it off
    /// takes effect on the next launch, because Sentry cannot be unstarted
    /// within a process — the toggle's caption says so rather than implying an
    /// immediacy it does not have.
    var crashReportingEnabled: Bool {
        didSet { defaults.set(crashReportingEnabled, forKey: Keys.crashReportingEnabled) }
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
        // `object(forKey:)` rather than `bool(forKey:)`: the latter returns
        // false for an absent key, which would silently opt every existing
        // user out on upgrade rather than leaving the default in place.
        self.crashReportingEnabled = defaults.object(forKey: Keys.crashReportingEnabled) as? Bool ?? true
        if let raw = defaults.string(forKey: Keys.appearance),
           let parsed = AppearanceChoice(rawValue: raw) {
            self.appearance = parsed
        } else {
            // Following the system is the behaviour every build before this
            // one effectively had — chrome was light because nothing read the
            // appearance, so `.system` is the least surprising default.
            self.appearance = .system
        }
    }

    private enum Keys {
        static let hapticIntensity = "reels-studio.hapticIntensity"
        static let crashReportingEnabled = "reels-studio.crashReportingEnabled"
        static let appearance = "reels-studio.appearance"
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

/// Which appearance the app's chrome follows.
enum AppearanceChoice: String, Codable, CaseIterable, Sendable {
    case system, light, dark

    var displayName: String {
        switch self {
        case .system: return NSLocalizedString("settings.appearance.system", comment: "")
        case .light:  return NSLocalizedString("settings.appearance.light", comment: "")
        case .dark:   return NSLocalizedString("settings.appearance.dark", comment: "")
        }
    }

    /// What to hand `preferredColorScheme`. `nil` means "follow the device",
    /// which is exactly what SwiftUI wants for the system case.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
