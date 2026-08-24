import SwiftUI
import CoreMedia
import Kadr
#if canImport(UIKit)
import UIKit
#endif

/// Export sheet — preset picker, run button, progress UI, and a share-sheet
/// presentation on completion. Drives `Kadr.Exporter.run()`'s
/// `AsyncThrowingStream<ExportProgress, Error>` to surface live progress.
///
/// v0.8 Tier 5a rebuilds the chrome to the approved design (Screens §6): a
/// 2-up preset grid with real-proportion aspect glyphs, a RENDER card with a
/// flat accent progress bar, and a ruled footer carrying Cancel + Export.
/// Every piece of state, every mutation and the whole export lifecycle are
/// exactly what v0.4 shipped — this tier restyles, it does not rewire.
struct ExportSheet: View {

    var store: ProjectStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset: ExportPreset = .reelsAndShorts
    @State private var stage: ExportStage = .idle
    @State private var fractionCompleted: Double = 0
    @State private var resultURL: URL?
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    @State private var exporter: Exporter?

    @Environment(\.reelPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            ReelSheetHeader("Export") {
                Button {
                    cancelAndDismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(ReelIconButtonStyle())
                // The header's square close button *is* the old
                // cancellation-action toolbar button; it carried "Cancel"
                // mid-render and "Close" otherwise, and VoiceOver keeps
                // hearing exactly that.
                .accessibilityLabel(stage == .running ? "Cancel" : "Close")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Reel.Space.s6) {
                    presetSection
                    renderSection
                    if stage == .completed, resultURL != nil {
                        shareButton
                    }
                }
                .padding(Reel.Space.s4)
            }

            footer
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showShareSheet) {
            if let url = resultURL {
                ActivityView(items: [url])
            }
        }
        #endif
        .reelSheet(Reel.SheetDetent.export)
    }

    // MARK: - Preset

    @ViewBuilder
    private var presetSection: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s3) {
            Text("Preset").reelLabel()
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: Reel.Space.s2),
                    count: Reel.presetGridColumns
                ),
                spacing: Reel.Space.s2
            ) {
                ForEach(ExportPreset.allCases) { preset in
                    presetCell(preset)
                }
            }
            .disabled(stage == .running)
        }
    }

    @ViewBuilder
    private func presetCell(_ preset: ExportPreset) -> some View {
        let isSelected = preset == selectedPreset
        Button {
            selectedPreset = preset
        } label: {
            HStack(spacing: Reel.Space.s3) {
                aspectGlyph(preset.aspect, isSelected: isSelected)
                VStack(alignment: .leading, spacing: Reel.Space.s1) {
                    Text(preset.label)
                        .font(Reel.Typography.bodyEmphasis)
                        .foregroundStyle(palette.text)
                    Text(preset.detail)
                        .font(Reel.Typography.caption)
                        .foregroundStyle(palette.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Reel.Space.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: Reel.minHitTarget)
            // The app-wide selected-cell pattern: `accentTint` fill, 2pt
            // accent rule. Never an ad-hoc accent opacity.
            .background(isSelected ? palette.accentTint : palette.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Reel.Radius.sm)
                    .strokeBorder(
                        isSelected ? palette.accent : Color.clear,
                        lineWidth: Reel.ruleWidth
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.label)
        .accessibilityValue(preset.detail)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// The design's aspect-ratio glyph: a 2pt-outlined rectangle drawn at the
    /// format's *real* proportion, so 9:16 reads as a portrait sliver and 16:9
    /// as a landscape bar without either being labelled.
    @ViewBuilder
    private func aspectGlyph(_ aspect: CGSize, isSelected: Bool) -> some View {
        let longest = max(aspect.width, aspect.height)
        let scale = Reel.aspectGlyphExtent / max(longest, 1)
        Rectangle()
            .strokeBorder(
                isSelected ? palette.accent : palette.divider,
                lineWidth: Reel.ruleWidth
            )
            .frame(width: aspect.width * scale, height: aspect.height * scale)
            .frame(
                width: Reel.aspectGlyphExtent,
                height: Reel.aspectGlyphExtent
            )
            .accessibilityHidden(true)
    }

    // MARK: - Render

    @ViewBuilder
    private var renderSection: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s3) {
            Text("Render").reelLabel()
            VStack(alignment: .leading, spacing: Reel.Space.s3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(stageTitle)
                        .font(Reel.Typography.bodyEmphasis)
                        .foregroundStyle(stage == .failed ? palette.accentText : palette.text)
                    Spacer()
                    Text(percentText)
                        .font(Reel.Typography.numeric)
                        .foregroundStyle(palette.textMuted)
                }
                progressBar
                Text(specLine)
                    .font(Reel.Typography.numeric)
                    .foregroundStyle(palette.textMuted)
                if stage == .failed, let errorMessage {
                    Text(errorMessage)
                        .font(Reel.Typography.caption)
                        .foregroundStyle(palette.accentText)
                }
            }
            .reelCard()
        }
        .accessibilityElement(children: .combine)
    }

    /// 6pt, square, flat accent — no gradient, per the design.
    @ViewBuilder
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(palette.divider)
                Rectangle()
                    .fill(palette.accent)
                    .frame(width: geo.size.width * CGFloat(displayedFraction))
            }
        }
        .frame(height: Reel.progressBarHeight)
        .accessibilityHidden(true)
    }

    private var displayedFraction: Double {
        switch stage {
        case .idle:      return 0
        case .running:   return min(max(fractionCompleted, 0), 1)
        case .completed: return 1
        case .failed:    return min(max(fractionCompleted, 0), 1)
        }
    }

    private var stageTitle: LocalizedStringKey {
        switch stage {
        case .idle:      return "Ready"
        case .running:   return "Rendering…"
        case .completed: return "Export complete"
        case .failed:    return "Export failed"
        }
    }

    private var percentText: String {
        String(format: "%.0f%%", displayedFraction * 100)
    }

    /// "1080×1920 · 30 fps · HEVC · 0:06" — the preset's spec plus the
    /// composition's own length, both read straight off existing state.
    private var specLine: String {
        let seconds = max(0, CMTimeGetSeconds(store.video.duration))
        return "\(selectedPreset.detail) · \(ExportSheet.timecode(seconds))"
    }

    /// `m:ss`, tabular. Pure so it's testable.
    nonisolated static func timecode(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Share

    @ViewBuilder
    private var shareButton: some View {
        Button {
            showShareSheet = true
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(ReelSecondaryButtonStyle(isBlock: true))
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: Reel.Space.s2) {
            Button("Cancel") { cancelAndDismiss() }
                .buttonStyle(ReelGhostButtonStyle())
            Button("Export") { Task { await runExport() } }
                .buttonStyle(ReelPrimaryButtonStyle(isBlock: true))
                // The style already fades a disabled control to 45% — the
                // v0.5 "disabled, never hidden" rule, unchanged.
                .disabled(stage == .running)
        }
        .padding(.horizontal, Reel.Space.s4)
        .padding(.vertical, Reel.Space.s3)
        .reelRule(.top)
    }

    // MARK: - Actions

    /// The old cancellation-action toolbar button's body, unchanged: cancel a
    /// render in flight, then dismiss.
    private func cancelAndDismiss() {
        if stage == .running { exporter?.cancel() }
        dismiss()
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
            // `.joined` rather than the description alone: kadr writes a
            // recovery suggestion for most of what can fail here, and this is
            // the one surface where the person is stopped and waiting.
            errorMessage = AppError.readable(error).joined
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

        /// Frame proportion, for the grid's aspect glyph. Ratio only — the
        /// glyph is scaled to `Reel.aspectGlyphExtent`, so these are read
        /// as a shape, never as pixels.
        var aspect: CGSize {
            switch self {
            case .reelsAndShorts, .tiktok: return CGSize(width: 9, height: 16)
            case .square:                  return CGSize(width: 1, height: 1)
            case .cinema:                  return CGSize(width: 16, height: 9)
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
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
