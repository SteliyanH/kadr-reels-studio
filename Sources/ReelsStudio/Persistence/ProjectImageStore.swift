import Foundation
import CryptoKit
import Kadr
import KadrPersistence

/// How this app names the images in a composition, so `KadrPersistence` can
/// write them down.
///
/// An `ImageClip` holds a decoded `PlatformImage` and nothing else — by the time
/// a composition reaches the encoder, whether that image came from the photo
/// library or was synthesised in-process is no longer knowable from the image.
/// That provenance is the app's to remember, which is why `ImageStore` is a
/// protocol the host implements rather than something the package guesses at.
///
/// Two kinds of token, matching what the app has always stored:
///
/// - `file:<url>` — an image that lives somewhere on disk. Only the location is
///   written to the project file.
/// - `png:<sha256>` — an image with no file behind it (a synthesised swatch, a
///   pasted bitmap). The PNG bytes travel in the document, keyed by their own
///   hash.
///
/// Hashing rather than counting matters: a token must be **stable across saves**.
/// A store that minted `image-1`, `image-2`, … per encode would rewrite every
/// byte of the project file on every save, defeating the sorted-key determinism
/// the format is built for, and making "is this project dirty?" unanswerable.
final class ProjectImageStore: ImageStore, @unchecked Sendable {

    private let lock = NSLock()

    /// Tokens for images whose origin the app knows, keyed by instance identity.
    /// Populated on import and on load.
    private var tokensByImage: [ObjectIdentifier: String] = [:]

    /// Images already resolved, so a decode → encode cycle reuses the same
    /// instances and therefore the same tokens.
    private var imagesByToken: [String: PlatformImage] = [:]

    /// PNG payloads for `png:` tokens. Serialised with the document.
    private(set) var blobs: [String: Data] = [:]

    init(blobs: [String: Data] = [:]) {
        self.blobs = blobs
    }

    // MARK: - Registration

    /// Record that `image` came from `url`, so it is stored by reference rather
    /// than by embedding its bytes. Call this at import time.
    func register(_ image: PlatformImage, from url: URL) {
        lock.lock(); defer { lock.unlock() }
        let token = "file:\(url.absoluteString)"
        tokensByImage[ObjectIdentifier(image)] = token
        imagesByToken[token] = image
    }

    // MARK: - ImageStore

    func token(for image: PlatformImage) throws -> String {
        lock.lock()
        if let known = tokensByImage[ObjectIdentifier(image)] {
            lock.unlock()
            return known
        }
        lock.unlock()

        guard let png = Self.pngData(from: image) else {
            throw ProjectImageStoreError.notEncodable
        }
        let token = "png:\(Self.hex(SHA256.hash(data: png)))"

        lock.lock(); defer { lock.unlock() }
        tokensByImage[ObjectIdentifier(image)] = token
        imagesByToken[token] = image
        blobs[token] = png
        return token
    }

    func image(for token: String) throws -> PlatformImage {
        lock.lock()
        if let cached = imagesByToken[token] {
            lock.unlock()
            return cached
        }
        let blob = blobs[token]
        lock.unlock()

        let resolved: PlatformImage?
        if token.hasPrefix("file:") {
            let raw = String(token.dropFirst("file:".count))
            resolved = URL(string: raw).flatMap { url in
                (try? Data(contentsOf: url)).flatMap(PlatformImage.init(data:))
            }
        } else if let blob {
            resolved = PlatformImage(data: blob)
        } else {
            resolved = nil
        }

        guard let image = resolved else {
            throw ProjectImageStoreError.unresolvable(token)
        }
        lock.lock()
        imagesByToken[token] = image
        tokensByImage[ObjectIdentifier(image)] = token
        lock.unlock()
        return image
    }

    // MARK: - Helpers

    /// Only the blobs still referenced by `tokens`. Called before a save so a
    /// project file doesn't accumulate the bytes of every image ever deleted
    /// from it.
    func blobs(reachableFrom tokens: Set<String>) -> [String: Data] {
        lock.lock(); defer { lock.unlock() }
        return blobs.filter { tokens.contains($0.key) }
    }

    private static func hex(_ digest: SHA256Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func pngData(from image: PlatformImage) -> Data? {
        #if canImport(UIKit)
        return image.pngData()
        #else
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
        #endif
    }
}

enum ProjectImageStoreError: Error, LocalizedError, Equatable {
    /// The image could not be turned into PNG bytes, so there is nothing to store.
    case notEncodable
    /// A token in the document resolves to nothing — the file moved, or the blob
    /// was pruned.
    case unresolvable(String)

    var errorDescription: String? {
        switch self {
        case .notEncodable:
            return "An image in this project couldn't be saved."
        case .unresolvable:
            return "An image in this project is missing."
        }
    }
}
