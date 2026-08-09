import SwiftUI

/// Modernist — the design system's tokens, expressed in Swift.
///
/// Mirrors the `:root` block of the system's `styles.css` one-for-one (a copy of
/// that file ships alongside this one in `reference/`). This is the single
/// source of truth for the app's look: nothing outside this file hard-codes a
/// hex, a point size, a corner radius or a shadow.
///
/// Direction, from the system's own guide: flat and architectural, set entirely
/// in Archivo, near-mono red, a visible modular grid, **zero** corner radius,
/// and 2px rules doing the organising. Nothing floats and nothing is decorated —
/// alignment and the strength of the dividers do all the work.
enum Modernist {

    // MARK: - Spacing

    /// Density is 1.00×; the scale carries it. Use these, never a raw number.
    /// CSS names preserved so the two files stay diffable.
    enum Space {
        static let s1: CGFloat = 4
        static let s2: CGFloat = 8
        static let s3: CGFloat = 12
        static let s4: CGFloat = 16
        static let s6: CGFloat = 24
        static let s8: CGFloat = 32
    }

    // MARK: - Radius

    /// Zero everywhere, on purpose. Kept as tokens rather than literal `0` so a
    /// call site reads as a deliberate system value. Do not round a corner.
    enum Radius {
        static let sm: CGFloat = 0
        static let md: CGFloat = 0
        static let lg: CGFloat = 0
    }

    // MARK: - Rules

    /// Dividers are 2px, always — never a hairline, never dropped for
    /// whitespace. `0.5`/`1`pt separators elsewhere in the app are migrated to
    /// this value.
    static let ruleWidth: CGFloat = 2

    /// `:focus-visible { outline: 2px solid accent; outline-offset: 2px }`
    static let focusRingWidth: CGFloat = 2
    static let focusRingOffset: CGFloat = 2

    /// Minimum hit target. The system's own metrics are tighter than iOS wants;
    /// interactive controls pad out to this.
    static let minHitTarget: CGFloat = 44

    /// A non-interactive colour swatch block — the chroma-key sheet's key
    /// preview. Bigger than the hit target because it's read, not tapped.
    /// Added by the v0.8 Tier 2 sweep, which had no token for the existing
    /// 64pt block.
    static let swatchSize: CGFloat = 64

    // MARK: - Stage & scrim
    //
    // Two values the CSS never had to carry: it never letterboxed video and
    // never dimmed a modal backdrop. Both are reference surfaces rather than
    // UI grounds, so neither may take a ground-tinted neutral.

    /// True black. The preview stage's letterbox is the field the user grades
    /// colour against — tinting it with `bg` (`#0C0C0E`) would bias that
    /// judgement, which is the same functional regression Decision 5 forbids
    /// for grayscale. Added by the v0.8 Tier 2 sweep so the stage stops
    /// writing `Color.black` at the call site.
    static let stageInk = Color(hex: 0x000000)

    /// The approved design dims the editor to 55% black behind a modal.
    /// Added by the v0.8 Tier 2 sweep — the loading scrim was an inline
    /// `Color.black.opacity(0.4)`.
    static let scrimOpacity: Double = 0.55

    // MARK: - Tonal ramps
    //
    // Generated in OKLCH on one shared lightness scale, so the same step of any
    // role matches the others in visual value. Use 100–300 for tinted fills and
    // subtle borders, 500 as the base, 700–900 for text on tinted fills and for
    // pressed states. Reach for a ramp step before reaching for `.opacity(_:)`.

    enum Neutral {
        static let n100 = Color(hex: 0xF8F4F4)
        static let n200 = Color(hex: 0xEAE7E7)
        static let n300 = Color(hex: 0xD7D3D3)
        static let n400 = Color(hex: 0xBAB6B6)
        static let n500 = Color(hex: 0x9B9797)
        static let n600 = Color(hex: 0x7D7979)
        static let n700 = Color(hex: 0x605D5D)
        static let n800 = Color(hex: 0x444141)
        static let n900 = Color(hex: 0x2D2B2B)
    }

