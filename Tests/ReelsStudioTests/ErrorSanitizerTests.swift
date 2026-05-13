import XCTest
@testable import ReelsStudio

final class ErrorSanitizerTests: XCTestCase {

    func testFileURLIsReplaced() {
        let raw = "Couldn't open file file:///Users/alice/Library/foo.json — permission denied"
        let sanitized = ErrorSanitizer.sanitize(raw)
        XCTAssertEqual(sanitized, "Couldn't open file [file] — permission denied")
    }

    func testHomePathIsReplaced() {
        let raw = "missing /Users/alice/Library/Application Support/ReelsStudio/Projects/abc.json"
        let sanitized = ErrorSanitizer.sanitize(raw)
        XCTAssertTrue(sanitized.contains("[file]"))
        XCTAssertFalse(sanitized.contains("/Users/alice"))
    }

    func testSandboxContainerPathIsReplaced() {
        let raw = "write failed at /private/var/mobile/Containers/Data/Application/UUID/Library/foo"
        let sanitized = ErrorSanitizer.sanitize(raw)
        XCTAssertTrue(sanitized.contains("[file]"))
        XCTAssertFalse(sanitized.contains("Containers"))
    }

    func testPlainMessageIsUnchanged() {
        let raw = "Decoding failed: missing key 'filters'"
        XCTAssertEqual(ErrorSanitizer.sanitize(raw), raw)
    }

    func testGenericRootPathSurvives() {
        // We don't strip every leading '/'; "/dev/null" is fine and useful.
        let raw = "read /dev/null"
        XCTAssertEqual(ErrorSanitizer.sanitize(raw), raw)
    }

    func testAppErrorTransientRoutesThroughSanitizer() {
        struct PathLeakError: LocalizedError {
            var errorDescription: String? { "decode failed at /Users/alice/Library/foo.json" }
        }
        let appError = AppError.transient(PathLeakError(), prefix: "Couldn't load")
        XCTAssertEqual(appError.message, "Couldn't load")
        XCTAssertEqual(appError.detail, "decode failed at [file]")
    }
}
