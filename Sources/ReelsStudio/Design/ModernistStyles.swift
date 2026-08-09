import SwiftUI

// The design system's component layer as SwiftUI styles and modifiers.
//
// `styles.css` ships classes (`.btn-primary`, `.btn-secondary`, `.btn-ghost`,
// `.btn-icon`, `.tag`, `.card`, `.hr`, `.grayscale`, `.elev-*`, `.seg`);
// SwiftUI's equivalents are `ButtonStyle`s, `ViewModifier`s and `View`
// extensions. Same names, one-for-one.
//
// Every style reads `\.modernistPalette` from the environment, so the same
// button renders correctly on the light chrome and on the dark editor surround
// without a call site ever naming a color. Set the ground once per surface:
//
//     LibraryView().modernistSurface(.print)
//     EditorView().modernistSurface(.studio)
//
// No literal colors, sizes, radii or shadows below — everything comes from
// `Modernist.*`.

// MARK: - Surface

extension View {
    /// Establishes the ground for a subtree: sets the palette in the
    /// environment, paints the background, and tints the standard controls.
    /// Apply once per screen, at the root.
    func modernistSurface(_ palette: ModernistPalette) -> some View {
        environment(\.modernistPalette, palette)
            .background(palette.bg.ignoresSafeArea())
            .tint(palette.accent)
            .foregroundStyle(palette.text)
    }
}

// MARK: - Buttons
//
// Each style defers to a nested `StyleBody` view so it can read the palette and
// `\.isEnabled` from the environment. The nested type is deliberately *not*
// called `Body`: a nested type with that name is taken as `ButtonStyle`'s
// `Body` associated-type witness, and would then have to be as accessible as
// the style itself rather than private.

/// `.btn.btn-primary` — a solid accent fill, square corners, label flush left.
///
/// The flush-left rule is the one people get wrong: a button wider than its
/// label starts the text at the leading padding edge (trailing icon and all),
/// never centered. That's what the `alignment: .leading` frame is for — don't
/// swap it for a centered one.
struct ModernistPrimaryButtonStyle: ButtonStyle {
    /// `.btn-block` — fills the available width. `false` hugs the label.
    var isBlock: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, isBlock: isBlock)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        let isBlock: Bool
        @Environment(\.modernistPalette) private var palette
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Modernist.Typography.buttonLabel)
                .foregroundStyle(palette.onAccent)
                .padding(.horizontal, Modernist.Space.s4)
                .padding(.vertical, Modernist.Space.s3)
                .frame(maxWidth: isBlock ? .infinity : nil, alignment: .leading)
                .frame(minHeight: Modernist.minHitTarget)
                .background(configuration.isPressed ? palette.accentPressed : palette.accent)
                .clipShape(RoundedRectangle(cornerRadius: Modernist.Radius.md))
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(Rectangle())
        }
    }
}

/// `.btn.btn-secondary` — outlined in a 2px accent rule, accent label.
/// Also the destructive treatment: in a mono scheme the accent *is* the red, so
/// Delete is the outlined variant with a trash icon, never a second red fill.
struct ModernistSecondaryButtonStyle: ButtonStyle {
    var isBlock: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, isBlock: isBlock)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        let isBlock: Bool
        @Environment(\.modernistPalette) private var palette
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Modernist.Typography.buttonLabel)
                .foregroundStyle(palette.accentText)
                .padding(.horizontal, Modernist.Space.s4)
                .padding(.vertical, Modernist.Space.s3)
                .frame(maxWidth: isBlock ? .infinity : nil, alignment: .leading)
                .frame(minHeight: Modernist.minHitTarget)
                .background(configuration.isPressed ? palette.accentTint : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: Modernist.Radius.md)
                        .strokeBorder(palette.accent, lineWidth: Modernist.ruleWidth)
                )
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(Rectangle())
        }
    }
}

/// `.btn.btn-ghost` — no fill, no rule, ink label; a tint on press.
struct ModernistGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        @Environment(\.modernistPalette) private var palette
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Modernist.Typography.buttonLabel)
                .foregroundStyle(palette.text)
                .padding(.horizontal, Modernist.Space.s3)
                .padding(.vertical, Modernist.Space.s2)
                .frame(minHeight: Modernist.minHitTarget, alignment: .leading)
                .background(configuration.isPressed ? palette.accentTint : Color.clear)
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(Rectangle())
        }
    }
}

