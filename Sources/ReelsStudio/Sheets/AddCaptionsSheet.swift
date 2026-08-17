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
struct AddCaptionsSheet: View {

    var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toasts

    @State private var selectedTab: Tab
    @Environment(\.reelPalette) private var palette

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
        VStack(spacing: 0) {
            ReelSheetHeader("Captions") {
                Button("Done") { dismiss() }
                    .buttonStyle(ReelGhostButtonStyle())
            }

            ReelSegmentedControl(
                options: [
                    (Tab.edit, NSLocalizedString("Edit", comment: "Caption edit tab")),
                    (Tab.import, NSLocalizedString("Import", comment: "Caption import tab")),
                ],
                selection: $selectedTab
            )
            .padding(Reel.Space.s4)

            switch selectedTab {
            case .edit:    editTab
            case .import:  importTab
            }
        }
        // The design gives no fixed height for this one; the cue editor is a
        // full working surface, so it takes the full-height stop.
        .reelSheet(detents: [.large])
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
            .padding(.horizontal, Reel.Space.s4)
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
        ScrollView {
            VStack(alignment: .leading, spacing: Reel.Space.s6) {
                VStack(alignment: .leading, spacing: Reel.Space.s2) {
                    Text("Caption file").reelLabel()
                    Button {
                        showImporter = true
                    } label: {
                        Label(
                            pickedURL?.lastPathComponent
                                ?? NSLocalizedString("Pick caption file", comment: "Caption importer"),
                            systemImage: "captions.bubble"
                        )
                    }
                    .buttonStyle(ReelSecondaryButtonStyle(isBlock: true))
                    if let pickedURL {
                        Text(pickedURL.pathExtension.uppercased())
                            .font(Reel.Typography.numeric)
                            .foregroundStyle(palette.textMuted)
                    }
                }
                if lastImportedCount > 0 {
                    VStack(alignment: .leading, spacing: Reel.Space.s2) {
                        Text("Imported").reelLabel()
                        Label(
                            importedCountText,
                            systemImage: "checkmark.circle"
                        )
                        .font(Reel.Typography.body)
                        // Decision 4 — no success role; a confirmation is ink.
                        .foregroundStyle(palette.text)
                        Button("Switch to Edit") {
                            selectedTab = .edit
                        }
                        .buttonStyle(ReelGhostButtonStyle())
                    }
                }
                Text("Supported formats: SRT, VTT, iTT, ASS, SSA. Cues append to the project's caption list — switch to Edit to retime / rename / delete.")
                    .font(Reel.Typography.caption)
                    .foregroundStyle(palette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Reel.Space.s4)
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

    /// "1 cue appended" / "12 cues appended", through the keys the bundle
    /// already carries — the `Form` version interpolated the count into an
    /// unlocalizable literal.
    private var importedCountText: String {
        lastImportedCount == 1
            ? NSLocalizedString("captions.imported.singular", comment: "One cue imported")
            : String(
                format: NSLocalizedString("captions.imported.plural", comment: "Many cues imported"),
                lastImportedCount
              )
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

// v0.8 Tier 5a — the navigation-bar shim went with the `NavigationStack` this
// sheet no longer wraps itself in; `ReelSheetHeader` draws the title.
