import XCTest
@testable import ReelsStudio

/// `PhotosAuthorizationGate` is largely OS-driven — we can't fake
/// `PHPhotoLibrary.authorizationStatus` from a unit test. We *deliberately*
/// don't call `ensureAccess()` here: on a fresh CI runner the status is
/// `.notDetermined`, which routes through `PHPhotoLibrary.requestAuthorization`
/// and waits for a system prompt dismissal that never comes — the test would
/// hang forever. (We learned this the hard way: PR #48 stalled CI for 35min
/// before we cancelled it.) The integration behavior is verified by hand
/// in the simulator permission flow instead.
final class PhotosAuthorizationGateTests: XCTestCase {

    func testDecisionEquatable() {
        XCTAssertEqual(PhotosAuthorizationGate.Decision.proceed, .proceed)
        XCTAssertNotEqual(PhotosAuthorizationGate.Decision.proceed, .openSettings)
        XCTAssertNotEqual(PhotosAuthorizationGate.Decision.proceed, .unavailable)
    }
}
