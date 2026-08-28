import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Reels Studio app icon.
//
// Modernist: paper ground, flat geometry, no gradient or gloss. The mark is a
// timeline — three stacked clip bars, the top one cut — because that is the
// thing the app is, and because a rounded 9:16 rectangle reads as a phone
// rather than as video.

let side: CGFloat = 1024
let paper  = CGColor(red: 0xF3/255, green: 0xF2/255, blue: 0xF2/255, alpha: 1)
let accent = CGColor(red: 0xFF/255, green: 0x56/255, blue: 0x3C/255, alpha: 1)
let ink    = CGColor(red: 0x2D/255, green: 0x2B/255, blue: 0x2B/255, alpha: 1)

let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(
    data: nil, width: Int(side), height: Int(side),
    bitsPerComponent: 8, bytesPerRow: 0, space: space,
    // noneSkipLast, not premultipliedLast: the App Store rejects an icon that
    // carries an alpha channel, even a fully opaque one.
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("context") }

ctx.setFillColor(paper)
ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))

// Three clip bars. Widths differ so the stack reads as real material rather
// than as a hamburger menu; the corner radius is small so they stay rectangles.
let barHeight = side * 0.132
let gap = side * 0.062
let radius = barHeight * 0.28
let left = side * 0.185
let fullWidth = side * 0.63
let stackHeight = barHeight * 3 + gap * 2
let firstY = (side - stackHeight) / 2

func bar(_ rect: CGRect, _ color: CGColor) {
    ctx.setFillColor(color)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.fillPath()
}

// Bottom bar — full width, ink. The base layer of the composition.
bar(CGRect(x: left, y: firstY, width: fullWidth, height: barHeight), ink)

// Middle bar — short, accent.
bar(CGRect(x: left, y: firstY + barHeight + gap, width: fullWidth * 0.55, height: barHeight), accent)

// Top bar — accent, cut in two. The gap is the edit.
let topY = firstY + (barHeight + gap) * 2
let cut = side * 0.045
let leftPiece = fullWidth * 0.42
bar(CGRect(x: left, y: topY, width: leftPiece, height: barHeight), accent)
bar(CGRect(x: left + leftPiece + cut, y: topY,
           width: fullWidth - leftPiece - cut, height: barHeight), accent)

// The playhead: one ink rule straight down through the stack, sitting in the
// cut so the two ideas read as one gesture.
let playheadWidth = side * 0.021
ctx.setFillColor(ink)
ctx.fill(CGRect(
    x: left + leftPiece + (cut - playheadWidth) / 2,
    y: firstY - side * 0.055,
    width: playheadWidth,
    height: stackHeight + side * 0.11
))

guard let image = ctx.makeImage() else { fatalError("image") }
let out = URL(fileURLWithPath: CommandLine.arguments[1])
guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("destination")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("write") }
print("wrote \(out.path)")
