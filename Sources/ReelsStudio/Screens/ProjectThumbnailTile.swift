import SwiftUI
import KadrPersistence

/// Leading-edge thumbnail tile for `ProjectRow`. v0.7 Tier 5.
///
/// Reads the cached JPEG synchronously in `body` for the hot path; on cache
/// miss kicks off `ProjectThumbnailRenderer.render(_:)` from `.onAppear` so
/// the row renders something immediately rather than blocking on
/// AVAssetImageGenerator.
///
/// v0.8 Tier 5a: per the approved design, an *empty* project's tile is a 2pt
/// dashed `divider` frame on `surface` — nothing else — and a tile that can
/// name the project's length carries a `numeric` duration chip along its
/// bottom edge. Real thumbnails still go through `.reelGrayscale()`
/// (Decision 5).
struct ProjectThumbnailTile: View {

    let document: ProjectDocument

    /// Cache lookup result. `nil` = miss (placeholder rendered); resolved
    /// `Image` = hit.
    @State private var image: Image?

    @Environment(\.reelPalette) private var palette

    var body: some View {
        ZStack {
            if let image {
                // Decision 5 — every content photograph and video thumbnail
                // goes through grayscale. (The preview *stage* does not; the
                // user grades colour there.)
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .reelGrayscale()
            } else {
                // v0.8 Tier 3 — the placeholder was a hue-derived gradient
                // keyed off the project id. A generated hue is the opposite
                // of a mono scheme, so an unrendered tile reads as a flat
                // surface, and an *empty* project as nothing but the dashed
                // frame below.
                palette.surface
                if !document.compositionClips.isEmpty {
                    Image(systemName: "film")
                        .font(.system(size: Reel.Typography.Glyph.sm, weight: Reel.Typography.headingWeight))
                        .foregroundStyle(palette.textMuted)
                }
            }
        }
        .overlay(alignment: .bottom) { durationChip }
        .clipShape(RoundedRectangle(cornerRadius: Reel.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Reel.Radius.md)
                .strokeBorder(palette.divider, style: frameStroke)
        )
        .onAppear { loadIfNeeded() }
    }

    /// The design's chip along the tile's bottom edge, in tabular figures.
    /// Hidden when the document can't name its own length — a video clip
    /// persists no duration until it has been trimmed, and inventing one
    /// would be worse than omitting it.
    @ViewBuilder
    private var durationChip: some View {
        if let label = ProjectThumbnailTile.durationLabel(for: document) {
            Text(label)
                .font(Reel.Typography.numeric)
                // `bg`, not `onAccent`: this is an *inverted* chip — a
                // `text`-coloured fill — not an accent one. On a dark chrome
                // ground `onAccent` and `text` are both white, so the label
                // vanished into its own background. `ToastView` inverts the
                // same way and was already correct.
                .foregroundStyle(palette.bg)
                .frame(maxWidth: .infinity)
                .frame(height: Reel.thumbnailChipHeight)
                .background(palette.text)
                .accessibilityHidden(true)
        }
    }

    /// A rendered frame sits inside a solid 2pt rule; an empty project sits
    /// inside a dashed one, which is how the approved design distinguishes
    /// "nothing here yet" from "a frame that happens to be dark".
    private var frameStroke: StrokeStyle {
        document.compositionClips.isEmpty
            ? StrokeStyle(
                lineWidth: Reel.ruleWidth,
                dash: [Reel.Space.s1, Reel.Space.s1]
              )
            : StrokeStyle(lineWidth: Reel.ruleWidth)
    }

    // MARK: - Duration

    /// `m:ss` for the tile's chip, or `nil` when the document carries no
    /// usable duration. Pure so it's testable.
    nonisolated static func durationLabel(for document: ProjectDocument) -> String? {
        let seconds = durationSeconds(of: document.compositionClips)
        guard seconds > 0 else { return nil }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Best-effort composition length straight off the persisted shape.
    ///
    /// Image, title and track clips all persist their own length. A video
    /// clip only does once it has been trimmed (`trimDurationSeconds`);
    /// before that its length lives in the asset, which a list row must not
    /// open. Transitions are skipped deliberately — kadr overlaps them into
    /// their neighbours, so adding them would over-count.
    nonisolated static func durationSeconds(of clips: [KadrPersistence.ClipData]) -> Double {
        clips.reduce(into: 0) { total, clip in
            switch clip {
            case .video(let data):      total += data.trimRange?.duration.time.seconds ?? 0
            case .image(let data):      total += data.duration.time.seconds
            case .title(let data):      total += data.duration.time.seconds
            case .transition:           break
            case .track(let data):      total += durationSeconds(of: data.clips)
            }
        }
    }

    // MARK: - Loading

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
