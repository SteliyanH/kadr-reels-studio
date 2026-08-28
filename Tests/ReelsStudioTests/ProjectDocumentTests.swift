import XCTest
import CoreMedia
import Kadr
import KadrPersistence
@testable import ReelsStudio

/// Tests for v0.2 Tier 1 — Codable round-trip + bridge between
/// `ProjectDocument` (the persisted JSON shape) and the in-memory `Project`.
final class ProjectDocumentTests: XCTestCase {

    // MARK: - Round-trip helpers

    private func roundTrip(_ doc: ProjectDocument) throws -> ProjectDocument {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(doc)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProjectDocument.self, from: data)
    }

    // MARK: - Schema versioning

    func testNewDocumentCarriesCurrentSchemaVersion() {
        let doc = ProjectDocument(name: "Test")
        XCTAssertEqual(doc.schemaVersion, ProjectDocument.currentSchemaVersion)
    }

    func testEmptyDocumentRoundTrips() throws {
        let original = ProjectDocument(name: "Empty")
        let restored = try roundTrip(original)
        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.name, "Empty")
        XCTAssertEqual(restored.schemaVersion, ProjectDocument.currentSchemaVersion)
        XCTAssertTrue((restored.legacyClips ?? []).isEmpty)
        XCTAssertTrue((restored.legacyOverlays ?? []).isEmpty)
    }

    // MARK: - Clip round-trip

    func testVideoClipRoundTrips() throws {
        let url = URL(fileURLWithPath: "/tmp/sample.mp4")
        let clip = VideoClipData(
            clipID: "clip-1",
            url: url,
            trimStartSeconds: 0.5,
            trimDurationSeconds: 3.0,
            isReversed: true,
            isMuted: false,
            speedRate: 0.5,
            opacity: 0.75
        )
        let doc = ProjectDocument(name: "VideoOnly", legacyClips: [.video(clip)])
        let restored = try roundTrip(doc)
        guard case .video(let v) = (restored.legacyClips ?? []).first else {
            return XCTFail("Expected .video")
        }
        XCTAssertEqual(v.clipID, "clip-1")
        XCTAssertEqual(v.url, url)
        XCTAssertEqual(v.trimStartSeconds, 0.5)
        XCTAssertEqual(v.trimDurationSeconds, 3.0)
        XCTAssertTrue(v.isReversed)
        XCTAssertFalse(v.isMuted)
        XCTAssertEqual(v.speedRate, 0.5)
        XCTAssertEqual(v.opacity, 0.75)
    }

    func testEmbeddedPNGImageClipRoundTrips() throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header magic, sufficient for round-trip
        let clip = ImageClipData(
            clipID: "img-1",
            storage: .embeddedPNG(png),
            durationSeconds: 2.0,
            opacity: 0.9
        )
        let doc = ProjectDocument(name: "ImageOnly", legacyClips: [.image(clip)])
        let restored = try roundTrip(doc)
        guard case .image(let i) = (restored.legacyClips ?? []).first else {
            return XCTFail("Expected .image")
        }
        if case .embeddedPNG(let restoredData) = i.storage {
            XCTAssertEqual(restoredData, png)
        } else {
            XCTFail("Expected .embeddedPNG storage")
        }
        XCTAssertEqual(i.durationSeconds, 2.0)
    }

    func testTitleSequenceRoundTrips() throws {
        let title = TitleSequenceData(
            text: "Hello",
            fontSize: 48,
            fontWeight: .bold,
            colorHex: "#FF8800",
            alignment: .center,
            durationSeconds: 1.5
        )
        let doc = ProjectDocument(name: "Titled", legacyClips: [.title(title)])
        let restored = try roundTrip(doc)
        guard case .title(let t) = (restored.legacyClips ?? []).first else {
            return XCTFail("Expected .title")
        }
        XCTAssertEqual(t.text, "Hello")
        XCTAssertEqual(t.fontSize, 48)
        XCTAssertEqual(t.fontWeight, .bold)
        XCTAssertEqual(t.colorHex, "#FF8800")
        XCTAssertEqual(t.alignment, .center)
        XCTAssertEqual(t.durationSeconds, 1.5)
    }

    func testTransitionRoundTrips() throws {
        let transition = TransitionData(kind: .dissolve, durationSeconds: 0.75)
        let doc = ProjectDocument(name: "Transition", legacyClips: [.transition(transition)])
        let restored = try roundTrip(doc)
        guard case .transition(let t) = (restored.legacyClips ?? []).first else {
            return XCTFail("Expected .transition")
        }
        XCTAssertEqual(t.kind, .dissolve)
        XCTAssertEqual(t.durationSeconds, 0.75)
    }

    // MARK: - Overlay round-trip

    func testTextOverlayRoundTrips() throws {
        let overlay = TextOverlayData(
            layerID: "title",
            text: "Reels Studio",
            fontSize: 56,
            fontWeight: .bold,
            colorHex: "#FFFFFF",
            alignment: .center,
            positionX: 0.5,
            positionY: 0.2,
            anchor: .top,
            opacity: 0.95
        )
        let doc = ProjectDocument(name: "Overlay", legacyOverlays: [.text(overlay)])
        let restored = try roundTrip(doc)
        guard case .text(let t) = (restored.legacyOverlays ?? []).first else {
            return XCTFail("Expected .text")
        }
        XCTAssertEqual(t.layerID, "title")
        XCTAssertEqual(t.text, "Reels Studio")
        XCTAssertEqual(t.positionX, 0.5)
        XCTAssertEqual(t.positionY, 0.2)
        XCTAssertEqual(t.anchor, .top)
        XCTAssertEqual(t.opacity, 0.95)
    }

    func testStickerOverlayRoundTrips() throws {
        let sticker = StickerOverlayData(
            layerID: "sticker-1",
            storage: .embeddedPNG(Data([0xFF, 0x00])),
            positionX: 0.7,
            positionY: 0.3,
            anchor: .topRight,
            opacity: 1.0,
            rotationRadians: .pi / 4
        )
        let doc = ProjectDocument(name: "Sticker", legacyOverlays: [.sticker(sticker)])
        let restored = try roundTrip(doc)
        guard case .sticker(let s) = (restored.legacyOverlays ?? []).first else {
            return XCTFail("Expected .sticker")
        }
        XCTAssertEqual(s.rotationRadians, .pi / 4, accuracy: 0.0001)
    }

    // MARK: - Audio / caption / preset round-trip

    func testAudioTrackRoundTrips() throws {
        let track = ProjectAudioTrack(
            url: URL(fileURLWithPath: "/tmp/song.mp3"),
            startTimeSeconds: 1.0,
            explicitDurationSeconds: 30.0,
            volume: 0.8,
            fadeInSeconds: 0.5,
            fadeOutSeconds: 1.0,
            duckingTargetVolume: 0.3,
            crossfadeDurationSeconds: nil
        )
        let doc = ProjectDocument(name: "Audio", legacyAudioTracks: [track])
        let restored = try roundTrip(doc)
        let restoredTrack = (restored.legacyAudioTracks ?? []).first
        XCTAssertEqual(restoredTrack?.volume, 0.8)
        XCTAssertEqual(restoredTrack?.fadeInSeconds, 0.5)
        XCTAssertEqual(restoredTrack?.duckingTargetVolume, 0.3)
        XCTAssertNil(restoredTrack?.crossfadeDurationSeconds)
    }

    func testCaptionsRoundTrip() throws {
        let cues = [
            ProjectCaption(text: "Hello", startSeconds: 0.5, durationSeconds: 1.5),
            ProjectCaption(text: "World", startSeconds: 2.5, durationSeconds: 1.0),
        ]
        let doc = ProjectDocument(name: "Captioned", legacyCaptions: cues)
        let restored = try roundTrip(doc)
        XCTAssertEqual((restored.legacyCaptions ?? []).count, 2)
        XCTAssertEqual((restored.legacyCaptions ?? [])[0].text, "Hello")
        XCTAssertEqual((restored.legacyCaptions ?? [])[1].startSeconds, 2.5)
    }

    func testPresetVariantsRoundTrip() throws {
        for preset in [
            ProjectPreset.auto,
            ProjectPreset.reelsAndShorts,
            ProjectPreset.tiktok,
            ProjectPreset.square,
            ProjectPreset.cinema,
            ProjectPreset.custom(width: 1280, height: 720, frameRate: 60, codecHEVC: true),
        ] {
            let doc = ProjectDocument(name: "Preset", legacyPreset: preset)
            let restored = try roundTrip(doc)
            XCTAssertEqual((restored.legacyPreset ?? .reelsAndShorts), preset)
        }
    }

    // MARK: - Bridge — runtime ↔ document round-trip

    func testRuntimeProjectRoundTripsThroughDocument() throws {
        let original = ProjectDocument(
            name: "Demo",
            legacyClips: [
                .title(TitleSequenceData(
                    clipID: "intro",
                    text: "Intro",
                    fontSize: 36,
                    fontWeight: .bold,
                    durationSeconds: 1.0
                ))
            ],
            legacyOverlays: [
                .text(TextOverlayData(
                    layerID: "watermark",
                    text: "Reels",
                    fontSize: 24,
                    fontWeight: .regular,
                    alignment: .leading,
                    positionX: 0.05,
                    positionY: 0.95,
                    anchor: .bottomLeft,
                    opacity: 0.6
                ))
            ]
        )
        let runtime = try original.toRuntimeProject(images: ProjectImageStore())
        XCTAssertEqual(runtime.clips.count, 1)
        XCTAssertEqual(runtime.overlays.count, 1)
        let rebuilt = try runtime.toDocument(inheriting: original, images: ProjectImageStore())
        XCTAssertEqual(rebuilt.id, original.id)
        XCTAssertEqual(rebuilt.compositionClips.count, 1)
        XCTAssertEqual(rebuilt.composition?.video.overlays.count, 1)
        if case .title(let t) = rebuilt.compositionClips.first {
            XCTAssertEqual(t.text, "Intro")
        } else {
            XCTFail("Expected title clip in rebuilt document")
        }
    }

    // MARK: - Tier 1.5: filter / transform / color round-trip

    func testVideoClipFiltersRoundTrip() throws {
        let clip = VideoClipData(
            url: URL(fileURLWithPath: "/tmp/x.mp4"),
            filters: [
                .brightness(0.3),
                .contrast(1.5),
                .saturation(0.8),
                .gaussianBlur(8.0),
            ]
        )
        let doc = ProjectDocument(name: "Filtered", legacyClips: [.video(clip)])
        let restored = try roundTrip(doc)
        guard case .video(let v) = (restored.legacyClips ?? []).first else {
            return XCTFail("Expected .video")
        }
        XCTAssertEqual(v.filters.count, 4)
        if case .brightness(let val) = v.filters[0] { XCTAssertEqual(val, 0.3) }
        else { XCTFail("Expected .brightness") }
        if case .gaussianBlur(let val) = v.filters[3] { XCTAssertEqual(val, 8.0) }
        else { XCTFail("Expected .gaussianBlur") }
    }

    func testTransformRoundTrip() throws {
        let transform = ProjectTransform(
            centerX: 0.7,
            centerY: 0.3,
            rotation: .pi / 4,
            scale: 1.5,
            anchor: .topLeft
        )
        let clip = VideoClipData(
            url: URL(fileURLWithPath: "/tmp/x.mp4"),
            transform: transform
        )
        let doc = ProjectDocument(name: "Transformed", legacyClips: [.video(clip)])
        let restored = try roundTrip(doc)
        guard case .video(let v) = (restored.legacyClips ?? []).first,
              let t = v.transform else {
            return XCTFail("Expected .video with transform")
        }
        XCTAssertEqual(t.centerX, 0.7, accuracy: 0.0001)
        XCTAssertEqual(t.centerY, 0.3, accuracy: 0.0001)
        XCTAssertEqual(t.rotation, .pi / 4, accuracy: 0.0001)
        XCTAssertEqual(t.scale, 1.5, accuracy: 0.0001)
        XCTAssertEqual(t.anchor, .topLeft)
    }

    func testTextOverlayColorSurvivesBridgeRoundTrip() throws {
        // Build an overlay with a custom color, run it through the runtime
        // bridge (which includes the PlatformColor extraction path), then
        // back into a document. Verify the hex matches.
        let original = TextOverlayData(
            text: "Hello",
            colorHex: "#FF8800",
            opacity: 1.0
        )
        let doc = ProjectDocument(name: "Color", legacyOverlays: [.text(original)])
        let runtime = try doc.toRuntimeProject(images: ProjectImageStore())
        let rebuilt = try runtime.toDocument(inheriting: doc, name: doc.name, images: ProjectImageStore())
        // v6 stores colour as components rather than hex. #FF8800 is
        // (1.0, 0.533, 0.0) — the assertion this test has always been about is
        // that the colour arrives at all, which is the bug that lost
        // TextStyle.color twice before.
        guard case .text(let restored) = rebuilt.composition?.video.overlays.first else {
            return XCTFail("Expected .text")
        }
        XCTAssertEqual(restored.style.color.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(restored.style.color.green, 0.533, accuracy: 0.01)
        XCTAssertEqual(restored.style.color.blue, 0.0, accuracy: 0.01)
        XCTAssertEqual(restored.style.color.alpha, 1.0, accuracy: 0.01)
    }

    func testTitleSequenceTransformAndColorSurviveBridge() throws {
        let title = TitleSequenceData(
            text: "Title",
            colorHex: "#00FF00",
            durationSeconds: 1.0,
            transform: ProjectTransform(centerX: 0.25, centerY: 0.75, rotation: 0, scale: 1.0, anchor: .center)
        )
        let doc = ProjectDocument(name: "Title", legacyClips: [.title(title)])
        let runtime = try doc.toRuntimeProject(images: ProjectImageStore())
        let rebuilt = try runtime.toDocument(inheriting: doc, name: doc.name, images: ProjectImageStore())
        guard case .title(let restored) = rebuilt.compositionClips.first else {
            return XCTFail("Expected .title")
        }
        XCTAssertEqual(restored.style.color.red, 0.0, accuracy: 0.01)
        XCTAssertEqual(restored.style.color.green, 1.0, accuracy: 0.01)
        XCTAssertEqual(restored.style.color.blue, 0.0, accuracy: 0.01)
        XCTAssertEqual(restored.transform?.center.x ?? 0, 0.25, accuracy: 0.0001)
        XCTAssertEqual(restored.transform?.center.y ?? 0, 0.75, accuracy: 0.0001)
    }

    func testVideoFiltersSurviveBridge() throws {
        // End-to-end through runtime bridge — verifies kadr Filter cases
        // round-trip through `runtimeFilter` / `documentFilter`.
        let clipData = VideoClipData(
            url: URL(fileURLWithPath: "/tmp/x.mp4"),
            filters: [.exposure(0.5), .vignette(0.7)]
        )
        let doc = ProjectDocument(name: "F", legacyClips: [.video(clipData)])
        let runtime = try doc.toRuntimeProject(images: ProjectImageStore())
        let rebuilt = try runtime.toDocument(inheriting: doc, name: doc.name, images: ProjectImageStore())
        guard case .video(let v) = rebuilt.compositionClips.first else {
            return XCTFail("Expected .video")
        }
        XCTAssertEqual(v.filters.count, 2)
        // v6 tags a filter by kind with its scalar alongside, rather than as a
        // Swift enum with a payload.
        XCTAssertEqual(v.filters[0].kind, "exposure")
        if let val = v.filters[0].scalar {
            XCTAssertEqual(val, 0.5, accuracy: 0.0001)
        } else {
            XCTFail("Expected .exposure")
        }
    }

    func testMonoFilterRoundTrips() throws {
        let clip = VideoClip(url: URL(fileURLWithPath: "/tmp/x.mp4"))
            .filter(.mono)
            .filter(.brightness(0.5))
        let project = Project(clips: [clip])
        let doc = try project.toDocument(name: "Mixed", images: ProjectImageStore())
        guard case .video(let v) = doc.compositionClips.first else {
            return XCTFail("Expected .video")
        }
        XCTAssertEqual(v.filters.count, 2)
        // Order is render order, and a filter with no scalar must still occupy
        // its slot — .mono carries no intensity but is not skippable.
        XCTAssertEqual(v.filters[0].kind, "mono")
        XCTAssertEqual(v.filters[1].kind, "brightness")
        XCTAssertEqual(v.filters[1].scalar ?? 0, 0.5, accuracy: 0.0001)
    }

    func testChromaKeyRoundTripsRGBAndThreshold() throws {
        // Build a runtime ChromaKey filter, run through document, restore.
        // Verify the (r, g, b, threshold) survive — the GPU cube is rebuilt
        // from those parameters by `ChromaKey.init(color:threshold:)`.
        #if canImport(UIKit)
        let target = PlatformColor(red: 0, green: 1, blue: 0, alpha: 1)  // green
        #else
        let target = PlatformColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)
        #endif
        let key = ChromaKey(color: target, threshold: 0.4)
        let clip = VideoClip(url: URL(fileURLWithPath: "/tmp/x.mp4"))
            .filter(.chromaKey(key))
        let project = Project(clips: [clip])
        let doc = try project.toDocument(name: "ChromaKey", images: ProjectImageStore())
        guard case .video(let v) = doc.compositionClips.first,
              let filter = v.filters.first, filter.kind == "chromaKey" else {
            return XCTFail("Expected .chromaKey filter")
        }
        XCTAssertEqual(filter.red ?? -1, 0.0, accuracy: 0.001)
        XCTAssertEqual(filter.green ?? -1, 1.0, accuracy: 0.001)
        XCTAssertEqual(filter.blue ?? -1, 0.0, accuracy: 0.001)
        XCTAssertEqual(filter.threshold ?? -1, 0.4, accuracy: 0.0001)
    }

    func testLUTRoundTripsURL() throws {
        // Persist a LUT filter — we don't load a real .cube file in tests
        // (the runtime side handles missing files gracefully). We only
        // verify the URL survives the document round-trip.
        let lutURL = URL(fileURLWithPath: "/tmp/test.cube")
        let project = Project()  // start empty, hand-craft VideoClip with a non-loaded LUT case via documentFilter
        // Skip the full round-trip — we only verify documentFilter handles
        // .lut. Building a kadr LUT requires a real .cube file.
        _ = project
        let projectFilter: ProjectFilter = .lut(url: lutURL)
        // Encode + decode the case directly.
        let encoded = try? JSONEncoder().encode(projectFilter)
        XCTAssertNotNil(encoded)
        let decoded = try? JSONDecoder().decode(ProjectFilter.self, from: encoded ?? Data())
        if case .lut(let restoredURL) = decoded {
            XCTAssertEqual(restoredURL, lutURL)
        } else {
            XCTFail("Expected .lut(url:) after round-trip")
        }
    }

    func testLUTWithMissingFileDropsFilter() {
        // runtimeFilter returns nil when the .cube file can't be loaded.
        // The `for filter in data.filters` loop in runtimeVideoClip drops it.
        let result = ProjectDocument.runtimeFilter(
            from: .lut(url: URL(fileURLWithPath: "/tmp/definitely-missing.cube"))
        )
        XCTAssertNil(result)
    }

    func testRuntimeBridgeDropsCorruptImageClipSilently() throws {
        // Empty PNG data → platformImage returns nil → runtime drops the clip
        // entirely. The rest of the project stays intact.
        let doc = ProjectDocument(
            name: "Mixed",
            legacyClips: [
                .image(ImageClipData(storage: .embeddedPNG(Data()), durationSeconds: 1.0)),
                .title(TitleSequenceData(text: "Hi", durationSeconds: 0.5)),
            ]
        )
        let runtime = try doc.toRuntimeProject(images: ProjectImageStore())
        XCTAssertEqual(runtime.clips.count, 1) // image dropped, title kept
    }
}
