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
///
/// v0.8 Tier 5b — the band around the editor is the app's to style: the studio
/// `surface` ground and the design's row proportions (24pt rows, 4pt apart).
/// The row's own contents are not: `KeyframeEditor` draws the property label,
/// the track, its centre line, the playhead and the keyframe marks itself,
/// every one a private literal. Those are reported as gaps — in particular the
/// marks are white circles upstream, where the design calls for rotated accent
/// squares, and the 54pt caption label column is drawn inside the component,
/// so an app-side label column would duplicate it rather than restyle it.
struct KeyframeArea: View {

    var store: ProjectStore
    @Environment(\.reelPalette) private var palette

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
            rowHeight: Reel.Space.s6,
            rowSpacing: Reel.Space.s1,
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
        .padding(.horizontal, Reel.Space.s4)
        .padding(.vertical, Reel.Space.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Keyframe editor")
        .accessibilityHint("Tap below a property to add a keyframe at the playhead. Long-press a marker to remove. Drag to retime.")
    }
}
