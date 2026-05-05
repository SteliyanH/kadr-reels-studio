import SwiftUI
import Kadr
import KadrUI

/// Inspector panel for the currently-selected overlay. Sibling to
/// ``InspectorArea`` — surfaces `KadrUI.OverlayInspectorPanel`'s common
/// (Position / Anchor / Opacity) + type-specific (Text + animation,
/// Sticker rotation) controls. Mutations route through ``ProjectStore``'s
/// overlay-mutation surface.
@available(iOS 16, macOS 13, visionOS 1, *)
struct OverlayInspectorArea: View {

    @ObservedObject var store: ProjectStore

    var body: some View {
        OverlayInspectorPanel(
            store.video,
            selectedOverlayID: Binding(
                get: { store.selectedOverlayID },
                set: { store.selectedOverlayID = $0 }
            ),
            onPosition: { id, position in
                store.applyOverlayPosition(id: id, position)
            },
            onSize: { id, size in
                store.applyOverlaySize(id: id, size)
            },
            onAnchor: { id, anchor in
                store.applyOverlayAnchor(id: id, anchor)
            },
            onOpacity: { id, opacity in
                store.applyOverlayOpacity(id: id, opacity)
            },
            onText: { id, text in
                store.applyOverlayText(id: id, text)
            },
            onTextAnimation: { id, kind in
                store.applyOverlayTextAnimation(id: id, kind)
            },
            onRotation: { id, radians in
                store.applyOverlayRotation(id: id, radians)
            }
        )
        .frame(maxHeight: 320)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
