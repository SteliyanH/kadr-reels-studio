import SwiftUI

/// Leading-edge thumbnail tile for `ProjectRow`. v0.7 Tier 5.
///
/// Reads the cached JPEG synchronously in `body` for the hot path; on cache
/// miss kicks off `ProjectThumbnailRenderer.render(_:)` from `.onAppear` so
/// the row renders something immediately rather than blocking on
/// AVAssetImageGenerator. Empty / unrenderable projects fall back to a
/// deterministic `LinearGradient` keyed off the project id so each
/// project looks visually distinct even without a real first frame.
struct ProjectThumbnailTile: View {

    let document: ProjectDocument

    /// Cache lookup result. `nil` = miss (placeholder rendered); resolved
    /// `Image` = hit.
    @State private var image: Image?

    @Environment(\.modernistPalette) private var palette

    var body: some View {
        ZStack {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ProjectThumbnailTile.placeholderGradient(for: document.id)
                if document.clips.isEmpty {
                    Image(systemName: "film")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Modernist.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Modernist.Radius.md)
                .strokeBorder(palette.divider, lineWidth: Modernist.ruleWidth)
        )
        .onAppear { loadIfNeeded() }
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

    /// Pure: produce a deterministic gradient for the placeholder. Hash of
    /// the project id picks two hues so each empty project looks distinct
    /// in a long list. v0.7 Tier 5.
    nonisolated static func placeholderGradient(for projectID: UUID) -> LinearGradient {
        var hasher = Hasher()
        hasher.combine(projectID)
        let hash = abs(hasher.finalize())
        let h1 = Double(hash % 360) / 360
        let h2 = Double((hash / 7) % 360) / 360
        let start = Color(hue: h1, saturation: 0.45, brightness: 0.62)
        let end = Color(hue: h2, saturation: 0.55, brightness: 0.42)
        return LinearGradient(
            gradient: Gradient(colors: [start, end]),
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
