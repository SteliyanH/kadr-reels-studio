import XCTest
import CoreGraphics
import Kadr
import KadrPersistence
@testable import ReelsStudio

/// v0.7 Tier 3 — tests for schema v5's additive text-effect fields on
/// `TextOverlayData` + `TitleSequenceData`. Mirrors `SchemaV4Tests` shape
/// (round-trip, forward-compat decode, re-save promotion).
@MainActor
final class SchemaV5Tests: XCTestCase {

    func testCurrentSchemaVersionIsSix() {
        XCTAssertEqual(ProjectDocument.currentSchemaVersion, 6)
    }

    // MARK: - Stroke + shadow round-trip on TextOverlayData

    func testTextOverlayStrokeAndShadowRoundTripThroughCodable() throws {
        let original = ProjectDocument(
            name: "Effects",
            legacyOverlays: [.text(TextOverlayData(
                text: "HI",
                strokeWidth: 3,
                strokeColorHex: "#FF0000",
                shadowOffsetX: 2,
                shadowOffsetY: 4,
                shadowBlur: 6,
                shadowColorHex: "#00000080"
            ))]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProjectDocument.self, from: data)

        guard case .text(let text) = (decoded.legacyOverlays ?? []).first else {
            return XCTFail("Expected a text overlay")
        }
        XCTAssertEqual(text.strokeWidth, 3)
        XCTAssertEqual(text.strokeColorHex, "#FF0000")
        XCTAssertEqual(text.shadowOffsetX, 2)
        XCTAssertEqual(text.shadowOffsetY, 4)
        XCTAssertEqual(text.shadowBlur, 6)
        XCTAssertEqual(text.shadowColorHex, "#00000080")
    }

