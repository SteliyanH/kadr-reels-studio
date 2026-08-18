import XCTest
import CoreMedia
import SwiftUI
import ViewInspector
import Kadr
@testable import ReelsStudio

/// v0.9 — the transport band beneath the editor stage.
///
/// The view is deliberately thin: every decision it makes (what the readout
/// says, where a skip lands, whether a bound button is live, whether an
/// `isPlaying` fall means "loop") is a pure static on ``TransportBand``, so it
/// can be pinned here without driving SwiftUI's gesture surface. What's left
/// for ViewInspector is a body smoke and the strings actually on screen.
@MainActor
final class TransportBandTests: XCTestCase {

    private func seconds(_ value: Double) -> CMTime {
        CMTime(seconds: value, preferredTimescale: 600)
    }

    /// A store whose composition is `length` seconds long. `trimmed(to:)`
    /// gives a deterministic duration without touching a real asset — the
    /// same fixture shape `SceneStorageRestoreTests` uses.
    private func makeStore(length: Double = 6) -> ProjectStore {
        ProjectStore(project: Project(clips: [
            VideoClip(url: URL(fileURLWithPath: "/dev/null"))
                .trimmed(to: 0...length)
                .id("clip-a")
        ]))
    }

    // MARK: - Timecode

    /// The spec's own example: a one-second playhead in a six-second
    /// composition reads "0:01 / 0:06".
    func testTimecodeRendersTheSpecExample() {
        XCTAssertEqual(TransportBand.timecode(seconds(1)), "0:01")
        XCTAssertEqual(TransportBand.timecode(seconds(6)), "0:06")
    }

    func testTimecodeRollsOverPastAMinute() {
        XCTAssertEqual(TransportBand.timecode(seconds(65)), "1:05")
        XCTAssertEqual(TransportBand.timecode(seconds(60)), "1:00")
        XCTAssertEqual(TransportBand.timecode(seconds(600)), "10:00")
    }

    /// Truncates rather than rounds — a playhead 900ms in has not reached the
    /// first second, and a readout that says otherwise reads as a bug.
    func testTimecodeTruncatesWithinTheSecond() {
        XCTAssertEqual(TransportBand.timecode(seconds(0.9)), "0:00")
        XCTAssertEqual(TransportBand.timecode(seconds(1.99)), "0:01")
    }

    func testTimecodeClampsNonNumericAndNegativeTimes() {
        XCTAssertEqual(TransportBand.timecode(.zero), "0:00")
        XCTAssertEqual(TransportBand.timecode(seconds(-3)), "0:00")
        XCTAssertEqual(TransportBand.timecode(.invalid), "0:00")
        XCTAssertEqual(TransportBand.timecode(.indefinite), "0:00")
        XCTAssertEqual(TransportBand.timecode(.positiveInfinity), "0:00")
    }

    /// The total rounds where the elapsed truncates, so the band's total and
    /// the nav bar's `statusMetrics` — on screen at the same time, for the
    /// same composition — never disagree.
    func testDurationTimecodeRoundsAndAgreesWithTheNavBar() {
        XCTAssertEqual(TransportBand.durationTimecode(seconds(6)), "0:06")
        XCTAssertEqual(TransportBand.durationTimecode(seconds(5.97)), "0:06")
        XCTAssertEqual(TransportBand.durationTimecode(seconds(65)), "1:05")
        XCTAssertEqual(TransportBand.durationTimecode(.zero), "0:00")
        XCTAssertEqual(TransportBand.durationTimecode(.invalid), "0:00")

        for length in [6.0, 5.97, 65.0, 0.0] {
            XCTAssertEqual(
                TransportBand.durationTimecode(seconds(length)),
                EditorView.timecode(seconds(length)),
                "band total and nav bar disagree at \(length)s"
            )
        }
    }

    // MARK: - Skip interval

    /// A fixed second, not a frame. `VideoPreview` refuses seeks under 0.05s
    /// and one frame at the presets' 30fps is 0.0333s, so a frame-step button
    /// would be silently swallowed on every press. Pinned so the ruling can't
    /// be quietly reversed.
    func testSkipIntervalIsOneSecondAndClearsThePreviewSeekFloor() {
        XCTAssertEqual(TransportBand.skipInterval, 1.0)
        XCTAssertGreaterThan(TransportBand.skipInterval, 0.05)
    }

    // MARK: - Skip targets