/// `.btn-icon` — the square icon button, padded to the hit target.
struct ModernistIconButtonStyle: ButtonStyle {
    /// `true` gives the accent fill (the editor's Export slot); `false` the
    /// surface fill (undo / redo / back / settings).
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, isProminent: isProminent)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        let isProminent: Bool
        @Environment(\.modernistPalette) private var palette
        @Environment(\.isEnabled) private var isEnabled

        private var fill: Color {
            if isProminent {
                return configuration.isPressed ? palette.accentPressed : palette.accent
            }
            return configuration.isPressed ? palette.accentTint : palette.surface
        }

        var body: some View {
            configuration.label
                .font(Modernist.Typography.bodyEmphasis)
                .foregroundStyle(isProminent ? palette.onAccent : palette.text)
                .frame(width: Modernist.minHitTarget, height: Modernist.minHitTarget)
                .background(fill)
                .clipShape(RoundedRectangle(cornerRadius: Modernist.Radius.sm))
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(Rectangle())
        }
    }
}

/// The editor's toolbar cell — icon over label, in a ruled modular row.
/// Replaces `EditorToolbar.ToolbarButton`'s rounded pill. The label is flush
/// left with the icon, both leading-aligned, per the system's alignment rule.
struct ModernistToolbarButtonStyle: ButtonStyle {
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, isProminent: isProminent)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        let isProminent: Bool
        @Environment(\.modernistPalette) private var palette
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Modernist.Typography.caption.weight(Modernist.Typography.emphasisWeight))
                .foregroundStyle(isProminent ? palette.onAccent : palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: Modernist.minHitTarget + Modernist.Space.s2)
                .padding(.horizontal, Modernist.Space.s2)
                .background(
                    isProminent
                        ? (configuration.isPressed ? palette.accentPressed : palette.accent)
                        : (configuration.isPressed ? palette.accentTint : palette.surfaceRaised)
                )
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Tag

/// `.tag` and its variants. The scheme is mono, so `.accent2` reads the same as
/// `.accent` — kept only so both token sets resolve.
struct ModernistTag: View {
    enum Variant { case accent, neutral, outline }

    let text: String
    var variant: Variant = .neutral

    @Environment(\.modernistPalette) private var palette

    var body: some View {
        Text(text)
            .font(Modernist.Typography.caption.weight(Modernist.Typography.emphasisWeight))
            .textCase(.uppercase)
            .tracking(Modernist.Typography.labelTracking * 0.7)
            .foregroundStyle(variant == .accent ? palette.accentText : palette.text)
            .padding(.horizontal, Modernist.Space.s2)
            .padding(.vertical, Modernist.Space.s1)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: Modernist.Radius.sm)
                    .strokeBorder(
                        variant == .outline ? palette.divider : Color.clear,
                        lineWidth: Modernist.ruleWidth
                    )
            )
    }

    private var background: Color {
        switch variant {
        case .accent: return palette.accentTint
        case .neutral: return palette.surfaceRaised
        case .outline: return .clear
        }
    }
}

// MARK: - Rules, cards, elevation, imagery, type

extension View {

    /// `.hr` — the strong 2px rule, drawn on the bottom edge. Between major
    /// sections. Never soften it, never drop it for whitespace.
    func modernistRule(_ edge: VerticalAlignment = .bottom) -> some View {
        modifier(ModernistRule(edge: edge))
    }

    /// `.card` — a surface-filled block, square corners, flush-left content.
    func modernistCard(padding: CGFloat = Modernist.Space.s4) -> some View {
        modifier(ModernistCard(padding: padding))
    }

    /// `.elev-sm` / `.elev-md` / `.elev-lg`, on the current ground.
    func modernistElevation(_ level: Modernist.Elevation) -> some View {
        modifier(ModernistElevation(level: level))
    }

    /// `.grayscale` — every content photograph and every video thumbnail goes
    /// through this. Pure black and white, never tinted or colorized.
    func modernistGrayscale() -> some View {
        grayscale(1).contrast(1.08)
    }

    /// The `h6` micro-label: uppercase, tracked, flush left. Section headers
    /// ("PRESET", "RENDER", "PLAYBACK", "SKIPPED PROJECTS").
    func modernistLabel() -> some View {
        modifier(ModernistLabel())
    }

