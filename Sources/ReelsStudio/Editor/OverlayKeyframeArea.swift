import SwiftUI
import Kadr
import KadrUI

/// Per-property keyframe tracks for the currently-selected overlay.
/// Sibling to ``KeyframeArea``; routes through ``ProjectStore``'s
/// overlay-keyframe mutation surface.
///
/// Property availability per overlay kind (per `KadrUI.OverlayKeyframeEditor`):
/// - `ImageOverlay` / `StickerOverlay` — `.position`, `.size`
/// - `TextOverlay` — none (uses enum-driven `TextAnimation` instead;
///   the editor renders zero rows for text overlays)
///
/// v0.8 Tier 5b — same band treatment as ``KeyframeArea``: the app owns the
/// studio `surface` ground and the design's row proportions; the row's label,
/// track, playhead and marks are drawn inside `OverlayKeyframeEditor` and are
/// reported as gaps.
struct OverlayKeyframeArea: View {

    var store: ProjectStore
    @Environment(\.reelPalette) private var palette

    var body: some View {
        OverlayKeyframeEditor(
            store.video,
            selectedOverlayID: Binding(
                get: { store.selectedOverlayID },
                set: { store.selectedOverlayID = $0 }
            ),
            currentTime: Binding(
                get: { store.currentTime },
                set: { store.currentTime = $0 }
            ),
            rowHeight: Reel.Space.s6,
            rowSpacing: Reel.Space.s1,
            onAdd: { id, property, time in
                store.addOverlayKeyframe(layerID: id, property: property, time: time)
            },
            onRemove: { id, property, time in
                store.removeOverlayKeyframe(layerID: id, property: property, time: time)
            },
            onRetime: { id, property, from, to in
                store.retimeOverlayKeyframe(layerID: id, property: property, from: from, to: to)
            }
        )
        .padding(.horizontal, Reel.Space.s4)
        .padding(.vertical, Reel.Space.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Overlay keyframe editor")
        .accessibilityHint("Tap below a property to add a keyframe at the playhead. Long-press a marker to remove. Drag to retime.")
    }
}
