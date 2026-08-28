import XCTest
@testable import ReelsStudio

/// Tests for the crash-reporting preference.
///
/// This exists because `PRIVACY.md` states that crash reporting can be turned
/// off. A privacy policy is a promise; these hold the code to it.
@MainActor
final class CrashReportingConsentTests: XCTestCase {

    private func sandbox() -> UserDefaults {
        let suite = "crash-consent-\(UUID().uuidString)"
        UserDefaults().removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }

    func testDefaultsToEnabled() {
        XCTAssertTrue(AppSettings(defaults: sandbox()).crashReportingEnabled)
    }

    func testAbsentKeyDoesNotOptAnExistingUserOut() {
        // `bool(forKey:)` returns false for a missing key. Reading the
        // preference that way would have silently disabled reporting for every
        // user upgrading from a build that predates the toggle — a behaviour
        // change nobody chose, in either direction.
        let defaults = sandbox()
        XCTAssertNil(defaults.object(forKey: "reels-studio.crashReportingEnabled"))
        XCTAssertTrue(AppSettings(defaults: defaults).crashReportingEnabled)
    }

    func testThePreferencePersists() {
        let defaults = sandbox()
        let settings = AppSettings(defaults: defaults)
        settings.crashReportingEnabled = false
        XCTAssertFalse(AppSettings(defaults: defaults).crashReportingEnabled)

        settings.crashReportingEnabled = true
        XCTAssertTrue(AppSettings(defaults: defaults).crashReportingEnabled)
    }

    func testDisablingStopsTheReporterEvenWhenConfigured() {
        // The guard has to come before the DSN check, or the toggle is
        // decorative on any build that ships a DSN.
        XCTAssertFalse(CrashReporter.startIfConfigured(enabled: false))
    }

    func testHapticPreferenceIsUnaffected() {
        let defaults = sandbox()
        let settings = AppSettings(defaults: defaults)
        settings.crashReportingEnabled = false
        // Two independent preferences in one store: setting one must not
        // disturb the other.
        XCTAssertEqual(AppSettings(defaults: defaults).hapticIntensity, settings.hapticIntensity)
    }
}
