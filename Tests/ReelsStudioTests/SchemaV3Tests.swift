import XCTest
@testable import ReelsStudio

@MainActor
final class SchemaV3Tests: XCTestCase {

    // MARK: - currentSchemaVersion bumped

    func testCurrentSchemaVersionIsThree() {
        XCTAssertEqual(ProjectDocument.currentSchemaVersion, 3)
    }

    // MARK: - Round-trip

    /// A v3 document that explicitly stores `fixedCenterPlayhead = false`
    /// loads with that exact value — no default coercion.
    func testFixedCenterPlayheadFalseRoundTrips() throws {
        let project = Project(fixedCenterPlayhead: false)
        let doc = project.toDocument()
        XCTAssertEqual(doc.fixedCenterPlayhead, false)

        let encoded = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(ProjectDocument.self, from: encoded)
        XCTAssertEqual(decoded.fixedCenterPlayhead, false)

        let runtime = decoded.toRuntimeProject()
        XCTAssertFalse(runtime.fixedCenterPlayhead)
    }

    func testFixedCenterPlayheadTrueRoundTrips() throws {
        let project = Project(fixedCenterPlayhead: true)
        let doc = project.toDocument()
        let encoded = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(ProjectDocument.self, from: encoded)
        XCTAssertTrue(decoded.toRuntimeProject().fixedCenterPlayhead)
    }

    // MARK: - v1 / v2 forward compat

    /// Build an old-schema JSON blob by encoding a current-schema document,
    /// stripping `fixedCenterPlayhead`, and patching `schemaVersion`. This
    /// produces JSON in the exact Codable shape an older build wrote, so
    /// the test exercises the real decoder rather than a hand-rolled blob
    /// that drifts from the synthesized format. Same pattern as
    /// `SchemaV2Tests.testV1JSONLoadsCleanly`.
    private func oldVersionJSON(
        from doc: ProjectDocument,
        targetVersion: Int
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let raw = try encoder.encode(doc)
        var dict = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        dict["schemaVersion"] = targetVersion
        dict.removeValue(forKey: "fixedCenterPlayhead")
        return try JSONSerialization.data(withJSONObject: dict, options: .sortedKeys)
    }

    private func decodeDocument(_ data: Data) throws -> ProjectDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProjectDocument.self, from: data)
    }

    /// A v2 JSON blob that doesn't carry `fixedCenterPlayhead` decodes with
    /// the field nil, and the runtime project gets the v0.4 default
    /// (`true`). Simulates loading projects created by older app builds.
    func testV2DocumentDecodesWithoutFixedCenterPlayheadField() throws {
        let original = ProjectDocument(name: "Old Project")
        let v2Data = try oldVersionJSON(from: original, targetVersion: 2)

        let doc = try decodeDocument(v2Data)
        XCTAssertNil(doc.fixedCenterPlayhead)
        XCTAssertEqual(doc.schemaVersion, 2)
        XCTAssertTrue(doc.toRuntimeProject().fixedCenterPlayhead)
    }

    func testV1DocumentDecodesWithoutFixedCenterPlayheadField() throws {
        let original = ProjectDocument(name: "Older Project")
        let v1Data = try oldVersionJSON(from: original, targetVersion: 1)

        let doc = try decodeDocument(v1Data)
        XCTAssertNil(doc.fixedCenterPlayhead)
        XCTAssertTrue(doc.toRuntimeProject().fixedCenterPlayhead)
    }

    // MARK: - Re-saving an old document upgrades it

    /// Loading a v2 document and saving it back through the bridge promotes
    /// it to v3 and writes the explicit `fixedCenterPlayhead` field.
    func testReSavingOldDocumentPromotesSchemaToV3() throws {
        let original = ProjectDocument(name: "Promoted Project")
        let v2Data = try oldVersionJSON(from: original, targetVersion: 2)
        let loaded = try decodeDocument(v2Data)

        let runtime = loaded.toRuntimeProject()
        let promoted = runtime.toDocument(inheriting: loaded)

        XCTAssertEqual(promoted.schemaVersion, 3)
        XCTAssertEqual(promoted.fixedCenterPlayhead, true)
        XCTAssertEqual(promoted.id, loaded.id)
    }

    // MARK: - Default

    /// `Project()` (no args) gets `true` — the v0.4 behavior every new
    /// project should adopt.
    func testNewProjectDefaultIsTrue() {
        XCTAssertTrue(Project().fixedCenterPlayhead)
    }
}
