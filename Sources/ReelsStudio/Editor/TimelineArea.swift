import SwiftUI
import Kadr
import KadrUI

/// Bottom half of the editor — `TimelineView` with the editor's standard toolbar
/// row above it (+ Clip / + Overlay / + Music / Export buttons; their sheets
/// arrive in Tiers 2 / 3 / 6).
struct TimelineArea: View {

    @ObservedObject var store: ProjectStore

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
            ToolbarButton(systemImage: "plus.rectangle", label: "Clip") {
                // Tier 2 — PhotoPicker sheet. Stub for now.
            }
            ToolbarButton(systemImage: "textformat", label: "Overlay") {
                // Tier 3 — Add Overlay sheet.
            }
            ToolbarButton(systemImage: "music.note", label: "Music") {
                // Tier 3 — Add Music sheet.
            }
            Spacer()
            ToolbarButton(systemImage: "square.and.arrow.up", label: "Export") {
                // Tier 6 — Export sheet.
            }
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