    func testSkipForwardMovesByTheInterval() {
        let target = TransportBand.skipTarget(
            from: seconds(2),
            by: TransportBand.skipInterval,
            duration: seconds(6)
        )
        XCTAssertEqual(CMTimeGetSeconds(target), 3, accuracy: 0.001)
    }

    func testSkipBackMovesByTheInterval() {
        let target = TransportBand.skipTarget(
            from: seconds(2),
            by: -TransportBand.skipInterval,
            duration: seconds(6)
        )
        XCTAssertEqual(CMTimeGetSeconds(target), 1, accuracy: 0.001)
    }

    func testSkipBackClampsAtZeroRatherThanWrapping() {
        let target = TransportBand.skipTarget(
            from: seconds(0.4),
            by: -TransportBand.skipInterval,
            duration: seconds(6)
        )
        XCTAssertEqual(CMTimeGetSeconds(target), 0, accuracy: 0.001)
    }

    func testSkipForwardClampsAtDurationRatherThanWrapping() {
        let target = TransportBand.skipTarget(
            from: seconds(5.7),
            by: TransportBand.skipInterval,
            duration: seconds(6)
        )
        XCTAssertEqual(CMTimeGetSeconds(target), 6, accuracy: 0.001)
    }

    func testSkipTargetIsSafeOnAnEmptyComposition() {
        let target = TransportBand.skipTarget(
            from: .zero,
            by: TransportBand.skipInterval,
            duration: .zero
        )
        XCTAssertEqual(CMTimeGetSeconds(target), 0, accuracy: 0.001)
    }

    // MARK: - Bounds (what the buttons disable on)

    func testSkipBackIsBoundedOnlyAtZero() {
        XCTAssertTrue(TransportBand.isAtStart(.zero))
        // A scrub to 20ms still leaves skip-back real work to do.
        XCTAssertFalse(TransportBand.isAtStart(seconds(0.02)))
    }

    func testSkipForwardIsBoundedOnlyAtTheEnd() {
        XCTAssertTrue(TransportBand.isAtEnd(seconds(6), duration: seconds(6)))
        XCTAssertFalse(TransportBand.isAtEnd(seconds(5.5), duration: seconds(6)))
    }

    /// A composition with nothing in it is both bounds at once, and play is
    /// dead — no control in the band claims to be able to do anything.
    func testEmptyCompositionDisablesEveryTransportControl() {
        XCTAssertTrue(TransportBand.isAtStart(.zero))
        XCTAssertTrue(TransportBand.isAtEnd(.zero, duration: .zero))
        XCTAssertFalse(TransportBand.canPlay(duration: .zero))
        XCTAssertTrue(TransportBand.canPlay(duration: seconds(6)))
    }

    // MARK: - App-side loop

    /// Loop is implemented in the app, not by `VideoPreview(loops:)` — kadr-ui
    /// freezes that flag into the player at construction time. The signal the
    /// app watches for is `isPlaying` falling with the playhead at the end.
    func testLoopRestartsWhenPlaybackRunsOutWithLoopOn() {
        XCTAssertTrue(TransportBand.shouldRestartForLoop(
            wasPlaying: true,
            isPlaying: false,
            isLooping: true,
            current: seconds(6),
            duration: seconds(6)
        ))
    }

    /// The observer ticks every 0.1s and compares against the player item's
    /// duration, so the last published position can land just short of the
    /// composition's. The tolerance has to cover that.
    func testLoopRestartsFromJustShortOfTheEnd() {
        XCTAssertTrue(TransportBand.shouldRestartForLoop(
            wasPlaying: true,
            isPlaying: false,
            isLooping: true,
            current: seconds(5.9),
            duration: seconds(6)
        ))
    }

    func testLoopDoesNotRestartWhenLoopIsOff() {
        XCTAssertFalse(TransportBand.shouldRestartForLoop(
            wasPlaying: true,
            isPlaying: false,
            isLooping: false,
            current: seconds(6),
            duration: seconds(6)
        ))
    }

    /// A pause in the middle is a pause, not an ending.
    func testLoopDoesNotRestartOnAMidCompositionPause() {
        XCTAssertFalse(TransportBand.shouldRestartForLoop(
            wasPlaying: true,
            isPlaying: false,
            isLooping: true,
            current: seconds(3),
            duration: seconds(6)
        ))
    }

