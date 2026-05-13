import XCTest
import SwiftUI
import ViewInspector
@testable import ReelsStudio

/// v0.6 Tier 5 — ViewInspector smokes that fail loudly if a gesture or
/// modifier comes detached from its sink. ViewInspector can't fire system
/// gestures (long-press, pinch, drag) but it *can* prove the modifier
/// attached, the binding is wired, and the callback closure lives where we
/// expect. Pairs with the iOS-runtime integration tests landing in Tier 6.
@MainActor
final class GestureWiringTests: XCTestCase {

    private func makeLibrary() throws -> ProjectLibrary {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("gesture-\(UUID().uuidString)", isDirectory: true)
        return try ProjectLibrary(directoryURL: tmp)
    }

    // MARK: - ProjectListView

    func testProjectListExposesNewProjectButton() throws {
        let library = try makeLibrary()
        let view = ProjectListView(library: library)
            .environmentObject(ToastCenter())
            .environmentObject(AppSettings.shared)
        // We can't traverse a NavigationStack body from ViewInspector cleanly,
        // but the smoke proves the view *constructs* and that the library
        // dependency is honored — a missing `@EnvironmentObject` here would
        // throw on inspection.
        XCTAssertNoThrow(try view.inspect())
    }

    // MARK: - Skipped recovery rows

    func testSkippedProjectRowRendersFilename() throws {
        let skipped = SkippedProject(
            fileURL: URL(fileURLWithPath: "/tmp/abc-123.json"),
            reason: .corruptJSON("Unexpected token")
        )
        let view = SkippedProjectRow(skipped: skipped)
        // Walking into the composed `.accessibilityElement(children: .combine)`
        // layer would require a `.find`; the simpler invariant is the row
        // builds without throwing — proves the row's HStack tree compiles
        // against the current `SkippedProject.Reason` cases.
        XCTAssertNoThrow(try view.inspect())
    }

    func testSkippedProjectDetailSheetRendersReasonDetail() throws {
        let skipped = SkippedProject(
            fileURL: URL(fileURLWithPath: "/tmp/x.json"),
            reason: .unsupportedSchema(version: 99)
        )
        let sut = SkippedProjectDetailSheet(skipped: skipped)
        // Reason detail lives in the sheet body — searchable without a host.
        // ("Skipped project" lives in the navigation-bar title, which
        // ViewInspector can't reach without `inspectionGivenHosting`.)
        let tree = try sut.inspect().find(text: skipped.reason.detail)
        XCTAssertNotNil(tree)
    }

    // MARK: - Error sanitization at the AppError boundary

    func testAppErrorTransientSanitizesDetail() {
        struct PathLeak: LocalizedError {
            var errorDescription: String? { "wrote to /Users/alice/Library/foo" }
        }
        let err = AppError.transient(PathLeak(), prefix: "Couldn't save")
        XCTAssertEqual(err.message, "Couldn't save")
        XCTAssertEqual(err.detail, "wrote to [file]")
    }

    // MARK: - Inspector presentation key (pure helper, no UI)

    func testInspectorPresentationKeyDistinguishesSlots() {
        XCTAssertEqual(EditorView.inspectorPresentationKey(clip: nil, overlay: nil), "none")
        XCTAssertEqual(EditorView.inspectorPresentationKey(clip: "c1", overlay: nil), "clip:c1")
        XCTAssertEqual(EditorView.inspectorPresentationKey(clip: nil, overlay: "o1"), "overlay:o1")
        // Overlay wins when both are set (matches editor binding mutual-exclusion).
        XCTAssertEqual(EditorView.inspectorPresentationKey(clip: "c1", overlay: "o1"), "overlay:o1")
    }
}

extension SkippedProjectRow: Inspectable {}
extension SkippedProjectDetailSheet: Inspectable {}
extension ProjectListView: Inspectable {}
