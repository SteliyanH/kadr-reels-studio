import Foundation

/// Disk-backed library of saved projects. JSON-per-project under
/// `~/Library/Application Support/ReelsStudio/Projects/<uuid>.json`.
///
/// Reads / writes are synchronous and cheap — JSON encoding of a typical
/// reels project is sub-millisecond. The auto-save path in v0.2 Tier 2
/// schedules saves on a debounced background task; this layer doesn't
/// itself enforce any save cadence.
@MainActor
final class ProjectLibrary: ObservableObject {

    @Published public private(set) var documents: [ProjectDocument]

    /// Project files in the library directory that failed to load. Populated
    /// by ``loadAll(in:fileManager:)`` (v0.6 Tier 2) — drives the "Skipped
    /// projects" recovery section in `ProjectListView`. Mutations are
    /// ``discardSkipped(_:)`` to delete the file off disk and remove it
    /// from this list.
    @Published public private(set) var skippedProjects: [SkippedProject]

    private let directoryURL: URL
    private let fileManager: FileManager

    /// Public init. Builds the default directory under App Support and ensures
    /// it exists; any `FileManager` failure is surfaced as
    /// ``ProjectLibraryError/directorySetup(_:)``.
    public init() throws {
        self.fileManager = .default
        self.directoryURL = try Self.defaultDirectoryURL(fileManager: fileManager)
        let result = try Self.loadAll(in: directoryURL, fileManager: fileManager)
        self.documents = result.documents
        self.skippedProjects = result.skipped
    }

    /// Test-friendly init accepting an explicit directory.
    internal init(directoryURL: URL, fileManager: FileManager = .default) throws {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        try Self.ensureDirectory(at: directoryURL, fileManager: fileManager)
        let result = try Self.loadAll(in: directoryURL, fileManager: fileManager)
        self.documents = result.documents
        self.skippedProjects = result.skipped
    }

    // MARK: - CRUD

    /// Create a fresh empty project, save it, prepend to the in-memory list,
    /// and return it.
    @discardableResult
    public func newProject(name: String = "Untitled") throws -> ProjectDocument {
        let doc = ProjectDocument(name: name)
        try save(doc)  // save() already inserts into `documents`
        return doc
    }

    /// Load a project document by id. Throws ``ProjectLibraryError/notFound(_:)``
    /// when no file matches.
    public func load(id: UUID) throws -> ProjectDocument {
        if let cached = documents.first(where: { $0.id == id }) { return cached }
        let url = fileURL(for: id)
        return try Self.read(at: url)
    }

    /// Persist a document to disk and refresh the in-memory list. Updates
    /// `modifiedAt` to "now" before encoding.
    public func save(_ document: ProjectDocument) throws {
        var stamped = document
        stamped.modifiedAt = Date()
        try Self.write(stamped, to: fileURL(for: stamped.id))
        if let index = documents.firstIndex(where: { $0.id == stamped.id }) {
            documents[index] = stamped
        } else {
            documents.insert(stamped, at: 0)
        }
        // Re-sort by modifiedAt descending so the most recent project is first.
        documents.sort { $0.modifiedAt > $1.modifiedAt }
    }

    /// Delete a project from disk and the in-memory list.
    public func delete(id: UUID) throws {
        let url = fileURL(for: id)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        documents.removeAll { $0.id == id }
    }

    /// Duplicate an existing project under a new id with " Copy" suffixed name.
    @discardableResult
    public func duplicate(id sourceID: UUID) throws -> ProjectDocument {
        let original = try load(id: sourceID)
        let copy = ProjectDocument(
            id: UUID(),
            name: "\(original.name) Copy",
            createdAt: Date(),
            modifiedAt: Date(),
            schemaVersion: original.schemaVersion,
            clips: original.clips,
            overlays: original.overlays,
            audioTracks: original.audioTracks,
            captions: original.captions,
            preset: original.preset
        )
        try save(copy)
        return copy
    }

    // MARK: - Path helpers

    /// `~/Library/Application Support/ReelsStudio/Projects/`. Created if it
    /// doesn't exist. Internal — exposed for tests.
    nonisolated internal static func defaultDirectoryURL(
        fileManager: FileManager
    ) throws -> URL {
        do {
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dir = appSupport
                .appendingPathComponent("ReelsStudio", isDirectory: true)
                .appendingPathComponent("Projects", isDirectory: true)
            try ensureDirectory(at: dir, fileManager: fileManager)
            return dir
        } catch let error as ProjectLibraryError {
            throw error
        } catch {
            throw ProjectLibraryError.directorySetup(error.localizedDescription)
        }
    }

