import XCTest
import SwiftUI
import CoreMedia
import Kadr
import KadrPersistence
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
        XCTAssertTrue((doc.legacyClips ?? []).isEmpty)
        let tile = ProjectThumbnailTile(document: doc)
        XCTAssertNoThrow(try tile.inspect())
    }

    func testTileBodyConstructsForProjectWithClips() throws {
        let doc = ProjectDocument(
            name: "Has clips",
            legacyClips: [.title(TitleSequenceData(text: "Hi", durationSeconds: 2))]
        )
        let tile = ProjectThumbnailTile(document: doc)
        XCTAssertNoThrow(try tile.inspect())
    }

    // MARK: - Duration chip

    func testDurationLabelIsNilForEmptyProject() {
        let doc = ProjectDocument(name: "Empty")
        XCTAssertNil(ProjectThumbnailTile.durationLabel(for: doc))
    }

    func testDurationLabelFormatsMinutesAndSeconds() throws {
        // A real v6 document: the label reads the composition, so a fixture
        // built from the legacy payload would measure nothing.
        let doc = try Project(clips: [
            TitleSequence("a", duration: 2.0),
            TitleSequence("b", duration: 4.0),
        ]).toDocument(name: "Six seconds", images: ProjectImageStore.temporary())
        XCTAssertEqual(ProjectThumbnailTile.durationLabel(for: doc), "0:06")
    }

    func testDurationLabelPadsSecondsPastAMinute() throws {
        let doc = try Project(clips: [TitleSequence("a", duration: 65.0)])
            .toDocument(name: "Long", images: ProjectImageStore.temporary())
        XCTAssertEqual(ProjectThumbnailTile.durationLabel(for: doc), "1:05")
    }

    func testDurationSkipsTransitionsAndDescendsIntoTracks() {
        // Transitions overlap their neighbours in kadr, so counting them
        // would over-report; a `Track {}` block's children do count.
        let clips: [KadrPersistence.ClipData] = [
            .transition(TransitionData(kind: "fade", duration: TimeData(CMTime(seconds: 5, preferredTimescale: 600)), direction: nil)),
            .track(TrackData(name: nil, startTime: nil, opacityFactor: 1.0, clips: [
                .title(TitleSequenceData(
                    text: "nested",
                    style: TextStyleData(fontName: nil, fontSize: 24,
                                         color: ColorData(red: 1, green: 1, blue: 1, alpha: 1),
                                         alignment: "center", weight: "regular",
                                         stroke: nil, shadow: nil),
                    backgroundColor: ColorData(red: 0, green: 0, blue: 0, alpha: 1),
                    duration: TimeData(CMTime(seconds: 3, preferredTimescale: 600)), clipID: nil, startTime: nil, transform: nil,
                    transformAnimation: nil, opacity: nil, opacityAnimation: nil
                )),
            ])),
        ]
        XCTAssertEqual(ProjectThumbnailTile.durationSeconds(of: clips), 3, accuracy: 0.0001)
    }

    func testUntrimmedVideoClipContributesNoDuration() {
        // A video clip's length lives in the asset until it has been
        // trimmed; a list row must not open an asset to find out.
        let clips: [KadrPersistence.ClipData] = [
            .video(VideoClipData(
                url: "file:///tmp/x.mov", trimRange: nil, isReversed: false, isMuted: false,
                volumeLevel: 1.0, replacementAudioURL: nil, speedRate: 1.0, speedCurve: nil,
                filters: [], filterIDs: [], filterAnimations: [], clipID: nil, startTime: nil,
                transform: nil, transformAnimation: nil, opacity: nil, opacityAnimation: nil
            )),
        ]
        XCTAssertEqual(ProjectThumbnailTile.durationSeconds(of: clips), 0, accuracy: 0.0001)
    }
}

// ViewInspector dropped the `Inspectable` requirement; conforming to it is
// now deprecated, and declaring a conformance of an imported type to an
// imported protocol is unsafe besides. The four extensions that used to sit
// here did nothing.
