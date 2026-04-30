import XCTest
@testable import ReelsStudio

/// Placeholder for the v0.1 cycle. Real tests land alongside Tier 1+ source files.
/// Uses XCTest because the target is bundled into the iOS app via xcodegen and runs
/// against `ReelsStudio.app` in the simulator.
final class ReelsStudioTests: XCTestCase {

    func testModuleBuilds() throws {
        // If this compiles, the iOS app target's source files are reachable from the
        // test bundle. Real assertions land in subsequent tier PRs.
        XCTAssertTrue(true)
    }
}
