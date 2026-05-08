import SwiftUI
import Combine
import Kadr

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
    @EnvironmentObject private var toasts: ToastCenter

    /// The document this editor is bound to. Mutated in-place as auto-save
    /// runs so `modifiedAt` / clip counts stay current for the project list.
    @State private var document: ProjectDocument

    @State private var showPhotoPicker = false
    @State private var showOverlaySheet = false
    @State private var showLayersSheet = false
    @State private var showMusicSheet = false
    @State private var showSFXSheet = false
    @State private var showCaptionsSheet = false
    @State private var showExportSheet = false
    @State private var speedCurveClipID: ClipID?
    @State private var filtersClipID: ClipID?

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
                onLayers: { showLayersSheet = true },
                onAddMusic: { showMusicSheet = true },
                onAddSFX: { showSFXSheet = true },
                onAddCaptions: { showCaptionsSheet = true },
                onExport: { showExportSheet = true },
                onSpeedCurve: { speedCurveClipID = $0 },
                onFilters: { filtersClipID = $0 }
            )
            // Inspector / keyframe pair — routes to clip- or overlay-targeted
            // surfaces based on which selection slot is active. Mutual
            // exclusion is enforced by ProjectStore's didSet observers.
            // v0.4 Tier 4: reveal / dismiss with the editor-wide spring detent.
            Group {
                if store.selectedOverlayID != nil {
                    VStack(spacing: 16) {
                        OverlayKeyframeArea(store: store)
                        OverlayInspectorArea(store: store)
                            .padding(.horizontal)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if store.selectedClipID != nil {
                    VStack(spacing: 16) {
                        KeyframeArea(store: store)
                        InspectorArea(store: store)
                            .padding(.horizontal)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(
                .interactiveSpring(response: 0.35, dampingFraction: 0.78),
                value: EditorView.inspectorPresentationKey(
                    clip: store.selectedClipID,
                    overlay: store.selectedOverlayID
                )
            )
            Spacer(minLength: 16)
        }
        .padding(.top)
        .background(Color(.systemGray6).ignoresSafeArea())
        // v0.4 Tier 3: per-project accent threads through every `.tint`-aware
        // surface (inspector tabs, keyframe playhead, timeline selection
        // ring). nil = follow the system tint, which is the v0.4 default.
        .tint(store.project.accentColor ?? .accentColor)
        .addClipFlow(isPresented: $showPhotoPicker, store: store)
        .sheet(isPresented: $showOverlaySheet) {
            AddOverlaySheet(store: store)
        }
        .sheet(isPresented: $showLayersSheet) {
            LayersSheet(store: store)
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
        .sheet(
            isPresented: Binding(
                get: { speedCurveClipID != nil },
                set: { if !$0 { speedCurveClipID = nil } }
            )
        ) {
            if let id = speedCurveClipID {
                SpeedCurveSheet(store: store, clipID: id)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { filtersClipID != nil },
                set: { if !$0 { filtersClipID = nil } }
            )
        ) {
            if let id = filtersClipID {
                FiltersSheet(store: store, clipID: id)
            }
        }
        .navigationTitle(document.name)
        .navigationBarTitleDisplayModeInline()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    store.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .accessibilityLabel("Undo")
                }
                .disabled(!store.canUndo)
                Button {
                    store.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .accessibilityLabel("Redo")
                }
                .disabled(!store.canRedo)
            }
        }
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
    }

    /// Identity for the inspector-reveal animation. We can't use
    /// `selectedClipID` or `selectedOverlayID` directly as the `.animation`
    /// value because their types don't unify; collapse to a string the
    /// `.animation(value:)` modifier can compare. Pure for testability.
    static func inspectorPresentationKey(clip: ClipID?, overlay: LayerID?) -> String {
        if let overlay { return "overlay:\(overlay.rawValue)" }
        if let clip { return "clip:\(clip.rawValue)" }
        return "none"
    }

    /// Push the current in-memory project back through the library, preserving
    /// the document's id / createdAt / name. Failures surface as a transient
    /// toast; the in-memory edit is *not* rolled back — the next debounced
    /// cycle retries automatically.
    private func autoSave() {
        let updated = store.project.toDocument(inheriting: document)
        do {
            try library.save(updated)
            document = updated
        } catch {
            toasts.show(.transient(error, prefix: "Couldn't save"))
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
