import XCTest
import CoreMedia
import Kadr
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
        XCTAssertEqual(restored.schemaVersion, 1)
        XCTAssertTrue(restored.clips.isEmpty)
        XCTAssertTrue(restored.overlays.isEmpty)
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
        let doc = ProjectDocument(name: "VideoOnly", clips: [.video(clip)])
        let restored = try roundTrip(doc)
        guard case .video(let v) = restored.clips.first else {
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
        let doc = ProjectDocument(name: "ImageOnly", clips: [.image(clip)])
        let restored = try roundTrip(doc)
        guard case .image(let i) = restored.clips.first else {
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
        let doc = ProjectDocument(name: "Titled", clips: [.title(title)])
        let restored = try roundTrip(doc)
        guard case .title(let t) = restored.clips.first else {
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
        let doc = ProjectDocument(name: "Transition", clips: [.transition(transition)])
        let restored = try roundTrip(doc)
        guard case .transition(let t) = restored.clips.first else {
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
        let doc = ProjectDocument(name: "Overlay", overlays: [.text(overlay)])
        let restored = try roundTrip(doc)
        guard case .text(let t) = restored.overlays.first else {
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
        let doc = ProjectDocument(name: "Sticker", overlays: [.sticker(sticker)])
        let restored = try roundTrip(doc)
        guard case .sticker(let s) = restored.overlays.first else {
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
        let doc = ProjectDocument(name: "Audio", audioTracks: [track])
        let restored = try roundTrip(doc)
        let restoredTrack = restored.audioTracks.first
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
        let doc = ProjectDocument(name: "Captioned", captions: cues)
        let restored = try roundTrip(doc)
        XCTAssertEqual(restored.captions.count, 2)
        XCTAssertEqual(restored.captions[0].text, "Hello")
        XCTAssertEqual(restored.captions[1].startSeconds, 2.5)
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
            let doc = ProjectDocument(name: "Preset", preset: preset)
            let restored = try roundTrip(doc)
            XCTAssertEqual(restored.preset, preset)
        }
    }

    // MARK: - Bridge — runtime ↔ document round-trip

    func testRuntimeProjectRoundTripsThroughDocument() {
        let original = ProjectDocument(
            name: "Demo",
            clips: [
                .title(TitleSequenceData(
                    clipID: "intro",
                    text: "Intro",
                    fontSize: 36,
                    fontWeight: .bold,
                    durationSeconds: 1.0
                ))
            ],
            overlays: [
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
        let runtime = original.toRuntimeProject()
        XCTAssertEqual(runtime.clips.count, 1)
        XCTAssertEqual(runtime.overlays.count, 1)
        let rebuilt = runtime.toDocument(inheriting: original)
        XCTAssertEqual(rebuilt.id, original.id)
        XCTAssertEqual(rebuilt.clips.count, 1)
        XCTAssertEqual(rebuilt.overlays.count, 1)
        if case .title(let t) = rebuilt.clips.first {
            XCTAssertEqual(t.text, "Intro")
        } else {
            XCTFail("Expected title clip in rebuilt document")
        }
    }

    func testRuntimeBridgeDropsCorruptImageClipSilently() {
        // Empty PNG data → platformImage returns nil → runtime drops the clip
        // entirely. The rest of the project stays intact.
        let doc = ProjectDocument(
            name: "Mixed",
            clips: [
                .image(ImageClipData(storage: .embeddedPNG(Data()), durationSeconds: 1.0)),
                .title(TitleSequenceData(text: "Hi", durationSeconds: 0.5)),
            ]
        )
        let runtime = doc.toRuntimeProject()
        XCTAssertEqual(runtime.clips.count, 1) // image dropped, title kept
    }
}
