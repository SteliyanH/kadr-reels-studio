import SwiftUI
import UniformTypeIdentifiers
import Kadr

/// Sheet for adding a background music track. User picks an audio file via
/// `.fileImporter`, sets volume + ducking, taps **Add** → appends an `AudioTrack`
/// with sensible defaults (fade-in 0.5s, fade-out 1.0s, optional ducking 0.3).
///
/// v0.8 Tier 5a wears the app's sheet chrome and the design's block layout;
/// the import, the defaults and the mutation are v0.3's.
struct AddMusicSheet: View {

    var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modernistPalette) private var palette

    @State private var pickedURL: URL?
    @State private var showImporter = false
    @State private var volume: Double = 0.6
    @State private var enableDucking: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            ModernistSheetHeader("Add Music") {
                Button("Cancel") { dismiss() }
                    .buttonStyle(ModernistGhostButtonStyle())
                Button("Add") { addTrack() }
                    .buttonStyle(ModernistPrimaryButtonStyle())
                    .disabled(pickedURL == nil)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Modernist.Space.s6) {
                    audioSection
                    mixSection
                    Text("Music auto-fades in over 0.5s and out over 1.0s. Auto-ducking lowers music to 30% while clip audio plays.")
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
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: Modernist.Space.s2) {
            Text("Audio").modernistLabel()
            Button {
                showImporter = true
            } label: {
                Label(
                    pickedURL?.lastPathComponent ?? NSLocalizedString("Pick audio file", comment: "Audio file importer"),
                    systemImage: "music.note"
                )
            }
            .buttonStyle(ModernistSecondaryButtonStyle(isBlock: true))
        }
    }

    @ViewBuilder
    private var mixSection: some View {
        VStack(alignment: .leading, spacing: Modernist.Space.s3) {
            Text("Mix").modernistLabel()
            ModernistSlider(
                label: NSLocalizedString("Volume", comment: "Music volume"),
                value: $volume,
                range: 0...1,
                valueText: String(format: "%.2f", volume)
            )
            Toggle("Auto-duck during clip audio", isOn: $enableDucking)
                .font(Modernist.Typography.body)
                // Decision 4 — no success role; the switch's "on" fill is the
                // one accent, never the system green.
                .tint(palette.accent)
        }
    }

    private func addTrack() {
        guard let url = pickedURL else { return }
        var track = AudioTrack(url: url)
            .volume(volume)
            .fadeIn(0.5)
            .fadeOut(1.0)
        if enableDucking {
            track = track.ducking(0.3)
        }
        store.append(audioTrack: track)
        dismiss()
    }
}
