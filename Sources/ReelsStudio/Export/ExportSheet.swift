import SwiftUI
import Kadr
#if canImport(UIKit)
import UIKit
#endif

/// Export sheet — preset picker, run button, progress UI, and a share-sheet
/// presentation on completion. Drives `Kadr.Exporter.run()`'s
/// `AsyncThrowingStream<ExportProgress, Error>` to surface live progress.
@available(iOS 16, macOS 13, visionOS 1, *)
struct ExportSheet: View {

    @ObservedObject var store: ProjectStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset: ExportPreset = .reelsAndShorts
    @State private var stage: ExportStage = .idle
    @State private var fractionCompleted: Double = 0
    @State private var resultURL: URL?
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    @State private var exporter: Exporter?

    var body: some View {
        NavigationStack {
            Form {
                Section("Preset") {
                    Picker("Format", selection: $selectedPreset) {
                        ForEach(ExportPreset.allCases) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .disabled(stage == .running)
                    Text(selectedPreset.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Status") {
                    statusRow
                }
                if stage == .completed, resultURL != nil {
                    Section {
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(stage == .running ? "Cancel" : "Close") {
                        if stage == .running { exporter?.cancel() }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") { Task { await runExport() } }
                        .disabled(stage == .running)
                }
            }
            #if canImport(UIKit)
            .sheet(isPresented: $showShareSheet) {
                if let url = resultURL {
                    ActivityView(items: [url])
                }
            }
            #endif
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch stage {
        case .idle:
            Label("Ready", systemImage: "circle.dotted")
                .foregroundStyle(.secondary)
        case .running:
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: fractionCompleted)
                Text(String(format: "%.0f%%", fractionCompleted * 100))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        case .completed:
            Label("Export complete", systemImage: "checkmark.circle")
                .foregroundStyle(.green)
        case .failed:
            VStack(alignment: .leading, spacing: 4) {
                Label("Export failed", systemImage: "xmark.circle")
                    .foregroundStyle(.red)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    @MainActor
    private func runExport() async {
        let outputURL = makeTempOutputURL()
        let video = applyPreset(to: store.video, preset: selectedPreset)
        let exp = video.exporter(to: outputURL)
        self.exporter = exp
        stage = .running
        fractionCompleted = 0
        errorMessage = nil
        resultURL = nil
        do {
            for try await progress in exp.run() {
                fractionCompleted = progress.fractionCompleted
            }
            resultURL = outputURL
            stage = .completed
            // v0.4 Tier 4 — long-running task completion fires the success
            // haptic before the share sheet presents.
            HapticEngine.shared.success()
        } catch is CancellationError {
            stage = .idle
        } catch {
            errorMessage = ErrorSanitizer.sanitize(error)
            stage = .failed
        }
    }

    private func applyPreset(to video: Video, preset: ExportPreset) -> Video {
        guard let kadrPreset = preset.kadrPreset else { return video }
        return video.preset(kadrPreset)
    }

    private func makeTempOutputURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ReelsStudio-\(UUID().uuidString)")
            .appendingPathExtension("mp4")
    }
}

// MARK: - Preset enum (kadr-side bridge)

@available(iOS 16, macOS 13, visionOS 1, *)
extension ExportSheet {
    enum ExportPreset: String, CaseIterable, Identifiable {
        case reelsAndShorts
        case tiktok
        case square
        case cinema

        var id: String { rawValue }

        var label: String {
            switch self {
            case .reelsAndShorts: return "Reels / Shorts"
            case .tiktok:         return "TikTok"
            case .square:         return "Square"
            case .cinema:         return "Cinema"
            }
        }

        var detail: String {
            switch self {
            case .reelsAndShorts: return "1080×1920 · 30 fps · HEVC"
            case .tiktok:         return "1080×1920 · 30 fps · H.264"
            case .square:         return "1080×1080 · 30 fps · H.264"
            case .cinema:         return "1920×1080 · 24 fps · H.264"
            }
        }

        var kadrPreset: Preset? {
            switch self {
            case .reelsAndShorts: return .reelsAndShorts
            case .tiktok:         return .tiktok
            case .square:         return .square
            case .cinema:         return .cinema
            }
        }
    }

    enum ExportStage: Sendable {
        case idle, running, completed, failed
    }
}

// MARK: - UIActivityViewController bridge

#if canImport(UIKit)
@available(iOS 16, *)
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
