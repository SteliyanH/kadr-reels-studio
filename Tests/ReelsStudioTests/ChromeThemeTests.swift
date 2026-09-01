import XCTest
import SwiftUI
@testable import ReelsStudio

/// Tests for the two-theme chrome added in v0.16.
///
/// The palettes are asserted by value the way `ReelThemeTests` does, because a
/// design token is a fact and a typo in one is invisible at review.
@MainActor
final class ChromeThemeTests: XCTestCase {

    // MARK: - The palettes

    func testChromeDarkMatchesTheApprovedDesign() {
        let p = ReelPalette.chromeDark
        XCTAssertEqual(p.bg, Color(hex: 0x0C0C0E))
        XCTAssertEqual(p.surface, Color(hex: 0x1D1D20))
        XCTAssertEqual(p.surfaceRaised, Color(hex: 0x26262A))
        XCTAssertEqual(p.accent, Color(hex: 0x0A84FF))
        XCTAssertEqual(p.accentPressed, Color(hex: 0x0069DB))
        XCTAssertEqual(p.warning, Color(hex: 0xFF9500))
    }

    func testChromeLightMatchesTheApprovedDesign() {
        let p = ReelPalette.chromeLight
        XCTAssertEqual(p.bg, Color(hex: 0xF2F2F7))
        XCTAssertEqual(p.surface, Color(hex: 0xFFFFFF))
        XCTAssertEqual(p.accent, Color(hex: 0x007AFF))
        XCTAssertEqual(p.warning, Color(hex: 0xFF9500))
    }

    // MARK: - The resolver

    func testResolverPicksTheGround() {
        XCTAssertEqual(ReelPalette.chrome(for: .dark), .chromeDark)
        XCTAssertEqual(ReelPalette.chrome(for: .light), .chromeLight)
    }

    func testResolverNeverReturnsTheEditorGround() {
        // `studio` is the editor's grading surround. If it ever became
        // reachable through the chrome resolver, a light-mode library would
        // start rendering on the editor's ground and look like a bug in the
        // theme rather than a bug in the wiring.
        for scheme in [ColorScheme.light, .dark] {
            XCTAssertNotEqual(ReelPalette.chrome(for: scheme), .studio)
        }
    }

    // MARK: - Roles hold up on both grounds

