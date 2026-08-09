import SwiftUI

/// Leading-edge thumbnail tile for `ProjectRow`. v0.7 Tier 5.
///
/// Reads the cached JPEG synchronously in `body` for the hot path; on cache
/// miss kicks off `ProjectThumbnailRenderer.render(_:)` from `.onAppear` so
/// the row renders something immediately rather than blocking on
/// AVAssetImageGenerator. Empty / unrenderable projects fall back to a flat
/// `surface` block inside a 2pt dashed rule (v0.8 Tier 3 — the hue-derived
/// gradient this used to draw can't survive a mono scheme).
struct ProjectThumbnailTile: View {

    let document: ProjectDocument

    /// Cache lookup result. `nil` = miss (placeholder rendered); resolved
    /// `Image` = hit.
    @State private var image: Image?

    @Environment(\.modernistPalette) private var palette

    var body: some View {
        ZStack {
            if let image {
                // Decision 5 — every content photograph and video thumbnail
                // goes through grayscale. (The preview *stage* does not; the
                // user grades colour there.)
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .modernistGrayscale()
            } else {
                // v0.8 Tier 3 — the placeholder was a hue-derived gradient
                // keyed off the project id. A generated hue is the opposite
                // of a mono scheme, so an empty project reads as a flat
                // surface inside a 2pt dashed rule instead.
                palette.surface
                if document.clips.isEmpty {
                    Image(systemName: "film")
                        .font(.system(size: 22))
                        .foregroundStyle(palette.textMuted)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Modernist.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Modernist.Radius.md)
                .strokeBorder(palette.divider, style: frameStroke)
        )
        .onAppear { loadIfNeeded() }
    }

    /// A rendered frame sits inside a solid 2pt rule; a placeholder sits
    /// inside a dashed one, which is how the approved design distinguishes
    /// "nothing here yet" from "a frame that happens to be dark".
    private var frameStroke: StrokeStyle {
        image == nil
            ? StrokeStyle(
                lineWidth: Modernist.ruleWidth,
                dash: [Modernist.Space.s1, Modernist.Space.s1]
              )
            : StrokeStyle(lineWidth: Modernist.ruleWidth)
    }

    /// Sync cache-only lookup + async render fallback. Runs from
    /// `.onAppear` so the cost is amortized across scroll; no eager render
    /// at app launch.
    private func loadIfNeeded() {
        if image != nil { return }
        if let url = ProjectThumbnailRenderer.cachedURL(for: document) {
            image = imageFromDisk(url)
            return
        }
        Task.detached(priority: .utility) {
            let rendered = await ProjectThumbnailRenderer.render(document)
            if let rendered {
                let image = imageFromDisk(rendered)
                await MainActor.run { self.image = image }
            }
        }
    }

    /// The placeholder fill, as a `LinearGradient`.
    ///
    /// v0.7 Tier 5 derived two hues from a hash of the project id so empty
    /// projects looked distinct. v0.8 Tier 3 collapsed that into the mono
    /// scheme — a generated hue is exactly what the system forbids — so the
    /// "gradient" is now one flat print `surface` stop, and the tile paints
    /// `palette.surface` from the environment directly.
    ///
    /// Kept, with its original signature, because it is public API pinned by
    /// `ProjectThumbnailRendererTests`. It is still deterministic per id
    /// (trivially so). Retire it with that test, not before.
    nonisolated static func placeholderGradient(for projectID: UUID) -> LinearGradient {
        let fill = ModernistPalette.print.surface
        return LinearGradient(
            gradient: Gradient(colors: [fill, fill]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Bridge: load a JPEG / PNG from disk into a SwiftUI `Image`. Falls back
/// to a system "photo" glyph on failure so the cell can't get stuck at a
/// half-rendered state. Hoisted out of the tile body so the test surface
/// stays trivial.
private func imageFromDisk(_ url: URL) -> Image {
    #if canImport(UIKit)
    if let uiImage = UIImage(contentsOfFile: url.path) {
        return Image(uiImage: uiImage)
    }
    #elseif canImport(AppKit)
    if let nsImage = NSImage(contentsOf: url) {
        return Image(nsImage: nsImage)
    }
    #endif
    return Image(systemName: "photo")
}
