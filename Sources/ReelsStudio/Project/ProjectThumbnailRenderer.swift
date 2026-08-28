import Foundation
import KadrPersistence
import AVFoundation
import CoreGraphics
import ImageIO
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Renders + caches an 80×80 thumbnail (rendered at 2× = 160×160 for retina)
/// for a `ProjectDocument`. v0.7 Tier 5.
///
/// **Strategy.** Walks `project.clips` for the first clip we know how to
/// render frame 0 of — `VideoClip` (via `AVAssetImageGenerator`) or
/// `ImageClip` (via the embedded `PlatformImage`). Transitions / Tracks /
/// titles get skipped at this layer (Track-internal clips need deeper
/// traversal; titles need glyph rendering — both deferred to v0.7.x if real
/// users care). Returns nil when no renderable clip is found.
///
/// **Cache.** JPEG under `App Support/ReelsStudio/Thumbnails/` keyed by
/// `<projectID>-<modifiedAt-unix>.jpg`. The unix timestamp in the filename
/// is the lazy invalidation primitive: a save bumps `modifiedAt`, the
/// next cache lookup misses, the renderer emits a fresh thumbnail, and
/// the old stale one is left for `prune()` to garbage-collect (called from
/// `ProjectLibrary.delete` — covered in the Tier 5 wiring).
///
/// **Concurrency.** AVAssetImageGenerator is thread-safe on its own queue,
/// but the cache directory access goes through `FileManager` which is
/// thread-safe for reads. We keep the renderer free of state so callers
/// can dispatch from any task.
enum ProjectThumbnailRenderer {

    /// Rendered size in points. ProjectRow's leading tile is 56pt; 80pt
    /// gives a little crop tolerance for square subjects that fill the
    /// frame.
    static let pointSize: CGFloat = 80

    /// Pixel size at 2× — every iPhone we target since iPhone 8 has at
    /// least a 2× screen.
    private static var pixelSize: CGFloat { pointSize * 2 }

    // MARK: - Public surface

    /// Render frame 0 of `document` and write a JPEG to the cache. Returns
    /// the on-disk URL on success, nil if no clip in the project is
    /// renderable as a thumbnail (e.g. a project that only contains a
    /// transition or a TitleSequence).
    ///
    /// Idempotent — calling twice with the same `(id, modifiedAt)` returns
    /// the existing cached file on the second call rather than re-rendering.
    @discardableResult
    static func render(_ document: ProjectDocument) async -> URL? {
        let url = cacheURL(for: document)
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        guard let image = await renderImage(for: document) else { return nil }
        guard writeJPEG(image, to: url) else { return nil }
        return url
    }

    /// Look up a cached thumbnail without rendering. Returns nil on cache
    /// miss — `ProjectRow` calls this from `body` (the cheap path) and
    /// kicks off `render(_:)` from `.onAppear` for misses.
    static func cachedURL(for document: ProjectDocument) -> URL? {
        let url = cacheURL(for: document)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Delete every cached thumbnail for `projectID` regardless of
    /// modifiedAt. Called from `ProjectLibrary.delete` so a project's
    /// thumbnails don't outlive the project itself.
    static func purge(projectID: UUID) {
        guard let dir = try? cacheDirectory() else { return }
        let prefix = "\(projectID.uuidString)-"
        let contents = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        )
        for url in contents ?? [] where url.lastPathComponent.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Compute the cache file URL for a document without touching disk.
    /// Pure — exposed for tests that pin the keying convention.
    static func cacheURL(for document: ProjectDocument) -> URL {
        let dir: URL
        if let existing = try? cacheDirectory() {
            dir = existing
        } else {
            dir = FileManager.default.temporaryDirectory
        }
        return dir.appendingPathComponent(filename(for: document))
    }

    /// Pure: cache filename for a document. Keyed by id + the unix
    /// timestamp of `modifiedAt` so a save automatically invalidates the
    /// previous render via filename mismatch.
    static func filename(for document: ProjectDocument) -> String {
        let stamp = Int(document.modifiedAt.timeIntervalSince1970)
        return "\(document.id.uuidString)-\(stamp).jpg"
    }

    // MARK: - Rendering

    /// Walk `clips` and produce a `CGImage` of the first renderable frame.
    /// Returns nil when no clip yields one.
    private static func renderImage(for document: ProjectDocument) async -> CGImage? {
        for clip in document.compositionClips {
            switch clip {
            case .video(let data):
                if let image = await renderVideoFrame(from: data) { return image }
            case .image(let data):
                if let image = renderImageClip(from: data, in: document) { return image }
            case .title, .transition, .track:
                continue
            }
        }
        return nil
    }

    private static func renderVideoFrame(from data: KadrPersistence.VideoClipData) async -> CGImage? {
        guard let url = URL(string: data.url) else { return nil }
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: pixelSize, height: pixelSize)
        let time = data.trimRange?.start.time ?? .zero
        return await withCheckedContinuation { continuation in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, _, _ in
                continuation.resume(returning: image)
            }
        }
    }

    /// Resolve an image clip's token without building a whole composition.
    ///
    /// A list row must not construct a `Video` or decode a project just to draw
    /// a thumbnail, so this reads the token directly: `file:` opens the URL,
    /// `png:` reads the blob the document carries. Same two cases the old
    /// `ImageStorage` enum had, now expressed as tokens.
    private static func renderImageClip(
        from data: KadrPersistence.ImageClipData,
        in document: ProjectDocument
    ) -> CGImage? {
        let token = data.imageToken
        if token.hasPrefix("file:"), let url = URL(string: String(token.dropFirst("file:".count))) {
            return cgImage(at: url)
        }
        if let png = document.imageBlobs?[token] {
            return cgImage(from: png)
        }
        return nil
    }

    private static func cgImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    // MARK: - Cache plumbing

    private static func cacheDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport
            .appendingPathComponent("ReelsStudio", isDirectory: true)
            .appendingPathComponent("Thumbnails", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func writeJPEG(_ image: CGImage, to url: URL) -> Bool {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL,
            "public.jpeg" as CFString,
            1,
            nil
        ) else { return false }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.85,
        ]
        CGImageDestinationAddImage(dest, image, options as CFDictionary)
        return CGImageDestinationFinalize(dest)
    }
}
