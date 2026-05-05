import SwiftUI
import Kadr
import KadrUI

/// Full-screen sheet wrapping `KadrUI.SpeedCurveEditor`. Pushed from the
/// inspector's "Speed curve…" row when a `VideoClip` is selected. The
/// log-scaled multiplier axis (0.25× ... 4×) needs vertical room — inline
/// in the inspector would feel cramped, hence the sheet.
///
/// Edits route through ``ProjectStore/applySpeedCurve(id:_:)`` so undo /
/// redo + auto-save Just Work.
@available(iOS 16, macOS 13, visionOS 1, *)
struct SpeedCurveSheet: View {

    @ObservedObject var store: ProjectStore
    let clipID: ClipID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Speed Curve")
                .navigationBarTitleDisplayModeInline()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let clip = videoClip(matching: clipID) {
            VStack(alignment: .leading, spacing: 12) {
                Text(headerText(for: clip))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                SpeedCurveEditor(
                    clip: clip,
                    currentTime: Binding(
                        get: { store.currentTime },
                        set: { store.currentTime = $0 }
                    ),
                    height: 240,
                    onUpdate: { newCurve in
                        store.applySpeedCurve(id: clipID, newCurve)
                    }
                )
                .padding(.horizontal)
                Spacer()
            }
            .padding(.top)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Clip not available")
                    .font(.headline)
                Text("This clip is no longer in the project. Close this sheet and reselect.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func videoClip(matching id: ClipID) -> VideoClip? {
        store.project.clips.compactMap { $0 as? VideoClip }.first { $0.clipID == id }
    }

    private func headerText(for clip: VideoClip) -> String {
        if clip.speedCurve != nil {
            return "Drag points vertically to change the speed multiplier; horizontally to retime. Long-press to remove."
        }
        return "Tap inside the editor to add a keyframe at the playhead. Default speed is 1×."
    }
}

@available(iOS 16, macOS 13, visionOS 1, *)
private extension View {
    @ViewBuilder
    func navigationBarTitleDisplayModeInline() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
