import SwiftUI

// The design system's component layer as SwiftUI styles and modifiers.
//
// `styles.css` ships classes (`.btn-primary`, `.btn-secondary`, `.btn-ghost`,
// `.btn-icon`, `.tag`, `.card`, `.hr`, `.grayscale`, `.elev-*`, `.seg`);
// SwiftUI's equivalents are `ButtonStyle`s, `ViewModifier`s and `View`
// extensions. Same names, one-for-one.
//
// Every style reads `\.reelPalette` from the environment, so the same
// button renders correctly on the light chrome and on the dark editor surround
// without a call site ever naming a color. Set the ground once per surface:
//
//     LibraryView().reelSurface(.print)
//     EditorView().reelSurface(.studio)
//
// No literal colors, sizes, radii or shadows below — everything comes from
// `Reel.*`.

// MARK: - Surface

extension View {
    /// Establishes the ground for a subtree: sets the palette in the
    /// environment, paints the background, and tints the standard controls.
    /// Apply once per screen, at the root.
    func reelSurface(_ palette: ReelPalette) -> some View {
        environment(\.reelPalette, palette)
            .background(palette.bg.ignoresSafeArea())
            .tint(palette.accent)
            .foregroundStyle(palette.text)
            // v0.8.2 — every screen root already calls this, so it is the one
            // place the Dynamic Type clamp belongs. Setting it per-screen would
            // guarantee a screen gets missed.
            .dynamicTypeSize(...Reel.maxDynamicTypeSize)
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
struct ReelPrimaryButtonStyle: ButtonStyle {
    /// `.btn-block` — fills the available width. `false` hugs the label.
    var isBlock: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, isBlock: isBlock)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        let isBlock: Bool
        @Environment(\.reelPalette) private var palette
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Reel.Typography.buttonLabel)
                .foregroundStyle(palette.onAccent)
                .padding(.horizontal, Reel.Space.s4)
                .padding(.vertical, Reel.Space.s3)
                .frame(maxWidth: isBlock ? .infinity : nil, alignment: .leading)
                .frame(minHeight: Reel.minHitTarget)
                .background(configuration.isPressed ? palette.accentPressed : palette.accent)
                .clipShape(RoundedRectangle(cornerRadius: palette.radius.md))
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(Rectangle())
        }
    }
}

/// `.btn.btn-secondary` — outlined in a 2px accent rule, accent label.
/// Also the destructive treatment: in a mono scheme the accent *is* the red, so
/// Delete is the outlined variant with a trash icon, never a second red fill.
struct ReelSecondaryButtonStyle: ButtonStyle {
    var isBlock: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, isBlock: isBlock)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        let isBlock: Bool
        @Environment(\.reelPalette) private var palette
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Reel.Typography.buttonLabel)
                .foregroundStyle(palette.accentText)
                .padding(.horizontal, Reel.Space.s4)
                .padding(.vertical, Reel.Space.s3)
                .frame(maxWidth: isBlock ? .infinity : nil, alignment: .leading)
                .frame(minHeight: Reel.minHitTarget)
                .background(configuration.isPressed ? palette.accentTint : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: palette.radius.md)
                        .strokeBorder(palette.accent, lineWidth: palette.ruleWidth)
                )
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(Rectangle())
        }
    }
}

/// `.btn.btn-ghost` — no fill, no rule, ink label; a tint on press.
struct ReelGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        @Environment(\.reelPalette) private var palette
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Reel.Typography.buttonLabel)
                .foregroundStyle(palette.text)
                .padding(.horizontal, Reel.Space.s3)
                .padding(.vertical, Reel.Space.s2)
                .frame(minHeight: Reel.minHitTarget, alignment: .leading)
                .background(configuration.isPressed ? palette.accentTint : Color.clear)
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(Rectangle())
        }
    }
}

/// `.btn-icon` — the square icon button, padded to the hit target.
struct ReelIconButtonStyle: ButtonStyle {
    /// `true` gives the accent fill (the editor's Export slot); `false` the
    /// surface fill (undo / redo / back / settings).
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, isProminent: isProminent)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        let isProminent: Bool
        @Environment(\.reelPalette) private var palette
        @Environment(\.isEnabled) private var isEnabled

        private var fill: Color {
            if isProminent {
                return configuration.isPressed ? palette.accentPressed : palette.accent
            }
            return configuration.isPressed ? palette.accentTint : palette.surface
        }

        var body: some View {
            configuration.label
                .font(Reel.Typography.bodyEmphasis)
                .foregroundStyle(isProminent ? palette.onAccent : palette.text)
                .frame(width: Reel.minHitTarget, height: Reel.minHitTarget)
                .background(fill)
                .clipShape(RoundedRectangle(cornerRadius: palette.radius.sm))
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(Rectangle())
        }
    }
}

