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

    /// Decode a file without going through `read`, which migrates on the way.
    ///
    /// A test that wants to drive `migrateToV6` with its own media directory
    /// has to bypass the migration `read` already performs — otherwise it
    /// migrates an already-migrated document, whose legacy payload is empty.
    private func decodeRaw(at url: URL) throws -> ProjectDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProjectDocument.self, from: try Data(contentsOf: url))
    }

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

    func testAnEmbeddedImageBecomesAFile() throws {
        // Before this, an image with no file behind it was base64'd into the
        // project JSON. It is now written into the library's media directory
        // and referenced — the project file stays the size of its description.
        let png = ProjectMigrationTests.tinyPNG()
        let media = FileManager.default.temporaryDirectory
            .appendingPathComponent("media-\(UUID().uuidString)")
        let url = try write(legacyDocument(clips: [
            .image(ImageClipData(storage: .embeddedPNG(png), durationSeconds: 2)),
        ]))
        let migrated = try ProjectLibrary.migrateToV6(decodeRaw(at: url), mediaDirectory: media)

        guard case .image(let image) = migrated.compositionClips.first else {
            return XCTFail("Expected an image clip")
        }
        XCTAssertTrue(image.imageToken.hasPrefix("file:"))
        XCTAssertNil(migrated.imageBlobs, "images should no longer travel in the document")
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: media.path).count, 1,
            "the image should have been written into the media directory"
        )
        XCTAssertEqual(image.duration.time.seconds, 2, accuracy: 0.0001)
    }

    func testAMigratedTokenIsRelative() throws {
        // An absolute path would break after a reinstall: the container UUID
        // changes while the project file stays perfectly intact.
        let media = FileManager.default.temporaryDirectory
            .appendingPathComponent("media-\(UUID().uuidString)")
        let url = try write(legacyDocument(clips: [
            .image(ImageClipData(storage: .embeddedPNG(ProjectMigrationTests.tinyPNG()), durationSeconds: 1)),
        ]))
        let migrated = try ProjectLibrary.migrateToV6(decodeRaw(at: url), mediaDirectory: media)
        guard case .image(let image) = migrated.compositionClips.first else {
            return XCTFail("Expected an image clip")
        }
        XCTAssertFalse(image.imageToken.contains("/"), "token should name a file, not a path")
        XCTAssertFalse(image.imageToken.contains(media.path))
    }

    func testImageTokensAreContentAddressedAndStableAcrossSaves() throws {
        let store = ProjectImageStore.temporary()
        let image = ProjectMigrationTests.tinyImage()
        let first = try store.token(for: image)
        let second = try store.token(for: image)

        // A store that minted a fresh token per encode would rewrite every byte
        // of the project file on every save.
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.hasPrefix("file:"))
    }

    func testUnreferencedImagesArePrunedOnSave() throws {
        let media = FileManager.default.temporaryDirectory
            .appendingPathComponent("media-\(UUID().uuidString)")
        let store = try ProjectImageStore(directory: media)
        let kept = try store.token(for: ProjectMigrationTests.tinyImage())
        _ = try store.token(for: ProjectMigrationTests.tinyImage(CGSize(width: 6, height: 6)))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: media.path).count, 2)

        // A project that dropped an image should not keep carrying its bytes.
        XCTAssertEqual(try store.prune(keeping: [kept]), 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: media.path).count, 1)
    }

    // MARK: - Fixtures

    private static func tinyImage(_ size: CGSize = CGSize(width: 2, height: 2)) -> PlatformImage {
        #if canImport(UIKit)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        #else
        let image = NSImage(size: size)
        image.lockFocus(); NSColor.red.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
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
