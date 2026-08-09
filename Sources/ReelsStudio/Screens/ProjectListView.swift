import SwiftUI

/// Launch screen — lists every saved project in the ``ProjectLibrary`` and
/// hands the user a way to start a new one. Tapping a row pushes the
/// ``EditorView`` for that document onto the navigation stack; auto-save in
/// the editor keeps the on-disk copy in sync.
///
/// Tier 2 of v0.2 — first-run UX. Replaces the v0.1 launch path that booted
/// straight into a hardcoded sample project.
struct ProjectListView: View {

    var library: ProjectLibrary

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

    @Environment(\.modernistPalette) private var palette

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Projects")
                .onAppear { restoreLastOpenedIfPossible() }
                .onChange(of: path) { _, newPath in
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
                            .foregroundStyle(palette.textMuted)
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
        // v0.8 Tier 2 — the library is app chrome; chrome is the print
        // ground. Set once, at the root. `EditorView` re-establishes
        // `.studio` for its own subtree when pushed.
        .modernistSurface(.print)
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
                .font(.system(size: Modernist.Typography.Glyph.xxl, weight: Modernist.Typography.headingWeight))
                .foregroundStyle(palette.textMuted)
            Text("No projects yet")
                .font(Modernist.Typography.h4)
            Text("Start with a new project, or import the bundled sample to see what the editor can do.")
                .font(Modernist.Typography.body)
                .foregroundStyle(palette.textMuted)
                .padding(.horizontal, 32)
            HStack(spacing: 12) {
                Button { createNewProject() } label: {
                    Label("New Project", systemImage: "plus.circle.fill")
                        .font(Modernist.Typography.bodyEmphasis)
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
            errorMessage = ErrorSanitizer.sanitize(error)
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
                        // v0.8 Tier 3 — one accent, no second hue.
                        .tint(palette.accent)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { inspectingSkipped = skipped }
            }
        } header: {
            Text("Skipped projects")
                .modernistLabel()
        } footer: {
            Text("These files couldn't be loaded. Tap one to see details, or swipe to discard.")
                .font(Modernist.Typography.caption)
        }
    }

    private func discard(_ skipped: SkippedProject) {
        do {
            try library.discardSkipped(skipped)
        } catch {
            errorMessage = ErrorSanitizer.sanitize(error)
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
            errorMessage = ErrorSanitizer.sanitize(error)
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            let doc = library.documents[index]
            do {
                try library.delete(id: doc.id)
            } catch {
                errorMessage = ErrorSanitizer.sanitize(error)
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

struct ProjectRow: View {

    let document: ProjectDocument

    @Environment(\.modernistPalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            ProjectThumbnailTile(document: document)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(Modernist.Typography.bodyEmphasis)
                HStack(spacing: 8) {
                    Text(document.modifiedAt, format: .relative(presentation: .named))
                    Text("·")
                    Text("\(document.clips.count) clip\(document.clips.count == 1 ? "" : "s")")
                }
                .font(Modernist.Typography.caption)
                .foregroundStyle(palette.textMuted)
            }
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

struct SkippedProjectRow: View {

    let skipped: SkippedProject

    @Environment(\.modernistPalette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // v0.8 Tier 3 / Decision 4 — the scheme has no warning role. This
            // is the one place the accent flags a problem.
            Image(systemName: iconName)
                .foregroundStyle(palette.accent)
                .font(Modernist.Typography.h4)
            VStack(alignment: .leading, spacing: 2) {
                Text(skipped.id)
                    .font(Modernist.Typography.bodyEmphasis)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(skipped.reason.displayLabel)
                    .font(Modernist.Typography.caption)
                    .foregroundStyle(palette.textMuted)
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

struct SkippedProjectDetailSheet: View {

    let skipped: SkippedProject
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modernistPalette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    label("File", value: skipped.id)
                    label("Reason", value: skipped.reason.displayLabel)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Details")
                            .modernistLabel()
                        Text(skipped.reason.detail)
                            .font(Modernist.Typography.body)
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
        // v0.8 Tier 2 — sheets are chrome; chrome is the print ground.
        .modernistSurface(.print)
    }

    @ViewBuilder
    private func label(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .modernistLabel()
            Text(value)
                .font(Modernist.Typography.body)
                .textSelection(.enabled)
        }
    }
}
