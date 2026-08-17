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
struct SpeedCurveSheet: View {

    var store: ProjectStore
    let clipID: ClipID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.reelPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            ReelSheetHeader("Speed Curve") {
                Button("Done") { dismiss() }
                    .buttonStyle(ReelGhostButtonStyle())
            }
            content
        }
        // The design gives no fixed height for this one; the log-scaled
        // multiplier axis needs every point it can get, so it takes the
        // full-height stop.
        .reelSheet(detents: [.large])
    }

    @ViewBuilder
    private var content: some View {
        if let clip = videoClip(matching: clipID) {
            VStack(alignment: .leading, spacing: Reel.Space.s3) {
                Text(headerText(for: clip))
                    .font(Reel.Typography.body)
                    .foregroundStyle(palette.textMuted)
                SpeedCurveEditor(
                    clip: clip,
                    currentTime: Binding(
                        get: { store.currentTime },
                        set: { store.currentTime = $0 }
                    ),
                    height: Reel.speedCurveEditorHeight,
                    onUpdate: { newCurve in
                        store.applySpeedCurve(id: clipID, newCurve)
                    }
                )
                Spacer()
            }
            .padding(Reel.Space.s4)
        } else {
            VStack(spacing: Reel.Space.s3) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: Reel.Typography.Glyph.lg, weight: Reel.Typography.headingWeight))
                    .foregroundStyle(palette.textMuted)
                Text("Clip not available")
                    .font(Reel.Typography.h5)
                Text("This clip is no longer in the project. Close this sheet and reselect.")
                    .font(Reel.Typography.body)
                    .foregroundStyle(palette.textMuted)
                    .frame(maxWidth: Reel.emptyStateMeasure)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(Reel.Space.s4)
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

// v0.8 Tier 5a — the navigation-bar shim went with the `NavigationStack` this
// sheet no longer wraps itself in; `ReelSheetHeader` draws the title.
