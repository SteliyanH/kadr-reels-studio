import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Kadr Studio app icon — the "Cut Stack" mark.
//
// Three clip bars, the top one cut, a playhead standing in the cut. Specific to
// what the app does, rather than the play triangle every video app uses.
//
// One source for all three appearance slots, so the geometry cannot drift
// between them. Every fraction below is from the design handoff's table; only
// the palette changes per appearance.
//
//   swiftc -O Tools/MakeIcon.swift -o /tmp/makeicon
//   /tmp/makeicon default <out.png>
//   /tmp/makeicon dark    <out-dark.png>
//   /tmp/makeicon tinted  <out-tinted.png>

struct Palette {
    let ground: CGColor
    /// The two accent bars — top pair and middle.
    let bars: CGColor
    /// The full-width base bar and the playhead.
    let base: CGColor
}

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
}

let palettes: [String: Palette] = [
    // #007AFF is the light-mode system blue the clip-action row uses.
    "default": Palette(ground: rgb(0xF2F2F7), bars: rgb(0x007AFF), base: rgb(0x1C1C1E)),
    // #0A84FF is the elevated blue the nav and New button use.
    "dark":    Palette(ground: rgb(0x0C0C0E), bars: rgb(0x0A84FF), base: rgb(0xFFFFFF)),
    // Tinted is geometry only — the system applies the user's tint to luminance.
    "tinted":  Palette(ground: rgb(0x0A0A0A), bars: rgb(0xFFFFFF), base: rgb(0x7A7A7A)),
]

guard CommandLine.arguments.count == 3,
      let palette = palettes[CommandLine.arguments[1]]
else {
    FileHandle.standardError.write(Data("usage: makeicon <default|dark|tinted> <output.png>\n".utf8))
    exit(2)
}
let output = URL(fileURLWithPath: CommandLine.arguments[2])

let side: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(
    data: nil, width: Int(side), height: Int(side),
    bitsPerComponent: 8, bytesPerRow: 0, space: space,
    // noneSkipLast, not premultipliedLast: the App Store rejects an icon that
    // carries an alpha channel, even a fully opaque one. The art is full-bleed
    // and the corner mask is Apple's, so there is nothing for alpha to do.
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("context") }

ctx.setFillColor(palette.ground)
ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))

// Geometry, as fractions of the side. From the handoff's table.
let barHeight  = side * 0.132
let gap        = side * 0.062
let radius     = side * 0.037
let left       = side * 0.185
let fullWidth  = side * 0.630
let midWidth   = fullWidth * 0.55
let leftPiece  = fullWidth * 0.42
let cut        = side * 0.045
let playheadW  = side * 0.021
let overhang   = side * 0.055

let stackHeight = barHeight * 3 + gap * 2
let firstY = (side - stackHeight) / 2

func bar(_ rect: CGRect, _ color: CGColor) {
    ctx.setFillColor(color)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.fillPath()
}

// Bottom: full width, the base layer of the composition.
bar(CGRect(x: left, y: firstY, width: fullWidth, height: barHeight), palette.base)
// Middle: short.
bar(CGRect(x: left, y: firstY + barHeight + gap, width: midWidth, height: barHeight), palette.bars)
// Top: split by the cut.
let topY = firstY + (barHeight + gap) * 2
bar(CGRect(x: left, y: topY, width: leftPiece, height: barHeight), palette.bars)
bar(CGRect(x: left + leftPiece + cut, y: topY,
           width: fullWidth - leftPiece - cut, height: barHeight), palette.bars)

// The playhead, drawn last so it reads as standing in front of the stack.
ctx.setFillColor(palette.base)
ctx.fill(CGRect(x: left + leftPiece + (cut - playheadW) / 2,
                y: firstY - overhang,
                width: playheadW,
                height: stackHeight + overhang * 2))

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fatalError("encode") }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("write") }
print("wrote \(output.lastPathComponent)")
