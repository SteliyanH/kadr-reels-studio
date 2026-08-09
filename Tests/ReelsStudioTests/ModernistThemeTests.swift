import XCTest
import SwiftUI
import CoreText
import Kadr
@testable import ReelsStudio

/// Tier 1 guards for the Modernist theme layer.
///
/// Two jobs. The first is cheap and boring: pin the tokens that a later
/// "tidy-up" would otherwise soften — a rounded corner, a hairline divider, a
/// drifted accent. The second is the expensive one: prove that the font the
/// design is set in actually resolves at the weight it asks for.
@MainActor
final class ModernistTokenTests: XCTestCase {

    // MARK: - Geometry

    /// Zero everywhere, on purpose. The whole system reads as squared blocks;
    /// one rounded corner breaks it.
    func testRadiusIsZeroAtEveryStep() {
        XCTAssertEqual(Modernist.Radius.sm, 0)
        XCTAssertEqual(Modernist.Radius.md, 0)
        XCTAssertEqual(Modernist.Radius.lg, 0)
    }

    /// Rules are 2pt, never a 0.5 or 1pt hairline — they're the system's main
    /// organising device, not a decoration.
    func testRuleWidthIsTwo() {
        XCTAssertEqual(Modernist.ruleWidth, 2)
    }

    func testFocusRingMatchesTheCSSOutline() {
        XCTAssertEqual(Modernist.focusRingWidth, 2)
        XCTAssertEqual(Modernist.focusRingOffset, 2)
    }

    func testSpacingScaleIsTheDocumentedSteps() {
        XCTAssertEqual(
            [Modernist.Space.s1, Modernist.Space.s2, Modernist.Space.s3,
             Modernist.Space.s4, Modernist.Space.s6, Modernist.Space.s8],
            [4, 8, 12, 16, 24, 32]
        )
    }

    // MARK: - Palette

    // Colors compare by hex rather than `Color == Color`, which is unreliable
    // across construction paths — the same helper the accent round-trip uses.

    private func hex(_ color: Color) throws -> String {
        try XCTUnwrap(ProjectDocument.hexString(from: PlatformColor(color)))
    }

    /// The one accent on the light chrome ground.
    func testPrintAccentIsTheDocumentedRed() throws {
        XCTAssertEqual(try hex(ModernistPalette.print.accent), "#EC3013")
    }

    /// A lighter ramp step on the dark editor ground, per the guide's rule.
    func testStudioAccentIsTheDocumentedRed() throws {
        XCTAssertEqual(try hex(ModernistPalette.studio.accent), "#FF563C")
    }

    /// The studio accent is `Accent.a500` itself, not a second hand-tuned red.
    func testStudioAccentIsTheAccentRampStep() throws {
        XCTAssertEqual(
            try hex(ModernistPalette.studio.accent),
            try hex(Modernist.Accent.a500)
        )
    }

    func testGroundsAreTheDocumentedValues() throws {
        XCTAssertEqual(try hex(ModernistPalette.print.bg), "#F3F2F2")
        XCTAssertEqual(try hex(ModernistPalette.studio.bg), "#0C0C0E")
    }

    /// The dark ground needs a deeper ambient; the multiplier is a property of
    /// the palette, not something a call site tunes.
    func testStudioScalesElevationHarderThanPrint() {
        XCTAssertEqual(ModernistPalette.print.elevationScale, 1.0)
        XCTAssertGreaterThan(
            ModernistPalette.studio.elevationScale,
            ModernistPalette.print.elevationScale
        )
    }

    // MARK: - Line height

    /// CSS gives line-height as a multiple; SwiftUI takes the delta. 15 × 1.55
    /// is 23.25, so the delta is 8.25.
    func testBodyLineSpacingIsTheCSSDelta() {
        XCTAssertEqual(
            Modernist.Typography.lineSpacing(forSize: 15, multiple: 1.55),
            8.25,
            accuracy: 0.0001
        )
        XCTAssertEqual(Modernist.Typography.bodyLineSpacing, 8.25, accuracy: 0.0001)
    }

    func testHeadingLineSpacingIsTheCSSDelta() {
        XCTAssertEqual(
            Modernist.Typography.headingLineSpacing,
            25 * 1.12 - 25,
            accuracy: 0.0001
        )
    }
}

/// Archivo is bundled, and — the part that actually matters — SwiftUI resolves
/// the theme's weights to the right cuts of it.
@MainActor
final class ModernistTypographyTests: XCTestCase {

    // MARK: - Bundling

    /// `UIAppFonts` in `project.yml` registers the three TTFs at launch. If this
    /// fails, every `Typography` style silently falls back to the system face —
    /// right sizes, wrong design, no error anywhere.
    func testFamilyIsBundled() {
        XCTAssertTrue(Modernist.Typography.isFamilyBundled)
    }

