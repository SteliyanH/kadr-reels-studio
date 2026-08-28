import XCTest
import CoreMedia
import SwiftUI
import SnapshotTesting
import Kadr
import KadrPersistence
@testable import ReelsStudio

/// Issue #75 — a thin slice of pixel-snapshot coverage over the editor view
/// group: ``EditorView``, ``PreviewArea``, ``TransportBand`` and
/// ``EditorToolbar``.
///
/// **Why this exists.** Every other test in this target proves *behaviour* —
/// a binding wired, a computed string, a selection slot. None of them would
/// catch a change that only shifts layout, colour, or spacing. This suite
/// fills that gap for the one screen group the approved design cares about
/// pixel-for-pixel.
///
/// **Determinism.** The stage is normally an AVKit player (`VideoPreview`)
/// that builds its `AVPlayer` asynchronously and races a loading spinner
/// against a failure glyph — unrepeatable in a snapshot. `StageRendering`
/// (see `Sources/ReelsStudio/Editor/StageRendering.swift`) removes that race:
/// every view below is snapshotted with `\.stageRendering` set to
/// `.placeholder`, which swaps the player for the stage's own letterbox
/// field. Every store is built from the same fixed fixture — one
/// `/dev/null` clip trimmed to a 6-second composition — with `currentTime`
/// pinned and `isPlaying` false, so nothing in the tree is mid-animation or
/// mid-load when the frame is captured.
///
/// **No baselines are committed.** This machine is not a canonical renderer
/// (it isn't even a *unique* one — two simulators on it both answer to
/// "iPhone 17 Pro"). Baselines live only in CI's pinned-runtime job; see
/// ``requireCIPinnedRuntime()`` below for how that's enforced, and do not
/// commit a `__Snapshots__/` directory alongside this file.
@MainActor
final class SnapshotTests: XCTestCase {

    // MARK: - Skip guard

