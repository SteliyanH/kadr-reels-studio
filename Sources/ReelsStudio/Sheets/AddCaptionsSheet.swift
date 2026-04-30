import SwiftUI
import UniformTypeIdentifiers
import Kadr
import KadrCaptions

/// Sheet for ingesting caption files into the project. Pick a `.srt` / `.vtt` /
/// `.itt` / `.ass` / `.ssa` file via `.fileImporter`; the auto-detect dispatch in
/// `Caption.load(_:)` chooses the matching parser. Resolved cues append to the
/// project's `captions` array — the engine bakes them as `AVMetadataItem` group
/// at export.
///
/// v0.1 ships plain caption ingest only. The v0.3 styled-VTT bridge
/// (`Caption.loadStyled(vtt:)` + `Video.styledCaptions(_:)`) is a v0.1.x patch.
@available(iOS 16, macOS 13, visionOS 1, *)
struct AddCaptionsSheet: View {

    @ObservedObject var store: ProjectStore
    @Environment(\.dismiss) private var dismiss

    @State private var pickedURL: URL?
    @State private var showImporter = false
    @State private var loadedCount: Int = 0
    @State private var loadError: String?
    @State private var isLoading = false

    /// `UTType`s for the five formats kadr-captions supports. Falls back to plain
    /// text for cases where the system doesn't ship a UTI for the extension.
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

    var body: some View {
        NavigationStack {
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
                if loadedCount > 0 {
                    Section("Parsed") {
                        Label("\(loadedCount) cue\(loadedCount == 1 ? "" : "s")", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }
                if let loadError {
                    Section("Error") {
                        Text(loadError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Text("Supported formats: SRT, VTT, iTT, ASS, SSA. Cues bake as AVMetadataItem at export — players that surface video metadata (Apple Photos, AVPlayer pickers) read them automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Captions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { dismiss() }
                        .disabled(loadedCount == 0)
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
                    loadError = error.localizedDescription
                }
            }
            .overlay {
                if isLoading { ProgressView().controlSize(.large) }
            }
        }
    }

    @MainActor
    private func loadCaptions(from url: URL) async {
        isLoading = true
        loadError = nil
        loadedCount = 0
        defer { isLoading = false }
        do {
            // Sandboxed file picks need security-scoped resource access.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let cues = try await Caption.load(url)
            store.append(captions: cues)
            loadedCount = cues.count
        } catch {
            loadError = error.localizedDescription
        }
    }
}
