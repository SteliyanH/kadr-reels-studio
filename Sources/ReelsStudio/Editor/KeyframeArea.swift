import SwiftUI
import Kadr
import KadrUI

/// Per-property keyframe tracks below the timeline. Wraps `KadrUI.KeyframeEditor`.
///
/// **v0.3 — full authoring.** `onAdd` / `onRemove` / `onRetime` route through
/// ``ProjectStore``'s keyframe mutation surface, which builds `Animation<T>`
/// values and rebuilds the affected clip via the immutable kadr modifier
/// chain. Every operation runs through ``ProjectStore/applyMutation(actionName:)``
/// so undo / redo and auto-save Just Work.
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
                store.addKeyframe(clipID: id, property: property, time: time)
            },
            onRemove: { id, property, time in
                store.removeKeyframe(clipID: id, property: property, time: time)
            },
            onRetime: { id, property, from, to in
                store.retimeKeyframe(clipID: id, property: property, from: from, to: to)
            }
        )
        .padding(.horizontal)
    }
}
