import SwiftUI
import Kadr
import KadrUI

/// Inspector panel for the currently-selected overlay. Sibling to
/// ``InspectorArea`` — surfaces `KadrUI.OverlayInspectorPanel`'s common
/// (Position / Anchor / Opacity) + type-specific (Text + animation,
/// Sticker rotation) controls. Mutations route through ``ProjectStore``'s
/// overlay-mutation surface.
///
/// v0.8 Tier 5b — the band is the design's `surfaceRaised` block, matching
/// ``InspectorArea``. `OverlayInspectorPanel`'s own rows are upstream
/// literals and reported as gaps; the rows this repo draws
/// (``TextEffectsSection``) take the design's slider treatment.
struct OverlayInspectorArea: View {

    var store: ProjectStore
    @Environment(\.modernistPalette) private var palette

    var body: some View {
        VStack(spacing: Modernist.Space.s2) {
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
            .frame(maxHeight: Modernist.inspectorMaxHeight)
            // v0.7 Tier 3 — stroke + shadow controls for `TextOverlay`. The
            // upstream `OverlayInspectorPanel` doesn't carry these yet
            // (would need a kadr-ui v0.10.3 patch), so we attach them
            // locally instead. Auto-hides for non-text overlays.
            TextEffectsSection(store: store)
        }
        // v0.8 Tier 2 — flat raised surface; see `InspectorArea`.
        .background(palette.surfaceRaised)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Overlay inspector")
    }
}
