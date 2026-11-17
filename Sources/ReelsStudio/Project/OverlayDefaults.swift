import CoreGraphics
import Kadr
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Sizes Studio gives overlays.
///
/// kadr draws an overlay without an explicit size at its natural size: a photo or
/// sticker at its full pixel size, and text in a box that hugs it. A photo
/// imported at up to 1024 pixels therefore covered most of a 1080 × 1920 reel.
/// The preview used to hide that behind a fixed 30% box; since kadr-ui 0.22 it
/// shows what the export draws, so Studio sizes photos itself when they are added.
enum OverlayDefaults {

    /// The largest share of the canvas a newly added photo or sticker takes.
    static let maxWidthFraction: CGFloat = 0.5
    static let maxHeightFraction: CGFloat = 0.4

    /// The size for a newly added photo or sticker: its pixel size, scaled down
    /// (never up) to fit ``maxWidthFraction`` × ``maxHeightFraction`` of the
    /// canvas, keeping its aspect ratio. `nil` when either size is empty.
    nonisolated static func addedImageSize(pixels: CGSize, canvas: CGSize) -> Size? {
        guard pixels.width > 0, pixels.height > 0, canvas.width > 0, canvas.height > 0 else { return nil }
        let scale = min(
            1,
            canvas.width * maxWidthFraction / pixels.width,
            canvas.height * maxHeightFraction / pixels.height
        )
        return .pixels(
            width: Double((pixels.width * scale).rounded()),
            height: Double((pixels.height * scale).rounded())
        )
    }

    /// The size kadr draws `overlay` at when it has no explicit size (kadr 1.2):
    /// text hugs its text, a photo or sticker takes its pixel size, anything else a
    /// quarter of the canvas. A size keyframe on an un-sized overlay starts here,
    /// so adding one does not make the overlay jump.
    nonisolated static func naturalSize(of overlay: any Overlay, canvas: CGSize) -> Size {
        if let text = overlay as? TextOverlay {
            let size = text.naturalSize(in: canvas)
            return .pixels(width: Double(size.width), height: Double(size.height))
        }
        let image = (overlay as? ImageOverlay)?.image ?? (overlay as? StickerOverlay)?.image
        if let image, let pixels = pixelSize(of: image) {
            return .pixels(width: Double(pixels.width), height: Double(pixels.height))
        }
        return .normalized(width: 0.25, height: 0.25)
    }

    /// The pixel size of the `CGImage` kadr draws, or `nil` when there is none.
    nonisolated static func pixelSize(of image: PlatformImage) -> CGSize? {
        #if canImport(UIKit)
        guard let cg = image.cgImage else { return nil }
        #else
        var rect = CGRect(origin: .zero, size: image.size)
        guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
        #endif
        return CGSize(width: cg.width, height: cg.height)
    }
}
