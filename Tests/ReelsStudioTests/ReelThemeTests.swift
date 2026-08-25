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
final class ReelTokenTests: XCTestCase {

    // MARK: - Geometry

    /// Zero everywhere, on purpose. The whole system reads as squared blocks;
    /// one rounded corner breaks it.
    func testRadiusIsZeroAtEveryStep() {
        XCTAssertEqual(Reel.Radius.sm, 0)
        XCTAssertEqual(Reel.Radius.md, 0)
        XCTAssertEqual(Reel.Radius.lg, 0)
    }

    /// Rules are 2pt, never a 0.5 or 1pt hairline — they're the system's main
    /// organising device, not a decoration.
    func testRuleWidthIsTwo() {
        XCTAssertEqual(Reel.ruleWidth, 2)
    }

    func testFocusRingMatchesTheCSSOutline() {
        XCTAssertEqual(Reel.focusRingWidth, 2)
        XCTAssertEqual(Reel.focusRingOffset, 2)
    }

    func testSpacingScaleIsTheDocumentedSteps() {
        XCTAssertEqual(
            [Reel.Space.s1, Reel.Space.s2, Reel.Space.s3,
             Reel.Space.s4, Reel.Space.s6, Reel.Space.s8],
            [4, 8, 12, 16, 24, 32]
        )
    }

    // MARK: - Palette

    // Colors compare by hex rather than `Color == Color`, which is unreliable
    // across construction paths — the same helper the accent round-trip uses.

    private func hex(_ color: Color) throws -> String {
        try XCTUnwrap(ProjectDocument.hexString(from: PlatformColor.baked(color)))
    }

    /// The one accent on the light chrome ground.
    func testPrintAccentIsTheDocumentedRed() throws {
        XCTAssertEqual(try hex(ReelPalette.print.accent), "#EC3013")
    }

    /// A lighter ramp step on the dark editor ground, per the guide's rule.
    func testStudioAccentIsTheDocumentedRed() throws {
        XCTAssertEqual(try hex(ReelPalette.studio.accent), "#FF563C")
    }

    /// The studio accent is `Accent.a500` itself, not a second hand-tuned red.
    func testStudioAccentIsTheAccentRampStep() throws {
        XCTAssertEqual(
            try hex(ReelPalette.studio.accent),
            try hex(Reel.Accent.a500)
        )
    }

    func testGroundsAreTheDocumentedValues() throws {
        XCTAssertEqual(try hex(ReelPalette.print.bg), "#F3F2F2")
        XCTAssertEqual(try hex(ReelPalette.studio.bg), "#0C0C0E")
    }

    /// The dark ground needs a deeper ambient; the multiplier is a property of
    /// the palette, not something a call site tunes.
    func testStudioScalesElevationHarderThanPrint() {
        XCTAssertEqual(ReelPalette.print.elevationScale, 1.0)
        XCTAssertGreaterThan(
            ReelPalette.studio.elevationScale,
            ReelPalette.print.elevationScale
        )
    }

    // MARK: - Line height

    /// CSS gives line-height as a multiple; SwiftUI takes the delta. 15 × 1.55
    /// is 23.25, so the delta is 8.25.
    func testBodyLineSpacingIsTheCSSDelta() {
        XCTAssertEqual(
            Reel.Typography.lineSpacing(forSize: 15, multiple: 1.55),
            8.25,
            accuracy: 0.0001
        )
        XCTAssertEqual(Reel.Typography.bodyLineSpacing, 8.25, accuracy: 0.0001)
    }

    func testHeadingLineSpacingIsTheCSSDelta() {
        XCTAssertEqual(
            Reel.Typography.headingLineSpacing,
            25 * 1.12 - 25,
            accuracy: 0.0001
        )
    }
}

/// Archivo is bundled, and — the part that actually matters — SwiftUI resolves
/// the theme's weights to the right cuts of it.
@MainActor
final class ReelTypographyTests: XCTestCase {

    // MARK: - Bundling

    /// `UIAppFonts` in `project.yml` registers the three TTFs at launch. If this
    /// fails, every `Typography` style silently falls back to the system face —
    /// right sizes, wrong design, no error anywhere.
    func testFamilyIsBundled() {
        XCTAssertTrue(Reel.Typography.isFamilyBundled)
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
        assertResolves(Reel.Typography.h2, to: "Archivo-ExtraBold")
    }

    func testEveryHeadingStepResolvesToExtraBold() {
        for font in [Reel.Typography.h1, Reel.Typography.h3,
                     Reel.Typography.h4, Reel.Typography.h5,
                     Reel.Typography.h6] {
            assertResolves(font, to: "Archivo-ExtraBold")
        }
    }

    func testBodyEmphasisResolvesToSemiBold() {
        assertResolves(Reel.Typography.bodyEmphasis, to: "Archivo-SemiBold")
    }

    func testButtonLabelResolvesToSemiBold() {
        assertResolves(Reel.Typography.buttonLabel, to: "Archivo-SemiBold")
    }

    func testBodyResolvesToRegular() {
        assertResolves(Reel.Typography.body, to: "Archivo-Regular")
    }

    func testCaptionResolvesToRegular() {
        assertResolves(Reel.Typography.caption, to: "Archivo-Regular")
    }

    /// Distinctness is the real claim: if the weight trait were being dropped,
    /// all three of these would come back as the same cut.
    func testTheThreeWeightsResolveToThreeDifferentCuts() {
        let resolved = Set(
            [Reel.Typography.body,
             Reel.Typography.bodyEmphasis,
             Reel.Typography.h2].flatMap(renderedPostScriptNames)
                .map { String($0.split(separator: "+").last ?? "") }
        )
        XCTAssertEqual(resolved, ["Archivo-Regular", "Archivo-SemiBold", "Archivo-ExtraBold"])
    }
}
