import XCTest
@testable import ReelsStudio

@MainActor
final class ToastCenterTests: XCTestCase {

    // MARK: - AppError severity routing

    func testTransientGoesToCurrentSlot() {
        let center = ToastCenter()
        center.show(.transient(message: "Hi"))
        XCTAssertEqual(center.current?.message, "Hi")
        XCTAssertNil(center.resumable)
        XCTAssertNil(center.catastrophic)
    }

    func testResumableGoesToResumableSlot() {
        let center = ToastCenter()
        center.show(.resumable(
            message: "Save failed",
            retry: { }
        ))
        XCTAssertNil(center.current)
        XCTAssertEqual(center.resumable?.message, "Save failed")
        XCTAssertNil(center.catastrophic)
    }

    func testCatastrophicGoesToCatastrophicSlot() {
        let center = ToastCenter()
        center.show(.catastrophic(message: "Project corrupt"))
        XCTAssertNil(center.current)
        XCTAssertNil(center.resumable)
        XCTAssertEqual(center.catastrophic?.message, "Project corrupt")
    }

    // MARK: - Replacement / dismissal

    func testNewTransientReplacesInFlight() {
        let center = ToastCenter()
        center.show(.transient(message: "First"))
        center.show(.transient(message: "Second"))
        XCTAssertEqual(center.current?.message, "Second")
    }

    func testManualDismissTransient() {
        let center = ToastCenter()
        center.show(.transient(message: "Hi"))
        XCTAssertNotNil(center.current)
        center.dismissTransient()
        XCTAssertNil(center.current)
    }

    func testManualDismissResumable() {
        let center = ToastCenter()
        center.show(.resumable(message: "Retry?", retry: {}))
        center.dismissResumable()
        XCTAssertNil(center.resumable)
    }

    func testManualDismissCatastrophic() {
        let center = ToastCenter()
        center.show(.catastrophic(message: "Bad"))
        center.dismissCatastrophic()
        XCTAssertNil(center.catastrophic)
    }

    // MARK: - Auto-dismiss

    func testTransientAutoDismissesAfterDuration() async throws {
        // Speed-test: rather than wait the full 2s default, verify the
        // mechanism by shortening via a manual setup. We can't easily lower
        // the static duration without touching production code; instead we
        // verify the auto-dismiss path *does* fire by waiting one full
        // duration window plus a small slack.
        let center = ToastCenter()
        center.show(.transient(message: "Hi"))
        XCTAssertNotNil(center.current)
        let total = ToastCenter.transientDuration + 0.5
        try await Task.sleep(nanoseconds: UInt64(total * 1_000_000_000))
        XCTAssertNil(center.current, "Toast should have auto-dismissed by now")
    }

    // MARK: - AppError factories

    func testTransientFromErrorIncludesPrefix() {
        struct Fail: LocalizedError {
            var errorDescription: String? { "underlying" }
        }
        let err: AppError = .transient(Fail(), prefix: "Couldn't import")
        XCTAssertEqual(err.message, "Couldn't import")
        XCTAssertEqual(err.detail, "underlying")
    }

    func testTransientFromErrorWithoutPrefix() {
        struct Fail: LocalizedError {
            var errorDescription: String? { "boom" }
        }
        let err: AppError = .transient(Fail())
        XCTAssertEqual(err.message, "boom")
        XCTAssertNil(err.detail)
    }

    func testCatastrophicFromError() {
        struct Fail: LocalizedError {
            var errorDescription: String? { "library setup failed" }
        }
        let err: AppError = .catastrophic(Fail(), prefix: "Couldn't open library")
        XCTAssertEqual(err.message, "Couldn't open library")
        XCTAssertEqual(err.detail, "library setup failed")
    }
}
