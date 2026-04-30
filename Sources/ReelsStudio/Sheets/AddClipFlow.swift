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
@available(iOS 16, macOS 13, visionOS 1, *)
struct AddClipFlow: ViewModifier {

    @Binding var isPresented: Bool
    @ObservedObject var store: ProjectStore
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
            .onChange(of: pickedItems) { newItems in
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
            // v0.1: log only. Consumers running the app see the failure in console;
            // a v0.1.x patch wires this through an alert / toast.
            print("AddClipFlow: failed to resolve clips — \(error)")
        }
    }
}

@available(iOS 16, macOS 13, visionOS 1, *)
extension View {
    /// Convenience: attach the ``AddClipFlow`` modifier.
    func addClipFlow(isPresented: Binding<Bool>, store: ProjectStore) -> some View {
        modifier(AddClipFlow(isPresented: isPresented, store: store))
    }
}

/// Loading overlay shown while `clips(from:)` is in flight. Dimmed background +
/// progress indicator + label.
@available(iOS 16, macOS 13, visionOS 1, *)
private struct ResolvingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("Importing clips…")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#endif
