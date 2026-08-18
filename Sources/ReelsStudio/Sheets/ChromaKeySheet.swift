import SwiftUI
import Kadr
import KadrUI

/// Pick a key color + threshold for a Chroma Key filter, then add it to the
/// selected clip's filter stack. v0.7 Tier 4.
///
/// Pushed from `FiltersSheet`'s add menu when the user taps "Chroma Key".
/// Defaults to green (`#00FF00`) with a moderate threshold — the canonical
/// green-screen starting point. Apply commits via
/// `ProjectStore.addChromaKey(id:color:threshold:)` and dismisses; Cancel
/// just dismisses.
///
/// v0.8.3 — "sample from frame" landed. kadr-ui 0.14 exposes tap → colour
/// sampling on `VideoPreview`, so the user can lift the key colour off the
/// footage instead of guessing it in a colour wheel. The preview is bound to
/// the editor's playhead, so it shows the frame the user was already looking
/// at rather than frame zero.
struct ChromaKeySheet: View {

    var store: ProjectStore
    let clipID: ClipID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.reelPalette) private var palette

    /// The one chromatic literal left in view code, deliberately. This is not
    /// chrome — it's the sampled key colour the filter matches against, and
    /// green is the canonical green-screen start. The v0.8 Tier 3 mono sweep
    /// styles the chrome around this control and leaves the control (and its
    /// default) whole: constraining it to the ramp would be a functional
    /// regression, not a style call.
    @State private var keyColor: Color = .green
    @State private var threshold: Double = 0.4

    /// Where the last sample was taken, normalised. Drives the reticle, so the
    /// user can see which pixel produced the swatch — without it, a sample that
    /// lands a few pixels off reads as the picker simply being wrong.
    @State private var samplePoint: CGPoint?

    /// Canonical chroma-key starting threshold. 0.0 = exact-match (no
    /// tolerance — chips off only literal pixel-equal hits); 1.0 = max
    /// tolerance (everything keys out). 0.4 is the green-screen default
    /// most editors land on.
    private static let defaultThreshold: Double = 0.4

    var body: some View {
        VStack(spacing: 0) {
            ReelSheetHeader("Chroma Key") {
                Button("Cancel") { dismiss() }
                    .buttonStyle(ReelGhostButtonStyle())
                Button("Apply") {
                    apply()
                    dismiss()
                }
                .buttonStyle(ReelPrimaryButtonStyle())
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Reel.Space.s6) {
                    sampleFromFrameSection
                    colorPreviewSection
                    thresholdSection
                    helpText
                }
                .padding(Reel.Space.s4)
            }
        }
        .reelSheet(Reel.SheetDetent.layers)
    }

    // MARK: - Subviews

    /// The footage, tappable. Bound to the editor's playhead so it opens on the
    /// frame the user was looking at, not frame zero — the whole point is to
    /// sample the green they can actually see.
    @ViewBuilder
    private var sampleFromFrameSection: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s2) {
            Text("Sample from frame")
                .reelLabel()

            VideoPreview(
                store.video,
                currentTime: Binding(
                    get: { store.currentTime },
                    set: { store.currentTime = $0 }
                ),
                onSampleColor: { sample in
                    keyColor = sample.color
                    samplePoint = sample.point
                    // Same light tap the timeline uses for a discrete pick.
                    HapticEngine.shared.snap()
                }
            )
            .aspectRatio(
                store.video.preset.resolution.width / store.video.preset.resolution.height,
                contentMode: .fit
            )
            .frame(maxHeight: Reel.chromaSampleHeight)
            .overlay { reticle }
            // The stage is never grayscaled and neither is this: the user is
            // picking a colour, so showing them a desaturated frame would make
            // the task impossible.
            .accessibilityElement(children: .contain)

            Text("Tap the picture to lift its colour. Taps outside the frame are ignored.")
                .font(Reel.Typography.caption)
                .foregroundStyle(palette.textMuted)
        }
    }

    /// Crosshair over the last sampled point.
    @ViewBuilder
    private var reticle: some View {
        if let samplePoint {
            GeometryReader { proxy in
                Rectangle()
                    .strokeBorder(palette.text, lineWidth: Reel.ruleWidth)
                    .frame(width: Reel.reticleSize, height: Reel.reticleSize)
                    .position(
                        x: samplePoint.x * proxy.size.width,
                        y: samplePoint.y * proxy.size.height
                    )
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var colorPreviewSection: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s2) {
            Text("Key color")
                .reelLabel()
            HStack(spacing: Reel.Space.s3) {
                Rectangle()
                    .fill(keyColor)
                    .frame(width: Reel.swatchSize, height: Reel.swatchSize)
                    .overlay(
                        Rectangle()
                            .strokeBorder(palette.divider, lineWidth: Reel.ruleWidth)
                    )
                // Commander's ruling: this picker is functional, not chrome.
                // The sheet around it is restyled; the control itself is left
                // whole so arbitrary key colours stay reachable.
                ColorPicker("Pick color", selection: $keyColor, supportsOpacity: false)
                    .labelsHidden()
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s2) {
            Text("Threshold")
                .reelLabel()
            ReelSlider(
                label: NSLocalizedString("Threshold", comment: "Chroma key tolerance"),
                value: $threshold,
                range: 0...1,
                valueText: String(format: "%.2f", threshold)
            )
            .accessibilityValue(String(format: "%.2f", threshold))
        }
    }

    @ViewBuilder
    private var helpText: some View {
        Text("Picks any pixel near the key color and replaces it with transparency. Lower threshold keeps more of the subject; higher keys out more background.")
            .font(Reel.Typography.caption)
            .foregroundStyle(palette.textMuted)
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

// v0.8 Tier 5a — the navigation-bar shim went with the `NavigationStack` this
// sheet no longer wraps itself in; `ReelSheetHeader` draws the title.

private extension PlatformColor {
    convenience init(_ color: Color) {
        #if canImport(UIKit)
        self.init(color)
        #else
        self.init(cgColor: NSColor(color).cgColor) ?? .green
        #endif
    }
}