    nonisolated internal static func ensureDirectory(
        at url: URL,
        fileManager: FileManager
    ) throws {
        if fileManager.fileExists(atPath: url.path) { return }
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw ProjectLibraryError.directorySetup(error.localizedDescription)
        }
    }

    private func fileURL(for id: UUID) -> URL {
        directoryURL
            .appendingPathComponent(id.uuidString)
            .appendingPathExtension("json")
    }

    // MARK: - Load / read / write

    /// Walk the directory, decode every `*.json` file, return the list sorted
    /// by `modifiedAt` descending plus a parallel list of files that failed
    /// to load. v0.6 Tier 2 — prior to this the failures were swallowed via
    /// `try?`, which left corrupt or future-schema projects invisible. The
    /// caller surfaces ``LoadResult/skipped`` through the
    /// "Skipped projects" recovery section in `ProjectListView`.
    nonisolated internal static func loadAll(
        in directoryURL: URL,
        fileManager: FileManager
    ) throws -> LoadResult {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return LoadResult(documents: [], skipped: [])
        }
        let entries: [URL]
        do {
            entries = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw ProjectLibraryError.directorySetup(error.localizedDescription)
        }
        var docs: [ProjectDocument] = []
        var skipped: [SkippedProject] = []
        for entry in entries where entry.pathExtension == "json" {
            do {
                docs.append(try read(at: entry))
            } catch let error as ProjectLibraryError {
                skipped.append(SkippedProject(fileURL: entry, reason: .init(from: error)))
            } catch {
                skipped.append(SkippedProject(fileURL: entry, reason: .corruptJSON(error.localizedDescription)))
            }
        }
        return LoadResult(
            documents: docs.sorted { $0.modifiedAt > $1.modifiedAt },
            skipped: skipped.sorted { $0.fileURL.lastPathComponent < $1.fileURL.lastPathComponent }
        )
    }

    /// Pair returned by ``loadAll(in:fileManager:)`` — successful documents
    /// plus the files that couldn't be loaded.
    internal struct LoadResult: Sendable {
        let documents: [ProjectDocument]
        let skipped: [SkippedProject]
    }

    /// Permanently delete a skipped file off disk and drop it from
    /// ``skippedProjects``. Used by the recovery UI's "Discard" action.
    public func discardSkipped(_ skipped: SkippedProject) throws {
        if fileManager.fileExists(atPath: skipped.fileURL.path) {
            do {
                try fileManager.removeItem(at: skipped.fileURL)
            } catch {
                throw ProjectLibraryError.write(error.localizedDescription)
            }
        }
        skippedProjects.removeAll { $0.id == skipped.id }
    }

    nonisolated internal static func read(at url: URL) throws -> ProjectDocument {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ProjectLibraryError.notFound(url.lastPathComponent)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let doc: ProjectDocument
        do {
            doc = try decoder.decode(ProjectDocument.self, from: data)
        } catch {
            throw ProjectLibraryError.decode(error.localizedDescription)
        }
        if doc.schemaVersion > ProjectDocument.currentSchemaVersion {
            throw ProjectLibraryError.unsupportedSchema(doc.schemaVersion)
        }
        return doc
    }

    nonisolated internal static func write(
        _ document: ProjectDocument,
        to url: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data: Data
        do {
            data = try encoder.encode(document)
        } catch {
            throw ProjectLibraryError.encode(error.localizedDescription)
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ProjectLibraryError.write(error.localizedDescription)
        }
    }
}

// MARK: - Skipped project (v0.6 Tier 2 recovery surface)

/// A project file that lives in the library directory but couldn't be loaded.
/// Surfaced through ``ProjectLibrary/skippedProjects`` so users can see what
/// the editor refused, view raw JSON, or discard the file outright instead of
/// having corruptions silently disappear.
public struct SkippedProject: Identifiable, Hashable, Sendable {
    public let id: String  // file name — stable per disk path
    public let fileURL: URL
    public let reason: Reason

    public init(fileURL: URL, reason: Reason) {
        self.id = fileURL.lastPathComponent
        self.fileURL = fileURL
        self.reason = reason
    }

    /// Why the file couldn't be loaded. Mapped from `ProjectLibraryError`
    /// cases that can fire mid-`loadAll`.
    public enum Reason: Hashable, Sendable {
        /// JSON parse / shape mismatch / unreadable file. Message is the
        /// underlying decoder / FileManager description, surfaced as-is in
        /// the recovery UI's "View details" affordance.
        case corruptJSON(String)
        /// Document declares `schemaVersion > currentSchemaVersion` — the
        /// project was saved by a newer build of the app. We refuse to load
        /// it (loading would risk silently dropping fields we don't know
        /// about) but keep it on disk so a future build can pick it up.
        case unsupportedSchema(version: Int)

        init(from error: ProjectLibraryError) {
            switch error {
            case .unsupportedSchema(let v):
                self = .unsupportedSchema(version: v)
            case .decode(let s), .notFound(let s):
                self = .corruptJSON(s)
            case .encode(let s), .write(let s), .directorySetup(let s):
                self = .corruptJSON(s)
            }
        }

        public var displayLabel: String {
            switch self {
            case .corruptJSON:
                return "Couldn't read file"
            case .unsupportedSchema(let v):
                return "Project uses a newer schema (v\(v))"
            }
        }

        public var detail: String {
            switch self {
            case .corruptJSON(let s):
                return s
            case .unsupportedSchema(let v):
                return "This project was saved by a newer build (schema v\(v)). Update Reels Studio to open it."
            }
        }
    }
}

// MARK: - Errors

enum ProjectLibraryError: Error, LocalizedError, Equatable {
    case directorySetup(String)
    case notFound(String)
    case decode(String)
    case encode(String)
    case write(String)
    case unsupportedSchema(Int)

    public var errorDescription: String? {
        switch self {
        case .directorySetup(let s): return "Library setup failed: \(s)"
        case .notFound(let s):       return "Project not found: \(s)"
        case .decode(let s):         return "Couldn't read project: \(s)"
        case .encode(let s):         return "Couldn't write project: \(s)"
        case .write(let s):          return "Save failed: \(s)"
        case .unsupportedSchema(let v):
            return "Project uses a newer schema (\(v)) than this app supports."
        }
    }
}
