import SwiftUI

/// Reel — the Modernist design system's tokens, expressed in Swift.
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
enum Reel {

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

        /// Every text style routes through here.
        ///
        /// **v0.8.2 — Dynamic Type.** This used `fixedSize:`, which pins the
        /// size and ignores the user's text-size setting entirely. Before the
        /// design migration the app used system text styles and scaled for
        /// free; the fixed scale silently removed that, which made Dynamic Type
        /// not merely un-audited but actively unsupported.
        ///
        /// `relativeTo:` restores it. Each role names the system text style
        /// whose default size sits nearest its own, so the growth curve is the
        /// one users already know from every other app.
        ///
        /// Growth is bounded — see ``Reel/maxDynamicTypeSize``, applied once in
        /// `.reelSurface(_:)`. Unbounded, the Modernist proportions come apart:
        /// a 42pt h1 at accessibility5 is roughly 100pt, and the grid was drawn
        /// against fixed sizes.
        ///
        /// The `fixedSize:` branch on `isFamilyBundled` is gone deliberately.
        /// `.custom` already falls back to the system face at the requested
        /// size when the family is missing — and unlike the old branch, the
        /// fallback now scales too. `isFamilyBundled` stays as a diagnostic and
        /// is asserted by `ReelTypographyTests`.
        static func font(
            size: CGFloat,
            weight: Font.Weight,
            relativeTo style: Font.TextStyle
        ) -> Font {
            .custom(family, size: size, relativeTo: style).weight(weight)
        }

        // Each role is paired with the system text style whose default size is
        // nearest its own, so scaling follows a familiar curve rather than an
        // invented one.
        static var h1: Font { font(size: 42, weight: headingWeight, relativeTo: .largeTitle) }
        static var h2: Font { font(size: 32, weight: headingWeight, relativeTo: .title) }
        static var h3: Font { font(size: 25, weight: headingWeight, relativeTo: .title2) }
        static var h4: Font { font(size: 20, weight: headingWeight, relativeTo: .title3) }
        static var h5: Font { font(size: 16, weight: headingWeight, relativeTo: .headline) }
        /// The uppercase micro-label — see `.reelLabel()`.
        static var h6: Font { font(size: 13, weight: headingWeight, relativeTo: .caption) }

        static var body: Font { font(size: 15, weight: bodyWeight, relativeTo: .body) }
        static var bodyEmphasis: Font { font(size: 15, weight: emphasisWeight, relativeTo: .body) }
        static var buttonLabel: Font { font(size: 15, weight: emphasisWeight, relativeTo: .body) }
        static var caption: Font { font(size: 11, weight: bodyWeight, relativeTo: .caption2) }
        /// Timecodes, durations, percentages, px/s readouts. Tabular, always.
        static var numeric: Font {
            font(size: 11, weight: bodyWeight, relativeTo: .caption2).monospacedDigit()
        }

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
struct ReelPalette: Equatable {

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
    static let print = ReelPalette(
        bg: Color(hex: 0xF3F2F2),
        surface: Color(hex: 0xEAE9E9),
        surfaceRaised: Reel.Neutral.n100,
        text: Color(hex: 0x201E1D),
        textMuted: Color(hex: 0x201E1D).opacity(0.55),
        divider: Color(hex: 0x201E1D).opacity(0.40),
        accent: Color(hex: 0xEC3013),
        accentPressed: Reel.Accent.a600,
        accentTint: Reel.Accent.a200,
        accentText: Reel.Accent.a700,
        onAccent: Color(hex: 0xF3F2F2),
        shadowInk: Reel.Neutral.n900,
        elevationScale: 1.0
    )

