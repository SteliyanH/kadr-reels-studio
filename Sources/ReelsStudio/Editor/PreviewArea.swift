import SwiftUI
import Kadr
import KadrUI

/// The stage — `VideoPreview` (AVKit player) overlaid with `OverlayHost`
/// (gesture-routed overlays). Aspect ratio locked to the project preset's
/// resolution.
///
/// v0.8 Tier 5b — the approved design's stage band: the 9:16 frame sits on a
/// true-black letterbox with square corners and `.modernistElevation(.lg)`,
/// and carries a `numeric` spec chip in its top-left corner reading the
/// preset's own resolution and frame rate. Decision 5 is explicit that the
/// stage is the one surface that is **never** grayscaled — the user is
/// grading colour here.
struct PreviewArea: View {

    var store: ProjectStore
    @Environment(\.modernistPalette) private var palette

    var body: some View {
        let video = store.video
        let aspect = video.preset.resolution.width / video.preset.resolution.height

        ZStack {
            VideoPreview(video)
            OverlayHost(video, currentTime: store.currentTime)
                // v0.4 Tier 6: tap an overlay's hit region to select it.
                // Routes to the same selection slot the Layers sheet writes,
                // so the inspector / keyframe pair swaps the moment a layer
                // is tapped. v0.3's LayersSheet stays as the secondary
                // affordance (still useful for stacked or off-screen layers).
                .onLayerTap { id in
                    store.selectedOverlayID = id
                }
        }
        .aspectRatio(aspect, contentMode: .fit)
        // v0.8 Tier 2 — the letterbox stays true black: this is the field the
        // user grades against, so it takes the stage token rather than a
        // ground-tinted role. Decision 5's "never grayscale the stage" applies
        // to the same surface for the same reason.
        .background(Modernist.stageInk)
        .clipShape(RoundedRectangle(cornerRadius: Modernist.Radius.md))
        // The chip rides the *fitted* frame, not the band: `.aspectRatio(.fit)`
        // resolves this view's own bounds to the letterboxed rectangle, so a
        // `.topLeading` overlay lands in the video's corner on every device
        // width without measuring anything.
        .overlay(alignment: .topLeading) { specChip }
        .modernistElevation(.lg)
    }

    // MARK: - Spec chip

    /// "1080×1920 · 30 fps", flush in the stage's top-left corner.
    ///
    /// Flat and opaque rather than a translucent capsule: nothing in this
    /// system floats, and a solid `bg` block reads on any frame the user
    /// scrubs to — which a text-only chip over live footage would not.
    private var specChip: some View {
        Text(verbatim: PreviewArea.specChipText(for: store.project.preset))
            .font(Modernist.Typography.numeric)
            .foregroundStyle(palette.text)
            .padding(.horizontal, Modernist.Space.s2)
            .padding(.vertical, Modernist.Space.s1)
            .background(palette.bg)
            .padding(Modernist.Space.s2)
            .accessibilityLabel("Output format")
            .accessibilityValue(PreviewArea.specChipText(for: store.project.preset))
    }
}

extension PreviewArea {
    /// The stage chip's copy, from the preset the project already carries —
    /// no new state, no new field. Pure for testability.
    ///
    /// The multiplication sign is U+00D7, not the letter x, per the design.
    /// Digits and the unit ride `Typography.numeric` at the call site, so the
    /// string itself stays free of markup.
    nonisolated static func specChipText(for preset: Preset) -> String {
        let size = preset.resolution
        return "\(Int(size.width))×\(Int(size.height)) · \(preset.frameRate) fps"
    }
}
