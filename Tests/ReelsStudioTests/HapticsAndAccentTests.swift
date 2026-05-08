import XCTest
import SwiftUI
import Kadr
@testable import ReelsStudio

@MainActor
final class HapticEngineTests: XCTestCase {

    // The HapticEngine wraps UIKit feedback generators on iOS and no-ops on
    // macOS. We can't observe the actual hardware tap, so the smoke goal is:
    // calls don't crash, the singleton hands out a stable instance, and
    // every public entry point is callable from the main actor (the only
    // place we'll ever invoke them in production).

    func testSharedReturnsStableInstance() {
        let a = HapticEngine.shared
        let b = HapticEngine.shared
        XCTAssertTrue(a === b)
    }

    func testSnapDoesNotCrash() {
        HapticEngine.shared.snap()
    }

    func testThudDoesNotCrash() {
        HapticEngine.shared.thud()
    }

    func testSuccessDoesNotCrash() {
        HapticEngine.shared.success()
    }

    /// Steady-state pinch fires several snap haptics per second; the engine
    /// re-arms after each call. Verify back-to-back calls don't compound
    /// state in a way that crashes.
    func testRepeatedSnapsArmCleanly() {
        for _ in 0..<20 { HapticEngine.shared.snap() }
    }
}

@MainActor
final class AccentColorRoundTripTests: XCTestCase {

    private func roundTrip(_ project: Project) throws -> Project {
        let doc = project.toDocument()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(doc)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProjectDocument.self, from: data).toRuntimeProject()
    }

    // MARK: - Defaults

    func testNewProjectAccentColorIsNil() {
        XCTAssertNil(Project().accentColor)
    }

    func testNewProjectDocumentAccentColorHexIsNil() {
        XCTAssertNil(ProjectDocument(name: "x").accentColorHex)
    }

    // MARK: - Round-trip

    /// A non-nil accent encodes to hex and decodes to a Color the runtime
    /// can compare against the original via PlatformColor component
    /// extraction. We compare the bytes rather than Color equality, since
    /// SwiftUI's `Color == Color` is unreliable across construction paths.
    func testCustomAccentRoundTripsByHex() throws {
        let original = Project(accentColor: Color(red: 0.2, green: 0.6, blue: 0.9))
        let restored = try roundTrip(original)

        XCTAssertNotNil(restored.accentColor)
        // Encode both runtime colors back to hex and compare.
        let originalHex = ProjectDocument.hexString(from: PlatformColor(original.accentColor!))
        let restoredHex = ProjectDocument.hexString(from: PlatformColor(restored.accentColor!))
        XCTAssertEqual(originalHex, restoredHex)
    }

    /// A nil accent stays nil through the round-trip (no field is written;
    /// no field is read).
    func testNilAccentRoundTripsAsNil() throws {
        let original = Project(accentColor: nil)
        let restored = try roundTrip(original)
        XCTAssertNil(restored.accentColor)
    }

    // MARK: - Old-schema forward compat

    /// A v3 document without `accentColorHex` decodes nil; runtime gets nil
    /// (= follow the system tint).
    func testV3DocumentDecodesWithoutAccentField() throws {
        let original = ProjectDocument(name: "x", accentColorHex: "#FF8800")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        var dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        dict.removeValue(forKey: "accentColorHex")
        let stripped = try JSONSerialization.data(withJSONObject: dict)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let doc = try decoder.decode(ProjectDocument.self, from: stripped)
        XCTAssertNil(doc.accentColorHex)
        XCTAssertNil(doc.toRuntimeProject().accentColor)
    }

    // MARK: - Hex shape

    /// Hex round-trips through the existing `hexString(from:)` helper —
    /// regression-guards the additive use of the v0.2 PlatformColor helper.
    func testAccentHexHasExpectedShape() {
        let project = Project(accentColor: Color(red: 1, green: 0, blue: 0))
        let doc = project.toDocument()
        let hex = try? XCTUnwrap(doc.accentColorHex)
        // Either #RRGGBB (6 chars after #) or #RRGGBBAA (8 chars after #).
        XCTAssertTrue(hex?.hasPrefix("#") ?? false)
        XCTAssertTrue([7, 9].contains(hex?.count ?? 0))
    }
}