    enum Accent {
        static let a100 = Color(hex: 0xFFF2EF)
        static let a200 = Color(hex: 0xFFE0D9)
        static let a300 = Color(hex: 0xFFC4B8)
        /// Pressed step on a dark ground (the guide's rule).
        static let a400 = Color(hex: 0xFF9783)
        /// The accent's base on a dark ground.
        static let a500 = Color(hex: 0xFF563C)
        /// Pressed step on a light ground.
        static let a600 = Color(hex: 0xDD2B0F)
        /// Paragraph-size accent text — the base only clears 3:1.
        static let a700 = Color(hex: 0xAE1800)
        static let a800 = Color(hex: 0x7C1405)
        static let a900 = Color(hex: 0x4D170E)
    }

    // MARK: - Elevation

    /// Ink-tinted shadows tuned to the ground. Three steps, no ad-hoc shadows.
    /// The studio surround needs a deeper ambient than the print ground, so
    /// `Palette` carries its own multiplier — see `elevationOpacity`.
    struct Elevation {
        let baseOpacity: Double
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat

        static let sm = Elevation(baseOpacity: 0.14, radius: 2, x: 0, y: 1)
        static let md = Elevation(baseOpacity: 0.16, radius: 10, x: 0, y: 3)
        static let lg = Elevation(baseOpacity: 0.22, radius: 32, x: 0, y: 12)
    }

    // MARK: - Type
    //
    // Archivo over Archivo, weights 400 / 600 / 800. Bundle the family in the
    // app target and list it under `UIAppFonts` in Info.plist. Density moves
    // spacing, not sizes — the scale is fixed and matches the CSS h1…h6 / body.

    enum Typography {
        static let family = "Archivo"
        static let headingWeight: Font.Weight = .heavy      // 800
        static let emphasisWeight: Font.Weight = .semibold  // 600
        static let bodyWeight: Font.Weight = .regular       // 400

        /// `true` once the family is bundled; drives the fallback below.
        static var isFamilyBundled: Bool {
            #if canImport(UIKit)
            return UIFont(name: family, size: 12) != nil
            #else
            return NSFont(name: family, size: 12) != nil
            #endif
        }

        /// Every text style routes through here, so a missing font degrades to
        /// the system face at the same size and weight rather than silently
        /// falling back to a different scale.
        static func font(size: CGFloat, weight: Font.Weight) -> Font {
            isFamilyBundled
                ? .custom(family, fixedSize: size).weight(weight)
                : .system(size: size, weight: weight)
        }

        static var h1: Font { font(size: 42, weight: headingWeight) }
        static var h2: Font { font(size: 32, weight: headingWeight) }
        static var h3: Font { font(size: 25, weight: headingWeight) }
        static var h4: Font { font(size: 20, weight: headingWeight) }
        static var h5: Font { font(size: 16, weight: headingWeight) }
        /// The uppercase micro-label — see `.modernistLabel()`.
        static var h6: Font { font(size: 13, weight: headingWeight) }

        static var body: Font { font(size: 15, weight: bodyWeight) }
        static var bodyEmphasis: Font { font(size: 15, weight: emphasisWeight) }
        static var buttonLabel: Font { font(size: 15, weight: emphasisWeight) }
        static var caption: Font { font(size: 11, weight: bodyWeight) }
        /// Timecodes, durations, percentages, px/s readouts. Tabular, always.
        static var numeric: Font { font(size: 11, weight: bodyWeight).monospacedDigit() }

        /// Display glyph sizes.
        ///
        /// SF Symbols sit outside the CSS type scale — they're set with
        /// `.system(size:weight:)`, not a text style — but a bare
        /// `.font(.system(size: 40))` at a call site is still a literal. These
        /// name the five sizes the app's empty-state and status glyphs
        /// already used, so the v0.8 Tier 4 sweep could keep every size
        /// pixel-identical while removing the literals. Weight comes from the
        /// scale (`headingWeight`), which is the part that actually changed.
        enum Glyph {
            static let sm: CGFloat = 22
            static let md: CGFloat = 32
            static let lg: CGFloat = 40
            static let xl: CGFloat = 48
            static let xxl: CGFloat = 56
        }

        /// CSS gives line-height as a multiple; SwiftUI takes the delta.
        static func lineSpacing(forSize size: CGFloat, multiple: CGFloat) -> CGFloat {
            (size * multiple) - size
        }

        static let bodyLineSpacing = lineSpacing(forSize: 15, multiple: 1.55)
        static let headingLineSpacing = lineSpacing(forSize: 25, multiple: 1.12)
        /// Headings carry `letter-spacing: -0.015em`.
        static let headingTracking: CGFloat = -0.015 * 25
        /// The `h6` micro-label's `letter-spacing: 0.08em`.
        static let labelTracking: CGFloat = 0.08 * 13
    }
}

