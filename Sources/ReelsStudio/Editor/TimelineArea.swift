import SwiftUI
import Kadr
import KadrUI

/// Bottom half of the editor — `TimelineView` with the editor's standard toolbar
/// row above it (+ Clip / + Overlay / + Music / Export buttons; their sheets
/// arrive in Tiers 2 / 3 / 6).
struct TimelineArea: View {

    @ObservedObject var store: ProjectStore
    /// Tap callbacks for each toolbar button — owned by the parent so it can
    /// present sheets with shared state.
    var onAddClip: () -> Void = {}
    var onAddOverlay: () -> Void = {}
    var onAddMusic: () -> Void = {}
    var onAddSFX: () -> Void = {}
    var onAddCaptions: () -> Void = {}
    var onExport: () -> Void = {}

    var body: some View {
        VStack(spacing: 8) {
            toolbar
            timeline
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 12) {
            ToolbarButton(systemImage: "plus.rectangle", label: "Clip", action: onAddClip)
            ToolbarButton(systemImage: "textformat", label: "Overlay", action: onAddOverlay)
            ToolbarButton(systemImage: "music.note", label: "Music", action: onAddMusic)
            ToolbarButton(systemImage: "speaker.wave.2", label: "SFX", action: onAddSFX)
            ToolbarButton(systemImage: "captions.bubble", label: "Captions", action: onAddCaptions)
            Spacer()
            ToolbarButton(systemImage: "square.and.arrow.up", label: "Export", action: onExport)
        }
        .padding(.horizontal)
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
                set: { store.selectedClipID = $0 }
            ),
            laneHeight: 56,
            showAudioWaveforms: true,
            showLaneLabels: true,
            onReorder: { _, _, newClips in
                store.replaceClips(newClips)
            }
        )
        .frame(height: 96)
        .padding(.horizontal)
    }
}

private struct ToolbarButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(minWidth: 56, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }
}
