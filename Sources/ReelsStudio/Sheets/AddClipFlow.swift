import SwiftUI
import Kadr
import KadrPhotos
#if canImport(Photos)
import Photos
#endif

#if canImport(PhotosUI)

/// View modifier that presents `PhotoPicker` when `isPresented` is true and resolves
/// the picked PHAssets into kadr `Clip` values, appending them to the store. Used by
/// `EditorView` for the `+ Clip` toolbar action.
///
/// Picker selection fires via `pickedItems` binding; an `onChange` watcher kicks off
/// `PhotosClipResolver.clips(from:)` and appends the resolved clips to the project.
/// Resolution failures surface as a console log in v0.1; a v0.1.x patch can wire an
/// alert.
struct AddClipFlow: ViewModifier {

    @Binding var isPresented: Bool
    var store: ProjectStore
    @Environment(ToastCenter.self) private var toasts
    @State private var pickedItems: [PhotoPickerResult] = []
    @State private var isResolving = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                PhotoPicker(
                    selection: $pickedItems,
                    configuration: .init(selectionLimit: 0, filter: .any)
                )
                .ignoresSafeArea()
            }
            .onChange(of: pickedItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                let items = newItems
                Task { await resolveAndAppend(items) }
            }
            .overlay {
                if isResolving {
                    ResolvingOverlay()
                }
            }
    }

    @MainActor
    private func resolveAndAppend(_ items: [PhotoPickerResult]) async {
        isResolving = true
        defer {
            isResolving = false
            pickedItems = []
        }
        do {
            let clips = try await PhotosClipResolver.clips(from: items)
            store.append(clips: clips)
        } catch {
            toasts.show(.transient(
                error,
                prefix: "Couldn't import \(items.count == 1 ? "clip" : "clips")"
            ))
        }
    }
}

extension View {
    /// Convenience: attach the ``AddClipFlow`` modifier.
    func addClipFlow(isPresented: Binding<Bool>, store: ProjectStore) -> some View {
        modifier(AddClipFlow(isPresented: isPresented, store: store))
    }
}

/// Loading overlay shown while `clips(from:)` is in flight. Dimmed background +
/// progress indicator + label.
private struct ResolvingOverlay: View {
    @Environment(\.modernistPalette) private var palette

    var body: some View {
        ZStack {
            // v0.8 Tier 2 — the modal scrim is the approved design's 55%
            // black over the live editor, not an ad-hoc 40%.
            Modernist.stageInk.opacity(Modernist.scrimOpacity).ignoresSafeArea()
            VStack(spacing: Modernist.Space.s3) {
                ProgressView()
                    .controlSize(.large)
                Text("Importing clips…")
                    .font(Modernist.Typography.body)
                    .foregroundStyle(palette.text)
            }
            .padding(Modernist.Space.s6)
            // Nothing floats: the card is a flat surface block, square.
            .background(palette.surface)
        }
    }
}

#endif
