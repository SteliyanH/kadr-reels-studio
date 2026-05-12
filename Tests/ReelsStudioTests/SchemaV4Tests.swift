import XCTest
import Kadr
@testable import ReelsStudio

/// Tests for schema v4 — additive `filterIDs: [String]?` on `VideoClipData`,
/// parallel-array mirror of kadr v0.11's `VideoClip.filterIDs`. v0.6 Tier 2.
@MainActor
final class SchemaV4Tests: XCTestCase {

    // MARK: - currentSchemaVersion bump

    func testCurrentSchemaVersionIsFour() {
        XCTAssertEqual(ProjectDocument.currentSchemaVersion, 4)
    }

    // MARK: - filterIDs persistence

    /// Writing a clip with filters writes a parallel `filterIDs` array that
    /// matches the live `VideoClip.filterIDs`. Without this guarantee, future
    /// tooling that binds animations by id couldn't trust persisted state.
    func testClipWithFiltersWritesFilterIDs() {
        let clip = VideoClip(url: URL(fileURLWithPath: "/dev/null"))
            .filter(.brightness(0.2))
            .filter(.contrast(1.3))
        let data = ProjectDocument.documentVideoClip(from: clip)

        XCTAssertEqual(data.filters.count, 2)
        XCTAssertEqual(data.filterIDs?.count, 2)
        XCTAssertEqual(data.filterIDs, clip.filterIDs.map(\.rawValue))
    }

    func testClipWithoutFiltersOmitsFilterIDs() {
        let clip = VideoClip(url: URL(fileURLWithPath: "/dev/null"))
        let data = ProjectDocument.documentVideoClip(from: clip)
        XCTAssertNil(data.filterIDs)
    }

    // MARK: - Forward-compat decode

    /// Hand-craft a v3 JSON blob the same way `SchemaV3Tests.oldVersionJSON`
    /// does — encode a current-schema doc, strip `filterIDs` from every clip,
    /// patch `schemaVersion`. Exercises the real decoder rather than a
    /// shape-drifted literal.
    private func v3JSON(from doc: ProjectDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let raw = try encoder.encode(doc)
        var dict = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        dict["schemaVersion"] = 3
        if var clips = dict["clips"] as? [[String: Any]] {
            for i in clips.indices {
                if var videoWrapper = clips[i]["video"] as? [String: Any],
                   var inner = videoWrapper["_0"] as? [String: Any] {
                    inner.removeValue(forKey: "filterIDs")
                    videoWrapper["_0"] = inner
                    clips[i]["video"] = videoWrapper
                }
            }
            dict["clips"] = clips
        }
        return try JSONSerialization.data(withJSONObject: dict, options: .sortedKeys)
    }

    private func makeDocWithBrightnessFilter() -> ProjectDocument {
        let clip = VideoClip(url: URL(fileURLWithPath: "/dev/null"))
            .filter(.brightness(0.2))
        let videoData = ProjectDocument.documentVideoClip(from: clip)
        return ProjectDocument(name: "WithFilter", clips: [.video(videoData)])
    }

    /// v3 JSON (missing `filterIDs`) decodes cleanly into the v4 shape with
    /// `filterIDs == nil`. Pre-v4 documents on disk should keep loading.
    func testV3DocumentDecodesWithoutFilterIDsField() throws {
        let doc = makeDocWithBrightnessFilter()
        let v3Data = try v3JSON(from: doc)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ProjectDocument.self, from: v3Data)
        XCTAssertEqual(decoded.schemaVersion, 3)
        guard case .video(let videoData) = decoded.clips.first else {
            return XCTFail("Expected a video clip")
        }
        XCTAssertNil(videoData.filterIDs)
        // Bridge falls back to kadr-generated ids — clip rebuilds cleanly.
        let runtime = decoded.toRuntimeProject()
        XCTAssertEqual(runtime.clips.count, 1)
    }

    // MARK: - Re-save promotion

    /// Loading a v3 doc through the bridge and writing it back yields a v4
    /// doc with `filterIDs` populated for any clip carrying filters.
    func testResavingV3DocumentPopulatesFilterIDs() throws {
        let doc = makeDocWithBrightnessFilter()
        let v3Data = try v3JSON(from: doc)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loaded = try decoder.decode(ProjectDocument.self, from: v3Data)

        let runtime = loaded.toRuntimeProject()
        let promoted = runtime.toDocument(inheriting: loaded)

        XCTAssertEqual(promoted.schemaVersion, 4)
        guard case .video(let videoData) = promoted.clips.first else {
            return XCTFail("Expected video clip after re-save")
        }
        XCTAssertEqual(videoData.filterIDs?.count, 1)
    }
}
