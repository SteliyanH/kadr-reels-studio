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
@available(iOS 16, macOS 13, visionOS 1, *)
struct OverlayKeyframeArea: View {

    @ObservedObject var store: ProjectStore

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
        .padding(.horizontal)
    }
}
