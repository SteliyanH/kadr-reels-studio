import SwiftUI
import Kadr
import KadrUI

/// Bottom half of the editor — `TimelineView` with the two-tier
/// `EditorToolbar` above it (root verbs ↔ clip-action ↔ overlay-action,
/// selection-driven swap).
struct TimelineArea: View {

    @ObservedObject var store: ProjectStore
    /// Root-row sheet triggers — owned by the parent so it can present them.
    var onAddClip: () -> Void = {}
    var onAddOverlay: () -> Void = {}
    var onLayers: () -> Void = {}
    var onAddMusic: () -> Void = {}
    var onAddSFX: () -> Void = {}
    var onAddCaptions: () -> Void = {}
    var onExport: () -> Void = {}
    /// Clip-action: pushes `SpeedCurveSheet` for the selected clip id.
    var onSpeedCurve: (Kadr.ClipID) -> Void = { _ in }
    /// Clip-action: pushes `FiltersSheet` for the selected clip id.
    var onFilters: (Kadr.ClipID) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 8) {
            EditorToolbar(
                store: store,
                onAddClip: onAddClip,
                onAddOverlay: onAddOverlay,
                onLayers: onLayers,
                onAddMusic: onAddMusic,
                onAddSFX: onAddSFX,
                onAddCaptions: onAddCaptions,
                onExport: onExport,
                onSpeedCurve: onSpeedCurve,
                onFilters: onFilters
            )
            timeline
        }
    }

    // MARK: - Timeline

    @ViewBuilder
    private var timeline: some View {
        TimelineView(
            store.video,
            currentTime: Binding(
                get: { store.currentTime },
                set: { store.currentTime = $0 }
            ),
            selectedClipID: Binding(
                get: { store.selectedClipID },
                set: { newValue in
                    // v0.4 Tier 5: in multi-select mode, kadr-ui's tap-to-
                    // select still writes here. We intercept and route the
                    // tapped id into the set toggle instead of replacing
                    // the single-select slot. Outside the mode the binding
                    // behaves normally.
                    if store.isMultiSelecting {
                        if let id = newValue {
                            if store.selectedClipIDs.contains(id) {
                                store.selectedClipIDs.remove(id)
                            } else {
                                store.selectedClipIDs.insert(id)
                            }
                        }
                    } else {
                        store.selectedClipID = newValue
                    }
                }
            ),
            selectedClipIDs: Binding(
                get: { store.selectedClipIDs },
                set: { store.selectedClipIDs = $0 }
            ),
            zoom: zoomBinding,
            laneHeight: 56,
            showAudioWaveforms: true,
            showLaneLabels: true,
            onReorder: { _, _, newClips in
                store.replaceClips(newClips)
            },
            onTrackReorder: { _, _, _, newClips in
                // KadrUI hands us the full new top-level clips array with
                // the rebuilt Track substituted in place — same shape as
                // onReorder. Routes through the existing replaceClips
                // mutation.
                store.replaceClips(newClips)
            },
            onTrackTrim: { trackIndex, clipIndex, leadingTrim, trailingTrim in
                store.applyTrackTrim(
                    trackIndex: trackIndex,
                    clipIndex: clipIndex,
                    leadingTrim: leadingTrim,
                    trailingTrim: trailingTrim
                )
            }
        )
        .fixedCenterPlayhead(store.project.fixedCenterPlayhead)
        .onZoomSnap { _ in HapticEngine.shared.snap() }
        .onClipDragSnap { HapticEngine.shared.snap() }
        .onLongPressClip { id in
            // Enter multi-select mode + seed the set with the long-pressed
            // clip. Subsequent single taps toggle membership via the
            // intercepted selectedClipID binding above.
            HapticEngine.shared.thud()
            store.selectedClipID = nil  // clear single-select so the spring
                                        // doesn't transition through the clip row
            store.isMultiSelecting = true
            store.selectedClipIDs = [id]
        }
        .frame(height: 96)
        .padding(.horizontal)
        // The inner TimelineView's gesture surface is rich (tap to scrub,
        // pinch to zoom, drag to reorder, long-press to multi-select) and
        // not easily VoiceOver-introspectable. Label the wrapper so a
        // VoiceOver user at least gets oriented; per-clip a11y is gated on
        // a future kadr-ui surface. v0.5 Tier 2.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timeline")
        .accessibilityHint("\(store.project.clips.count) clip\(store.project.clips.count == 1 ? "" : "s"). Long-press a clip to start a multi-selection.")
    }

    /// Binding to ``Project/zoom`` that initializes a non-nil value on first
    /// access. Without this, the first pinch wouldn't have anywhere to
    /// write — `TimelineView`'s `Binding<TimelineZoom>?` accepts nil for
    /// the auto fit-to-width path, but kadr-ui needs a writable binding to
    /// honor pinch gestures. We seed with a starting density (50 px/sec)
    /// the first time the pinch handler reads it.
    private var zoomBinding: Binding<TimelineZoom>? {
        Binding(
            get: { store.project.zoom ?? TimelineZoom(pixelsPerSecond: 50) },
            set: { store.updateZoom($0) }
        )
    }
}

