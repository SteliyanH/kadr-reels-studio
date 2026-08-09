import SwiftUI
import UniformTypeIdentifiers
import CoreMedia
import Kadr

/// Sheet for adding a time-pinned sound effect. User picks an audio file, drags a
/// slider to set the composition time at which the SFX fires, taps **Add** →
/// appends an `AudioTrack` pinned via `.at(time:)`.
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
        NavigationStack {
            Form {
                Section(header: Text("Sound").modernistLabel()) {
                    Button {
                        showImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "speaker.wave.2")
                            Text(pickedURL?.lastPathComponent ?? "Pick audio file")
                        }
                    }
                }
                Section(header: Text("Timing").modernistLabel()) {
                    HStack {
                        Text("Pin at")
                        Slider(value: $pinTimeSeconds, in: 0...max(compositionDurationSeconds, 0.1))
                        Text(String(format: "%.1fs", pinTimeSeconds))
                            .font(Modernist.Typography.numeric)
                            .frame(width: 48, alignment: .trailing)
                    }
                    HStack {
                        Text("Volume")
                        Slider(value: $volume, in: 0...1)
                        Text(String(format: "%.2f", volume))
                            .font(Modernist.Typography.numeric)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                Section {
                    Text("SFX play once at the pinned time and don't loop. Total composition is \(String(format: "%.1fs", compositionDurationSeconds)).")
                        .font(Modernist.Typography.caption)
                        .foregroundStyle(palette.textMuted)
                }
            }
            .navigationTitle("Add SFX")
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
        // v0.8 Tier 2 — sheets are chrome; chrome is the print ground.
        .modernistSurface(.print)
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
