import SwiftUI
import Kadr
import KadrUI

/// Per-property keyframe tracks below the timeline. Wraps `KadrUI.KeyframeEditor`.
///
/// **v0.2 — read-only.** The editor renders any keyframes already present on
/// a clip (driven by kadr's `Animation<T>` storage). The add / remove /
/// retime callbacks are intentionally `nil` — `KeyframeEditor` falls back to
/// non-interactive markers in that mode. Full authoring requires building
/// `Animation<T>` mutation helpers + a comprehensive clip-rebuild path; that
/// lands in **v0.3 alongside `SpeedCurveEditor` / `OverlayKeyframeEditor`**.
@available(iOS 16, macOS 13, visionOS 1, *)
struct KeyframeArea: View {

    @ObservedObject var store: ProjectStore

    var body: some View {
        KeyframeEditor(
            store.video,
            selectedClipID: Binding(
                get: { store.selectedClipID },
                set: { store.selectedClipID = $0 }
            ),
            currentTime: Binding(
                get: { store.currentTime },
                set: { store.currentTime = $0 }
            )
            // onAdd / onRemove / onRetime intentionally omitted — see header.
        )
        .padding(.horizontal)
    }
}
