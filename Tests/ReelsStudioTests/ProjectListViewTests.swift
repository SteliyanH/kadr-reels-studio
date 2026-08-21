import XCTest
import Kadr
@testable import ReelsStudio

/// Tests for v0.2 Tier 2 — pure helpers + smoke for `ProjectListView`. Body
/// rendering / NavigationStack pushes are covered by integration testing in
/// the simulator app; here we verify the helpers ProjectListView relies on.
@MainActor
final class ProjectListViewTests: XCTestCase {

    private var tempDirectory: URL!
    private var library: ProjectLibrary!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        library = try ProjectLibrary(directoryURL: tempDirectory)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
    }

    // MARK: - Library auto-save through Project.toDocument

    func testAutoSaveRoundTripsClipMutationToDisk() throws {
        // Create a project, mutate the runtime project, save back through
        // the library, re-init a fresh library — the mutation should survive.
        var doc = try library.newProject(name: "AutoSave")
        var project = doc.toRuntimeProject()
        XCTAssertEqual(project.clips.count, 0)

        // Add a title clip.
        let title = TitleSequence(
            "Hi",
            duration: 1.0,
            style: TextStyle.default
        )
        project.clips.append(title)

        // Persist.
        let updated = project.toDocument(inheriting: doc, name: doc.name)
        try library.save(updated)
        doc = updated

        // Simulate app relaunch.
        let library2 = try ProjectLibrary(directoryURL: tempDirectory)
        let reloaded = library2.documents.first { $0.id == doc.id }
        XCTAssertNotNil(reloaded)
        XCTAssertEqual(reloaded?.clips.count, 1)
        if case .title(let t) = reloaded?.clips.first {
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

    func testPresetLabelMapsPortraitPresetsToNineBySixteen() {
        XCTAssertEqual(ProjectRow.presetLabel(for: .reelsAndShorts), "9:16")
        XCTAssertEqual(ProjectRow.presetLabel(for: .tiktok), "9:16")
    }

    func testPresetLabelMapsSquareAndCinema() {
        XCTAssertEqual(ProjectRow.presetLabel(for: .square), "1:1")
        XCTAssertEqual(ProjectRow.presetLabel(for: .cinema), "16:9")
    }

    func testPresetLabelReducesACustomSize() {
        XCTAssertEqual(
            ProjectRow.presetLabel(
                for: .custom(width: 1080, height: 1920, frameRate: 30, codecHEVC: true)
            ),
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