    /// The restart writes `isPlaying = true`, which re-enters the same
    /// observer. A rise must never be treated as an ending or the band spins.
    func testLoopDoesNotRestartOnItsOwnEcho() {
        XCTAssertFalse(TransportBand.shouldRestartForLoop(
            wasPlaying: false,
            isPlaying: true,
            isLooping: true,
            current: .zero,
            duration: seconds(6)
        ))
    }

    // MARK: - Store state

    /// Playback state is session UX state, like the playhead and the
    /// selection: it must not enter the undo timeline or the document.
    func testPlaybackStateIsNotUndoable() {
        let store = makeStore()
        store.isPlaying = true
        store.isLooping = true
        XCTAssertFalse(store.canUndo)
    }

    func testPlaybackStateDefaultsOff() {
        let store = makeStore()
        XCTAssertFalse(store.isPlaying)
        XCTAssertFalse(store.isLooping)
    }

    // MARK: - Localization

    /// Every user-facing string in the band, asserted against its English
    /// value. `NSLocalizedString` returns the key unchanged when the bundle
    /// or the entry is missing, and a dotted key never equals its value — so
    /// a `==` against the expected copy catches a missing entry, a missing
    /// file and a typo alike. (Literal-English keys elsewhere in the app
    /// can't: they pass whether or not the entry exists.)
    func testEveryTransportKeyResolvesFromTheBundle() {
        XCTAssertEqual(NSLocalizedString("transport.play", comment: ""), "Play")
        XCTAssertEqual(NSLocalizedString("transport.pause", comment: ""), "Pause")
        XCTAssertEqual(NSLocalizedString("transport.skipBack", comment: ""), "Skip back")
        XCTAssertEqual(NSLocalizedString("transport.skipForward", comment: ""), "Skip forward")
        XCTAssertEqual(NSLocalizedString("transport.loop", comment: ""), "Loop")
        XCTAssertEqual(NSLocalizedString("transport.loop.on", comment: ""), "On")
        XCTAssertEqual(NSLocalizedString("transport.loop.off", comment: ""), "Off")
        XCTAssertEqual(
            NSLocalizedString("transport.fullscreen.enter", comment: ""),
            "Enter full screen"
        )
        XCTAssertEqual(
            NSLocalizedString("transport.fullscreen.exit", comment: ""),
            "Exit full screen"
        )
        XCTAssertEqual(NSLocalizedString("transport.time.a11y", comment: ""), "%1$@ of %2$@")
    }

    /// The spoken copy the controls actually carry, resolved the same way the
    /// call sites resolve it.
    func testSpokenLabelsSwitchWithState() {
        XCTAssertEqual(TransportBand.playPauseLabel(isPlaying: false), "Play")
        XCTAssertEqual(TransportBand.playPauseLabel(isPlaying: true), "Pause")
        XCTAssertEqual(TransportBand.loopValueLabel(isLooping: true), "On")
        XCTAssertEqual(TransportBand.loopValueLabel(isLooping: false), "Off")
        XCTAssertEqual(TransportBand.fullscreenLabel(isFullscreen: false), "Enter full screen")
        XCTAssertEqual(TransportBand.fullscreenLabel(isFullscreen: true), "Exit full screen")
        XCTAssertEqual(TransportBand.skipBackLabel, "Skip back")
        XCTAssertEqual(TransportBand.skipForwardLabel, "Skip forward")
        XCTAssertEqual(TransportBand.loopLabel, "Loop")
    }

    /// The readout is one element, and it speaks a sentence — not "0:01",
    /// which on its own tells a reader nothing.
    func testTimeReadoutSpeaksBothHalves() {
        XCTAssertEqual(
            TransportBand.timeReadoutLabel(elapsed: "0:01", total: "0:06"),
            "0:01 of 0:06"
        )
    }

    // MARK: - Body smoke

    func testBandBuildsAcrossEveryTransportState() {
        let store = makeStore()
        let band = TransportBand(store: store)
        _ = band.body

        store.isPlaying = true
        _ = band.body

        store.isLooping = true
        store.currentTime = CMTime(seconds: 6, preferredTimescale: 600)
        _ = band.body
    }

    func testBandBuildsOnAnEmptyProject() {
        let band = TransportBand(store: ProjectStore(project: Project()))
        XCTAssertNoThrow(try band.inspect())
    }

