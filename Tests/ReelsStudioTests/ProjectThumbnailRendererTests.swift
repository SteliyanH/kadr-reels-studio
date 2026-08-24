import XCTest
import SwiftUI
import ViewInspector
@testable import ReelsStudio

/// v0.7 Tier 5 — tests for the cache-keying primitives and rendering
/// dispatch. AVAssetImageGenerator-driven video thumbnails need a real
/// asset; out of scope for unit tests. The keying logic is what we
/// actually need to pin — a future "save invalidates cache" bug would
/// land here.
@MainActor
final class ProjectThumbnailRendererTests: XCTestCase {

    // MARK: - Filename keying

    func testFilenameContainsProjectIDAndUnixTimestamp() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_000_000)
        let doc = ProjectDocument(id: id, name: "X", modifiedAt: date)

        let filename = ProjectThumbnailRenderer.filename(for: doc)
        XCTAssertTrue(filename.contains(id.uuidString))
        XCTAssertTrue(filename.contains("1000000"))
        XCTAssertTrue(filename.hasSuffix(".jpg"))
    }

    func testFilenameChangesWhenModifiedAtAdvances() {
        let id = UUID()
        let early = ProjectDocument(id: id, name: "X", modifiedAt: Date(timeIntervalSince1970: 1_000_000))
        let later = ProjectDocument(id: id, name: "X", modifiedAt: Date(timeIntervalSince1970: 2_000_000))

        // Two saves of the same project must hash to different cache files —
        // that's the entire invalidation mechanism. Lose this assertion and
        // edits silently render against a stale thumbnail.
        XCTAssertNotEqual(
            ProjectThumbnailRenderer.filename(for: early),
            ProjectThumbnailRenderer.filename(for: later)
        )
    }

    func testFilenameIsStableForIdenticalIDAndTimestamp() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_000_000)
        let a = ProjectDocument(id: id, name: "X", modifiedAt: date)
        let b = ProjectDocument(id: id, name: "X", modifiedAt: date)
        XCTAssertEqual(
            ProjectThumbnailRenderer.filename(for: a),
            ProjectThumbnailRenderer.filename(for: b)
        )
    }

    // MARK: - cacheURL

    func testCacheURLEndsAtTheFilename() {
        let doc = ProjectDocument(name: "X")
        let url = ProjectThumbnailRenderer.cacheURL(for: doc)
        XCTAssertEqual(url.lastPathComponent, ProjectThumbnailRenderer.filename(for: doc))
    }

    // MARK: - Cached-URL miss

    func testCachedURLReturnsNilWhenFileAbsent() {
        // A fresh doc has never been rendered. The synchronous lookup
        // returns nil — render kicks off via .onAppear in the tile.
        let doc = ProjectDocument(name: "Brand new")
        XCTAssertNil(ProjectThumbnailRenderer.cachedURL(for: doc))
    }

    // MARK: - Empty-project placeholder

    /// v0.8 Tier 5a retired `placeholderGradient(for:)` — the Wave-2 shim
    /// that survived only to keep this file compiling once the hue-derived
    /// gradient collapsed into the mono scheme. What actually needs pinning
    /// now is that the tile *builds* for a project with no clips, since that
    /// is the branch the approved design gives its own treatment: a 2pt
    /// dashed `divider` frame on `surface`, with no glyph and no chip.
    func testTileBodyConstructsForEmptyProject() throws {
        let doc = ProjectDocument(name: "Empty")
        XCTAssertTrue(doc.clips.isEmpty)
        let tile = ProjectThumbnailTile(document: doc)
        XCTAssertNoThrow(try tile.inspect())
    }

    func testTileBodyConstructsForProjectWithClips() throws {
        let doc = ProjectDocument(
            name: "Has clips",
            clips: [.title(TitleSequenceData(text: "Hi", durationSeconds: 2))]
        )
        let tile = ProjectThumbnailTile(document: doc)
        XCTAssertNoThrow(try tile.inspect())
    }

    // MARK: - Duration chip

    func testDurationLabelIsNilForEmptyProject() {
        let doc = ProjectDocument(name: "Empty")
        XCTAssertNil(ProjectThumbnailTile.durationLabel(for: doc))
    }

    func testDurationLabelFormatsMinutesAndSeconds() {
        let doc = ProjectDocument(
            name: "Six seconds",
            clips: [
                .title(TitleSequenceData(text: "a", durationSeconds: 2)),
                .title(TitleSequenceData(text: "b", durationSeconds: 4)),
            ]
        )
        XCTAssertEqual(ProjectThumbnailTile.durationLabel(for: doc), "0:06")
    }

    func testDurationLabelPadsSecondsPastAMinute() {
        let doc = ProjectDocument(
            name: "Long",
            clips: [.title(TitleSequenceData(text: "a", durationSeconds: 65))]
        )
        XCTAssertEqual(ProjectThumbnailTile.durationLabel(for: doc), "1:05")
    }

    func testDurationSkipsTransitionsAndDescendsIntoTracks() {
        // Transitions overlap their neighbours in kadr, so counting them
        // would over-report; a `Track {}` block's children do count.
        let clips: [ProjectClip] = [
            .transition(TransitionData(kind: .fade, durationSeconds: 5)),
            .track(TrackData(clips: [
                .title(TitleSequenceData(text: "nested", durationSeconds: 3)),
            ])),
        ]
        XCTAssertEqual(ProjectThumbnailTile.durationSeconds(of: clips), 3, accuracy: 0.0001)
    }

    func testUntrimmedVideoClipContributesNoDuration() {
        // A video clip's length lives in the asset until it has been
        // trimmed; a list row must not open an asset to find out.
        let clips: [ProjectClip] = [
            .video(VideoClipData(url: URL(fileURLWithPath: "/tmp/x.mov"))),
        ]
        XCTAssertEqual(ProjectThumbnailTile.durationSeconds(of: clips), 0, accuracy: 0.0001)
    }
}

// ViewInspector dropped the `Inspectable` requirement; conforming to it is
// now deprecated, and declaring a conformance of an imported type to an
// imported protocol is unsafe besides. The four extensions that used to sit
// here did nothing.
