import XCTest
@testable import ReelsStudio

/// Tests for v0.2 Tier 1 — disk-backed `ProjectLibrary`. Uses an isolated temp
/// directory per test so concurrent runs don't collide and a failed test can't
/// leak fixtures into the user's actual App Support directory.
@MainActor
final class ProjectLibraryTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
    }

    // MARK: - CRUD

    func testNewProjectAppearsInDocumentsList() throws {
        let library = try ProjectLibrary(directoryURL: tempDirectory)
        XCTAssertTrue(library.documents.isEmpty)
        let doc = try library.newProject(name: "First")
        XCTAssertEqual(doc.name, "First")
        XCTAssertEqual(library.documents.count, 1)
        XCTAssertEqual(library.documents.first?.id, doc.id)
    }

    func testSaveCreatesJSONFile() throws {
        let library = try ProjectLibrary(directoryURL: tempDirectory)
        let doc = try library.newProject(name: "Persisted")
        let expectedFile = tempDirectory
            .appendingPathComponent(doc.id.uuidString)
            .appendingPathExtension("json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedFile.path))
    }

    func testSaveUpdatesModifiedTimestamp() throws {
        let library = try ProjectLibrary(directoryURL: tempDirectory)
        var doc = try library.newProject(name: "TS")
        let originalModified = doc.modifiedAt
        // Mutate + save again. Sleep a few ms to ensure Date() resolution differs.
        Thread.sleep(forTimeInterval: 0.01)
        doc.name = "Renamed"
        try library.save(doc)
        let updated = library.documents.first { $0.id == doc.id }!
        XCTAssertGreaterThan(updated.modifiedAt, originalModified)
        XCTAssertEqual(updated.name, "Renamed")
    }

    func testDeleteRemovesFromListAndDisk() throws {
        let library = try ProjectLibrary(directoryURL: tempDirectory)
        let doc = try library.newProject(name: "Doomed")
        let file = tempDirectory
            .appendingPathComponent(doc.id.uuidString)
            .appendingPathExtension("json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        try library.delete(id: doc.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(library.documents.isEmpty)
    }

    func testDuplicateAppendsCopySuffix() throws {
        let library = try ProjectLibrary(directoryURL: tempDirectory)
        let original = try library.newProject(name: "Original")
        let copy = try library.duplicate(id: original.id)
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.name, "Original Copy")
        XCTAssertEqual(library.documents.count, 2)
    }

    func testLoadReturnsCachedDocument() throws {
        let library = try ProjectLibrary(directoryURL: tempDirectory)
        let doc = try library.newProject(name: "Cached")
        let loaded = try library.load(id: doc.id)
        XCTAssertEqual(loaded.id, doc.id)
    }

    func testLoadThrowsForUnknownID() throws {
        let library = try ProjectLibrary(directoryURL: tempDirectory)
        XCTAssertThrowsError(try library.load(id: UUID()))
    }

    // MARK: - Library re-init reads back what's on disk

    func testReinitReadsBackPreviouslySavedProjects() throws {
        let library1 = try ProjectLibrary(directoryURL: tempDirectory)
        let doc = try library1.newProject(name: "Persistent")
        // Simulate app restart: throw away the library, re-init pointing at
        // the same dir.
        let library2 = try ProjectLibrary(directoryURL: tempDirectory)
        XCTAssertEqual(library2.documents.count, 1)
        XCTAssertEqual(library2.documents.first?.id, doc.id)
    }

    // MARK: - Defensive: corrupt JSON doesn't take down the library

    func testCorruptJSONFileSkippedDuringLoad() throws {
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        // Drop a malformed JSON in the dir before init.
        let bogusURL = tempDirectory
            .appendingPathComponent("bogus")
            .appendingPathExtension("json")
        try Data("not json".utf8).write(to: bogusURL)

        let library = try ProjectLibrary(directoryURL: tempDirectory)
        XCTAssertTrue(library.documents.isEmpty)  // bogus skipped, not crashed
    }

    // MARK: - Sort order: most-recently-modified first

    func testDocumentsSortedByModifiedAtDescending() throws {
        let library = try ProjectLibrary(directoryURL: tempDirectory)
        _ = try library.newProject(name: "First")
        Thread.sleep(forTimeInterval: 0.01)
        let second = try library.newProject(name: "Second")
        XCTAssertEqual(library.documents.first?.id, second.id)
    }

    // MARK: - Skipped project surface (v0.6 Tier 2)

    func testCorruptJSONIsSurfacedAsSkipped() throws {
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let url = tempDirectory
            .appendingPathComponent("\(UUID().uuidString).json")
        try Data("{ this is not valid JSON }".utf8).write(to: url)

        let library = try ProjectLibrary(directoryURL: tempDirectory)
        XCTAssertTrue(library.documents.isEmpty)
        XCTAssertEqual(library.skippedProjects.count, 1)
        guard case .corruptJSON = library.skippedProjects.first?.reason else {
            return XCTFail("Expected .corruptJSON reason, got \(String(describing: library.skippedProjects.first?.reason))")
        }
    }

    func testDiscardSkippedRemovesFileFromDisk() throws {
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let url = tempDirectory.appendingPathComponent("\(UUID().uuidString).json")
        try Data("not json".utf8).write(to: url)

        let library = try ProjectLibrary(directoryURL: tempDirectory)
        let skipped = try XCTUnwrap(library.skippedProjects.first)
        try library.discardSkipped(skipped)

        XCTAssertTrue(library.skippedProjects.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - Schema versioning

    func testFutureSchemaVersionIsRejected() throws {
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        // Hand-craft a JSON with a schema version higher than current.
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "name": "FromTheFuture",
          "createdAt": "2030-01-01T00:00:00Z",
          "modifiedAt": "2030-01-01T00:00:00Z",
          "schemaVersion": 999,
          "clips": [],
          "overlays": [],
          "audioTracks": [],
          "captions": [],
          "preset": { "auto": {} }
        }
        """
        let url = tempDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        try json.data(using: .utf8)!.write(to: url)

        // v0.6 Tier 2: future-schema files are now surfaced via
        // `skippedProjects` with `.unsupportedSchema(version:)` instead of
        // being silently swallowed.
        let library = try ProjectLibrary(directoryURL: tempDirectory)
        XCTAssertTrue(library.documents.isEmpty)
        XCTAssertEqual(library.skippedProjects.count, 1)
        guard case .unsupportedSchema(let version) = library.skippedProjects.first?.reason else {
            return XCTFail("Expected .unsupportedSchema, got \(String(describing: library.skippedProjects.first?.reason))")
        }
        XCTAssertEqual(version, 999)
    }
}
