import SwiftUI
import Kadr

/// Pick a key color + threshold for a Chroma Key filter, then add it to the
/// selected clip's filter stack. v0.7 Tier 4.
///
/// Pushed from `FiltersSheet`'s add menu when the user taps "Chroma Key".
/// Defaults to green (`#00FF00`) with a moderate threshold — the canonical
/// green-screen starting point. Apply commits via
/// `ProjectStore.addChromaKey(id:color:threshold:)` and dismisses; Cancel
/// just dismisses.
///
/// "Pick from preview" (tap the video preview to sample a color) is a
/// follow-up — needs `VideoPreview` to expose tap → color sampling, which
/// the current kadr-ui surface doesn't offer.
@available(iOS 16, *)
struct ChromaKeySheet: View {

    @ObservedObject var store: ProjectStore
    let clipID: ClipID
    @Environment(\.dismiss) private var dismiss

    @State private var keyColor: Color = .green
    @State private var threshold: Double = 0.4

    /// Canonical chroma-key starting threshold. 0.0 = exact-match (no
    /// tolerance — chips off only literal pixel-equal hits); 1.0 = max
    /// tolerance (everything keys out). 0.4 is the green-screen default
    /// most editors land on.
    private static let defaultThreshold: Double = 0.4

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    colorPreviewSection
                    thresholdSection
                    helpText
                }
                .padding()
            }
            .navigationTitle("Chroma Key")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        apply()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var colorPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Key color")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(keyColor)
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                ColorPicker("Pick color", selection: $keyColor, supportsOpacity: false)
                    .labelsHidden()
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Threshold")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f", threshold))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $threshold, in: 0...1)
                .accessibilityValue(String(format: "%.2f", threshold))
        }
    }

    @ViewBuilder
    private var helpText: some View {
        Text("Picks any pixel near the key color and replaces it with transparency. Lower threshold keeps more of the subject; higher keys out more background.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Apply

    private func apply() {
        store.addChromaKey(
            id: clipID,
            color: PlatformColor(keyColor),
            threshold: threshold
        )
    }
}

// MARK: - Bridges

@available(iOS 16, *)
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

private extension PlatformColor {
    convenience init(_ color: Color) {
        #if canImport(UIKit)
        self.init(color)
        #else
        self.init(cgColor: NSColor(color).cgColor) ?? .green
        #endif
    }
}
