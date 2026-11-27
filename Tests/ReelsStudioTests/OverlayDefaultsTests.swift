import XCTest
import CoreMedia
import Kadr
@testable import ReelsStudio
#if canImport(UIKit)
import UIKit
#endif

/// Sizes Studio gives overlays: a fitted size for new photos, and the export's
/// natural size as the start of a size keyframe.
final class OverlayDefaultsTests: XCTestCase {

    private let reel = CGSize(width: 1080, height: 1920)

    private func pixels(_ size: Size?) -> CGSize? {
        guard case let .pixels(width, height)? = size else { return nil }
        return CGSize(width: width, height: height)
    }

    // MARK: - New photos

    /// A 1024-pixel photo, the size Studio imports at, would cover most of a reel.
    func testLargePhotoIsScaledToHalfTheCanvasWidth() {
        let size = pixels(OverlayDefaults.addedImageSize(pixels: CGSize(width: 1024, height: 768), canvas: reel))
        XCTAssertEqual(size, CGSize(width: 540, height: 405))
    }

    func testTallPhotoIsLimitedByHeight() {
        let size = pixels(OverlayDefaults.addedImageSize(pixels: CGSize(width: 768, height: 1024), canvas: CGSize(width: 1920, height: 1080)))
        XCTAssertEqual(size?.height, 432, "40% of 1080")
        XCTAssertEqual(size?.width, 324, "aspect kept")
    }

    func testSmallStickerIsNotEnlarged() {
        let size = pixels(OverlayDefaults.addedImageSize(pixels: CGSize(width: 128, height: 96), canvas: reel))
        XCTAssertEqual(size, CGSize(width: 128, height: 96))
    }

    func testEmptySizesGiveNoSize() {
        XCTAssertNil(OverlayDefaults.addedImageSize(pixels: .zero, canvas: reel))
        XCTAssertNil(OverlayDefaults.addedImageSize(pixels: CGSize(width: 10, height: 10), canvas: .zero))
    }

    // MARK: - Size keyframes

    private func image(width: Int, height: Int) throws -> PlatformImage {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let cg = try XCTUnwrap(context.makeImage())
        #if canImport(UIKit)
        return UIImage(cgImage: cg)
        #else
        return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
        #endif
    }

    /// A size keyframe on an un-sized photo records the size kadr draws it at,
    /// its pixel size. It used to record the full canvas, so the photo jumped to
    /// fill the frame the moment a keyframe was added.
    func testSizeKeyframeOnUnsizedPhotoStartsAtItsDrawnSize() throws {
        let overlay = ImageOverlay(try image(width: 300, height: 200))
        let keyed = ProjectStore.upsertOverlayKeyframe(
            overlay, property: .size, time: CMTime(seconds: 1, preferredTimescale: 600), canvas: reel
        )
        let first = try XCTUnwrap(keyed.sizeAnimation?.keyframes.first?.value)
        XCTAssertEqual(pixels(first), CGSize(width: 300, height: 200))
    }

    func testSizeKeyframeKeepsAnExplicitSize() throws {
        let overlay = ImageOverlay(try image(width: 300, height: 200)).size(.normalized(width: 0.3, height: 0.2))
        let keyed = ProjectStore.upsertOverlayKeyframe(
            overlay, property: .size, time: CMTime(seconds: 1, preferredTimescale: 600), canvas: reel
        )
        guard case let .normalized(width, height)? = keyed.sizeAnimation?.keyframes.first?.value else {
            return XCTFail("expected the overlay's own normalized size")
        }
        XCTAssertEqual(width, 0.3)
        XCTAssertEqual(height, 0.2)
    }

    func testTextNaturalSizeIsKadrs() {
        let text = TextOverlay("Title", style: TextStyle(fontSize: 56, weight: .bold))
        XCTAssertEqual(pixels(OverlayDefaults.naturalSize(of: text, canvas: reel)), text.naturalSize(in: reel))
    }
}
