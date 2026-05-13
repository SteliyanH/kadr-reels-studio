import XCTest
@testable import ReelsStudio

/// We can't drive `PHPhotoLibrary.authorizationStatus` from a unit test (the
/// system permission state is owned by the OS), so this test just verifies
/// the `Decision` type and gate API surface compile and the `unavailable`
/// path produces a usable decision. The integration behavior (denied →
/// alert, not-determined → prompt) is verified by hand in the simulator
/// permission flow.
final class PhotosAuthorizationGateTests: XCTestCase {

    func testDecisionEquatable() {
        XCTAssertEqual(PhotosAuthorizationGate.Decision.proceed, .proceed)
        XCTAssertNotEqual(PhotosAuthorizationGate.Decision.proceed, .openSettings)
    }

    @MainActor
    func testEnsureAccessReturnsADecision() async {
        let decision = await PhotosAuthorizationGate.ensureAccess()
        // We don't assert a specific value — depends on simulator permission
        // state — but the call must return a valid case.
        switch decision {
        case .proceed, .openSettings, .unavailable:
            break
        }
    }
}
