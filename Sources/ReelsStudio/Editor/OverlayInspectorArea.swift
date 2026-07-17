import SwiftUI
import Kadr
import KadrUI

/// Inspector panel for the currently-selected overlay. Sibling to
/// ``InspectorArea`` — surfaces `KadrUI.OverlayInspectorPanel`'s common
/// (Position / Anchor / Opacity) + type-specific (Text + animation,
/// Sticker rotation) controls. Mutations route through ``ProjectStore``'s
/// overlay-mutation surface.
struct OverlayInspectorArea: View {

    var store: ProjectStore

    var body: some View {
        VStack(spacing: 8) {
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
            // v0.7 Tier 3 — stroke + shadow controls for `TextOverlay`. The
            // upstream `OverlayInspectorPanel` doesn't carry these yet
            // (would need a kadr-ui v0.10.3 patch), so we attach them
            // locally instead. Auto-hides for non-text overlays.
            TextEffectsSection(store: store)
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Overlay inspector")
    }
}
