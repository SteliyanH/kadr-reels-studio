import SwiftUI
import Kadr
import KadrUI

/// Per-property keyframe tracks below the timeline. Wraps `KadrUI.KeyframeEditor`.
///
/// v0.1 surfaces the read-only view of any keyframes already present on a clip
/// (driven by kadr's `Animation<T>` storage). The add/remove/retime callbacks log
/// to console — full keyframe authoring requires building `Animation<T>` mutation
/// helpers and a comprehensive clip-rebuild path that's out of scope for v0.1.
/// A v0.1.x patch wires the writes.
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
            ),
            onAdd: { id, property, time in
                print("KeyframeArea: onAdd \(id) \(property) at \(time) — wiring lands in v0.1.x")
            },
            onRemove: { id, property, time in
                print("KeyframeArea: onRemove \(id) \(property) at \(time) — wiring lands in v0.1.x")
            },
            onRetime: { id, property, from, to in
                print("KeyframeArea: onRetime \(id) \(property) \(from) -> \(to) — wiring lands in v0.1.x")
            }
        )
        .padding(.horizontal)
    }
}
