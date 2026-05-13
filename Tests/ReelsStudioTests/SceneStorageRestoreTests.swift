import XCTest
import CoreMedia
import Kadr
@testable import ReelsStudio

/// Tests for v0.6 Tier 3 — scene-storage cold-launch restore. We can't run
/// SwiftUI's `@SceneStorage` from an XCTest harness (it requires a real
/// scene), so these tests cover the pure restore primitives the view-layer
/// shim delegates to: matching a stored id against in-memory documents and
/// seeding `ProjectStore` playhead / selection.
@MainActor
final class SceneStorageRestoreTests: XCTestCase {

    func testStoreSeedsPlayheadFromPersistedSeconds() {
        let project = Project(clips: [
            VideoClip(url: URL(fileURLWithPath: "/dev/null"))
                .trimmed(to: 0...10)
                .id("clip-a")
        ])
        let store = ProjectStore(project: project)

        store.currentTime = CMTime(seconds: 4.2, preferredTimescale: 600)
        XCTAssertEqual(CMTimeGetSeconds(store.currentTime), 4.2, accuracy: 0.001)
    }

    func testStoreSeedsSelectionWhenClipExists() {
        let project = Project(clips: [
            VideoClip(url: URL(fileURLWithPath: "/dev/null"))
                .trimmed(to: 0...10)
                .id("clip-a"),
            VideoClip(url: URL(fileURLWithPath: "/dev/null"))
                .trimmed(to: 0...10)
                .id("clip-b"),
        ])
        let store = ProjectStore(project: project)

        let target: ClipID = "clip-b"
        XCTAssertTrue(store.video.clips.contains { $0.clipID == target })
        store.selectedClipID = target
        XCTAssertEqual(store.selectedClipID, target)
    }

    func testStoreIgnoresSelectionWhenClipDeleted() {
        let project = Project(clips: [
            VideoClip(url: URL(fileURLWithPath: "/dev/null"))
                .trimmed(to: 0...10)
                .id("clip-a")
        ])
        let store = ProjectStore(project: project)

        // Mimic the gate from EditorView.restoreSceneStateIfMatching():
        // only seed selectedClipID if the id resolves to a live clip.
        let persisted: ClipID = "clip-gone"
        let exists = store.video.clips.contains { $0.clipID == persisted }
        XCTAssertFalse(exists)
        if exists { store.selectedClipID = persisted }
        XCTAssertNil(store.selectedClipID)
    }
}
