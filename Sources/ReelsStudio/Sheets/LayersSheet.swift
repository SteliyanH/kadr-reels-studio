import SwiftUI
import Kadr

/// Lists every overlay in the project with tap-to-select. Pushed from the
/// editor's "Layers" toolbar button. v0.4 will replace this with
/// tap-to-select directly on `KadrUI/OverlayHost`; for v0.3 the sheet is
/// the only selection affordance.
///
/// Tapping a row sets ``ProjectStore/selectedOverlayID`` and dismisses —
/// the editor's body picks up the new selection and swaps its inspector /
/// keyframe surface to the overlay-targeted variants.
///
/// v0.8 Tier 5a rebuilds the chrome to the approved design (Screens §8):
/// grabber, `h3` title, rows on `surfaceRaised` with a 40pt accent-tinted
/// icon tile, and a `caption` footer hint. Selection, deletion and dismissal
/// behave exactly as they did.
struct LayersSheet: View {

    var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modernistPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            ModernistSheetHeader("Layers") {
                Button("Done") { dismiss() }
                    .buttonStyle(ModernistGhostButtonStyle())
            }
            content
        }
        .modernistSheet(Modernist.SheetDetent.layers)
    }

    @ViewBuilder
    private var content: some View {
        if store.project.overlays.isEmpty {
            VStack(spacing: Modernist.Space.s3) {
                Image(systemName: "square.stack.3d.up.slash")
                    .font(.system(size: Modernist.Typography.Glyph.lg, weight: Modernist.Typography.headingWeight))
                    .foregroundStyle(palette.textMuted)
                Text("No overlays yet")
                    .font(Modernist.Typography.h5)
                Text("Tap **+ Overlay** in the toolbar to add text or stickers.")
                    .font(Modernist.Typography.body)
                    .foregroundStyle(palette.textMuted)
                    .frame(maxWidth: Modernist.emptyStateMeasure)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(Modernist.Space.s4)
        } else {
            VStack(spacing: 0) {
                layerList
                Text("Swipe a row to delete · use Forward / Back to restack")
                    .font(Modernist.Typography.caption)
                    .foregroundStyle(palette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Modernist.Space.s4)
                    .padding(.vertical, Modernist.Space.s3)
            }
        }
    }

    /// Still a `List`: swipe-to-delete is a `List` primitive, and the
    /// design's row block is reached by stripping the list's own chrome
    /// rather than by dropping the container that carries the gesture.
    @ViewBuilder
    private var layerList: some View {
        List {
            ForEach(Array(store.project.overlays.enumerated()), id: \.offset) { index, overlay in
                Button {
                    if let id = overlay.layerID {
                        store.selectedOverlayID = id
                    }
                    dismiss()
                } label: {
                    row(for: overlay, index: index)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onDelete { offsets in
                HapticEngine.shared.thud()
                // Walk highest → lowest so earlier deletes don't shift
                // pending indices. Same pattern as `FiltersSheet`.
                for index in offsets.sorted(by: >) {
                    if let id = store.project.overlays[index].layerID {
                        store.removeOverlay(id: id)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, Modernist.minHitTarget)
    }

    @ViewBuilder
    private func row(for overlay: any Overlay, index: Int) -> some View {
        let (icon, kind) = LayersSheet.iconAndKind(for: overlay)
        let isSelected = overlay.layerID != nil && store.selectedOverlayID == overlay.layerID
        HStack(spacing: Modernist.Space.s3) {
            // The icon tile is an accent-tinted block with an accent glyph;
            // `.tint` at an arbitrary opacity is replaced by the named role.
            Rectangle()
                .fill(palette.accentTint)
                .frame(width: Modernist.layerIconTileSize, height: Modernist.layerIconTileSize)
                .overlay(
                    Image(systemName: icon)
                        .font(Modernist.Typography.h4)
                        .foregroundStyle(palette.accent)
                )
            VStack(alignment: .leading, spacing: Modernist.Space.s1) {
                Text(LayersSheet.title(for: overlay, index: index))
                    .font(Modernist.Typography.bodyEmphasis)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(kind)
                    .font(Modernist.Typography.caption)
                    .foregroundStyle(palette.textMuted)
            }
            Spacer(minLength: Modernist.Space.s2)
            // Decision 4 — selection checkmarks go accent.
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(palette.accent)
            }
            Image(systemName: "chevron.right")
                .font(Modernist.Typography.caption)
                .foregroundStyle(palette.textMuted)
        }
        .padding(.horizontal, Modernist.Space.s4)
        .padding(.vertical, Modernist.Space.s2)
        .frame(minHeight: Modernist.minHitTarget)
        .background(isSelected ? palette.accentTint : palette.surfaceRaised)
        .overlay(
            RoundedRectangle(cornerRadius: Modernist.Radius.sm)
                .strokeBorder(
                    isSelected ? palette.accent : Color.clear,
                    lineWidth: Modernist.ruleWidth
                )
        )
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    nonisolated static func iconAndKind(for overlay: any Overlay) -> (String, String) {
        if overlay is TextOverlay { return ("textformat", "Text") }
        if overlay is StickerOverlay { return ("face.smiling", "Sticker") }
        if overlay is ImageOverlay { return ("photo", "Image") }
        return ("square", "Overlay")
    }

    nonisolated static func title(for overlay: any Overlay, index: Int) -> String {
        if let text = overlay as? TextOverlay {
            let preview = text.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return preview.isEmpty ? "Text \(index + 1)" : preview
        }
        if let id = overlay.layerID {
            return id.rawValue
        }
        if overlay is StickerOverlay { return "Sticker \(index + 1)" }
        if overlay is ImageOverlay { return "Image \(index + 1)" }
        return "Overlay \(index + 1)"
    }
}
