import XCTest
import Kadr
import KadrPersistence
@testable import ReelsStudio

/// Tests for v0.2 Tier 2 — pure helpers + smoke for `ProjectListView`. Body
/// rendering / NavigationStack pushes are covered by integration testing in
/// the simulator app; here we verify the helpers ProjectListView relies on.
@MainActor
final class ProjectListViewTests: XCTestCase {

    private var tempDirectory: URL!
    private var library: ProjectLibrary!

    // The `async` overrides: an override inherits its superclass's isolation,
    // and `setUpWithError()` / `tearDownWithError()` are nonisolated — so
    // neither could touch this class's main-actor state. Swift lets an
    // override of an `async` method add isolation.
    @MainActor
    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        library = try ProjectLibrary(directoryURL: tempDirectory)
    }

    @MainActor
    override func tearDown() async throws {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
    }

    // MARK: - Library auto-save through Project.toDocument

    func testAutoSaveRoundTripsClipMutationToDisk() throws {
        // Create a project, mutate the runtime project, save back through
        // the library, re-init a fresh library — the mutation should survive.
        var doc = try library.newProject(name: "AutoSave")
        var project = try doc.toRuntimeProject(images: ProjectImageStore.temporary())
        XCTAssertEqual(project.clips.count, 0)

        // Add a title clip.
        let title = TitleSequence(
            "Hi",
            duration: 1.0,
            style: TextStyle.default
        )
        project.clips.append(title)

        // Persist.
        let updated = try project.toDocument(inheriting: doc, name: doc.name, images: ProjectImageStore.temporary())
        try library.save(updated)
        doc = updated

        // Simulate app relaunch.
        let library2 = try ProjectLibrary(directoryURL: tempDirectory)
        let reloaded = library2.documents.first { $0.id == doc.id }
        XCTAssertNotNil(reloaded)
        XCTAssertEqual(reloaded?.compositionClips.count, 1)
        if case .title(let t) = reloaded?.compositionClips.first {
            XCTAssertEqual(t.text, "Hi")
        } else {
            XCTFail("Expected title clip after reload")
        }
    }

    func testNewProjectAndDeleteFlow() throws {
        let a = try library.newProject(name: "A")
        let b = try library.newProject(name: "B")
        XCTAssertEqual(library.documents.count, 2)

        try library.delete(id: a.id)
        XCTAssertEqual(library.documents.count, 1)
        XCTAssertEqual(library.documents.first?.id, b.id)
    }

    func testDocumentsListIsModifiedAtDescending() throws {
        let first = try library.newProject(name: "First")
        Thread.sleep(forTimeInterval: 0.01)
        let second = try library.newProject(name: "Second")
        XCTAssertEqual(library.documents.first?.id, second.id)
        XCTAssertEqual(library.documents.last?.id, first.id)
    }

    // MARK: - Nav count line (v0.8 Tier 5a)

    func testCountLineOmitsSkippedWhenThereAreNone() {
        XCTAssertEqual(ProjectListView.countLine(projects: 3, skipped: 0), "3 projects")
    }

    func testCountLineSingularisesBothHalves() {
        XCTAssertEqual(
            ProjectListView.countLine(projects: 1, skipped: 1),
            "1 project · 1 skipped file"
        )
    }

    func testCountLineMatchesTheDesignsExample() {
        XCTAssertEqual(
            ProjectListView.countLine(projects: 3, skipped: 2),
            "3 projects · 2 skipped files"
        )
    }

    func testCountLineHandlesZeroProjectsWithSkippedFiles() {
        // Reachable state: every document failed to load, so the empty state
        // does *not* show and the header still has to say something true.
        XCTAssertEqual(
            ProjectListView.countLine(projects: 0, skipped: 2),
            "0 projects · 2 skipped files"
        )
    }

    // MARK: - Row preset tag

    /// A `PresetData` as the persisted document carries it.
    private func fixture(_ kind: String, width: Int? = nil, height: Int? = nil) -> KadrPersistence.PresetData {
        KadrPersistence.PresetData(kind: kind, width: width, height: height, frameRate: nil, codec: nil)
    }

    func testPresetLabelMapsPortraitPresetsToNineBySixteen() {
        XCTAssertEqual(ProjectRow.presetLabel(for: fixture("reelsAndShorts")), "9:16")
        XCTAssertEqual(ProjectRow.presetLabel(for: fixture("tiktok")), "9:16")
    }

    func testPresetLabelMapsSquareAndCinema() {
        XCTAssertEqual(ProjectRow.presetLabel(for: fixture("square")), "1:1")
        XCTAssertEqual(ProjectRow.presetLabel(for: fixture("cinema")), "16:9")
    }

    func testPresetLabelFallsBackForAMissingComposition() {
        // A row must still render rather than crash if a document without a
        // composition ever reaches it.
        XCTAssertEqual(ProjectRow.presetLabel(for: nil), "Auto")
        XCTAssertEqual(ProjectRow.presetLabel(for: fixture("somethingNewer")), "Auto")
    }

    func testPresetLabelReducesACustomSize() {
        XCTAssertEqual(
            ProjectRow.presetLabel(for: fixture("custom", width: 1080, height: 1920)),
            "9:16"
        )
    }

    func testRatioSurvivesADegenerateSize() {
        XCTAssertEqual(ProjectRow.ratio(width: 0, height: 0), "0:0")
    }

    func testClipCountLabelSingularises() {
        XCTAssertEqual(ProjectRow.clipCountLabel(1), "1 clip")
        XCTAssertEqual(ProjectRow.clipCountLabel(3), "3 clips")
    }

    // MARK: - Body smoke

    func testListViewBodyConstructs() {
        let view = ProjectListView(library: library)
        _ = view.body
    }

    func testListViewBodyConstructsWithProjects() throws {
        _ = try library.newProject(name: "One")
        _ = try library.newProject(name: "Two")
        let view = ProjectListView(library: library)
        _ = view.body
    }

    func testProjectRowBodyConstructs() throws {
        let doc = try library.newProject(name: "Row")
        _ = ProjectRow(document: doc).body
    }

    func testLibraryHostBuildsLibraryFromDefaultInit() {
        // The fallback `LibraryHost` flow only fires when default init throws.
        // Default init succeeds on every reasonable test environment, so the
        // host's library should be non-nil.
        let host = LibraryHost()
        XCTAssertNotNil(host.library)
    }
}
