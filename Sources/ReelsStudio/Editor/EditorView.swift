import SwiftUI
import Combine

/// Root editor screen. Composes ``PreviewArea`` (top) + ``TimelineArea`` (bottom)
/// against a ``ProjectStore``.
///
/// v0.2 Tier 2 — the editor is now per-project: it's constructed with a
/// ``ProjectDocument`` (loaded from ``ProjectLibrary``) and writes every
/// edit back through the library on a debounced auto-save. There is no
/// Save button anywhere; closing the editor is enough.
struct EditorView: View {

    @StateObject private var store: ProjectStore
    @ObservedObject private var library: ProjectLibrary

    /// The document this editor is bound to. Mutated in-place as auto-save
    /// runs so `modifiedAt` / clip counts stay current for the project list.
    @State private var document: ProjectDocument

    @State private var saveError: String?

    @State private var showPhotoPicker = false
    @State private var showOverlaySheet = false
    @State private var showMusicSheet = false
    @State private var showSFXSheet = false
    @State private var showCaptionsSheet = false
    @State private var showExportSheet = false

    /// Debounce window for auto-save. Half a second swallows rapid edits
    /// (slider drags, inspector typing) while still feeling near-instant.
    private static let autoSaveDebounce: TimeInterval = 0.5

    init(document: ProjectDocument, library: ProjectLibrary) {
        self._document = State(initialValue: document)
        self._library = ObservedObject(initialValue: library)
        self._store = StateObject(
            wrappedValue: ProjectStore(project: document.toRuntimeProject())
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            PreviewArea(store: store)
                .padding(.horizontal)
            Spacer(minLength: 8)
            TimelineArea(
                store: store,
                onAddClip: { showPhotoPicker = true },
                onAddOverlay: { showOverlaySheet = true },
                onAddMusic: { showMusicSheet = true },
                onAddSFX: { showSFXSheet = true },
                onAddCaptions: { showCaptionsSheet = true },
                onExport: { showExportSheet = true }
            )
            if store.selectedClipID != nil {
                KeyframeArea(store: store)
                InspectorArea(store: store)
                    .padding(.horizontal)
            }
            Spacer(minLength: 16)
        }
        .padding(.top)
        .background(Color(.systemGray6).ignoresSafeArea())
        .addClipFlow(isPresented: $showPhotoPicker, store: store)
        .sheet(isPresented: $showOverlaySheet) {
            AddOverlaySheet(store: store)
        }
        .sheet(isPresented: $showMusicSheet) {
            AddMusicSheet(store: store)
        }
        .sheet(isPresented: $showSFXSheet) {
            AddSFXSheet(store: store)
        }
        .sheet(isPresented: $showCaptionsSheet) {
            AddCaptionsSheet(store: store)
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(store: store)
        }
        .navigationTitle(document.name)
        .navigationBarTitleDisplayModeInline()
        .onReceive(
            store.$project
                .dropFirst()
                .debounce(
                    for: .seconds(Self.autoSaveDebounce),
                    scheduler: DispatchQueue.main
                )
        ) { _ in
            autoSave()
        }
        .alert(
            "Couldn't save",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            ),
            presenting: saveError
        ) { _ in
            Button("OK", role: .cancel) { saveError = nil }
        } message: { message in
            Text(message)
        }
    }

    /// Push the current in-memory project back through the library, preserving
    /// the document's id / createdAt / name. Failures surface inline; the
    /// in-memory edit is *not* rolled back — the next debounced cycle retries.
    private func autoSave() {
        let updated = store.project.toDocument(inheriting: document)
        do {
            try library.save(updated)
            document = updated
        } catch {
            saveError = error.localizedDescription
        }
    }
}

/// `.navigationBarTitleDisplayMode(.inline)` is iOS-only; this shim keeps the
/// editor source compilable on macOS / Catalyst targets where the modifier
/// isn't available.
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
