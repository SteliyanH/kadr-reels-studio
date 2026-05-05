import SwiftUI
import UniformTypeIdentifiers
import CoreMedia
import Kadr
import KadrUI
import KadrCaptions

/// Two-tab caption sheet — **Edit** for live cue authoring (wraps
/// `KadrUI.CaptionEditor`); **Import** for ingesting a `.srt` / `.vtt` /
/// `.itt` / `.ass` / `.ssa` file. Defaults to Edit when there are existing
/// cues, Import when empty.
///
/// Edit-side mutations route through ``ProjectStore/setCaptions(_:)`` —
/// `CaptionEditor` always emits the full sorted-by-start array on every
/// commit, so a single replace call covers add / remove / retime / text
/// changes uniformly. Undo / redo + auto-save inherit.
@available(iOS 16, macOS 13, visionOS 1, *)
struct AddCaptionsSheet: View {

    @ObservedObject var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toasts: ToastCenter

    @State private var selectedTab: Tab

    init(store: ProjectStore) {
        self.store = store
        // Default to Edit when there are existing cues; Import otherwise.
        // CapCut / VN match this — surface the most-likely action first.
        self._selectedTab = State(
            initialValue: store.project.captions.isEmpty ? .import : .edit
        )
    }

    enum Tab: Hashable { case edit, `import` }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $selectedTab) {
                    Text("Edit").tag(Tab.edit)
                    Text("Import").tag(Tab.import)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                Divider()
                    .padding(.top, 8)

                Group {
                    switch selectedTab {
                    case .edit:    editTab
                    case .import:  importTab
                    }
                }
            }
            .navigationTitle("Captions")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Edit tab

    @ViewBuilder
    private var editTab: some View {
        ScrollView {
            CaptionEditor(
                captions: store.project.captions,
                compositionDuration: store.video.duration,
                currentTime: Binding(
                    get: { store.currentTime },
                    set: { store.currentTime = $0 }
                ),
                onUpdate: { newCaptions in
                    store.setCaptions(newCaptions)
                }
            )
            .padding(.horizontal)
            .padding(.top, 12)
        }
    }

    // MARK: - Import tab

    @State private var pickedURL: URL?
    @State private var showImporter = false
    @State private var lastImportedCount: Int = 0
    @State private var isLoading = false

    private var captionContentTypes: [UTType] {
        let candidates = [
            UTType(filenameExtension: "srt"),
            UTType(filenameExtension: "vtt"),
            UTType(filenameExtension: "itt"),
            UTType(filenameExtension: "ass"),
            UTType(filenameExtension: "ssa"),
        ]
        let resolved = candidates.compactMap { $0 }
        return resolved.isEmpty ? [.plainText] : resolved
    }

    @ViewBuilder
    private var importTab: some View {
        Form {
            Section("Caption file") {
                Button {
                    showImporter = true
                } label: {
                    HStack {
                        Image(systemName: "captions.bubble")
                        Text(pickedURL?.lastPathComponent ?? "Pick caption file")
                    }
                }
                if let pickedURL {
                    Text(pickedURL.pathExtension.uppercased())
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            if lastImportedCount > 0 {
                Section("Imported") {
                    Label(
                        "\(lastImportedCount) cue\(lastImportedCount == 1 ? "" : "s") appended",
                        systemImage: "checkmark.circle"
                    )
                    .foregroundStyle(.green)
                    Button("Switch to Edit") {
                        selectedTab = .edit
                    }
                    .font(.callout)
                }
            }
            Section {
                Text("Supported formats: SRT, VTT, iTT, ASS, SSA. Cues append to the project's caption list — switch to Edit to retime / rename / delete.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: captionContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    pickedURL = url
                    Task { await loadCaptions(from: url) }
                }
            case .failure(let error):
                toasts.show(.transient(error, prefix: "Couldn't open file"))
            }
        }
        .overlay {
            if isLoading { ProgressView().controlSize(.large) }
        }
    }

    @MainActor
    private func loadCaptions(from url: URL) async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Sandboxed file picks need security-scoped resource access.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let cues = try await Caption.load(url)
            store.append(captions: cues)
            lastImportedCount = cues.count
        } catch {
            toasts.show(.transient(error, prefix: "Couldn't import captions"))
        }
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
