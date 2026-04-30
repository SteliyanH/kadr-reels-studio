import Foundation
import CoreGraphics
import Kadr
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Builds the first-launch demo project. Three solid-color `ImageClip`s + a title
/// overlay so the editor has something to render before the user adds anything.
///
/// Mirrors `kadr-ui`'s `Examples/SimpleViewer` pattern — no bundled media files; the
/// demo is synthesized at runtime so the repo stays text-only.
enum SampleProject {

    static func make() -> Project {
        let palette: [(name: String, color: CGColor)] = [
            ("Sunset",  CGColor(red: 1.0, green: 0.45, blue: 0.30, alpha: 1)),
            ("Ocean",   CGColor(red: 0.20, green: 0.55, blue: 0.85, alpha: 1)),
            ("Forest",  CGColor(red: 0.20, green: 0.65, blue: 0.40, alpha: 1)),
        ]

        let clips: [any Clip] = palette.enumerated().map { index, swatch in
            ImageClip(
                makeSwatch(color: swatch.color, label: swatch.name),
                duration: 2.0
            )
            .id(ClipID("sample-\(index)"))
        }

        let title = TextOverlay(
            "Reels Studio",
            style: TextStyle(fontSize: 56, color: .white, alignment: .center, weight: .bold)
        )
        .position(.center)
        .anchor(.center)

        return Project(
            clips: clips,
            overlays: [title],
            audioTracks: [],
            captions: [],
            preset: .reelsAndShorts
        )
    }

    /// Render a 1080×1920 swatch with a centered label. Pure helper — exposed for
    /// tests so the bundled-clip count stays verifiable without spinning up SwiftUI.
    static func makeSwatch(color: CGColor, label: String) -> PlatformImage {
        let size = CGSize(width: 1080, height: 1920)
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            ctx.cgContext.setFillColor(color)
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 80, weight: .bold),
                .foregroundColor: UIColor.white,
            ]
            let text = NSAttributedString(string: label, attributes: attrs)
            let textSize = text.size()
            let origin = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            text.draw(at: origin)
        }
        #elseif canImport(AppKit)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return image }
        ctx.setFillColor(color)
        ctx.fill(CGRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 80, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let text = NSAttributedString(string: label, attributes: attrs)
        let textSize = text.size()
        let origin = CGPoint(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2
        )
        text.draw(at: origin)
        return image
        #endif
    }
}
