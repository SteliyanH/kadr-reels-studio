#if DEBUG
import SwiftUI

/// A preview-only specimen sheet for the Modernist layer.
///
/// Every component class and every step of the type scale, rendered on both
/// grounds. Nothing in the app references this view — it exists so a wrong
/// token is caught here, in a preview, rather than three tiers later in a
/// screen. When a later tier changes a style, open this first.
///
/// Debug-only on purpose: it ships no user-facing copy and no shipping build
/// should carry it.
struct ModernistGallery: View {
    let palette: ModernistPalette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Modernist.Space.s6) {
                typeScale
                buttons
                tags
                segmentedControl
                slider
                cardAndRule
            }
            .padding(Modernist.Space.s4)
        }
        .modernistSurface(palette)
    }

    // MARK: - Type

    private var typeScale: some View {
        VStack(alignment: .leading, spacing: Modernist.Space.s2) {
            Text("Type scale").modernistLabel()

            Text("Heading one").modernistHeading(Modernist.Typography.h1)
            Text("Heading two").modernistHeading(Modernist.Typography.h2)
            Text("Heading three").modernistHeading(Modernist.Typography.h3)
            Text("Heading four").modernistHeading(Modernist.Typography.h4)
            Text("Heading five").modernistHeading(Modernist.Typography.h5)
            Text("Heading six").modernistLabel()

            Text("Body copy sets at fifteen point on a 1.55 line-height, flush left, and never justifies. This paragraph is here to show the measure.")
                .modernistBody()

            Text("Body emphasis — the 600 weight")
                .font(Modernist.Typography.bodyEmphasis)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Caption — secondary meta copy")
                .font(Modernist.Typography.caption)
                .foregroundStyle(palette.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("00:01 / 00:06 · 48 px/s · 124%")
                .font(Modernist.Typography.numeric)
                .foregroundStyle(palette.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Buttons

    private var buttons: some View {
        VStack(alignment: .leading, spacing: Modernist.Space.s3) {
            Text("Buttons").modernistLabel()

            Button("Primary") {}
                .buttonStyle(ModernistPrimaryButtonStyle())
            Button("Primary block") {}
                .buttonStyle(ModernistPrimaryButtonStyle(isBlock: true))
            Button("Primary disabled") {}
                .buttonStyle(ModernistPrimaryButtonStyle())
                .disabled(true)

            Button("Secondary") {}
                .buttonStyle(ModernistSecondaryButtonStyle())
            Button("Secondary block") {}
                .buttonStyle(ModernistSecondaryButtonStyle(isBlock: true))

            Button("Ghost") {}
                .buttonStyle(ModernistGhostButtonStyle())

            HStack(spacing: Modernist.Space.s2) {
                Button { } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(ModernistIconButtonStyle())
                Button { } label: { Image(systemName: "arrow.uturn.backward") }
                    .buttonStyle(ModernistIconButtonStyle())
                Button { } label: { Image(systemName: "arrow.uturn.forward") }
                    .buttonStyle(ModernistIconButtonStyle())
                    .disabled(true)
                Button { } label: { Image(systemName: "square.and.arrow.up") }
                    .buttonStyle(ModernistIconButtonStyle(isProminent: true))
            }

            HStack(spacing: Modernist.ruleWidth) {
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
            VStack(alignment: .leading, spacing: Modernist.Space.s1) {
                Image(systemName: symbol)
                Text(title)
            }
        }
        .buttonStyle(ModernistToolbarButtonStyle(isProminent: prominent))
    }

    // MARK: - Tags

    private var tags: some View {
        VStack(alignment: .leading, spacing: Modernist.Space.s2) {
            Text("Tags").modernistLabel()
            HStack(spacing: Modernist.Space.s2) {
                ModernistTag(text: "9:16", variant: .neutral)
                ModernistTag(text: "HEVC", variant: .accent)
                ModernistTag(text: "Draft", variant: .outline)
            }
        }
    }

    // MARK: - Segmented control

    private var segmentedControl: some View {
        VStack(alignment: .leading, spacing: Modernist.Space.s2) {
            Text("Segmented control").modernistLabel()
            SegmentedSpecimen()
        }
    }

    private struct SegmentedSpecimen: View {
        @State private var selection = "Transform"

        var body: some View {
            ModernistSegmentedControl(
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
        VStack(alignment: .leading, spacing: Modernist.Space.s2) {
            Text("Slider").modernistLabel()
            SliderSpecimen()
        }
    }

    private struct SliderSpecimen: View {
        @State private var scale: Double = 1.24
        @State private var opacity: Double = 0.88

        var body: some View {
            VStack(spacing: Modernist.Space.s2) {
                ModernistSlider(
                    label: "Scale",
                    value: $scale,
                    range: 0.5...2,
                    valueText: String(format: "%.2f×", scale)
                )
                ModernistSlider(
                    label: "Opacity",
                    value: $opacity,
                    valueText: "\(Int(opacity * 100))%"
                )
            }
        }
    }

    // MARK: - Card and rule

    private var cardAndRule: some View {
        VStack(alignment: .leading, spacing: Modernist.Space.s3) {
            Text("Card and rule").modernistLabel()

            VStack(alignment: .leading, spacing: Modernist.Space.s1) {
                Text("Rendering…").font(Modernist.Typography.bodyEmphasis)
                Text("1080×1920 · 30 fps · HEVC · 0:06")
                    .font(Modernist.Typography.numeric)
                    .foregroundStyle(palette.textMuted)
            }
            .modernistCard()

            Color.clear
                .frame(height: Modernist.Space.s4)
                .modernistRule()

            Rectangle()
                .fill(palette.surfaceRaised)
                .frame(height: 56)
                .overlay(alignment: .leading) {
                    Text("Grayscale specimen")
                        .font(Modernist.Typography.caption)
                        .padding(.horizontal, Modernist.Space.s3)
                }
                .modernistGrayscale()
                .modernistElevation(.md)
        }
    }
}

#Preview("Modernist · print") {
    ModernistGallery(palette: .print)
}

#Preview("Modernist · studio") {
    ModernistGallery(palette: .studio)
}
#endif
