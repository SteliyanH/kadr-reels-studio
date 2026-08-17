#if DEBUG
import SwiftUI

/// A preview-only specimen sheet for the Reel layer (Modernist design system).
///
/// Every component class and every step of the type scale, rendered on both
/// grounds. Nothing in the app references this view — it exists so a wrong
/// token is caught here, in a preview, rather than three tiers later in a
/// screen. When a later tier changes a style, open this first.
///
/// Debug-only on purpose: it ships no user-facing copy and no shipping build
/// should carry it.
struct ReelGallery: View {
    let palette: ReelPalette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Reel.Space.s6) {
                typeScale
                buttons
                tags
                segmentedControl
                slider
                cardAndRule
            }
            .padding(Reel.Space.s4)
        }
        .reelSurface(palette)
    }

    // MARK: - Type

    private var typeScale: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s2) {
            Text("Type scale").reelLabel()

            Text("Heading one").reelHeading(Reel.Typography.h1)
            Text("Heading two").reelHeading(Reel.Typography.h2)
            Text("Heading three").reelHeading(Reel.Typography.h3)
            Text("Heading four").reelHeading(Reel.Typography.h4)
            Text("Heading five").reelHeading(Reel.Typography.h5)
            Text("Heading six").reelLabel()

            Text("Body copy sets at fifteen point on a 1.55 line-height, flush left, and never justifies. This paragraph is here to show the measure.")
                .reelBody()

            Text("Body emphasis — the 600 weight")
                .font(Reel.Typography.bodyEmphasis)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Caption — secondary meta copy")
                .font(Reel.Typography.caption)
                .foregroundStyle(palette.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("00:01 / 00:06 · 48 px/s · 124%")
                .font(Reel.Typography.numeric)
                .foregroundStyle(palette.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Buttons

    private var buttons: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s3) {
            Text("Buttons").reelLabel()

            Button("Primary") {}
                .buttonStyle(ReelPrimaryButtonStyle())
            Button("Primary block") {}
                .buttonStyle(ReelPrimaryButtonStyle(isBlock: true))
            Button("Primary disabled") {}
                .buttonStyle(ReelPrimaryButtonStyle())
                .disabled(true)

            Button("Secondary") {}
                .buttonStyle(ReelSecondaryButtonStyle())
            Button("Secondary block") {}
                .buttonStyle(ReelSecondaryButtonStyle(isBlock: true))

            Button("Ghost") {}
                .buttonStyle(ReelGhostButtonStyle())

            HStack(spacing: Reel.Space.s2) {
                Button { } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(ReelIconButtonStyle())
                Button { } label: { Image(systemName: "arrow.uturn.backward") }
                    .buttonStyle(ReelIconButtonStyle())
                Button { } label: { Image(systemName: "arrow.uturn.forward") }
                    .buttonStyle(ReelIconButtonStyle())
                    .disabled(true)
                Button { } label: { Image(systemName: "square.and.arrow.up") }
                    .buttonStyle(ReelIconButtonStyle(isProminent: true))
            }

            HStack(spacing: Reel.ruleWidth) {
                toolbarCell("scissors", "Split")
                toolbarCell("doc.on.doc", "Copy")
                toolbarCell("speedometer", "Speed")
                toolbarCell("square.and.arrow.up", "Export", prominent: true)
            }
        }
    }

    private func toolbarCell(_ symbol: String, _ title: String, prominent: Bool = false) -> some View {
        Button {
        } label: {
            VStack(alignment: .leading, spacing: Reel.Space.s1) {
                Image(systemName: symbol)
                Text(title)
            }
        }
        .buttonStyle(ReelToolbarButtonStyle(isProminent: prominent))
    }

    // MARK: - Tags

    private var tags: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s2) {
            Text("Tags").reelLabel()
            HStack(spacing: Reel.Space.s2) {
                ReelTag(text: "9:16", variant: .neutral)
                ReelTag(text: "HEVC", variant: .accent)
                ReelTag(text: "Draft", variant: .outline)
            }
        }
    }

    // MARK: - Segmented control

    private var segmentedControl: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s2) {
            Text("Segmented control").reelLabel()
            SegmentedSpecimen()
        }
    }

    private struct SegmentedSpecimen: View {
        @State private var selection = "Transform"

        var body: some View {
            ReelSegmentedControl(
                options: [
                    (value: "Transform", label: "Transform"),
                    (value: "Opacity", label: "Opacity"),
                    (value: "Filters", label: "Filters")
                ],
                selection: $selection
            )
        }
    }

    // MARK: - Slider

    private var slider: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s2) {
            Text("Slider").reelLabel()
            SliderSpecimen()
        }
    }

    private struct SliderSpecimen: View {
        @State private var scale: Double = 1.24
        @State private var opacity: Double = 0.88

        var body: some View {
            VStack(spacing: Reel.Space.s2) {
                ReelSlider(
                    label: "Scale",
                    value: $scale,
                    range: 0.5...2,
                    valueText: String(format: "%.2f×", scale)
                )
                ReelSlider(
                    label: "Opacity",
                    value: $opacity,
                    valueText: "\(Int(opacity * 100))%"
                )
            }
        }
    }

    // MARK: - Card and rule

    private var cardAndRule: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s3) {
            Text("Card and rule").reelLabel()

            VStack(alignment: .leading, spacing: Reel.Space.s1) {
                Text("Rendering…").font(Reel.Typography.bodyEmphasis)
                Text("1080×1920 · 30 fps · HEVC · 0:06")
                    .font(Reel.Typography.numeric)
                    .foregroundStyle(palette.textMuted)
            }
            .reelCard()

            Color.clear
                .frame(height: Reel.Space.s4)
                .reelRule()

            Rectangle()
                .fill(palette.surfaceRaised)
                .frame(height: 56)
                .overlay(alignment: .leading) {
                    Text("Grayscale specimen")
                        .font(Reel.Typography.caption)
                        .padding(.horizontal, Reel.Space.s3)
                }
                .reelGrayscale()
                .reelElevation(.md)
        }
    }
}

#Preview("Reel · print") {
    ReelGallery(palette: .print)
}

#Preview("Reel · studio") {
    ReelGallery(palette: .studio)
}
#endif