// MARK: - Palettes

/// The system's color roles for one ground.
///
/// Two instances ship: `.print` is the system as authored (light ground, the one
/// red), used for every piece of app chrome — library, sheets, settings, export.
/// `.studio` is the same system on the dark grading surround the editor needs;
/// footage can't be colour-judged against a light field, so the editor stage
/// keeps its dark ground and takes Modernist's *structure* — zero radius, 2px
/// rules, flush-left labels, Archivo, one accent — rather than its ground.
///
/// Both are real Modernist: same ramps, same accent, same geometry. Choosing
/// between them is a matter of which surface you're on, never taste.
struct ModernistPalette: Equatable {

    /// The page ground.
    var bg: Color
    /// A block sitting on the ground — `.card`, a grouped list, a sheet.
    var surface: Color
    /// A block sitting on a surface — an inspector inside a sheet, a row inside
    /// a card. The print ground has only two levels; the studio needs three.
    var surfaceRaised: Color
    var text: Color
    /// Secondary copy — the CSS `color-mix(text 55%)`.
    var textMuted: Color
    /// The 2px rule — the CSS `color-mix(text 40%)`.
    var divider: Color
    /// The one accent. Primary actions, active states, small emphasis.
    var accent: Color
    /// One ramp step past the base, per the guide: `a600` on light, `a400` on dark.
    var accentPressed: Color
    /// A tinted fill derived from the accent — selected rows, active segments.
    var accentTint: Color
    /// Legible paragraph-size accent text. The base accent only clears 3:1.
    var accentText: Color
    /// What sits on top of a solid accent fill.
    var onAccent: Color
    /// Shadow ink, and how much of the `Elevation` opacity to use.
    var shadowInk: Color
    var elevationScale: Double

    /// The system as authored. App chrome: library, sheets, settings, export.
    static let print = ModernistPalette(
        bg: Color(hex: 0xF3F2F2),
        surface: Color(hex: 0xEAE9E9),
        surfaceRaised: Modernist.Neutral.n100,
        text: Color(hex: 0x201E1D),
        textMuted: Color(hex: 0x201E1D).opacity(0.55),
        divider: Color(hex: 0x201E1D).opacity(0.40),
        accent: Color(hex: 0xEC3013),
        accentPressed: Modernist.Accent.a600,
        accentTint: Modernist.Accent.a200,
        accentText: Modernist.Accent.a700,
        onAccent: Color(hex: 0xF3F2F2),
        shadowInk: Modernist.Neutral.n900,
        elevationScale: 1.0
    )

    /// The editor's grading surround. Same system, dark ground.
    static let studio = ModernistPalette(
        bg: Color(hex: 0x0C0C0E),
        surface: Color(hex: 0x151517),
        surfaceRaised: Color(hex: 0x1D1D20),
        text: Color(hex: 0xFFFFFF),
        textMuted: Color.white.opacity(0.55),
        divider: Color.white.opacity(0.40),
        accent: Modernist.Accent.a500,
        accentPressed: Modernist.Accent.a400,
        accentTint: Modernist.Accent.a500.opacity(0.18),
        accentText: Modernist.Accent.a400,
        onAccent: Color(hex: 0x201E1D),
        shadowInk: .black,
        elevationScale: 2.2
    )
}

extension ModernistPalette {
    /// A shadow color for one elevation step on this ground.
    func shadowColor(_ level: Modernist.Elevation) -> Color {
        shadowInk.opacity(min(level.baseOpacity * elevationScale, 0.85))
    }
}

// MARK: - Environment

private struct ModernistPaletteKey: EnvironmentKey {
    static let defaultValue: ModernistPalette = .print
}

extension EnvironmentValues {
    /// The ground the current subtree is drawn on. Set it once per surface with
    /// `.modernistSurface(.studio)`; every style below reads it, so no call site
    /// has to pass a palette around.
    var modernistPalette: ModernistPalette {
        get { self[ModernistPaletteKey.self] }
        set { self[ModernistPaletteKey.self] = newValue }
    }
}

// MARK: - Hex convenience

extension Color {
    /// `Color(hex: 0xEC3013)` — sRGB, so values match the CSS exactly.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