    func testBandRendersTheElapsedAndTotalReadout() throws {
        let store = makeStore()
        store.currentTime = CMTime(seconds: 1, preferredTimescale: 600)
        let band = TransportBand(store: store)

        XCTAssertEqual(CMTimeGetSeconds(store.video.duration), 6, accuracy: 0.001)
        XCTAssertNoThrow(try band.inspect().find(text: "0:01"))
        XCTAssertNoThrow(try band.inspect().find(text: "0:06"))
    }

    /// The full-screen binding is the band's only outward wire, and the band
    /// is the only exit from full screen — so the toggle has to reach back.
    func testFullscreenBindingIsTwoWay() throws {
        var isFullscreen = true
        let binding = Binding(get: { isFullscreen }, set: { isFullscreen = $0 })
        let band = TransportBand(store: makeStore(), isFullscreen: binding)

        XCTAssertNoThrow(try band.inspect())
        XCTAssertEqual(TransportBand.fullscreenLabel(isFullscreen: isFullscreen), "Exit full screen")

        binding.wrappedValue.toggle()
        XCTAssertFalse(isFullscreen)
    }
}

// MARK: - Scene-storage playhead gating

/// v0.9 — the transport band made `store.currentTime` hot, and `EditorView`
/// answered by gating the `@SceneStorage` write on `!isPlaying`. A gate has to
/// be matched by flushes, and a missing flush is silent data loss: the user
/// leaves the editor mid-play and a cold relaunch restores a stale position.
///
/// `@SceneStorage` itself can't run under XCTest (it needs a real scene), so
/// the whole rule lives in `EditorView.playheadRecord(...)` and is pinned here
/// — every trigger, in both playback states.
@MainActor
final class EditorPlayheadPersistenceTests: XCTestCase {

    private let documentID = UUID()

    private func record(
        _ trigger: EditorView.PlayheadTrigger,
        isPlaying: Bool,
        at seconds: Double = 4.2
    ) -> EditorView.PlayheadRecord? {
        EditorView.playheadRecord(
            for: trigger,
            isPlaying: isPlaying,
            currentTime: CMTime(seconds: seconds, preferredTimescale: 600),
            documentID: documentID
        )
    }

    // MARK: The gate

    /// The hot path. ~10 writes a second for the length of a play, every one
    /// of them a position the user never chose.
    func testPlayheadMovesAreSuppressedDuringPlayback() {
        XCTAssertNil(record(.playheadMoved, isPlaying: true))
    }

    /// A scrub happens while paused and must still land immediately — the gate
    /// is not allowed to cost the feature it was added to protect.
    func testScrubsStillWriteWhilePaused() {
        let written = record(.playheadMoved, isPlaying: false)
        XCTAssertEqual(written?.seconds ?? -1, 4.2, accuracy: 0.001)
        XCTAssertEqual(written?.documentID, documentID.uuidString)
    }

    // MARK: The flushes

    /// Playback stopping is the gate's own release valve: no further
    /// `currentTime` change is coming to carry the final position across.
    func testPlaybackStoppingFlushesTheFinalPosition() {
        let written = record(.playbackStateChanged, isPlaying: false, at: 6)
        XCTAssertEqual(written?.seconds ?? -1, 6, accuracy: 0.001)
    }

    /// The rise half of the same trigger is still inside playback and stays
    /// suppressed.
    func testPlaybackStartingWritesNothing() {
        XCTAssertNil(record(.playbackStateChanged, isPlaying: true))
    }

    /// Home / swipe-up / lock, which the system may follow with a kill.
    func testBackgroundingFlushesEvenMidPlayback() {
        let written = record(.sceneBackgrounded, isPlaying: true, at: 3.5)
        XCTAssertEqual(written?.seconds ?? -1, 3.5, accuracy: 0.001)
    }

    /// Wound 3. The nav bar's back button and the restored interactive
    /// edge-swipe pop both tear the editor down without touching `scenePhase`
    /// and without an `isPlaying` change. With the gate in place and no
    /// dismissal flush, leaving mid-play drops the position silently.
    func testDismissalFlushesEvenMidPlayback() {
        let written = record(.editorDismissed, isPlaying: true, at: 5.1)
        XCTAssertEqual(written?.seconds ?? -1, 5.1, accuracy: 0.001)
        XCTAssertEqual(written?.documentID, documentID.uuidString)
    }

    func testDismissalFlushesWhenPausedToo() {
        XCTAssertNotNil(record(.editorDismissed, isPlaying: false))
    }