    /// v4 docs (no effect fields in JSON) decode cleanly — every field is
    /// optional and defaults to nil. The runtime renders the overlay as it
    /// did pre-v0.7.
    func testV4TextOverlayWithoutEffectsDecodes() throws {
        // Hand-craft a v4-shaped JSON (no effect keys). Production v4 docs
        // didn't write any of the new fields, so decoding must tolerate
        // them being absent.
        let v4JSON = """
        {
          "id": "\(UUID().uuidString)",
          "name": "Legacy v4",
          "createdAt": "2026-05-01T00:00:00Z",
          "modifiedAt": "2026-05-01T00:00:00Z",
          "schemaVersion": 4,
          "clips": [],
          "overlays": [
            {
              "text": {
                "_0": {
                  "text": "HELLO",
                  "fontSize": 36,
                  "fontWeight": "regular",
                  "alignment": "center",
                  "positionX": 0.5,
                  "positionY": 0.5,
                  "anchor": "center",
                  "opacity": 1.0
                }
              }
            }
          ],
          "audioTracks": [],
          "captions": [],
          "preset": { "reelsAndShorts": {} }
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let doc = try decoder.decode(ProjectDocument.self, from: Data(v4JSON.utf8))
        guard case .text(let text) = (doc.legacyOverlays ?? []).first else {
            return XCTFail("Expected a text overlay")
        }
        XCTAssertNil(text.strokeWidth)
        XCTAssertNil(text.shadowOffsetX)
    }

    // MARK: - Bridge: runtime stroke / shadow reconstruction

    func testBridgeReconstructsStrokeFromPersistedFields() {
        let stroke = ProjectDocument.runtimeStroke(width: 4, colorHex: "#FF0000")
        XCTAssertNotNil(stroke)
        XCTAssertEqual(stroke?.width, 4)
    }

    func testBridgeReturnsNilStrokeForZeroWidth() {
        // RFC: width 0 = no stroke. The bridge mirrors that on the load
        // side so a v5 doc with width 0 doesn't allocate a stroke struct.
        XCTAssertNil(ProjectDocument.runtimeStroke(width: 0, colorHex: "#000000"))
    }

    func testBridgeReturnsNilStrokeForMissingWidth() {
        XCTAssertNil(ProjectDocument.runtimeStroke(width: nil, colorHex: "#000000"))
    }

    func testBridgeReconstructsShadowOnlyWhenAllFieldsPresent() {
        let full = ProjectDocument.runtimeShadow(
            offsetX: 1, offsetY: 2, blur: 3, colorHex: "#000000"
        )
        XCTAssertNotNil(full)
        XCTAssertEqual(full?.offset, CGSize(width: 1, height: 2))
        XCTAssertEqual(full?.blur, 3)

        // Partial state = nil. Persistence is all-or-nothing on shadow.
        XCTAssertNil(ProjectDocument.runtimeShadow(
            offsetX: 1, offsetY: nil, blur: 3, colorHex: "#000000"
        ))
        XCTAssertNil(ProjectDocument.runtimeShadow(
            offsetX: 1, offsetY: 2, blur: nil, colorHex: "#000000"
        ))
    }

    // MARK: - Re-save promotion

    func testReSavingV4TextOverlayWritesV5FieldsAsNil() throws {
        // Take a v4 doc, route through the runtime, and re-encode.
        // Without effects set, the new fields should be nil — not zero —
        // so the JSON still mirrors the pre-v0.7 shape semantically.
        let original = ProjectDocument(
            name: "Legacy v4",
            legacyOverlays: [.text(TextOverlayData(text: "HELLO"))]
        )
        let runtime = original.legacyRuntimeProject()
        let promoted = try runtime.toDocument(inheriting: original, images: ProjectImageStore())
        XCTAssertEqual(promoted.schemaVersion, ProjectDocument.currentSchemaVersion)
        // v6 carries text effects inside the style rather than as flattened
        // sibling fields. Absent stays absent: an overlay saved without a
        // stroke or shadow must not acquire a zero-width one.
        guard case .text(let text) = promoted.composition?.video.overlays.first else {
            return XCTFail("Expected text overlay")
        }
        XCTAssertNil(text.style.stroke)
        XCTAssertNil(text.style.shadow)
    }

    /// A text overlay built with stroke + shadow at the runtime layer
    /// round-trips through the bridge with both intact. Pins the save +
    /// load symmetry.
    func testStyledTextOverlayRoundTripsThroughBridge() throws {
        let runtimeOverlay = TextOverlay("HI", style: TextStyle(
            stroke: TextStroke(width: 5, color: .black),
            shadow: TextShadow(offset: CGSize(width: 2, height: 4), blur: 6)
        ))
        let document = ProjectDocument.documentOverlay(from: runtimeOverlay)
        guard case .text(let text) = document else {
            return XCTFail("Expected text overlay")
        }
        XCTAssertEqual(text.strokeWidth, 5)
        XCTAssertEqual(text.shadowBlur, 6)

        let reconstructed = ProjectDocument.runtimeTextOverlay(from: text)
        XCTAssertNotNil(reconstructed.style.stroke)
        XCTAssertEqual(reconstructed.style.stroke?.width, 5)
        XCTAssertNotNil(reconstructed.style.shadow)
        XCTAssertEqual(reconstructed.style.shadow?.blur, 6)
    }

    // MARK: - Mutations

    func testSetTextStrokeMutationIsUndoable() {
        let overlay = TextOverlay("X", style: TextStyle()).id("text-1")
        let project = Project(overlays: [overlay])
        let store = ProjectStore(project: project)

        store.setTextStroke(id: "text-1", TextStroke(width: 3, color: .black))
        let after = store.project.overlays.first as? TextOverlay
        XCTAssertEqual(after?.style.stroke?.width, 3)

        store.undo()
        let restored = store.project.overlays.first as? TextOverlay
        XCTAssertNil(restored?.style.stroke)
    }

    func testSetTextShadowMutationIsUndoable() {
        let overlay = TextOverlay("X", style: TextStyle()).id("text-1")
        let project = Project(overlays: [overlay])
        let store = ProjectStore(project: project)

        store.setTextShadow(id: "text-1", TextShadow(offset: .zero, blur: 4))
        let after = store.project.overlays.first as? TextOverlay
        XCTAssertEqual(after?.style.shadow?.blur, 4)

        store.undo()
        let restored = store.project.overlays.first as? TextOverlay
        XCTAssertNil(restored?.style.shadow)
    }

    func testTextEffectMutationsAreNoOpsForNonTextOverlays() {
        // Stroke + shadow are TextOverlay-only. Issuing them against an
        // ImageOverlay leaves the project unchanged.
        let image = ImageOverlay(PlatformImage()).id("img-1")
        let project = Project(overlays: [image])
        let store = ProjectStore(project: project)

        store.setTextStroke(id: "img-1", TextStroke(width: 4, color: .black))
        store.setTextShadow(id: "img-1", TextShadow(offset: .zero, blur: 4))

        XCTAssertTrue(store.project.overlays.first is ImageOverlay)
    }
}
