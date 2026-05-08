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
@available(iOS 16, macOS 13, visionOS 1, *)
struct LayersSheet: View {

    @ObservedObject var store: ProjectStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Layers")
                .navigationBarTitleDisplayModeInline()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.project.overlays.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("No overlays yet")
                    .font(.headline)
                Text("Tap **+ Overlay** in the toolbar to add text or stickers.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
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
            .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private func row(for overlay: any Overlay, index: Int) -> some View {
        let (icon, kind) = LayersSheet.iconAndKind(for: overlay)
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.tint.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(.tint)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(LayersSheet.title(for: overlay, index: index))
                    .font(.body.bold())
                Text(kind)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let id = overlay.layerID, store.selectedOverlayID == id {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
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

@available(iOS 16, macOS 13, visionOS 1, *)
private extension View {
    @ViewBuilder
    func navigationBarTitleDisplayModeInline() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
