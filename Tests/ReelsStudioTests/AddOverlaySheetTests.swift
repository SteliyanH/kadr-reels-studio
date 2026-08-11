import XCTest
import SwiftUI
import Kadr
@testable import ReelsStudio

@MainActor
final class AddOverlaySheetTests: XCTestCase {

    // MARK: - Body smoke per tab

    func testSheetBodyConstructs() {
        let store = ProjectStore(project: Project())
        let sheet = AddOverlaySheet(store: store)
        _ = sheet.body
    }

    // MARK: - Text overlay append routes through the store

    func testAppendTextOverlayLandsInProject() {
        let store = ProjectStore(project: Project())
        let style = TextStyle(
            fontSize: 56,
            color: .white,
            alignment: .center,
            weight: .bold
        )
        let overlay = TextOverlay("Hello", style: style)
            .position(.center)
            .anchor(.center)
        store.append(overlay: overlay)
        XCTAssertEqual(store.project.overlays.count, 1)
        XCTAssertNotNil(store.project.overlays.first as? TextOverlay)
    }

    // MARK: - ImageOverlay round-trips through Project

    func testAppendImageOverlay() {
        let store = ProjectStore(project: Project())
        let overlay = ImageOverlay(PlatformImage())
            .position(.center)
            .anchor(.center)
            .opacity(0.8)
            .id(LayerID("img-1"))
        store.append(overlay: overlay)
        XCTAssertNotNil(store.project.overlays.first as? ImageOverlay)
        XCTAssertEqual(store.project.overlays.first?.layerID, LayerID("img-1"))
        XCTAssertEqual(store.project.overlays.first?.opacity, 0.8)
    }

    func testAppendStickerOverlay() {
        let store = ProjectStore(project: Project())
        let overlay = StickerOverlay(PlatformImage())
            .position(.center)
            .anchor(.center)
            .opacity(0.9)
            .id(LayerID("sticker-1"))
        store.append(overlay: overlay)
        XCTAssertNotNil(store.project.overlays.first as? StickerOverlay)
    }

    // MARK: - Undo / redo

    func testUndoRevertsOverlayAppend() {
        let store = ProjectStore(project: Project())
        let overlay = StickerOverlay(PlatformImage()).id(LayerID("s1"))
        store.append(overlay: overlay)
        XCTAssertEqual(store.project.overlays.count, 1)
        store.undo()
        XCTAssertEqual(store.project.overlays.count, 0)
    }

    // MARK: - Default text colour is content, not chrome
    //
    // The Modernist migration retinted the new-text-overlay default from
    // `Color.white` to `Modernist.Neutral.n100`. That value goes into
    // `TextStyle(color:)` and is baked into exported pixels — overlay content,
    // not app chrome, and outside the two behaviour changes the migration was
    // allowed. These pin it so it can't drift back on the next sweep.

    private func hex(_ color: Color) -> String? {
        ProjectDocument.hexString(from: PlatformColor(color))
    }

    func testDefaultTextColorIsLiteralWhite() {
        XCTAssertEqual(AddOverlaySheet.defaultTextColor, Color.white)
    }

    func testDefaultTextColorBakesPureWhitePixels() {
        XCTAssertEqual(hex(AddOverlaySheet.defaultTextColor), "#FFFFFF")
    }

    func testDefaultTextColorIsNotTheNeutralRamp() {
        // The exact regression: n100 is #F8F4F4, three channels short of white.
        XCTAssertNotEqual(
            hex(AddOverlaySheet.defaultTextColor),
            hex(Modernist.Neutral.n100),
            "The text-overlay default was themed onto the neutral ramp. It is "
            + "content, not chrome — it must stay literal white."
        )
    }

    // MARK: - Font size keeps its step
    //
    // v0.5–v0.7 shipped `Slider(value:in:step:)` with step 2; the drawn slider
    // dropped it, letting `TextStyle.fontSize` persist fractional points that
    // the "56 pt" readout only rounded for display.

    func testFontSizeStepIsTwo() {
        XCTAssertEqual(AddOverlaySheet.fontSizeStep, 2)
    }

    func testFontSizeSliderCannotPersistFractionalPoints() {
        // Sweep the whole track the way a drag does, at a deliberately awkward
        // pitch, and assert every value that could reach the store is on grid.
        for raw in stride(from: 24.0, through: 96.0, by: 0.37) {
            let resolved = ModernistSlider.resolve(
                raw, range: 24...96, step: AddOverlaySheet.fontSizeStep
            )
            XCTAssertEqual(resolved.rounded(), resolved, accuracy: 1e-9)
            XCTAssertEqual(resolved.truncatingRemainder(dividingBy: 2), 0, accuracy: 1e-9)
            XCTAssertTrue((24...96).contains(resolved))
        }
    }

    // MARK: - Colour swatches are one list, not two

    private var swatches: [AddOverlaySheet.TextColorSwatch] {
        AddOverlaySheet.textColorSwatches(groundText: ModernistPalette.print.text)
    }

    func testSwatchListIsTheApprovedRampInOrder() {
        XCTAssertEqual(
            swatches.map(\.color),
            [
                Modernist.Neutral.n100,
                Modernist.Neutral.n500,
                Modernist.Neutral.n900,
                Modernist.Accent.a500,
                Modernist.Accent.a700,
                ModernistPalette.print.text,
            ]
        )
    }

    func testSwatchNamesAreTheOnesVoiceOverSpoke() {
        XCTAssertEqual(
            swatches.map(\.name),
            ["Off-white", "Mid gray", "Near black", "Accent, light", "Accent, dark", "Ground text color"]
        )
    }

    /// The row uses `name` as the `ForEach` identity, so a duplicate would
    /// collapse two cells into one.
    func testSwatchNamesAreUniqueAndNonEmpty() {
        XCTAssertEqual(Set(swatches.map(\.name)).count, swatches.count)
        XCTAssertFalse(swatches.contains { $0.name.isEmpty })
    }

    /// Every swatch carries its own name, which is what the two parallel
    /// literal arrays could not guarantee: `swatchLabels[index]` trapped the
    /// moment the lists differed in length.
    func testEverySwatchCarriesItsOwnName() {
        XCTAssertEqual(swatches.count, 6)
        for swatch in swatches {
            XCTAssertFalse(swatch.name.isEmpty)
        }
    }

    func testGroundTextSwatchTracksTheGroundItIsGiven() {
        let studio = AddOverlaySheet.textColorSwatches(groundText: ModernistPalette.studio.text)
        XCTAssertEqual(studio.last?.color, ModernistPalette.studio.text)
        XCTAssertEqual(studio.last?.name, swatches.last?.name)
    }
}