    /// Every trigger, both states, in one place — so a new trigger added
    /// without a decision fails here rather than shipping.
    func testEveryTriggerHasADecisionInBothStates() {
        let suppressedDuringPlayback: [EditorView.PlayheadTrigger] =
            [.playheadMoved, .playbackStateChanged]
        let alwaysFlushed: [EditorView.PlayheadTrigger] =
            [.sceneBackgrounded, .editorDismissed]

        for trigger in suppressedDuringPlayback {
            XCTAssertNil(record(trigger, isPlaying: true), "\(trigger) wrote during playback")
            XCTAssertNotNil(record(trigger, isPlaying: false), "\(trigger) lost a paused write")
        }
        for trigger in alwaysFlushed {
            XCTAssertNotNil(record(trigger, isPlaying: true), "\(trigger) lost a mid-play flush")
            XCTAssertNotNil(record(trigger, isPlaying: false), "\(trigger) lost a paused flush")
        }
    }

    // MARK: Values

    /// A NaN in scene storage comes back as a garbage seek on the next cold
    /// launch, so a non-numeric playhead records as zero instead.
    func testNonNumericAndNegativeTimesRecordAsZero() {
        XCTAssertEqual(
            EditorView.playheadRecord(
                for: .editorDismissed,
                isPlaying: false,
                currentTime: .invalid,
                documentID: documentID
            )?.seconds,
            0
        )
        XCTAssertEqual(record(.editorDismissed, isPlaying: false, at: -3)?.seconds, 0)
    }
}

// MARK: - Player-rebuild identity

/// v0.9 — kadr-ui rebuilds the `AVPlayer` inside `.task(id: identity)` and
/// removes the old player's periodic time observer only in `.onDisappear`,
/// which a rebuild does not run. The app's bindings are the first caller to
/// make that observer attach at all, so an edit made mid-playback would leave
/// an orphaned, still-ticking player writing into the same store as its
/// replacement. `PreviewArea` stops playback on the same fingerprint kadr-ui
/// rebuilds on; these pin that fingerprint.
@MainActor
final class CompositionIdentityTests: XCTestCase {

    private func makeClip(id: ClipID, length: Double = 5) -> VideoClip {
        VideoClip(url: URL(fileURLWithPath: "/dev/null"))
            .trimmed(to: 0...length)
            .id(id)
    }

    func testAddingAClipChangesTheIdentity() {
        let store = ProjectStore(project: Project(clips: [makeClip(id: "a")]))
        let before = PreviewArea.compositionIdentity(of: store.video)
        store.append(clip: makeClip(id: "b"))
        XCTAssertNotEqual(before, PreviewArea.compositionIdentity(of: store.video))
    }

    func testAddingAnOverlayChangesTheIdentity() {
        let store = ProjectStore(project: Project(clips: [makeClip(id: "a")]))
        let before = PreviewArea.compositionIdentity(of: store.video)
        store.append(overlay: TextOverlay("hi").id(LayerID("o1")))
        XCTAssertNotEqual(before, PreviewArea.compositionIdentity(of: store.video))
    }

    /// Same counts, different length — a trim. kadr-ui rebuilds on duration
    /// too, so the app has to stop playback on it too.
    func testChangingDurationAloneChangesTheIdentity() {
        let short = ProjectStore(project: Project(clips: [makeClip(id: "a", length: 5)]))
        let long = ProjectStore(project: Project(clips: [makeClip(id: "a", length: 6)]))
        XCTAssertNotEqual(
            PreviewArea.compositionIdentity(of: short.video),
            PreviewArea.compositionIdentity(of: long.video)
        )
    }

    /// The other half of the contract: an edit kadr-ui does *not* rebuild on
    /// must not stop playback either, or every inspector drag would kill the
    /// preview. A filter changes no count and no duration.
    func testANonStructuralEditLeavesTheIdentityAlone() {
        let store = ProjectStore(project: Project(clips: [makeClip(id: "a")]))
        let before = PreviewArea.compositionIdentity(of: store.video)
        store.addFilter(id: "a", .brightness(0.2))
        XCTAssertEqual(before, PreviewArea.compositionIdentity(of: store.video))
    }

    func testIdentityIsStableAcrossRepeatedReads() {
        let store = ProjectStore(project: Project(clips: [makeClip(id: "a")]))
        XCTAssertEqual(
            PreviewArea.compositionIdentity(of: store.video),
            PreviewArea.compositionIdentity(of: store.video)
        )
    }
}
