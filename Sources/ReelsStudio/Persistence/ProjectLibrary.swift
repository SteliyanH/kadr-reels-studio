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

    private let directoryURL: URL
    private let fileManager: FileManager

    /// Public init. Builds the default directory under App Support and ensures
    /// it exists; any `FileManager` failure is surfaced as
    /// ``ProjectLibraryError/directorySetup(_:)``.
    public init() throws {
        self.fileManager = .default
        self.directoryURL = try Self.defaultDirectoryURL(fileManager: fileManager)
        self.documents = try Self.loadAll(in: directoryURL, fileManager: fileManager)
    }

    /// Test-friendly init accepting an explicit directory.
    internal init(directoryURL: URL, fileManager: FileManager = .default) throws {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        try Self.ensureDirectory(at: directoryURL, fileManager: fileManager)
        self.documents = try Self.loadAll(in: directoryURL, fileManager: fileManager)
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
    /// by `modifiedAt` descending. Files that fail to decode are skipped — a
    /// corrupt project shouldn't take the whole library down.
    nonisolated internal static func loadAll(
        in directoryURL: URL,
        fileManager: FileManager
    ) throws -> [ProjectDocument] {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return [] }
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
        for entry in entries where entry.pathExtension == "json" {
            if let doc = try? read(at: entry) {
                docs.append(doc)
            }
        }
        return docs.sorted { $0.modifiedAt > $1.modifiedAt }
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
