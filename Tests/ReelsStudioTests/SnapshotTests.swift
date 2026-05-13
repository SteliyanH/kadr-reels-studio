import XCTest
import SwiftUI
import SnapshotTesting
@testable import ReelsStudio

/// v0.6 Tier 5 — visual-regression baselines for the app's main screens.
///
/// Mirrors kadr-ui v0.10.1's pattern:
/// - First run on a fresh checkout emits baseline images under
///   `Tests/ReelsStudioTests/__Snapshots__/` and fails with "no reference".
///   Commit the generated baselines; subsequent runs diff against them.
/// - Re-record after intentional visual changes by setting `record: true` per
///   call or `isRecording = true` globally.
/// - Skipped on CI by default: macOS/Xcode version drift between contributor
///   laptops and the GitHub runner produces tiny pixel diffs that fail
///   otherwise-correct rendering. Override with `KADR_UI_FORCE_SNAPSHOTS=1`.
@MainActor
final class SnapshotTests: XCTestCase {

    private let phoneSize = CGSize(width: 393, height: 852)  // iPhone 17

    /// Snapshot tests run on every invocation. Baselines are pinned to the
    /// recording toolchain — CI runs `macos-15` with `latest-stable` Xcode,
    /// matching the laptop they're recorded on, so version drift is small
    /// enough to tolerate. If a future CI bump churns baselines we'll either
    /// re-record or gate them; for now the simplicity wins.
    ///
    /// xcodebuild doesn't propagate host env to the simulator process
    /// without scheme-level wiring, so the env-skip pattern used in
    /// kadr-ui's `swift test` doesn't apply here.

    // MARK: - Fixtures

    private func makeLibrary() throws -> ProjectLibrary {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshot-\(UUID().uuidString)", isDirectory: true)
        return try ProjectLibrary(directoryURL: tmp)
    }

    private func makeSampleDocument(name: String) -> ProjectDocument {
        ProjectDocument(name: name)
    }

    // MARK: - ProjectListView

    func testProjectListEmptyState() throws {
        let library = try makeLibrary()
        let view = ProjectListView(library: library)
            .environmentObject(ToastCenter())
            .environmentObject(AppSettings.shared)
            .frame(width: phoneSize.width, height: phoneSize.height)

        assertSnapshot(of: view, as: .image(layout: .fixed(width: phoneSize.width, height: phoneSize.height)))
    }

    func testProjectListWithDocuments() throws {
        let library = try makeLibrary()
        _ = try library.newProject(name: "Reel A")
        _ = try library.newProject(name: "Reel B")

        let view = ProjectListView(library: library)
            .environmentObject(ToastCenter())
            .environmentObject(AppSettings.shared)
            .frame(width: phoneSize.width, height: phoneSize.height)

        assertSnapshot(of: view, as: .image(layout: .fixed(width: phoneSize.width, height: phoneSize.height)))
    }

    // MARK: - Recovery rows (v0.6 Tier 2 surface)

    func testSkippedProjectRowCorruptJSON() {
        let skipped = SkippedProject(
            fileURL: URL(fileURLWithPath: "/tmp/abc-123.json"),
            reason: .corruptJSON("Unexpected character at line 3")
        )
        let view = SkippedProjectRow(skipped: skipped)
            .padding()
            .background(Color(.systemBackground))

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 360, height: 80)))
    }

    func testSkippedProjectRowFutureSchema() {
        let skipped = SkippedProject(
            fileURL: URL(fileURLWithPath: "/tmp/future.json"),
            reason: .unsupportedSchema(version: 99)
        )
        let view = SkippedProjectRow(skipped: skipped)
            .padding()
            .background(Color(.systemBackground))

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 360, height: 80)))
    }

    func testSkippedProjectDetailSheet() {
        let skipped = SkippedProject(
            fileURL: URL(fileURLWithPath: "/tmp/future.json"),
            reason: .unsupportedSchema(version: 99)
        )
        let view = SkippedProjectDetailSheet(skipped: skipped)
            .frame(width: phoneSize.width, height: 480)

        assertSnapshot(of: view, as: .image(layout: .fixed(width: phoneSize.width, height: 480)))
    }
}
