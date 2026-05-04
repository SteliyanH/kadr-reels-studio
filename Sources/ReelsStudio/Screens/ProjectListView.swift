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

    /// Surfaces save / new-project / delete failures inline. Tier 3 will
    /// replace this with the global toast / alert infra; for now a minimal
    /// alert keeps the list robust.
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Projects")
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

    @ViewBuilder
    private var content: some View {
        if library.documents.isEmpty {
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
            ForEach(library.documents) { doc in
                NavigationLink(value: doc.id) {
                    ProjectRow(document: doc)
                }
            }
            .onDelete(perform: deleteProjects)
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

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
private struct ProjectRow: View {

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
    }
}
