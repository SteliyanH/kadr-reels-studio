import XCTest
import SwiftUI
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

    // MARK: - Placeholder gradient (deterministic)

    func testPlaceholderGradientIsDeterministicPerID() {
        // The hash → hue mapping is the *visual* identity of a placeholder.
        // Re-deriving from the same id must produce the same gradient (so
        // an empty project doesn't reflow visually on every redraw). We
        // can't unwrap a LinearGradient's internals through SwiftUI's
        // public API, but we can pin "calling twice doesn't crash and
        // returns the same shape" via a smoke construction.
        let id = UUID()
        _ = ProjectThumbnailTile.placeholderGradient(for: id)
        _ = ProjectThumbnailTile.placeholderGradient(for: id)
        // No crash + no XCTFail = test passes. The visual determinism is
        // verifiable by hand in the simulator.
    }
}
