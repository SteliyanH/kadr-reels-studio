import Foundation
import Kadr
import KadrPersistence

/// How this app names the images in a composition.
///
/// A thin composite over ``KadrPersistence/FileImageStore``: images live as
/// files in the library's media directory, and the project references them.
///
/// ## Why not keep the bytes in the document
///
/// It used to. Every image with no file behind it was base64'd into the project
/// JSON, which made a project self-contained and made it enormous — a ten-photo
/// slideshow at full resolution is on the order of a hundred megabytes of text.
/// Referencing is what every editor worth the name does.
///
/// ## Why the tokens are relative
///
/// The store writes `file:<name>.png`, resolved against a directory the app
/// locates at runtime. The previous version wrote `file:<absoluteString>`, and
/// an iOS container path carries a UUID that changes on reinstall and on
/// restore from backup — so an absolute reference could point nowhere while the
/// project itself was perfectly intact.
///
/// ## Legacy blobs
///
/// A document written before this change carries its images in `imageBlobs`.
/// Those still resolve, read-only, so nothing stops opening; the next save
/// writes them out as files and the field disappears on its own.
final class ProjectImageStore: ImageStore, @unchecked Sendable {

    private let files: FileImageStore
    private let legacyBlobs: [String: Data]

    /// - Parameters:
    ///   - directory: where images are kept. One directory per library, not per
    ///     project — content addressing means two projects using the same photo
    ///     store it once.
    ///   - blobs: `imageBlobs` from an older document, resolved but never written.
    init(directory: URL, blobs: [String: Data] = [:]) throws {
        self.files = try FileImageStore(directory: directory)
        self.legacyBlobs = blobs
    }

    // MARK: - ImageStore

    func token(for image: PlatformImage) throws -> String {
        try files.token(for: image)
    }

    func image(for token: String) throws -> PlatformImage {
        do {
            return try files.image(for: token)
        } catch {
            // A `png:` token from a document written before the switch. Falling
            // back rather than failing is what makes the upgrade invisible.
            guard let data = legacyBlobs[token], let image = PlatformImage(data: data) else {
                throw error
            }
            return image
        }
    }

    /// A store over a fresh temporary directory.
    ///
    /// For tests and previews. Named rather than defaulted, because a store
    /// that silently wrote to a temporary directory in production would lose
    /// every image the next time the system cleaned it up.
    /// Non-throwing, so it can sit in a default argument. If a directory
    /// cannot be created under `/tmp` the process has problems this store
    /// cannot help with, and failing loudly here beats a store that silently
    /// resolves nothing.
    static func temporary() -> ProjectImageStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kadr-studio-images-\(UUID().uuidString)")
        guard let store = try? ProjectImageStore(directory: directory) else {
            preconditionFailure("could not create a temporary image directory at \(directory.path)")
        }
        return store
    }

    // MARK: - Provenance

    /// Record that `image` came from `url`, copying it into the store.
    ///
    /// Called when migrating a legacy document whose images were referenced by
    /// absolute path. Copying rather than re-referencing is the point: the
    /// original may sit in a temporary directory, or in a container path that
    /// will not survive the next install.
    func adopt(_ image: PlatformImage, from url: URL) {
        _ = try? files.token(for: image)
    }

    /// Delete stored images no live composition refers to.
    @discardableResult
    func prune(keeping tokens: Set<String>) throws -> Int {
        try files.prune(keeping: tokens)
    }
}