    /// WCAG relative luminance for an sRGB hex.
    private func luminance(_ hex: UInt32) -> Double {
        let parts = [(hex >> 16) & 0xFF, (hex >> 8) & 0xFF, hex & 0xFF].map { Double($0) / 255 }
        let linear = parts.map { $0 <= 0.03928 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }

    private func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    func testAccentTextClearsAAForBodyCopyOnItsOwnGround() {
        // Assert the *guarantee* the role encodes, not an inequality. The base
        // accent on a white row is 4.02:1 — large-text AA, body-text failure —
        // which is why `accentText` is a separate role at all.
        XCTAssertGreaterThanOrEqual(contrast(0x0062CC, 0xFFFFFF), 4.5,
                                    "light chrome accent text must clear AA on a row")
        XCTAssertGreaterThanOrEqual(contrast(0x0A84FF, 0x1D1D20), 4.5,
                                    "dark chrome accent text must clear AA on a row")
    }

    func testTheBaseAccentWouldNotHaveClearedIt() {
        // Pins why the light ground needs its own step: if someone "simplifies"
        // accentText back to the accent, this is the number they broke.
        XCTAssertLessThan(contrast(0x007AFF, 0xFFFFFF), 4.5)
    }

    func testMutedCopyIsDistinctFromPrimary() {
        XCTAssertNotEqual(ReelPalette.chromeDark.textMuted, ReelPalette.chromeDark.text)
        XCTAssertNotEqual(ReelPalette.chromeLight.textMuted, ReelPalette.chromeLight.text)
    }

    func testInvertedChipsStayLegibleOnEveryGround() {
        // The duration chip and the toast both fill with `text` and label with
        // `bg`. On chromeDark, `onAccent` and `text` are both white — using it
        // there made the label invisible, which is the bug this pins.
        for p in [ReelPalette.chromeLight, .chromeDark, .print, .studio] {
            XCTAssertNotEqual(p.bg, p.text, "an inverted chip needs bg and text to differ")
        }
    }

    func testWarningIsDistinctFromTheChromeAccent() {
        // On the Modernist grounds the accent *is* the warning, deliberately.
        // On chrome it must not be: a blue warning reads as information.
        XCTAssertNotEqual(ReelPalette.chromeLight.warning, ReelPalette.chromeLight.accent)
        XCTAssertNotEqual(ReelPalette.chromeDark.warning, ReelPalette.chromeDark.accent)
        XCTAssertEqual(ReelPalette.studio.warning, ReelPalette.studio.accent)
    }

    // MARK: - Chrome geometry is chrome's alone

    func testChromeRoundsWhereTheEditorDoesNot() {
        XCTAssertEqual(Reel.Radius.lg, 0, "the editor's radius is zero, by design")
        XCTAssertEqual(Reel.Chrome.Radius.lg, 10)
        XCTAssertEqual(Reel.Chrome.Radius.sheet, 16)
    }

    func testChromeHairlineDoesNotDisturbTheEditorRule() {
        XCTAssertEqual(Reel.ruleWidth, 2, "the editor's 2px rule is load-bearing")
        XCTAssertEqual(Reel.Chrome.ruleWidth, 0.5)
    }

    // MARK: - The preference

    private func sandbox() -> UserDefaults {
        let suite = "chrome-\(UUID().uuidString)"
        UserDefaults().removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }

    func testAppearanceDefaultsToSystem() {
        XCTAssertEqual(AppSettings(defaults: sandbox()).appearance, .system)
    }

    func testAppearancePersists() {
        let defaults = sandbox()
        let settings = AppSettings(defaults: defaults)
        settings.appearance = .dark
        XCTAssertEqual(AppSettings(defaults: defaults).appearance, .dark)
    }

    func testSystemMeansNilSoSwiftUIFollowsTheDevice() {
        XCTAssertNil(AppearanceChoice.system.colorScheme)
        XCTAssertEqual(AppearanceChoice.light.colorScheme, .light)
        XCTAssertEqual(AppearanceChoice.dark.colorScheme, .dark)
    }

    func testEveryAppearanceHasASpokenName() {
        for choice in AppearanceChoice.allCases {
            XCTAssertFalse(choice.displayName.isEmpty)
        }
        XCTAssertEqual(Set(AppearanceChoice.allCases.map(\.displayName)).count,
                       AppearanceChoice.allCases.count)
    }

    func testChangingAppearanceLeavesOtherPreferencesAlone() {
        let defaults = sandbox()
        let settings = AppSettings(defaults: defaults)
        let haptics = settings.hapticIntensity
        settings.appearance = .light
        XCTAssertEqual(AppSettings(defaults: defaults).hapticIntensity, haptics)
        XCTAssertTrue(AppSettings(defaults: defaults).crashReportingEnabled)
    }

    // MARK: - The rule belongs to the ground

    func testChromeRulesAtAHairlineAndTheEditorStillRulesAtTwo() {
        XCTAssertEqual(ReelPalette.chromeLight.ruleWidth, Reel.Chrome.ruleWidth)
        XCTAssertEqual(ReelPalette.chromeDark.ruleWidth, Reel.Chrome.ruleWidth)
        XCTAssertEqual(ReelPalette.studio.ruleWidth, Reel.ruleWidth)
        XCTAssertEqual(ReelPalette.print.ruleWidth, Reel.ruleWidth)
        XCTAssertLessThan(Reel.Chrome.ruleWidth, Reel.ruleWidth)
    }

    /// The reason the width moved onto the palette: a view used on both grounds
    /// has to be right on both without knowing which one it is on. If a call
    /// site reaches for the global instead, it hardcodes the editor's 2px rule
    /// into chrome and this suite cannot see it — so assert on the source.
    func testNoChromeSurfaceReachesForTheGlobalRuleWidth() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ReelsStudioTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("Sources/ReelsStudio")
        let chromeDirs = ["Sheets", "Screens", "Export", "Settings"]
        var offenders: [String] = []
        for dir in chromeDirs {
            let base = root.appendingPathComponent(dir)
            guard let walker = FileManager.default.enumerator(
                at: base, includingPropertiesForKeys: nil
            ) else { continue }
            for case let file as URL in walker where file.pathExtension == "swift" {
                let source = try String(contentsOf: file, encoding: .utf8)
                for (n, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
                where line.contains("Reel.ruleWidth") {
                    offenders.append("\(dir)/\(file.lastPathComponent):\(n + 1)")
                }
            }
        }
        XCTAssertTrue(
            offenders.isEmpty,
            "chrome must rule from its palette, not the editor's global: \(offenders.joined(separator: ", "))"
        )
    }
}
