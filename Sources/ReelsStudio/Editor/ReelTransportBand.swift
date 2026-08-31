import SwiftUI
import CoreMedia
import KadrUI

/// The transport band — the strip of playback controls the approved design
/// puts directly beneath the stage and above the timeline.
///
/// v0.9 — until now the editor had a stage but no way to *run* it: the only
/// thing that moved the playhead was a tap on the timeline. This band is the
/// missing half. Left to right it reads skip-back · play/pause · skip-forward,
/// with the elapsed/total readout centred in the band and loop / full-screen
/// pinned to the trailing edge.
///
/// **Why the app drives playback and not `VideoPreview(loops:)`.** kadr-ui
/// 0.14's preview takes `isPlaying` and `currentTime` as two-way bindings, and
/// those are enough: the store owns both, this band writes them, and the
/// player follows. `loops` is the one parameter that must *not* be threaded
/// through — see ``restartForLoopIfNeeded(wasPlaying:)`` and the note on
/// ``ProjectStore/isLooping``. ``PreviewArea`` therefore always passes
/// `loops: false`, and the restart lives here.
///
/// **No coordinator, no player handle.** The band never touches `AVPlayer`.
/// Everything it does is a write to `store.isPlaying` / `store.currentTime`,
/// exactly the way ``TimelineArea`` and ``KeyframeArea`` drive their kadr-ui
/// components. That is what keeps the whole surface unit-testable: every
/// decision below is a pure static, and the view is the thin part.
struct ReelTransportBand: View {

    var store: ProjectStore

    /// Whether the editor's chrome is collapsed around the stage. Owned by
    /// ``EditorView`` as plain `@State` — full screen is a view mode, not
    /// project state and not session state worth persisting.
    ///
    /// The band itself stays on screen in full screen: it carries the only
    /// exit affordance there is. See ``EditorView``'s body.
    @Binding var isFullscreen: Bool

    @Environment(\.reelPalette) private var palette

    /// Set by the pause half of the play/pause button, cleared by the very
    /// next `isPlaying` observation.
    ///
    /// Without it, pausing by hand inside the last
    /// ``endOfPlaybackTolerance`` of the composition is indistinguishable from
    /// playback running out — both arrive as `isPlaying` going false with the
    /// playhead at the end — and loop would drag the user back to zero after
    /// they deliberately stopped.
    @State private var suppressLoopRestart = false

    /// `isFullscreen` defaults so the band can be constructed as
    /// `ReelTransportBand(store:)` in tests and previews, where the chrome mode is
    /// not the thing under test.
    init(store: ProjectStore, isFullscreen: Binding<Bool> = .constant(false)) {
        self.store = store
        self._isFullscreen = isFullscreen
    }

    var body: some View {
        // One read of the derived composition per body pass. `store.video`
        // recomputes `Project.makeVideo()` on every access, and during
        // playback this body runs ~10 times a second.
        let duration = store.video.duration

        HStack(spacing: Reel.Space.s2) {
            // The two flexible frames split whatever the readout doesn't take
            // *equally*, which is what actually centres the readout in the
            // band — the leading group is three cells wide and the trailing
            // group two, so a plain `Spacer()` pair would sit it off-centre,
            // and a centred overlay would collide with the cells at 320pt.
            transportGroup(duration: duration)
                .frame(maxWidth: .infinity, alignment: .leading)
            timeReadout(duration: duration)
            trailingGroup
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, Reel.Space.s3)
        .padding(.vertical, Reel.Space.s2)
        // Deliberately no `.background`: the band sits flush on the studio
        // ground the stage above it is drawn on, exactly as the nav bar does.
        // The timeline's `surface` block starts below it, and that edge is
        // where the design puts the change of ground.
        .frame(maxWidth: .infinity)
        .onChange(of: store.isPlaying) { wasPlaying, _ in
            restartForLoopIfNeeded(wasPlaying: wasPlaying)
        }
    }

