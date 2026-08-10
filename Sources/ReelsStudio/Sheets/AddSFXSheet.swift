import SwiftUI
import UniformTypeIdentifiers
import CoreMedia
import Kadr

/// Sheet for adding a time-pinned sound effect. User picks an audio file, drags a
/// slider to set the composition time at which the SFX fires, taps **Add** →
/// appends an `AudioTrack` pinned via `.at(time:)`.
///
/// v0.8 Tier 5a wears the app's sheet chrome and the design's block layout;
/// the import, the pinning and the mutation are v0.3's.
struct AddSFXSheet: View {

    var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modernistPalette) private var palette

    @State private var pickedURL: URL?
    @State private var showImporter = false
    @State private var pinTimeSeconds: Double = 0
    @State private var volume: Double = 1.0

    private var compositionDurationSeconds: Double {
        max(0, CMTimeGetSeconds(store.video.duration))
    }

    var body: some View {
        VStack(spacing: 0) {
            ModernistSheetHeader("Add SFX") {
                Button("Cancel") { dismiss() }
                    .buttonStyle(ModernistGhostButtonStyle())
                Button("Add") { addTrack() }
                    .buttonStyle(ModernistPrimaryButtonStyle())
                    .disabled(pickedURL == nil)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Modernist.Space.s6) {
                    soundSection
                    timingSection
                    Text(
                        String(
                            format: NSLocalizedString("sfx.composition.footer", comment: "SFX footer"),
                            compositionDurationSeconds
                        )
                    )
                    .font(Modernist.Typography.caption)
                    .foregroundStyle(palette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Modernist.Space.s4)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result {
                pickedURL = urls.first
            }
        }
        .modernistSheet(Modernist.SheetDetent.settings)
    }

    @ViewBuilder
    private var soundSection: some View {
        VStack(alignment: .leading, spacing: Modernist.Space.s2) {
            Text("Sound").modernistLabel()
            Button {
                showImporter = true
            } label: {
                Label(
                    pickedURL?.lastPathComponent ?? NSLocalizedString("Pick audio file", comment: "Audio file importer"),
                    systemImage: "speaker.wave.2"
                )
            }
            .buttonStyle(ModernistSecondaryButtonStyle(isBlock: true))
        }
    }

    @ViewBuilder
    private var timingSection: some View {
        VStack(alignment: .leading, spacing: Modernist.Space.s3) {
            Text("Timing").modernistLabel()
            ModernistSlider(
                label: NSLocalizedString("Pin at", comment: "SFX pin time"),
                value: $pinTimeSeconds,
                range: 0...max(compositionDurationSeconds, 0.1),
                valueText: String(format: "%.1fs", pinTimeSeconds)
            )
            ModernistSlider(
                label: NSLocalizedString("Volume", comment: "SFX volume"),
                value: $volume,
                range: 0...1,
                valueText: String(format: "%.2f", volume)
            )
        }
    }

    private func addTrack() {
        guard let url = pickedURL else { return }
        let track = AudioTrack(url: url)
            .volume(volume)
            .at(time: pinTimeSeconds)
        store.append(audioTrack: track)
        dismiss()
    }
}
