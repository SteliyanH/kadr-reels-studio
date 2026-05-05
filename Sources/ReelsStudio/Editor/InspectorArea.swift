import SwiftUI
import Kadr
import KadrUI

/// Inspector panel — slides in when a clip is selected on the timeline.
/// Wraps `KadrUI.InspectorPanel` for clip-property sliders, plus a "Speed
/// curve…" affordance that pushes ``SpeedCurveSheet`` for `VideoClip`
/// selections (the editor's log-scaled multiplier axis needs room a row
/// can't give).
@available(iOS 16, macOS 13, visionOS 1, *)
struct InspectorArea: View {

    @ObservedObject var store: ProjectStore
    @State private var showSpeedCurveSheet = false

    var body: some View {
        VStack(spacing: 8) {
            InspectorPanel(
                store.video,
                selectedClipID: Binding(
                    get: { store.selectedClipID },
                    set: { store.selectedClipID = $0 }
                ),
                onTransform: { id, transform in
                    store.applyTransform(id: id, transform)
                },
                onOpacity: { id, opacity in
                    store.applyOpacity(id: id, opacity)
                },
                onFilterIntensity: { id, index, value in
                    store.applyFilterIntensity(id: id, filterIndex: index, value: value)
                }
            )
            if isSelectedAVideoClip {
                speedCurveRow
            }
        }
        .frame(maxHeight: 320)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showSpeedCurveSheet) {
            if let id = store.selectedClipID {
                SpeedCurveSheet(store: store, clipID: id)
            }
        }
    }

    private var isSelectedAVideoClip: Bool {
        guard let id = store.selectedClipID else { return false }
        return store.project.clips.contains { $0.clipID == id && $0 is VideoClip }
    }

    @ViewBuilder
    private var speedCurveRow: some View {
        Button { showSpeedCurveSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "speedometer")
                Text("Speed curve…")
                Spacer()
                if hasSpeedCurve {
                    Text("Custom")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var hasSpeedCurve: Bool {
        guard let id = store.selectedClipID else { return false }
        return store.project.clips
            .compactMap { $0 as? VideoClip }
            .first { $0.clipID == id }?
            .speedCurve != nil
    }
}