    // MARK: - Leading group: skip · play/pause · skip

    private func transportGroup(duration: CMTime) -> some View {
        HStack(spacing: Reel.Space.s1) {
            Button {
                seek(by: -ReelTransportBand.skipInterval, duration: duration)
            } label: {
                Image(systemName: ReelTransportBand.skipBackSymbol)
            }
            .buttonStyle(ReelIconButtonStyle())
            // Disabled *at* the bound rather than silently clamping, so what
            // VoiceOver reports and what the button does agree.
            .disabled(ReelTransportBand.isAtStart(store.currentTime))
            .accessibilityLabel(ReelTransportBand.skipBackLabel)

            playPauseButton(duration: duration)

            Button {
                seek(by: ReelTransportBand.skipInterval, duration: duration)
            } label: {
                Image(systemName: ReelTransportBand.skipForwardSymbol)
            }
            .buttonStyle(ReelIconButtonStyle())
            .disabled(ReelTransportBand.isAtEnd(store.currentTime, duration: duration))
            .accessibilityLabel(ReelTransportBand.skipForwardLabel)
        }
    }

    /// One button, two faces — never two buttons swapped in and out. VoiceOver
    /// users navigate by position; a control that appears and disappears under
    /// the focus cursor is a worse experience than a label that changes.
    private func playPauseButton(duration: CMTime) -> some View {
        Button {
            if store.isPlaying {
                suppressLoopRestart = true
                store.isPlaying = false
            } else {
                // Pressing play on a finished composition starts it over
                // rather than doing nothing visible.
                if ReelTransportBand.isAtEnd(store.currentTime, duration: duration) {
                    store.currentTime = .zero
                }
                store.isPlaying = true
            }
        } label: {
            Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                // The size lives on the glyph, not on the style:
                // `ReelIconButtonStyle` hard-wires `Typography.bodyEmphasis`
                // (15pt) onto every label it draws, and the design calls for a
                // 26pt play glyph. Setting it here — nearer the leaf — wins.
                .font(.system(
                    size: ReelTransportBand.playGlyphSize,
                    weight: Reel.Typography.headingWeight
                ))
        }
        // The one prominent cell in the band: play is the primary action on
        // this screen and takes the accent fill.
        .buttonStyle(ReelIconButtonStyle(isProminent: true))
        .disabled(!ReelTransportBand.canPlay(duration: duration))
        .accessibilityLabel(ReelTransportBand.playPauseLabel(isPlaying: store.isPlaying))
    }

    // MARK: - Centre: elapsed / total

    /// "0:01 / 0:06". Elapsed carries full `text` because it is the value that
    /// moves; the separator and the total are `textMuted` — they are context,
    /// not the reading. Both ride `Typography.numeric`, which is tabular, so
    /// the digits don't jitter as they tick.
    private func timeReadout(duration: CMTime) -> some View {
        let elapsed = ReelTransportBand.timecode(store.currentTime)
        let total = ReelTransportBand.durationTimecode(duration)

        return HStack(spacing: Reel.Space.s1) {
            Text(verbatim: elapsed)
                .foregroundStyle(palette.text)
            Text(verbatim: "/")
                .foregroundStyle(palette.textMuted)
            Text(verbatim: total)
                .foregroundStyle(palette.textMuted)
        }
        .font(Reel.Typography.numeric)
        .fixedSize()
        // Three Texts on screen, one element in the accessibility tree: a
        // reader that lands on "0:01" alone has been told nothing.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ReelTransportBand.timeReadoutLabel(elapsed: elapsed, total: total))
    }

    // MARK: - Trailing group: loop · full screen

