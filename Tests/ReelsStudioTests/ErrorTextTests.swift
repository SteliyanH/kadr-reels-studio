import XCTest
import SwiftUI
import Kadr
import KadrPersistence
@testable import ReelsStudio

/// `AppError.readable(_:)` and the colour bridge.
///
/// Both guard bugs that shipped and stayed shipped because nothing exercised
/// the path the app actually takes:
///
/// - `localizedDescription` returns `errorDescription` alone, so every
///   `recoverySuggestion` the kadr family writes was dropped before it reached
///   a toast — the actionable half of the message, silently discarded.
/// - Three view files each declared a file-private
///   `PlatformColor.init(_ color: Color)` that shadowed SwiftUI's and called
///   itself. The tests never noticed: they rebuilt each `TextStyle` by hand
///   instead of calling the view method that built the real one, and the test
///   target has no shadow to fall into.
final class ErrorTextTests: XCTestCase {

    // MARK: - The suggestion reaches the surface

    func testRecoverySuggestionIsCarriedAlongsideTheDescription() {
        let text = AppError.readable(KadrError.noClipsProvided)
        XCTAssertEqual(text.description, "There's nothing to export.")
        XCTAssertEqual(text.recovery, "Add at least one clip before exporting.")
    }

    func testJoinedReadsAsTwoSentences() {
        let text = AppError.readable(KadrError.noClipsProvided)
        XCTAssertEqual(
            text.joined,
            "There's nothing to export. Add at least one clip before exporting."
        )
    }

    /// Not every case has advice, and upstream deliberately writes none rather
    /// than filler. A `nil` here must stay `nil` — not an empty trailing space.
    func testCaseWithNoSuggestionCarriesNone() {
        let text = AppError.readable(KadrError.cancelled)
        XCTAssertEqual(text.description, "The export was cancelled.")
        XCTAssertNil(text.recovery)
        XCTAssertEqual(text.joined, "The export was cancelled.")
    }

    func testErrorWithoutLocalizedErrorConformanceHasNoSuggestion() {
        struct Bare: Error {}
        XCTAssertNil(AppError.readable(Bare()).recovery)
    }

    /// Foundation carries its suggestion in `userInfo` without conforming to
    /// `LocalizedError` in Swift, which is what the `NSError` fallback is for.
    func testNSErrorUserInfoSuggestionIsRead() {
        let error = NSError(
            domain: "test",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Couldn't open the file.",
                NSLocalizedRecoverySuggestionErrorKey: "Check it still exists.",
            ]
        )
        let text = AppError.readable(error)
        XCTAssertEqual(text.description, "Couldn't open the file.")
        XCTAssertEqual(text.recovery, "Check it still exists.")
    }

    // MARK: - The suggestion is sanitized too

    func testSuggestionIsSanitizedNotJustTheDescription() throws {
        let error = NSError(
            domain: "test",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Couldn't read /Users/alice/clip.mov.",
                NSLocalizedRecoverySuggestionErrorKey: "Move /Users/alice/clip.mov back.",
            ]
        )
        let text = AppError.readable(error)
        XCTAssertFalse(text.description.contains("/Users/"))
        XCTAssertFalse(try XCTUnwrap(text.recovery).contains("/Users/"))
    }

    // MARK: - The factories put each half somewhere visible

    func testTransientWithoutPrefixPutsTheSuggestionInDetail() {
        let error = AppError.transient(KadrError.noClipsProvided)
        XCTAssertEqual(error.message, "There's nothing to export.")
        XCTAssertEqual(error.detail, "Add at least one clip before exporting.")
    }

    /// With a prefix the message slot is taken, so both halves share `detail`
    /// rather than one of them being dropped.
    func testTransientWithPrefixKeepsBothHalves() {
        let error = AppError.transient(KadrError.noClipsProvided, prefix: "Couldn't export")
        XCTAssertEqual(error.message, "Couldn't export")
        XCTAssertEqual(
            error.detail,
            "There's nothing to export. Add at least one clip before exporting."
        )
    }

    func testCatastrophicCarriesTheSuggestionToo() {
        let error = AppError.catastrophic(KadrError.noClipsProvided)
        XCTAssertEqual(error.detail, "Add at least one clip before exporting.")
    }

    // MARK: - The colour bridge does not recurse

    /// If a file-private `init(_ color: Color)` shadow is ever reintroduced on
    /// the path `baked(_:)` takes, this overflows the stack rather than
    /// failing politely — which is still a red gate, and still louder than the
    /// compiler warning that went unread for three releases.
    func testBakedColorsRoundTripToTheExpectedPixels() {
        for color in [Color.white, .black, .red, .blue] {
            XCTAssertNotNil(ProjectDocument.hexString(from: PlatformColor.baked(color)))
        }
        XCTAssertEqual(ProjectDocument.hexString(from: PlatformColor.baked(.white)), "#FFFFFF")
        XCTAssertEqual(ProjectDocument.hexString(from: PlatformColor.baked(.black)), "#000000")
    }

    func testBakedPreservesComponentsThroughAFullRoundTrip() throws {
        let original = PlatformColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 1)
        let hex = try XCTUnwrap(ProjectDocument.hexString(from: original))
        let restored = PlatformColor.baked(ProjectDocument.color(from: original))
        XCTAssertEqual(ProjectDocument.hexString(from: restored), hex)
    }
}
