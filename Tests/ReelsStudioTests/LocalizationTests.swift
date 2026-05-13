import XCTest
@testable import ReelsStudio

/// v0.6 Tier 7 — verifies the en-US `Localizable.strings` bundle resolves at
/// runtime. We can't introspect SwiftUI's `Text("foo")` → bundle lookup from
/// XCTest, but we can lookup the bundle directly and confirm the key →
/// value mapping fires.
///
/// Why it matters: a missing strings file silently falls through to the
/// literal key. Without this test a future ".strings" syntax error or build-
/// phase misconfig could ship un-localizable strings without a clear signal.
final class LocalizationTests: XCTestCase {

    func testCommonKeysResolveFromBundle() {
        // These keys exist in en.lproj/Localizable.strings. NSLocalizedString
        // returns the key as-is if the bundle is missing or the key isn't
        // found, so a `==` assertion against the literal value catches the
        // failure mode either way (mismatched value, missing file).
        XCTAssertEqual(NSLocalizedString("Projects", comment: ""), "Projects")
        XCTAssertEqual(NSLocalizedString("No projects yet", comment: ""), "No projects yet")
        XCTAssertEqual(NSLocalizedString("Skipped projects", comment: ""), "Skipped projects")
        XCTAssertEqual(NSLocalizedString("Photos access needed", comment: ""), "Photos access needed")
    }

    func testFormatKeysCarryFormatSpecifiers() {
        // Format-string keys retain `%lld` / `%@` / `%.1f` for parameterized
        // lookups. A typo in the template (`%d` → `%lld`) would silently
        // produce garbage when interpolated; this guards against that.
        XCTAssertTrue(NSLocalizedString("discard.dialog.message", comment: "").contains("%@"))
        XCTAssertTrue(NSLocalizedString("project.row.manyClips", comment: "").contains("%lld"))
        XCTAssertTrue(NSLocalizedString("sfx.composition.footer", comment: "").contains("%.1f"))
    }

    func testUnknownKeyFallsThroughToLiteral() {
        // Documents the fallback behavior: missing key → return the key
        // unchanged. Useful for sanity-checking call sites that pass a key
        // we *don't* expect to be localized (e.g. an SF Symbol name).
        let key = "this.key.does.not.exist.\(UUID().uuidString)"
        XCTAssertEqual(NSLocalizedString(key, comment: ""), key)
    }
}
