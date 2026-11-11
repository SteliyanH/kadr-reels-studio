import SwiftUI
import CoreMedia
import Kadr
import KadrUI

/// The stage — `VideoPreview` (AVKit player) overlaid with `OverlayHost`
/// (gesture-routed overlays). Aspect ratio locked to the project preset's
/// resolution.
///
/// v0.8 Tier 5b — the approved design's stage band: the 9:16 frame sits on a
/// true-black letterbox with square corners and `.reelElevation(.lg)`,
/// and carries a `numeric` spec chip in its top-left corner reading the
/// preset's own resolution and frame rate. Decision 5 is explicit that the
/// stage is the one surface that is **never** grayscaled — the user is
/// grading colour here.
///
/// v0.9 — the stage is now *driven*: `isPlaying` / `currentTime` are two-way
/// with the store, so ``ReelTransportBand`` starts and stops the player by writing
/// state. Three things had to be handled here for that to be safe, each marked
/// at its site below: AVKit's own transport chrome (blocked), kadr-ui's
/// player rebuild leaking a live time observer (playback is stopped first),
/// and a load failure leaving `isPlaying` stuck true (cleared and surfaced).
struct PreviewArea: View {

    var store: ProjectStore
    @Environment(\.reelPalette) private var palette
    @Environment(ToastCenter.self) private var toasts
    /// Test-only seam (issue #75). Defaults to `.live`; nothing in the app
    /// writes it, so production always takes the `VideoPreview` branch below.
    @Environment(\.stageRendering) private var stageRendering

    var body: some View {
        let video = store.video
        let aspect = video.preset.resolution.width / video.preset.resolution.height

        ZStack {
            picture(video: video)

            OverlayHost(video, currentTime: store.currentTime)
                // v0.4 Tier 6: tap an overlay's hit region to select it.
                // Routes to the same selection slot the Layers sheet writes,
                // so the inspector / keyframe pair swaps the moment a layer
                // is tapped. v0.3's LayersSheet stays as the secondary
                // affordance (still useful for stacked or off-screen layers).
                //
                // Sits above the picture in the ZStack, so it gets first
                // refusal on every touch — overlay tap-to-select and drag are
                // unaffected by the preview declining AVKit's own transport.
                .onLayerTap { id in
                    store.selectedOverlayID = id
                }
        }
        // v0.9 — kadr-ui rebuilds the player inside `.task(id: identity)` when
        // the composition's structural identity changes, and it removes the old
        // player's periodic time observer only in `.onDisappear` — which does
        // not run on a rebuild. Nothing stops the user editing mid-playback, so
        // adding, deleting or trimming a clip while it plays would leave an
        // orphaned, still-ticking AVPlayer writing `currentTime` and
        // `isPlaying` into the same store as its replacement: two playheads
        // fighting over one binding.
        //
        // Stopping playback on the identity change is the narrow fix. The
        // alternative — stopping inside `ProjectStore.applyMutation` — fires on
        // *every* mutation, including the opacity and speed sliders that don't
        // rebuild anything, so playback would die under any inspector drag.
        // This watches exactly what kadr-ui watches, so it triggers exactly
        // when a rebuild does. It writes only session state, so nothing enters
        // the undo timeline.
        .onChange(of: VideoPreview.compositionIdentity(of: video)) {
            store.isPlaying = false
        }
        .aspectRatio(aspect, contentMode: .fit)
        // v0.8 Tier 2 — the letterbox stays true black: this is the field the
        // user grades against, so it takes the stage token rather than a
        // ground-tinted role. Decision 5's "never grayscale the stage" applies
        // to the same surface for the same reason.
        .background(Reel.stageInk)
        .clipShape(RoundedRectangle(cornerRadius: palette.radius.md))
        // The chip rides the *fitted* frame, not the band: `.aspectRatio(.fit)`
        // resolves this view's own bounds to the letterboxed rectangle, so a
        // `.topLeading` overlay lands in the video's corner on every device
        // width without measuring anything.
        .overlay(alignment: .topLeading) { specChip }
        .reelElevation(.lg)
    }

    // MARK: - Picture layer

