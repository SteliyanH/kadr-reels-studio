import XCTest
import CoreMedia
import Kadr
import KadrPersistence
@testable import ReelsStudio

/// Migration from the hand-written v1–v5 document to v6's `KadrDocument`.
///
/// The question these answer is the only one that matters about a format
/// change: **does a project someone already had still open, unchanged?**
///
/// Fixtures are built in the legacy shape and pushed through
/// `ProjectLibrary.read`, which is where migration happens — not through the
/// bridge directly, so the test exercises the path a real launch takes.
@MainActor
final class ProjectMigrationTests: XCTestCase {

    private func write(_ document: ProjectDocument) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString).json")
        try ProjectLibrary.write(document, to: url)
        return url
    }

    private func legacyDocument(
        name: String = "Legacy",
        clips: [ProjectClip] = [],
        overlays: [ProjectOverlay] = [],
        audioTracks: [ProjectAudioTrack] = [],
        captions: [ProjectCaption] = [],
        preset: ProjectPreset = .reelsAndShorts,
        schema: Int = 5
    ) -> ProjectDocument {
        ProjectDocument(
            name: name,
            schemaVersion: schema,
            zoomPixelsPerSecond: 80,
            fixedCenterPlayhead: false,
            accentColorHex: "#FF8800",
            legacyClips: clips,
            legacyOverlays: overlays,
            legacyAudioTracks: audioTracks,
            legacyCaptions: captions,
            legacyPreset: preset
        )
    }

    // MARK: - The composition survives

    func testAV5ProjectOpensAsV6() throws {
        let url = try write(legacyDocument(clips: [
            .title(TitleSequenceData(text: "Intro", durationSeconds: 2)),
            .transition(TransitionData(kind: .dissolve, durationSeconds: 0.5)),
            .title(TitleSequenceData(text: "Outro", durationSeconds: 3)),
        ]))
        let migrated = try ProjectLibrary.read(at: url)

        XCTAssertEqual(migrated.schemaVersion, ProjectDocument.currentSchemaVersion)
        XCTAssertNotNil(migrated.composition)
        XCTAssertEqual(migrated.compositionClips.count, 3)
        guard case .title(let first) = migrated.compositionClips.first else {
            return XCTFail("Expected the first clip to still be a title")
        }
        XCTAssertEqual(first.text, "Intro")
        XCTAssertEqual(first.duration.time.seconds, 2, accuracy: 0.0001)
    }

    func testMigrationPreservesIdentityAndTimestamps() throws {
        let original = legacyDocument(clips: [.title(TitleSequenceData(text: "x", durationSeconds: 1))])
        let url = try write(original)
        let migrated = try ProjectLibrary.read(at: url)

        // A migration that changed a project's id would orphan its thumbnail
        // cache and its place in the list.
        XCTAssertEqual(migrated.id, original.id)
        XCTAssertEqual(migrated.name, original.name)
        XCTAssertEqual(
            migrated.createdAt.timeIntervalSince1970,
            original.createdAt.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    func testMigrationPreservesEditorPreferences() throws {
        let url = try write(legacyDocument(clips: [.title(TitleSequenceData(text: "x", durationSeconds: 1))]))
        let migrated = try ProjectLibrary.read(at: url)

        // These are the app's own fields, not kadr's. The point of splitting
        // the document was that they keep working.
        XCTAssertEqual(migrated.zoomPixelsPerSecond, 80)
        XCTAssertEqual(migrated.fixedCenterPlayhead, false)
        XCTAssertEqual(migrated.accentColorHex, "#FF8800")
    }

    func testMigrationPreservesAudioTracksAndCaptions() throws {
        let url = try write(legacyDocument(
            clips: [.title(TitleSequenceData(text: "x", durationSeconds: 4))],
            audioTracks: [ProjectAudioTrack(url: URL(fileURLWithPath: "/tmp/m.m4a"), volume: 0.4)],
            captions: [ProjectCaption(text: "hello", startSeconds: 0.5, durationSeconds: 1.5)]
        ))
        let migrated = try ProjectLibrary.read(at: url)

        XCTAssertEqual(migrated.composition?.video.audioTracks.count, 1)
        XCTAssertEqual(migrated.composition?.video.audioTracks.first?.volumeLevel ?? 0, 0.4, accuracy: 0.0001)
        XCTAssertEqual(migrated.composition?.video.captions.count, 1)
        XCTAssertEqual(migrated.composition?.video.captions.first?.text, "hello")
    }

    func testMigrationPreservesFiltersAndTheirOrder() throws {
        let clip = VideoClipData(
            url: URL(fileURLWithPath: "/tmp/x.mov"),
            trimStartSeconds: 0,
            trimDurationSeconds: 5,
            filters: [.exposure(0.5), .mono, .vignette(0.7)]
        )
        let url = try write(legacyDocument(clips: [.video(clip)]))
        let migrated = try ProjectLibrary.read(at: url)

        guard case .video(let v) = migrated.compositionClips.first else {
            return XCTFail("Expected a video clip")
        }
        XCTAssertEqual(v.filters.map(\.kind), ["exposure", "mono", "vignette"])
        // Parallel arrays stay parallel — including for `.mono`, which has no
        // scalar and used to be the case that fell out of step.
        XCTAssertEqual(v.filterIDs.count, 3)
        XCTAssertEqual(v.filterAnimations.count, 3)
    }

    func testMigrationIsIdempotent() throws {
        let url = try write(legacyDocument(clips: [
            .title(TitleSequenceData(text: "Once", durationSeconds: 2)),
        ]))
        let once = try ProjectLibrary.read(at: url)

        // Saving the migrated document and reading it again must not migrate a
        // second time, and must not change a byte.
        let saved = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-twice-\(UUID().uuidString).json")
        try ProjectLibrary.write(once, to: saved)
        let twice = try ProjectLibrary.read(at: saved)

        XCTAssertFalse(twice.needsMigration)
        XCTAssertEqual(twice.composition, once.composition)
        XCTAssertEqual(
            try Data(contentsOf: saved),
            try { try ProjectLibrary.write(twice, to: saved); return try Data(contentsOf: saved) }()
        )
    }

    // MARK: - Refusals

    func testADocumentFromTheFutureIsRefused() throws {
        let url = try write(legacyDocument(schema: ProjectDocument.currentSchemaVersion + 1))
        XCTAssertThrowsError(try ProjectLibrary.read(at: url)) { error in
            guard case ProjectLibraryError.unsupportedSchema(let found) = error else {
                return XCTFail("Expected unsupportedSchema, got \(error)")
            }
            XCTAssertEqual(found, ProjectDocument.currentSchemaVersion + 1)
        }
    }

    func testAnEmptyLegacyProjectMigratesToAnEmptyComposition() throws {
        let url = try write(legacyDocument(clips: []))
        let migrated = try ProjectLibrary.read(at: url)
        XCTAssertNotNil(migrated.composition)
        XCTAssertTrue(migrated.compositionClips.isEmpty)
    }

    // MARK: - Images

    func testAnEmbeddedImageSurvivesAsABlob() throws {
        let png = ProjectMigrationTests.tinyPNG()
        let url = try write(legacyDocument(clips: [
            .image(ImageClipData(storage: .embeddedPNG(png), durationSeconds: 2)),
        ]))
        let migrated = try ProjectLibrary.read(at: url)

        guard case .image(let image) = migrated.compositionClips.first else {
            return XCTFail("Expected an image clip")
        }
        // No file behind it, so its bytes travel in the document under a
        // content-addressed token.
        XCTAssertTrue(image.imageToken.hasPrefix("png:"))
        XCTAssertNotNil(migrated.imageBlobs?[image.imageToken])
        XCTAssertEqual(image.duration.time.seconds, 2, accuracy: 0.0001)
    }

    func testImageTokensAreContentAddressedAndStableAcrossSaves() throws {
        let store = ProjectImageStore()
        let image = ProjectMigrationTests.tinyImage()
        let first = try store.token(for: image)
        let second = try store.token(for: image)

        // A store that minted a fresh token per encode would rewrite every byte
        // of the project file on every save.
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.hasPrefix("png:"))
    }

    func testUnreferencedBlobsArePrunedOnSave() throws {
        let store = ProjectImageStore()
        _ = try store.token(for: ProjectMigrationTests.tinyImage())
        XCTAssertEqual(store.blobs.count, 1)

        // A project that dropped its only image should not keep carrying it.
        XCTAssertTrue(store.blobs(reachableFrom: []).isEmpty)
    }

    // MARK: - Fixtures

    private static func tinyImage() -> PlatformImage {
        #if canImport(UIKit)
        return UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        #else
        let image = NSImage(size: CGSize(width: 2, height: 2))
        image.lockFocus(); NSColor.red.setFill()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: 2, height: 2)).fill()
        image.unlockFocus()
        return image
        #endif
    }

    private static func tinyPNG() -> Data {
        #if canImport(UIKit)
        return tinyImage().pngData() ?? Data()
        #else
        guard let tiff = tinyImage().tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return Data() }
        return rep.representation(using: .png, properties: [:]) ?? Data()
        #endif
    }
}