    private var trailingGroup: some View {
        HStack(spacing: Reel.Space.s1) {
            Button {
                store.isLooping.toggle()
            } label: {
                Image(systemName: "repeat")
                    // Active state on the glyph rather than the cell: the
                    // prominent (accent-filled) treatment belongs to play
                    // alone, and `ReelIconButtonStyle` paints the label
                    // `palette.text` from outside — a colour set here, nearer
                    // the leaf, is the one that lands.
                    .foregroundStyle(store.isLooping ? palette.accent : palette.text)
            }
            .buttonStyle(ReelIconButtonStyle())
            .accessibilityLabel(ReelTransportBand.loopLabel)
            .accessibilityValue(ReelTransportBand.loopValueLabel(isLooping: store.isLooping))
            .accessibilityAddTraits(store.isLooping ? AccessibilityTraits.isSelected : [])

            Button {
                isFullscreen.toggle()
            } label: {
                Image(systemName: isFullscreen
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(ReelIconButtonStyle())
            .accessibilityLabel(ReelTransportBand.fullscreenLabel(isFullscreen: isFullscreen))
            .accessibilityAddTraits(isFullscreen ? AccessibilityTraits.isSelected : [])
        }
    }

    // MARK: - Behaviour

    private func seek(by delta: Double, duration: CMTime) {
        store.currentTime = ReelTransportBand.skipTarget(
            from: store.currentTime,
            by: delta,
            duration: duration
        )
    }

    /// App-side loop. Runs when `isPlaying` falls.
    ///
    /// kadr-ui 0.14 sets `actionAtItemEnd` and reads `loops` inside
    /// `.task(id: identity)`, and `identity` is a fingerprint over clip /
    /// overlay / audio counts and duration — it does not include `loops`. The
    /// periodic observer's closure therefore captures whatever `loops` was
    /// when the player was built, and toggling the flag mid-session changes
    /// nothing until something rebuilds the player. Passing `isLooping` down
    /// would ship a loop button that reviews clean and is inert on device.
    ///
    /// So the app does it. `loops: false` means the observer clears
    /// `isPlaying` when a composition runs out; that fall is the signal, and
    /// the restart is a seek to zero plus a play. Nothing is torn down —
    /// deliberately not `reloadToken`, which rebuilds the player and resets
    /// the playhead as a side effect.
    ///
    /// The seek clears kadr-ui's `abs(delta) > 0.05s` floor comfortably: it
    /// runs from the end of the composition back to zero.
    private func restartForLoopIfNeeded(wasPlaying: Bool) {
        if suppressLoopRestart {
            suppressLoopRestart = false
            return
        }
        guard ReelTransportBand.shouldRestartForLoop(
            wasPlaying: wasPlaying,
            isPlaying: store.isPlaying,
            isLooping: store.isLooping,
            current: store.currentTime,
            duration: store.video.duration
        ) else { return }

        store.currentTime = .zero
        store.isPlaying = true
    }
}

// MARK: - Pure decisions

extension ReelTransportBand {

    /// How far one skip moves the playhead, in seconds.
    ///
    /// A fixed second, not a frame. Frame-step was the obvious design and it
    /// cannot work here: `VideoPreview` only seeks when the requested time
    /// differs from the player's by more than 0.05s, and one frame at the
    /// presets' 30fps is 0.0333s — under the floor. A frame-step button would
    /// be silently swallowed on every press and do nothing at all. A second is
    /// well clear of the floor and is the unit the readout is already in.
    ///
    /// The glyphs have nothing to do with it. The cells carry the *unnumbered*
    /// ``skipBackSymbol`` / ``skipForwardSymbol``. Until v0.9.1 this note
    /// claimed the second "matches the `gobackward.1` / `goforward.1` glyphs
    /// the cells carry" — it never did: SF Symbols has no `.1` member in that
    /// family and never has (the ladder runs .5 / .10 / .15 / .30 / .45 / .60
    /// / .75 / .90), so both names resolved to nothing and both cells drew a
    /// missing-glyph placeholder on device. The interval stands on the seek
    /// floor alone.
    // MARK: - Decisions, delegated
    //
    // Every judgement below moved to KadrUI's `TransportControls` in kadr-ui 0.21
    // is re-exported here so this file's call sites — and its tests — keep
    // reading the same way. What stays local is the *chrome*: the Reel spacing
    // and typography, and the localised copy below. That split is deliberate.
    // This app exists to demonstrate a design system, so its transport band
    // should look like the design rather than like KadrUI's defaults; but the
    // arithmetic was never app-specific and should not have been here.

    nonisolated static let skipInterval = TransportControls.defaultSkipInterval
    nonisolated static let skipBackSymbol = TransportControls.skipBackSymbol
    nonisolated static let skipForwardSymbol = TransportControls.skipForwardSymbol
    nonisolated static let playGlyphSize = TransportControls.playGlyphSize
    nonisolated static let boundEpsilon = TransportControls.boundEpsilon
    nonisolated static let endOfPlaybackTolerance = TransportControls.endOfPlaybackTolerance

    nonisolated static func timecode(_ time: CMTime) -> String {
        TransportControls.timecode(time)
    }

    nonisolated static func durationTimecode(_ time: CMTime) -> String {
        TransportControls.durationTimecode(time)
    }

    nonisolated static func skipTarget(from current: CMTime, by delta: Double, duration: CMTime) -> CMTime {
        TransportControls.skipTarget(from: current, by: delta, duration: duration)
    }

    nonisolated static func isAtStart(_ time: CMTime) -> Bool {
        TransportControls.isAtStart(time)
    }

    nonisolated static func isAtEnd(_ time: CMTime, duration: CMTime) -> Bool {
        TransportControls.isAtEnd(time, duration: duration)
    }

    nonisolated static func canPlay(duration: CMTime) -> Bool {
        TransportControls.canPlay(duration: duration)
    }

    nonisolated static func reachedEndOfPlayback(_ time: CMTime, duration: CMTime) -> Bool {
        TransportControls.reachedEndOfPlayback(time, duration: duration)
    }

    nonisolated static func shouldRestartForLoop(
        wasPlaying: Bool, isPlaying: Bool, isLooping: Bool, current: CMTime, duration: CMTime
    ) -> Bool {
        TransportControls.shouldRestartForLoop(
            wasPlaying: wasPlaying, isPlaying: isPlaying, isLooping: isLooping,
            current: current, duration: duration
        )
    }
}

// MARK: - Spoken copy

extension ReelTransportBand {

    /// Resolved through the bundle rather than handed to SwiftUI as a
    /// `LocalizedStringKey`, so what VoiceOver speaks and what a test reads
    /// are the same string.
    nonisolated static func playPauseLabel(isPlaying: Bool) -> String {
        NSLocalizedString(isPlaying ? "transport.pause" : "transport.play", comment: "")
    }

    nonisolated static var skipBackLabel: String {
        NSLocalizedString("transport.skipBack", comment: "")
    }

    nonisolated static var skipForwardLabel: String {
        NSLocalizedString("transport.skipForward", comment: "")
    }

    nonisolated static var loopLabel: String {
        NSLocalizedString("transport.loop", comment: "")
    }

    nonisolated static func loopValueLabel(isLooping: Bool) -> String {
        NSLocalizedString(isLooping ? "transport.loop.on" : "transport.loop.off", comment: "")
    }

    nonisolated static func fullscreenLabel(isFullscreen: Bool) -> String {
        NSLocalizedString(
            isFullscreen ? "transport.fullscreen.exit" : "transport.fullscreen.enter",
            comment: ""
        )
    }

    /// "0:01 of 0:06" — the readout as a sentence. The slash on screen is
    /// punctuation a reader would either skip or spell out.
    nonisolated static func timeReadoutLabel(elapsed: String, total: String) -> String {
        String(
            format: NSLocalizedString("transport.time.a11y", comment: ""),
            elapsed,
            total
        )
    }
}