    /// The editor's grading surround. Same system, dark ground.
    static let studio = ReelPalette(
        bg: Color(hex: 0x0C0C0E),
        surface: Color(hex: 0x151517),
        surfaceRaised: Color(hex: 0x1D1D20),
        text: Color(hex: 0xFFFFFF),
        textMuted: Color.white.opacity(0.55),
        divider: Color.white.opacity(0.40),
        accent: Reel.Accent.a500,
        accentPressed: Reel.Accent.a400,
        accentTint: Reel.Accent.a500.opacity(0.18),
        accentText: Reel.Accent.a400,
        onAccent: Color(hex: 0x201E1D),
        shadowInk: .black,
        elevationScale: 2.2
    )
}

extension ReelPalette {
    /// A shadow color for one elevation step on this ground.
    func shadowColor(_ level: Reel.Elevation) -> Color {
        shadowInk.opacity(min(level.baseOpacity * elevationScale, 0.85))
    }
}

// MARK: - Environment

private struct ReelPaletteKey: EnvironmentKey {
    static let defaultValue: ReelPalette = .print
}

extension EnvironmentValues {
    /// The ground the current subtree is drawn on. Set it once per surface with
    /// `.reelSurface(.studio)`; every style below reads it, so no call site
    /// has to pass a palette around.
    var reelPalette: ReelPalette {
        get { self[ReelPaletteKey.self] }
        set { self[ReelPaletteKey.self] = newValue }
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

// MARK: - Tier 5 additions (studio squad)
//
// Metrics the approved design names for the *editor* bands specifically, which
// the CSS never had to carry (it describes a print system; none of these
// surfaces exist there). Every one is a value the editor call sites would
// otherwise write as a literal. Appended at the end of the file so the print
// squad's parallel additions and these never collide.

extension Reel {

    /// The auto-save status dot in the editor nav bar's second title line.
    /// The design draws a 5pt disc; nothing on the 4/8/12/16/24/32 spacing
    /// scale lands there, and rounding it to `Space.s1` reads as a speck.
    /// Decision 4 recolours it to `Neutral.n400` — status is not an accent job.
    static let navStatusDotSize: CGFloat = 5

    /// The unavailable step of the editor's undo/redo cell pair.
    ///
    /// **Exception, recorded deliberately.** The repo-wide disabled convention
    /// is 45% (`ReelStyles`' button styles hard-wire it, and the v0.5
    /// "disabled, never hidden" rule assumes it). The approved design specifies
    /// 28% for *this pair only* — the two cells share one ruled group, so the
    /// unavailable half has to drop further to read as unavailable rather than
    /// as a second live cell. Applies nowhere else; do not generalise it.
    static let pairedControlDisabledOpacity: Double = 0.28

    /// Height of one timeline lane.
    ///
    /// **A compromise, not a preference.** The design specifies three lane
    /// heights — video 44, overlay 18, audio 22 — and `KadrUI.TimelineView`
    /// takes a single `laneHeight` that applies to every lane it draws. The
    /// spec's video lane wins because it is the one the user drags, trims and
    /// reads filmstrips in; the audio lane simply renders taller than drawn.
    /// See the gap list.
    static let timelineLaneHeight: CGFloat = 44

    /// Minimum horizontal distance between two labelled ticks on the app-drawn
    /// tick row. Below this the numerals collide, so the row steps up to the
    /// next coarser interval (1 / 2 / 5 / 10 / 30 / 60s). Also the design's
    /// nominal timeline scale ("48 px/s"), which is where the number comes
    /// from: at the design's own zoom, ticks land exactly one second apart.
    static let timelineTickMinSpacing: CGFloat = 48

    /// How many lanes the timeline band sizes itself for before it stops
    /// growing. `TimelineView` lays lanes out top-down inside whatever frame it
    /// is given and does not scroll vertically, so the band has to name a
    /// ceiling or a music-heavy project would push the stage off-screen.
    static let timelineMaxVisibleLanes = 4

    /// Bottom padding under the editor's toolbar row — the design's safe-area
    /// gutter, so the bottom row of cells clears the home indicator.
    static let toolbarBottomInset: CGFloat = 22

    /// Ceiling on the inspector band's height, so a long parameter list can't
    /// crowd out the stage. Tokenises the literal `320` the inspector areas
    /// have carried since v0.3.
    static let inspectorMaxHeight: CGFloat = 320

    /// Floor on the stage's height once the keyframe + inspector bands appear.
    /// The design shrinks the stage in the clip-selected state but never lets
    /// it collapse; without a floor SwiftUI would happily give it zero.
    static let stageMinHeight: CGFloat = 120
}

// MARK: - Tier 5 additions (print squad)
//
// Metrics the approved design names for the *print-ground* screens — the
// project library and every sheet. Every one of these is a number the CSS
// never had to carry (it describes a print system; a bottom sheet and a video
// duration chip do not exist there) and that a call site would otherwise
// write as a literal. Appended at the very end of the file so this tier's
// parallel sections never collide.

extension Reel {

    // MARK: Project library

    /// The library nav's top inset, as the design measures it: from the top of
    /// the screen, not from the safe area. On every device we ship to, the
    /// status-bar safe-area inset already spends this budget (47–59pt), so the
    /// library renders flush to the safe-area top and this token exists to
    /// document the intent rather than to be added on top of it. Named so a
    /// future edge-to-edge layout that *does* ignore the safe area has the
    /// number to reach for.
    static let libraryTopInset: CGFloat = 52

    /// Height cap for the chroma-key sampling preview. Big enough to aim at a
    /// pixel, small enough to leave the swatch, threshold and help text on
    /// screen in a 400pt sheet.
    static let chromaSampleHeight: CGFloat = 180

    /// Edge of the crosshair marking the last sampled point.
    static let reticleSize: CGFloat = 16

    /// Upper bound on Dynamic Type growth.
    ///
    /// v0.8.2 — the type scale now scales with the user's setting, but not
    /// without limit. The Modernist grid was drawn against fixed sizes: at
    /// `accessibility5` an h1 lands near 100pt, the two-line nav title block
    /// stops fitting beside the undo/redo cells, and the timeline's 44pt clip
    /// cells cannot hold a legible label.
    ///
    /// `accessibility1` is the first accessibility step, so every standard size
    /// is honoured in full plus one step beyond. That is a real limit and worth
    /// naming as one: a user at `accessibility3` gets less than they asked for.
    /// The alternative was honouring it everywhere and letting the layout break,
    /// which serves them worse.
    ///
    /// Applied once, in `.reelSurface(_:)`. Raising it is a one-line change
    /// here — the work is re-checking the layouts, not the token.
    static let maxDynamicTypeSize: DynamicTypeSize = .accessibility1

    /// Edge of a project row's leading thumbnail. Square, per the design.
    static let projectThumbnailSize: CGFloat = 56

    /// The duration chip strip laid across the bottom of a project thumbnail.
    /// Sized to the `numeric` cap height plus its padding; nothing on the
    /// 4/8/12/16/24/32 spacing scale lands there without either clipping the
    /// digits or eating a quarter of the tile.
    static let thumbnailChipHeight: CGFloat = 14

    /// Measure ceiling for a centred empty-state paragraph. Body copy past
    /// ~60 characters per line stops being readable in a centred column.
    static let emptyStateMeasure: CGFloat = 280

    // MARK: Sheets

    /// The sheet grabber — 36×5, drawn by the app rather than by
    /// `presentationDragIndicator`, whose capsule can't be squared off.
    static let sheetGrabberWidth: CGFloat = 36
    static let sheetGrabberHeight: CGFloat = 5

    /// The design's documented bottom-sheet heights.
    ///
    /// The spec gives each sheet a *top inset* measured from the top of a
    /// 430×880 frame. Those are proportions, not absolutes, so each converts
    /// to the fraction of the screen the sheet actually occupies —
    /// `(880 - inset) / 880` — and lands as a `.fraction` detent, which
    /// scales correctly on every device instead of pinning a 430×880 phone.
    enum SheetDetent {
        /// The design's reference frame height.
        private static let referenceHeight: CGFloat = 880

        private static func height(topInset: CGFloat) -> CGFloat {
            (referenceHeight - topInset) / referenceHeight
        }

        /// Export — top inset 250.
        static let export = height(topInset: 250)
        /// Add overlay — top inset 120.
        static let addOverlay = height(topInset: 120)
        /// Layers — top inset 400.
        static let layers = height(topInset: 400)
        /// Settings — top inset 330.
        static let settings = height(topInset: 330)
    }

    // MARK: Export sheet

    /// The preset picker is a 2-up grid.
    static let presetGridColumns = 2

    /// Longest edge of a preset's aspect-ratio glyph — a 2pt-outlined
    /// rectangle drawn at the format's real proportion, so the short edge is
    /// derived from the ratio rather than named here.
    static let aspectGlyphExtent: CGFloat = 26

    /// The render card's progress bar. Square, flat accent, no gradient.
    static let progressBarHeight: CGFloat = 6

    // MARK: Add-overlay sheet

    /// The overlay sheet's canvas preview — the design's 104×185 block, which
    /// is 9:16 to within half a point.
    static let overlayCanvasWidth: CGFloat = 104
    static let overlayCanvasHeight: CGFloat = 185

    // MARK: Layers sheet

    /// The 40pt square icon tile leading each layer row. Deliberately below
    /// `minHitTarget`: the tile is decoration inside a row-sized hit area, not
    /// a control of its own.
    static let layerIconTileSize: CGFloat = 40

    // MARK: Speed-curve sheet

    /// Drawing height handed to `KadrUI.SpeedCurveEditor`. The multiplier axis
    /// is log-scaled over 0.25×…4×; below roughly this the low end compresses
    /// into an unusable sliver. Tokenises the literal `240` the sheet has
    /// carried since v0.4.
    static let speedCurveEditorHeight: CGFloat = 240
}
