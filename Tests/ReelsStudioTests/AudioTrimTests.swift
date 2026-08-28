import XCTest
import CoreMedia
import Kadr
import KadrPersistence
@testable import ReelsStudio

/// v0.7 Tier 1 — tests for `ProjectStore.applyAudioTrim` and its pure helper.
/// Mirrors `applyTrackTrim`'s test shape so the audio path stays at parity
/// with the video-clip path.
@MainActor
final class AudioTrimTests: XCTestCase {

    private func makeTrack(startSeconds: Double? = nil, durationSeconds: Double? = nil) -> AudioTrack {
        var track = AudioTrack(url: URL(fileURLWithPath: "/dev/null"))
        if let startSeconds {
            track = track.at(time: CMTime(seconds: startSeconds, preferredTimescale: 600))
        }
        if let durationSeconds {
            track = track.duration(CMTime(seconds: durationSeconds, preferredTimescale: 600))
        }
        return track
    }

    // MARK: - Pure helper

    func testLeadingTrimShiftsStartTimeLater() {
        let tracks = [makeTrack(startSeconds: 1.0, durationSeconds: 10.0)]
        let result = ProjectStore.applyingAudioTrim(
            tracks: tracks,
            trackIndex: 0,
            leadingTrim: CMTime(seconds: 2.0, preferredTimescale: 600),
            trailingTrim: .zero
        )
        XCTAssertEqual(CMTimeGetSeconds(result[0].startTime ?? .zero), 3.0, accuracy: 0.001)
    }

    func testTrailingTrimReducesExplicitDuration() {
        let tracks = [makeTrack(startSeconds: 0.0, durationSeconds: 10.0)]
        let result = ProjectStore.applyingAudioTrim(
            tracks: tracks,
            trackIndex: 0,
            leadingTrim: .zero,
            trailingTrim: CMTime(seconds: 3.0, preferredTimescale: 600)
        )
        XCTAssertEqual(CMTimeGetSeconds(result[0].explicitDuration ?? .zero), 7.0, accuracy: 0.001)
    }

    func testBothEndsTrimReduceDurationByCombinedDelta() {
        let tracks = [makeTrack(startSeconds: 0.0, durationSeconds: 10.0)]
        let result = ProjectStore.applyingAudioTrim(
            tracks: tracks,
            trackIndex: 0,
            leadingTrim: CMTime(seconds: 1.5, preferredTimescale: 600),
            trailingTrim: CMTime(seconds: 2.5, preferredTimescale: 600)
        )
        XCTAssertEqual(CMTimeGetSeconds(result[0].startTime ?? .zero), 1.5, accuracy: 0.001)
        XCTAssertEqual(CMTimeGetSeconds(result[0].explicitDuration ?? .zero), 6.0, accuracy: 0.001)
    }

    func testRunawayLeadingTrimClampsStartTimeAtZero() {
        // Drag the leading handle past the track's natural start. We clamp
        // startTime at .zero rather than letting it go negative — kadr's
        // compositor doesn't accept negative composition times.
        let tracks = [makeTrack(startSeconds: 0.5, durationSeconds: 5.0)]
        let result = ProjectStore.applyingAudioTrim(
            tracks: tracks,
            trackIndex: 0,
            leadingTrim: CMTime(seconds: -2.0, preferredTimescale: 600),
            trailingTrim: .zero
        )
        XCTAssertEqual(CMTimeGetSeconds(result[0].startTime ?? .zero), 0, accuracy: 0.001)
    }

    func testTrailingTrimWithoutExplicitDurationIsNoOp() {
        // Music added without `.duration(_:)` plays to natural asset end.
        // kadr-ui doesn't resolve the asset length synchronously so a
        // trailing trim on this kind of row is intentionally a no-op for
        // now (per the RFC's "acceptable for v0.7" caveat).
        let tracks = [makeTrack(startSeconds: 0.0, durationSeconds: nil)]
        let result = ProjectStore.applyingAudioTrim(
            tracks: tracks,
            trackIndex: 0,
            leadingTrim: .zero,
            trailingTrim: CMTime(seconds: 1.0, preferredTimescale: 600)
        )
        XCTAssertNil(result[0].explicitDuration)
    }

    func testOutOfRangeIndexLeavesArrayUnchanged() {
        let tracks = [makeTrack(startSeconds: 0.0, durationSeconds: 5.0)]
        let result = ProjectStore.applyingAudioTrim(
            tracks: tracks,
            trackIndex: 99,
            leadingTrim: CMTime(seconds: 1.0, preferredTimescale: 600),
            trailingTrim: .zero
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(CMTimeGetSeconds(result[0].startTime ?? .zero), 0, accuracy: 0.001)
    }

    // MARK: - Mutation + undo

    func testApplyAudioTrimMutationIsUndoable() {
        let project = Project(audioTracks: [makeTrack(startSeconds: 0.0, durationSeconds: 10.0)])
        let store = ProjectStore(project: project)

        store.applyAudioTrim(
            trackIndex: 0,
            leadingTrim: CMTime(seconds: 1.0, preferredTimescale: 600),
            trailingTrim: CMTime(seconds: 2.0, preferredTimescale: 600)
        )
        XCTAssertEqual(CMTimeGetSeconds(store.project.audioTracks[0].startTime ?? .zero), 1.0, accuracy: 0.001)
        XCTAssertEqual(CMTimeGetSeconds(store.project.audioTracks[0].explicitDuration ?? .zero), 7.0, accuracy: 0.001)

        XCTAssertTrue(store.canUndo)
        store.undo()
        XCTAssertEqual(CMTimeGetSeconds(store.project.audioTracks[0].startTime ?? .zero), 0, accuracy: 0.001)
        XCTAssertEqual(CMTimeGetSeconds(store.project.audioTracks[0].explicitDuration ?? .zero), 10.0, accuracy: 0.001)
    }
}