    /// Every test in this file calls this first, before building any view.
    ///
    /// Snapshot baselines are recorded and judged on exactly one machine:
    /// CI's pinned simulator runtime. A laptop — any laptop, any simulator,
    /// any Xcode version — renders fonts, hinting and color management
    /// subtly differently, so a baseline recorded here would fail against
    /// CI on machines that changed nothing, and a comparison run here
    /// against CI's baseline would fail for the same reason in reverse.
    /// Neither direction is a real signal.
    ///
    /// This guard is what keeps that from mattering day to day: unless
    /// `SNAPSHOT_RUNTIME_PINNED=1` is set, every test below reports
    /// **skipped**, not passed and not failed — so a contributor running
    /// `xcodebuild test` (or the local tests gate) on their own machine sees
    /// a green run and *only* a green run, never a false failure and never a
    /// false pass.
    ///
    /// The flip side matters just as much: a green local run that skipped
    /// every snapshot test proves nothing about the editor's pixels. CI sets
    /// `SNAPSHOT_RUNTIME_PINNED=1` on its pinned runtime and *only* there —
    /// that job is the sole judge of these baselines. A future contributor
    /// who sees this suite pass locally and concludes the stage is
    /// pixel-covered has mistaken silence for coverage; the coverage lives
    /// entirely on the other side of this guard.
    ///
    /// **How the variable actually reaches this process.** By injecting it
    /// into the *booted simulator's* `launchd` environment before `xcodebuild`
    /// runs — that is the authoritative mechanism, and what CI does:
    ///
    /// ```sh
    /// xcrun simctl boot <UDID>
    /// xcrun simctl bootstatus <UDID> -b
    /// xcrun simctl spawn <UDID> launchctl setenv SNAPSHOT_RUNTIME_PINNED 1
    /// # then run xcodebuild test against that same -destination id=<UDID>
    /// ```
    ///
    /// Anything the test host launches under that `launchd` inherits the
    /// variable, so `ProcessInfo` below sees it. Run those three lines against
    /// the simulator you are targeting and a local run will genuinely execute
    /// these tests instead of skipping them (it will then record or compare
    /// baselines on *your* renderer, which is exactly what the paragraphs
    /// above warn about — do not commit the result).
    ///
    /// CI additionally passes `TEST_RUNNER_SNAPSHOT_RUNTIME_PINNED=1` on the
    /// `xcodebuild` command line, but that is belt-and-braces only: it is
    /// **measured not to work** on this toolchain (Xcode 26.6 / macOS 25.5).
    /// `xcodebuild` accepts it as a build setting and echoes it back under
    /// "Build settings from command line", then silently drops it — a dump of
    /// all 73 variables visible inside the running test host showed neither it
    /// nor a control `TEST_RUNNER_FOOBAR=hello`, with plain `test` and with
    /// `build-for-testing` + `test-without-building` alike. It is retained
    /// only in case a future Xcode honours the prefix; do not rely on it, and
    /// do not delete the `launchctl setenv` step believing it redundant.
    private func requireCIPinnedRuntime() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["SNAPSHOT_RUNTIME_PINNED"] == "1",
            "Snapshot baselines are judged only on CI's pinned runtime — " +
            "skipping locally so a laptop's rendering never produces a " +
            "false pass or a false failure. Set SNAPSHOT_RUNTIME_PINNED=1 " +
            "in the booted simulator's launchd (xcrun simctl spawn <UDID> " +
            "launchctl setenv SNAPSHOT_RUNTIME_PINNED 1) to run for real."
        )
    }

    // MARK: - Fixtures

    /// The one composition every snapshot in this file is built from: a
    /// single `/dev/null` clip trimmed to 6 seconds, id'd `"clip-a"` — the
    /// exact fixture pattern `TransportBandTests` uses. `currentTime` and
    /// `isPlaying` are fixed by the caller (default: zero / not playing) so
    /// nothing about the captured frame depends on wall-clock or gesture
    /// state.
    private func makeStore(currentTime: CMTime = .zero, isPlaying: Bool = false) -> ProjectStore {
        let store = ProjectStore(project: Project(clips: [
            VideoClip(url: URL(fileURLWithPath: "/dev/null"))
                .trimmed(to: 0...6)
                .id("clip-a")
        ]))
        store.currentTime = currentTime
        store.isPlaying = isPlaying
        return store
    }

    /// A throwaway on-disk library for `EditorView`'s `library:` parameter —
    /// same temp-directory pattern as `GestureWiringTests.makeLibrary()`.
    private func makeLibrary() throws -> ProjectLibrary {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshot-\(UUID().uuidString)", isDirectory: true)
        return try ProjectLibrary(directoryURL: tmp)
    }

    /// The persisted mirror of `makeStore()`'s fixture, for the one snapshot
    /// (`EditorView`) that is constructed from a `ProjectDocument` rather
    /// than a `ProjectStore` directly.
    private func makeDocument() -> ProjectDocument {
        let clip = VideoClipData(
            clipID: "clip-a",
            url: URL(fileURLWithPath: "/dev/null"),
            trimStartSeconds: 0,
            trimDurationSeconds: 6
        )
        return ProjectDocument(name: "Snapshot Fixture", legacyClips: [.video(clip)])
    }

    // MARK: - EditorView

    /// The full editor screen in its default session state: nothing
    /// selected, not full screen, not playing.
    func testEditorViewDefaultSessionState() throws {
        try requireCIPinnedRuntime()

        let library = try makeLibrary()
        let view = EditorView(document: makeDocument(), library: library)
            .environment(ToastCenter())
            .environment(AppSettings.shared)
            .environment(\.stageRendering, .placeholder)

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 402, height: 874)))
    }

    // Every isolated view below carries `.reelSurface(.studio)`.
    //
    // `EditorView` applies it internally (EditorView.swift:263), so the
    // full-editor case gets the studio ground for free — but a view
    // snapshotted on its own does not, and renders on the default print
    // ground instead: light surface, pure-red accent. The first recorded
    // set had exactly that wrong, and it is the worse kind of wrong: a
    // baseline that pins an appearance the app never ships turns a real
    // theming regression into an expected result, and misleads whoever
    // reviews the next diff. Do not remove these — an isolated snapshot
    // must be taken in the ground the view actually lives in.

    // Two framing rules, both learned from the first reviewed baseline set.
    //
    // **Width is 402, not 390.** 402x874 is the logical size of the iPhone 17
    // Pro that the pinned CI job actually renders on. The first set was framed
    // at 390 and clipped the toolbar's longest label to "Captio…", which read
    // as a layout defect in the app. It was not: at the device's real width
    // "Captions" fits with room to spare. Framing a snapshot narrower than the
    // device it claims to represent manufactures defects that do not exist,
    // and the fix for one of those would have been to shrink shipping text.
    //
    // **The isolated stage is padded inside the studio ground.** `PreviewArea`
    // ends in `.reelElevation(.lg)`, and a shadow needs somewhere to fall. In
    // the editor the stage is inset, so it falls on the ground behind it; in an
    // isolated snapshot the stage filled the canvas edge to edge and the shadow
    // clipped against the image bounds, leaving a smudge in the corners that
    // looked like a rendering artifact. The padding gives it that room, and the
    // `.frame(maxWidth:maxHeight:)` before `.reelSurface(.studio)` makes the
    // ground cover the whole canvas rather than only the aspect-fitted stage.

    // MARK: - PreviewArea

    /// The stage alone, placeholder-rendered, with no overlay in the
    /// project.
    func testPreviewAreaPlaceholder() throws {
        try requireCIPinnedRuntime()

        let store = makeStore()
        let view = PreviewArea(store: store)
            .environment(ToastCenter())
            .environment(\.stageRendering, .placeholder)
            .padding(Reel.Space.s3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .reelSurface(.studio)

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 270, height: 480)))
    }

    /// The stage with one text overlay in the project — the
    /// `OverlayHost`-composed variant `PreviewArea` also has to render
    /// correctly in placeholder mode.
    func testPreviewAreaPlaceholderWithOverlay() throws {
        try requireCIPinnedRuntime()

        let store = makeStore()
        store.append(overlay: TextOverlay("hi").id(LayerID("o1")))
        let view = PreviewArea(store: store)
            .environment(ToastCenter())
            .environment(\.stageRendering, .placeholder)
            .padding(Reel.Space.s3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .reelSurface(.studio)

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 270, height: 480)))
    }

    // MARK: - TransportBand

    /// Playhead at zero: skip-back is disabled, the readout reads "0:00 /
    /// 0:06".
    func testTransportBandAtZero() throws {
        try requireCIPinnedRuntime()

        let store = makeStore(currentTime: .zero)
        let view = TransportBand(store: store)
            .reelSurface(.studio)

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 402, height: 96)))
    }

    /// Playhead three seconds into the six-second composition: both skip
    /// buttons are live and the readout reads "0:03 / 0:06".
    func testTransportBandMidComposition() throws {
        try requireCIPinnedRuntime()

        let store = makeStore(currentTime: CMTime(seconds: 3, preferredTimescale: 600))
        let view = TransportBand(store: store)
            .reelSurface(.studio)

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 402, height: 96)))
    }

    // MARK: - EditorToolbar

    /// The root row: nothing selected, so the toolbar shows its verb cells
    /// (Clip / Overlay / Layers / Music / SFX / Captions) plus Export.
    func testEditorToolbarRootMode() throws {
        try requireCIPinnedRuntime()

        let store = makeStore()
        let view = EditorToolbar(
            store: store,
            onAddClip: {}, onAddOverlay: {}, onLayers: {},
            onAddMusic: {}, onAddSFX: {}, onAddCaptions: {},
            onExport: {}, onSpeedCurve: { _ in }
        )
        .environment(ToastCenter())
        .reelSurface(.studio)

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 402, height: 140)))
    }

    /// The clip-action row: `store.selectedClipID` set to the fixture clip
    /// swaps the toolbar into its clip mode.
    func testEditorToolbarClipSelectedMode() throws {
        try requireCIPinnedRuntime()

        let store = makeStore()
        store.selectedClipID = "clip-a"
        let view = EditorToolbar(
            store: store,
            onAddClip: {}, onAddOverlay: {}, onLayers: {},
            onAddMusic: {}, onAddSFX: {}, onAddCaptions: {},
            onExport: {}, onSpeedCurve: { _ in }
        )
        .environment(ToastCenter())
        .reelSurface(.studio)

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 402, height: 140)))
    }
}