    /// All three cuts register, and they register under the PostScript names the
    /// design system expects.
    func testAllThreeCutsAreRegistered() {
        let names = (CTFontManagerCopyAvailablePostScriptNames() as? [String]) ?? []
        for cut in ["Archivo-Regular", "Archivo-SemiBold", "Archivo-ExtraBold"] {
            XCTAssertTrue(names.contains(cut), "\(cut) is not registered")
        }
    }

    /// The name-table layout puts all three cuts in one `Archivo` family
    /// (typographic family, name ID 16), which is what makes weight resolution
    /// work at all.
    func testTheThreeCutsShareOneFamily() {
        #if canImport(UIKit)
        XCTAssertEqual(UIFont.fontNames(forFamilyName: "Archivo").sorted(),
                       ["Archivo-ExtraBold", "Archivo-Regular", "Archivo-SemiBold"])
        #endif
    }

    // MARK: - Weight resolution

    // `Typography.font(size:weight:)` asks for the *family* name and applies a
    // weight trait: `.custom("Archivo", fixedSize:).weight(.heavy)`.
    //
    // CoreText has three ways to answer that, and they don't agree. A descriptor
    // keyed by `.family` plus a weight trait picks the right cut; a descriptor
    // keyed by `.name` plus a weight trait falls back to Regular for *every*
    // weight. If SwiftUI took the second path, every heading in the app would
    // render at 400 and nothing would report an error — `isFamilyBundled` would
    // still be true and the glyphs would still genuinely be Archivo.
    //
    // So we don't guess at SwiftUI's internals: we render the `Text` through
    // `ImageRenderer` into a PDF context and read back which font the renderer
    // actually embedded. Subset fonts carry a six-letter tag ("AAAAAB+"), hence
    // the suffix match.

    /// The PostScript names SwiftUI embeds when it renders `Text` in `font`.
    private func renderedPostScriptNames(_ font: Font) -> [String] {
        let renderer = ImageRenderer(content: Text("Hamburgefonstiv 0123").font(font))
        let pdf = NSMutableData()
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(data: pdf as CFMutableData),
                  let context = CGContext(consumer: consumer, mediaBox: &box, nil)
            else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
        }
        let blob = String(decoding: pdf as Data, as: UTF8.self)
        let tokens = blob.split(whereSeparator: {
            !($0.isLetter || $0.isNumber || $0 == "-" || $0 == "+")
        })
        return tokens.map(String.init).filter { $0.contains("Archivo") }
    }

    private func assertResolves(
        _ font: Font,
        to postScriptName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let names = renderedPostScriptNames(font)
        XCTAssertFalse(names.isEmpty, "Nothing Archivo was embedded at all", file: file, line: line)
        for name in names {
            XCTAssertTrue(
                name.hasSuffix(postScriptName),
                "Expected \(postScriptName), rendered \(name)",
                file: file, line: line
            )
        }
    }

    /// The load-bearing one: 32 / 800 must reach the ExtraBold cut. If this ever
    /// goes red, the fix is inside the theme — map the weight to the exact
    /// PostScript name and hand *that* to `Font.custom`.
    func testHeadingResolvesToExtraBold() {
        assertResolves(Modernist.Typography.h2, to: "Archivo-ExtraBold")
    }

    func testEveryHeadingStepResolvesToExtraBold() {
        for font in [Modernist.Typography.h1, Modernist.Typography.h3,
                     Modernist.Typography.h4, Modernist.Typography.h5,
                     Modernist.Typography.h6] {
            assertResolves(font, to: "Archivo-ExtraBold")
        }
    }

    func testBodyEmphasisResolvesToSemiBold() {
        assertResolves(Modernist.Typography.bodyEmphasis, to: "Archivo-SemiBold")
    }

    func testButtonLabelResolvesToSemiBold() {
        assertResolves(Modernist.Typography.buttonLabel, to: "Archivo-SemiBold")
    }

    func testBodyResolvesToRegular() {
        assertResolves(Modernist.Typography.body, to: "Archivo-Regular")
    }

    func testCaptionResolvesToRegular() {
        assertResolves(Modernist.Typography.caption, to: "Archivo-Regular")
    }

    /// Distinctness is the real claim: if the weight trait were being dropped,
    /// all three of these would come back as the same cut.
    func testTheThreeWeightsResolveToThreeDifferentCuts() {
        let resolved = Set(
            [Modernist.Typography.body,
             Modernist.Typography.bodyEmphasis,
             Modernist.Typography.h2].flatMap(renderedPostScriptNames)
                .map { String($0.split(separator: "+").last ?? "") }
        )
        XCTAssertEqual(resolved, ["Archivo-Regular", "Archivo-SemiBold", "Archivo-ExtraBold"])
    }
}
