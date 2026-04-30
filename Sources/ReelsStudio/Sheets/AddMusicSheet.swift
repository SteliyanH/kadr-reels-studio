import SwiftUI
import UniformTypeIdentifiers
import Kadr

/// Sheet for adding a background music track. User picks an audio file via
/// `.fileImporter`, sets volume + ducking, taps **Add** → appends an `AudioTrack`
/// with sensible defaults (fade-in 0.5s, fade-out 1.0s, optional ducking 0.3).
@available(iOS 16, macOS 13, visionOS 1, *)
struct AddMusicSheet: View {

    @ObservedObject var store: ProjectStore
    @Environment(\.dismiss) private var dismiss

    @State private var pickedURL: URL?
    @State private var showImporter = false
    @State private var volume: Double = 0.6
    @State private var enableDucking: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Audio") {
                    Button {
                        showImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "music.note")
                            Text(pickedURL?.lastPathComponent ?? "Pick audio file")
                        }
                    }
                }
                Section("Mix") {
                    HStack {
                        Text("Volume")
                        Slider(value: $volume, in: 0...1)
                        Text(String(format: "%.2f", volume))
                            .font(.caption.monospacedDigit())
                            .frame(width: 40, alignment: .trailing)
                    }
                    Toggle("Auto-duck during clip audio", isOn: $enableDucking)
                }
                Section {
                    Text("Music auto-fades in over 0.5s and out over 1.0s. Auto-ducking lowers music to 30% while clip audio plays.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addTrack() }
                        .disabled(pickedURL == nil)
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