    /// The stage's picture: kadr-ui's player, or — under the test-only
    /// ``StageRendering/placeholder`` seam — the bare letterbox field.
    ///
    /// The branch is the whole of issue #75's stage seam. `VideoPreview`'s
    /// initialiser is pure (it only stores its arguments); every effect it has
    /// — building the `AVPlayer`, attaching the periodic time observer,
    /// reporting a load failure — happens inside its `.task` on appear. So not
    /// constructing it is enough to remove all asynchronous work from the
    /// stage, and with it the loading-spinner-versus-failure-glyph race that
    /// makes a snapshot baseline of the editor unrepeatable. Nothing else in
    /// `body` changes: the chrome blocker, the overlay host, the spec chip and
    /// the letterbox all render from project data alone.
    ///
    /// ``StageRendering/live`` is the default and the only value the app ever
    /// resolves, so this branch is invisible to production.
    ///
    /// Takes the composition as a parameter rather than reading `store.video`
    /// itself: `body` already derived it once, and `Project.makeVideo()` runs
    /// afresh on every read. This view re-renders roughly ten times a second
    /// while the transport is running (see ``ReelTransportBand``), so the house
    /// rule is one read of the derived composition per body pass — the same
    /// value that feeds the aspect ratio and the rebuild fingerprint feeds the
    /// player.
    @ViewBuilder
    private func picture(video: Video) -> some View {
        switch stageRendering {
        case .live:
            // v0.9 — the stage is now driven, not just shown. `isPlaying` and
            // `currentTime` are two-way with the store, so the transport band
            // starts and stops the player by writing state and the player's
            // periodic observer writes the playhead back. Same shape as
            // `TimelineArea` / `KeyframeArea`'s bindings; no coordinator, no
            // player handle held anywhere in the app.
            VideoPreview(
                video,
                isPlaying: Binding(
                    get: { store.isPlaying },
                    set: { store.isPlaying = $0 }
                ),
                currentTime: Binding(
                    get: { store.currentTime },
                    set: { store.currentTime = $0 }
                ),
                // Still false, but no longer *forced* false. kadr-ui 0.15 made
                // `loops` live — the observer reads the current value rather
                // than a copy frozen at player construction — so threading
                // `store.isLooping` through here would now work.
                //
                // Not doing it in this change: the app-side restart in
                // `ReelTransportBand` is covered by unit tests, and real playback
                // cannot be exercised on a virtualised runner, so swapping
                // tested behaviour for behaviour nothing here can verify is a
                // bad trade. Worth revisiting on a device.
                loops: false,
                // kadr-ui 0.15 — decline AVKit's own transport rather than
                // covering it. This blocks hit-testing and hides the preview
                // from accessibility upstream, which is what the app used to do
                // for itself with a transparent tap-eater plus a blanket
                // `.accessibilityHidden` over the whole subtree.
                showsPlaybackControls: false,
                // v0.9 — without this a failed load strands the transport: the
                // band would read "Pause" over kadr-ui's failure glyph forever
                // because nothing ever clears `isPlaying`, and the error itself
                // would go nowhere. Clear the state, then surface it on the
                // same toast path the editor's auto-save failures use.
                onLoadFailure: { error in
                    store.isPlaying = false
                    toasts.show(.transient(error, prefix: "Couldn't load preview"))
                }
            )
        case .placeholder:
            // The same true black the letterbox behind it already uses, so the
            // stubbed frame is the stage with its picture switched off rather
            // than a stand-in drawn on top of it. A `Color` takes all offered
            // space exactly as the player does, so the ZStack, the aspect fit
            // and the chip's corner are unaffected. Deliberately carries no
            // text: a test fixture must not invent user-facing copy.
            Reel.stageInk
        }
    }

    // MARK: - AVKit chrome blocker

    /// Swallows every touch that would otherwise reach AVKit's own transport
    /// controls.
    ///
    /// kadr-ui renders a bare SwiftUI `VideoPlayer(player:)`, which draws
    /// AVKit's play/pause and scrubber over the picture, and exposes no
    /// `showsPlaybackControls` to turn them off (recorded as a known ceiling in
    /// DESIGN.md). That was harmless while nothing in the app drove playback.
    /// It is not harmless now: AVKit's controls talk straight to the
    /// `AVPlayer`, so a tap on *its* pause button stops the video and
    /// ``ProjectStore/isPlaying`` never hears about it — the band would then
    /// show "Pause" over a stopped frame, keep skip-forward enabled past the
    /// end, and never see the `isPlaying` fall that app-side loop watches for.
    // MARK: - Spec chip

    /// "1080×1920 · 30 fps", flush in the stage's top-left corner.
    ///
    /// Flat and opaque rather than a translucent capsule: nothing in this
    /// system floats, and a solid `bg` block reads on any frame the user
    /// scrubs to — which a text-only chip over live footage would not.
    private var specChip: some View {
        Text(verbatim: PreviewArea.specChipText(for: store.project.preset))
            .font(Reel.Typography.numeric)
            .foregroundStyle(palette.text)
            .padding(.horizontal, Reel.Space.s2)
            .padding(.vertical, Reel.Space.s1)
            .background(palette.bg)
            .padding(Reel.Space.s2)
            .accessibilityLabel("Output format")
            .accessibilityValue(PreviewArea.specChipText(for: store.project.preset))
    }
}

extension PreviewArea {
    /// The stage chip's copy, from the preset the project already carries —
    /// no new state, no new field. Pure for testability.
    ///
    /// The multiplication sign is U+00D7, not the letter x, per the design.
    /// Digits and the unit ride `Typography.numeric` at the call site, so the
    /// string itself stays free of markup.
    nonisolated static func specChipText(for preset: Preset) -> String {
        let size = preset.resolution
        return "\(Int(size.width))×\(Int(size.height)) · \(preset.frameRate) fps"
    }

    /// kadr-ui's player-rebuild fingerprint, restated.
    ///
    /// `VideoPreview` keys its `.task` on a coarse identity over
    /// `clips.count`, `overlays.count`, `audioTracks.count` and `duration`, and
    /// rebuilds the `AVPlayer` whenever it changes. The app cannot read that
    /// value — it is private — so it is recomputed here from the same four
    /// inputs. Any drift in kadr-ui's definition means playback survives a
    /// rebuild it should not have; that is what the tests below pin.
    ///
    /// A `String` rather than a tuple so it drops straight into
    /// `.onChange(of:)`, which needs `Equatable`. Pure for testability.
}