    /// A heading at the system's line-height and negative tracking, flush left.
    func modernistHeading(_ font: Font) -> some View {
        self
            .font(font)
            .tracking(Modernist.Typography.headingTracking)
            .lineSpacing(Modernist.Typography.headingLineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Body copy at the system's 1.55 line-height, flush left.
    func modernistBody() -> some View {
        self
            .font(Modernist.Typography.body)
            .lineSpacing(Modernist.Typography.bodyLineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ModernistRule: ViewModifier {
    let edge: VerticalAlignment
    @Environment(\.modernistPalette) private var palette

    func body(content: Content) -> some View {
        content.overlay(alignment: edge == .top ? .top : .bottom) {
            Rectangle()
                .fill(palette.divider)
                .frame(height: Modernist.ruleWidth)
        }
    }
}

private struct ModernistCard: ViewModifier {
    let padding: CGFloat
    @Environment(\.modernistPalette) private var palette

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Modernist.Radius.md))
    }
}

private struct ModernistElevation: ViewModifier {
    let level: Modernist.Elevation
    @Environment(\.modernistPalette) private var palette

    func body(content: Content) -> some View {
        content.shadow(
            color: palette.shadowColor(level),
            radius: level.radius,
            x: level.x,
            y: level.y
        )
    }
}

private struct ModernistLabel: ViewModifier {
    @Environment(\.modernistPalette) private var palette

    func body(content: Content) -> some View {
        content
            .font(Modernist.Typography.h6)
            .textCase(.uppercase)
            .tracking(Modernist.Typography.labelTracking)
            .foregroundStyle(palette.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Segmented control

/// `.seg` / `.seg-opt` — square, ruled, flush-left labels.
///
/// SwiftUI's own `.segmented` picker style is a rounded capsule that can't be
/// squared off or retinted, so the system draws its own. Use for the inspector's
/// Transform / Opacity / Filters tabs, the overlay sheet's Text / Image /
/// Sticker tabs, and Settings' haptic intensity.
struct ModernistSegmentedControl<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    @Environment(\.modernistPalette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(Modernist.Typography.bodyEmphasis)
                        .foregroundStyle(
                            selection == option.value ? palette.onAccent : palette.text
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: Modernist.minHitTarget)
                        .padding(.horizontal, Modernist.Space.s3)
                        .background(
                            selection == option.value ? palette.accent : palette.surface
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option.value ? [.isSelected] : [])

                if index < options.count - 1 {
                    Rectangle()
                        .fill(palette.divider)
                        .frame(width: Modernist.ruleWidth)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Modernist.Radius.sm)
                .strokeBorder(palette.divider, lineWidth: Modernist.ruleWidth)
        )
    }
}

// MARK: - Slider

/// The inspector / sheet slider: a square 2px-tall track, square accent fill,
/// square thumb. SwiftUI's `Slider` is a capsule with a circular thumb and
/// can't be reshaped, so parameter rows use this instead.
///
/// Ships the label + value row too, since every call site in the app pairs them
/// ("Scale … 1.24×", "SIZE … 56 pt").
struct ModernistSlider: View {
    let label: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    /// Formatted readout, right-aligned. `nil` hides the value column.
    var valueText: String?

    @Environment(\.modernistPalette) private var palette

    private var fraction: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat((value - range.lowerBound) / span)
    }

    var body: some View {
        HStack(spacing: Modernist.Space.s3) {
            Text(label)
                .font(Modernist.Typography.body)
                .foregroundStyle(palette.textMuted)
                .frame(width: 64, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(palette.divider)
                        .frame(height: Modernist.ruleWidth)
                    Rectangle()
                        .fill(palette.accent)
                        .frame(width: geo.size.width * fraction, height: Modernist.ruleWidth)
                    Rectangle()
                        .fill(palette.text)
                        .frame(width: Modernist.Space.s2, height: Modernist.Space.s4)
                        .offset(x: (geo.size.width - Modernist.Space.s2) * fraction)
                }
                .frame(height: Modernist.minHitTarget)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { drag in
                        let f = max(0, min(1, drag.location.x / geo.size.width))
                        value = range.lowerBound + Double(f) * (range.upperBound - range.lowerBound)
                    }
                )
            }
            .frame(height: Modernist.minHitTarget)

            if let valueText {
                Text(valueText)
                    .font(Modernist.Typography.numeric)
                    .foregroundStyle(palette.textMuted)
                    .frame(width: 48, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(valueText ?? "")
    }
}
