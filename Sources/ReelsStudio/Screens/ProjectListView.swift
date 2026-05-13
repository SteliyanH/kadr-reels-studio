import SwiftUI

/// Launch screen — lists every saved project in the ``ProjectLibrary`` and
/// hands the user a way to start a new one. Tapping a row pushes the
/// ``EditorView`` for that document onto the navigation stack; auto-save in
/// the editor keeps the on-disk copy in sync.
///
/// Tier 2 of v0.2 — first-run UX. Replaces the v0.1 launch path that booted
/// straight into a hardcoded sample project.
@available(iOS 16, *)
struct ProjectListView: View {

    @ObservedObject var library: ProjectLibrary

    /// Drives `NavigationStack` programmatic navigation: pushing a document id
    /// pushes the corresponding `EditorView`. Held by the list so the
    /// "+ New Project" button can both create and navigate in one step.
    @State private var path: [UUID] = []

    /// v0.6 Tier 3: id of the last-opened project, persisted per-scene so a
    /// cold relaunch puts the user back into the editor for whatever they
    /// were on. Updated reactively from `path` so backing out clears it.
    @SceneStorage("library.lastOpenedProjectID") private var lastOpenedProjectID: String = ""

    /// Surfaces save / new-project / delete failures inline. Tier 3 will
    /// replace this with the global toast / alert infra; for now a minimal
    /// alert keeps the list robust.
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Projects")
                .onAppear { restoreLastOpenedIfPossible() }
                .onChange(of: path) { newPath in
                    lastOpenedProjectID = newPath.last?.uuidString ?? ""
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            createNewProject()
                        } label: {
                            Label("New Project", systemImage: "plus")
                        }
                    }
                }
                .navigationDestination(for: UUID.self) { id in
                    if let doc = library.documents.first(where: { $0.id == id }) {
                        EditorView(document: doc, library: library)
                    } else {
                        // Document was deleted out from under us — bounce
                        // back to the list with a placeholder.
                        Text("Project not found")
                            .foregroundStyle(.secondary)
                    }
                }
                .alert(
                    "Something went wrong",
                    isPresented: Binding(
                        get: { errorMessage != nil },
                        set: { if !$0 { errorMessage = nil } }
                    ),
                    presenting: errorMessage
                ) { _ in
                    Button("OK", role: .cancel) { errorMessage = nil }
                } message: { message in
                    Text(message)
                }
        }
    }

    /// Skipped-project file selected for the JSON detail sheet.
    @State private var inspectingSkipped: SkippedProject?

    /// Skipped-project file pending discard confirmation.
    @State private var pendingDiscard: SkippedProject?

    @ViewBuilder
    private var content: some View {
        if library.documents.isEmpty && library.skippedProjects.isEmpty {
            emptyState
        } else {
            projectList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No projects yet")
                .font(.title3.weight(.semibold))
            Text("Start with a new project, or import the bundled sample to see what the editor can do.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            HStack(spacing: 12) {
                Button { createNewProject() } label: {
                    Label("New Project", systemImage: "plus.circle.fill")
                        .font(.body.bold())
                }
                .buttonStyle(.borderedProminent)
                Button { importSample() } label: {
                    Label("Sample", systemImage: "wand.and.stars")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func importSample() {
        do {
            // Run the sample project through the persistence bridge so the
            // user lands on a real on-disk project they can keep editing.
            let runtime = SampleProject.make()
            var doc = try library.newProject(name: "Sample")
            doc = runtime.toDocument(inheriting: doc, name: "Sample")
            try library.save(doc)
            path.append(doc.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var projectList: some View {
        List {
            Section {
                ForEach(library.documents) { doc in
                    NavigationLink(value: doc.id) {
                        ProjectRow(document: doc)
                    }
                }
                .onDelete(perform: deleteProjects)
            }
            if !library.skippedProjects.isEmpty {
                skippedSection
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $inspectingSkipped) { skipped in
            SkippedProjectDetailSheet(skipped: skipped)
        }
        .confirmationDialog(
            "Discard this project file?",
            isPresented: Binding(
                get: { pendingDiscard != nil },
                set: { if !$0 { pendingDiscard = nil } }
            ),
            presenting: pendingDiscard
        ) { skipped in
            Button("Discard", role: .destructive) {
                discard(skipped)
            }
            Button("Cancel", role: .cancel) { pendingDiscard = nil }
        } message: { skipped in
            Text("\(skipped.id) will be permanently removed from the library.")
        }
    }

    @ViewBuilder
    private var skippedSection: some View {
        Section {
            ForEach(library.skippedProjects) { skipped in
                SkippedProjectRow(skipped: skipped)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDiscard = skipped
                        } label: {
                            Label("Discard", systemImage: "trash")
                        }
                        Button {
                            inspectingSkipped = skipped
                        } label: {
                            Label("Details", systemImage: "doc.text.magnifyingglass")
                        }
                        .tint(.blue)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { inspectingSkipped = skipped }
            }
        } header: {
            Text("Skipped projects")
        } footer: {
            Text("These files couldn't be loaded. Tap one to see details, or swipe to discard.")
        }
    }

    private func discard(_ skipped: SkippedProject) {
        do {
            try library.discardSkipped(skipped)
        } catch {
            errorMessage = error.localizedDescription
        }
        pendingDiscard = nil
    }

    // MARK: - Actions

    /// v0.6 Tier 3: if the last navigation pushed an editor for project X,
    /// re-push it on cold launch so the user lands where they left off.
    /// No-op when the id is missing or no longer maps to a document (the
    /// user could have deleted it on another scene or via Files).
    private func restoreLastOpenedIfPossible() {
        guard path.isEmpty,
              !lastOpenedProjectID.isEmpty,
              let uuid = UUID(uuidString: lastOpenedProjectID),
              library.documents.contains(where: { $0.id == uuid }) else { return }
        path.append(uuid)
    }

    private func createNewProject() {
        do {
            let doc = try library.newProject(name: defaultNewName())
            path.append(doc.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            let doc = library.documents[index]
            do {
                try library.delete(id: doc.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// "Untitled", "Untitled 2", "Untitled 3"… — picks the lowest free slot
    /// so users hammering "+ New Project" don't end up with a wall of
    /// identical names.
    private func defaultNewName() -> String {
        let base = "Untitled"
        let existing = Set(library.documents.map(\.name))
        if !existing.contains(base) { return base }
        var n = 2
        while existing.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }
}

// MARK: - Row

@available(iOS 16, *)
struct ProjectRow: View {

    let document: ProjectDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(document.name)
                .font(.body.weight(.semibold))
            HStack(spacing: 8) {
                Text(document.modifiedAt, format: .relative(presentation: .named))
                Text("·")
                Text("\(document.clips.count) clip\(document.clips.count == 1 ? "" : "s")")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        // Collapse the row into a single VoiceOver element so the user
        // hears name + modified date + clip count as one announcement
        // instead of three sibling reads.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ProjectRow.accessibilityDescription(for: document))
        .accessibilityHint("Opens this project in the editor")
    }

    /// Composed VoiceOver string for a project row. Pure so it's testable.
    /// Example: "Reels Demo, modified 2 days ago, 3 clips".
    nonisolated static func accessibilityDescription(for document: ProjectDocument) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: document.modifiedAt, relativeTo: Date())
        let clipCount = document.clips.count
        let clipLabel = clipCount == 1 ? "1 clip" : "\(clipCount) clips"
        return "\(document.name), modified \(relative), \(clipLabel)"
    }
}

// MARK: - Skipped recovery views

@available(iOS 16, *)
struct SkippedProjectRow: View {

    let skipped: SkippedProject

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(skipped.id)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(skipped.reason.displayLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(skipped.id), \(skipped.reason.displayLabel)")
        .accessibilityHint("Shows file details. Swipe for discard.")
    }

    private var iconName: String {
        switch skipped.reason {
        case .unsupportedSchema: return "arrow.up.circle"
        case .corruptJSON:       return "exclamationmark.triangle"
        }
    }
}

@available(iOS 16, *)
struct SkippedProjectDetailSheet: View {

    let skipped: SkippedProject
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    label("File", value: skipped.id)
                    label("Reason", value: skipped.reason.displayLabel)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Details")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(skipped.reason.detail)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("Skipped project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func label(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
        }
    }
}