/// The editor's toolbar cell — icon over label, in a ruled modular row.
/// Replaces `EditorToolbar.ToolbarButton`'s rounded pill. The label is flush
/// left with the icon, both leading-aligned, per the system's alignment rule.
struct ReelToolbarButtonStyle: ButtonStyle {
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, isProminent: isProminent)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        let isProminent: Bool
        @Environment(\.reelPalette) private var palette
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Reel.Typography.caption.weight(Reel.Typography.emphasisWeight))
                .foregroundStyle(isProminent ? palette.onAccent : palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: Reel.minHitTarget + Reel.Space.s2)
                .padding(.horizontal, Reel.Space.s2)
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
struct ReelTag: View {
    enum Variant { case accent, neutral, outline }

    let text: String
    var variant: Variant = .neutral

    @Environment(\.reelPalette) private var palette

    var body: some View {
        Text(text)
            .font(Reel.Typography.caption.weight(Reel.Typography.emphasisWeight))
            .textCase(.uppercase)
            .tracking(Reel.Typography.labelTracking * 0.7)
            .foregroundStyle(variant == .accent ? palette.accentText : palette.text)
            .padding(.horizontal, Reel.Space.s2)
            .padding(.vertical, Reel.Space.s1)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: palette.radius.sm)
                    .strokeBorder(
                        variant == .outline ? palette.divider : Color.clear,
                        lineWidth: palette.ruleWidth
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
    func reelRule(_ edge: VerticalAlignment = .bottom) -> some View {
        modifier(ReelRule(edge: edge))
    }

    /// `.card` — a surface-filled block, square corners, flush-left content.
    func reelCard(padding: CGFloat = Reel.Space.s4) -> some View {
        modifier(ReelCard(padding: padding))
    }

    /// `.elev-sm` / `.elev-md` / `.elev-lg`, on the current ground.
    func reelElevation(_ level: Reel.Elevation) -> some View {
        modifier(ReelElevation(level: level))
    }

    /// `.grayscale` — every content photograph and every video thumbnail goes
    /// through this. Pure black and white, never tinted or colorized.
    func reelGrayscale() -> some View {
        grayscale(1).contrast(1.08)
    }

    /// The `h6` micro-label: uppercase, tracked, flush left. Section headers
    /// ("PRESET", "RENDER", "PLAYBACK", "SKIPPED PROJECTS").
    func reelLabel() -> some View {
        modifier(ReelLabel())
    }

    /// A heading at the system's line-height and negative tracking, flush left.
    func reelHeading(_ font: Font) -> some View {
        self
            .font(font)
            .tracking(Reel.Typography.headingTracking)
            .lineSpacing(Reel.Typography.headingLineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Body copy at the system's 1.55 line-height, flush left.
    func reelBody() -> some View {
        self
            .font(Reel.Typography.body)
            .lineSpacing(Reel.Typography.bodyLineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ReelRule: ViewModifier {
    let edge: VerticalAlignment
    @Environment(\.reelPalette) private var palette

    func body(content: Content) -> some View {
        content.overlay(alignment: edge == .top ? .top : .bottom) {
            Rectangle()
                .fill(palette.divider)
                .frame(height: palette.ruleWidth)
        }
    }
}

private struct ReelCard: ViewModifier {
    let padding: CGFloat
    @Environment(\.reelPalette) private var palette

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: palette.radius.md))
    }
}

private struct ReelElevation: ViewModifier {
    let level: Reel.Elevation
    @Environment(\.reelPalette) private var palette

    func body(content: Content) -> some View {
        content.shadow(
            color: palette.shadowColor(level),
            radius: level.radius,
            x: level.x,
            y: level.y
        )
    }
}

private struct ReelLabel: ViewModifier {
    @Environment(\.reelPalette) private var palette

    func body(content: Content) -> some View {
        content
            .font(Reel.Typography.h6)
            .textCase(.uppercase)
            .tracking(Reel.Typography.labelTracking)
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
struct ReelSegmentedControl<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    @Environment(\.reelPalette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(Reel.Typography.bodyEmphasis)
                        .foregroundStyle(
                            selection == option.value ? palette.onAccent : palette.text
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: Reel.minHitTarget)
                        .padding(.horizontal, Reel.Space.s3)
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
                        .frame(width: palette.ruleWidth)
                }
            }
        }
        // Clip before the border goes on. The segment fills are square and
        // run to the control's edge, so on a ground with a radius they
        // overflow the rounded border and square off its corners. On the
        // editor's ground the radius is 0 and this is a no-op — which is
        // why the bug only appeared once chrome started rounding.
        .clipShape(RoundedRectangle(cornerRadius: palette.radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: palette.radius.sm)
                .strokeBorder(palette.divider, lineWidth: palette.ruleWidth)
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
///
/// Drawing our own track costs us the two things `Slider` gave for free, so
/// both are restated here rather than at the twelve call sites:
///
/// - **VoiceOver adjustability.** A bare `DragGesture` is unreachable without
///   sight; `.accessibilityAdjustableAction` is what makes swipe-up /
///   swipe-down move the value. Fixed once here, inherited everywhere.
/// - **Quantization.** `Slider(value:in:step:)` snapped the value; a raw drag
///   maps pixels straight to `Double` and can persist fractions a readout only
///   rounds for display. `step` restores the snap.
///
/// The two are one mechanism: the step that quantizes a drag is the same step
/// an adjustable action moves by, so they can't drift apart.
struct ReelSlider: View {
    let label: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    /// Quantization, in value units. `nil` leaves the value continuous — the
    /// behaviour of a `Slider` with no `step:` argument.
    var step: Double?
    /// Formatted readout, right-aligned. `nil` hides the value column.
    var valueText: String?

    @Environment(\.reelPalette) private var palette

    private var fraction: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat((value - range.lowerBound) / span)
    }

    /// How far one VoiceOver swipe moves the value.
    ///
    /// A quantized slider moves by exactly one step — landing anywhere else
    /// would put the value off the grid the drag handler snaps to. A
    /// continuous one moves by a twentieth of its span, so a full traverse is
    /// twenty swipes on every slider in the app regardless of its units.
    nonisolated static func adjustmentStep(
        range: ClosedRange<Double>,
        step: Double?
    ) -> Double {
        if let step, step > 0 { return step }
        return (range.upperBound - range.lowerBound) / 20
    }

    /// Snaps a raw value onto the step grid (when there is one) and clamps it
    /// into `range`.
    ///
    /// Both the drag handler and the adjustable action resolve through here,
    /// which is the whole point: a value reachable by dragging is reachable by
    /// VoiceOver and vice versa.
    nonisolated static func resolve(
        _ raw: Double,
        range: ClosedRange<Double>,
        step: Double?
    ) -> Double {
        var resolved = raw
        if let step, step > 0 {
            let steps = ((raw - range.lowerBound) / step).rounded()
            resolved = range.lowerBound + steps * step
        }
        return min(max(resolved, range.lowerBound), range.upperBound)
    }

    /// The adjustable action's landing value for one swipe in `direction`.
    /// Factored out so the arithmetic is assertable without a host.
    nonisolated static func adjusted(
        _ current: Double,
        direction: AccessibilityAdjustmentDirection,
        range: ClosedRange<Double>,
        step: Double?
    ) -> Double {
        let delta = adjustmentStep(range: range, step: step)
        switch direction {
        case .increment: return resolve(current + delta, range: range, step: step)
        case .decrement: return resolve(current - delta, range: range, step: step)
        @unknown default: return resolve(current, range: range, step: step)
        }
    }

    var body: some View {
        HStack(spacing: Reel.Space.s3) {
            Text(label)
                .font(Reel.Typography.body)
                .foregroundStyle(palette.textMuted)
                .frame(width: 64, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(palette.divider)
                        .frame(height: palette.ruleWidth)
                    Rectangle()
                        .fill(palette.accent)
                        .frame(width: geo.size.width * fraction, height: palette.ruleWidth)
                    Rectangle()
                        .fill(palette.text)
                        .frame(width: Reel.Space.s2, height: Reel.Space.s4)
                        .offset(x: (geo.size.width - Reel.Space.s2) * fraction)
                }
                .frame(height: Reel.minHitTarget)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { drag in
                        let f = max(0, min(1, drag.location.x / geo.size.width))
                        let raw = range.lowerBound
                            + Double(f) * (range.upperBound - range.lowerBound)
                        value = Self.resolve(raw, range: range, step: step)
                    }
                )
            }
            .frame(height: Reel.minHitTarget)

            if let valueText {
                Text(valueText)
                    .font(Reel.Typography.numeric)
                    .foregroundStyle(palette.textMuted)
                    .frame(width: 48, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(valueText ?? "")
        // The migration's one real functional loss: `Slider` is adjustable to
        // VoiceOver out of the box, a `DragGesture` is not. Without this the
        // control has a name and a value and no way to change either.
        .accessibilityAdjustableAction { direction in
            value = Self.adjusted(value, direction: direction, range: range, step: step)
        }
    }
}
