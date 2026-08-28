import SwiftUI
import UniformTypeIdentifiers
import Kadr
import KadrAudio

/// Sheet for adding a background music track. User picks an audio file via
/// `.fileImporter`, sets volume + ducking, taps **Add** → appends an `AudioTrack`
/// with sensible defaults (fade-in 0.5s, fade-out 1.0s, optional ducking 0.3).
///
/// v0.8 Tier 5a wears the app's sheet chrome and the design's block layout;
/// the import, the defaults and the mutation are v0.3's.
struct AddMusicSheet: View {

    var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.reelPalette) private var palette
    @Environment(ToastCenter.self) private var toasts

    @State private var pickedURL: URL?
    @State private var showImporter = false
    @State private var volume: Double = 0.6
    @State private var enableDucking: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            ReelSheetHeader("Add Music") {
                Button("Cancel") { dismiss() }
                    .buttonStyle(ReelGhostButtonStyle())
                Button("Add") { addTrack() }
                    .buttonStyle(ReelPrimaryButtonStyle())
                    .disabled(pickedURL == nil)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Reel.Space.s6) {
                    audioSection
                    mixSection
                    Text("Music auto-fades in over 0.5s and out over 1.0s. Auto-ducking lowers music to 30% while clip audio plays.")
                        .font(Reel.Typography.caption)
                        .foregroundStyle(palette.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Reel.Space.s4)
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
        .reelSheet(Reel.SheetDetent.settings)
    }

    @ViewBuilder
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s2) {
            Text("Audio").reelLabel()
            Button {
                showImporter = true
            } label: {
                Label(
                    pickedURL?.lastPathComponent ?? NSLocalizedString("Pick audio file", comment: "Audio file importer"),
                    systemImage: "music.note"
                )
            }
            .buttonStyle(ReelSecondaryButtonStyle(isBlock: true))
        }
    }

    @ViewBuilder
    private var mixSection: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s3) {
            Text("Mix").reelLabel()
            ReelSlider(
                label: NSLocalizedString("Volume", comment: "Music volume"),
                value: $volume,
                range: 0...1,
                valueText: String(format: "%.2f", volume)
            )
            Toggle("Auto-duck during clip audio", isOn: $enableDucking)
                .font(Reel.Typography.body)
                // Decision 4 — no success role; the switch's "on" fill is the
                // one accent, never the system green.
                .tint(palette.accent)
        }
    }

    private func addTrack() {
        guard let url = pickedURL else { return }
        Task { await addTrack(from: url) }
    }

    /// v0.12 — validate before the file reaches a composition.
    ///
    /// The `.fileImporter` content-type list above is a guess: `.audio` admits
    /// files with no decodable audio track, and a user can rename anything. Before
    /// this check a video file picked here produced a project that saved fine and
    /// exported without the music, with nothing said at any point.
    ///
    /// `AudioFile` costs one asset load and turns that into a sentence naming the
    /// file.
    @MainActor
    private func addTrack(from url: URL) async {
        do {
            _ = try await AudioFile.inspect(url)
        } catch {
            toasts.show(.transient(error, prefix: "Couldn't add music"))
            return
        }
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
