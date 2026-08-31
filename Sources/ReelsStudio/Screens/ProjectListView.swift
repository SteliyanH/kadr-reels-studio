import SwiftUI
import KadrPersistence

/// Launch screen — lists every saved project in the ``ProjectLibrary`` and
/// hands the user a way to start a new one. Tapping a row pushes the
/// ``EditorView`` for that document onto the navigation stack; auto-save in
/// the editor keeps the on-disk copy in sync.
///
/// Tier 2 of v0.2 — first-run UX. Replaces the v0.1 launch path that booted
/// straight into a hardcoded sample project.
///
/// v0.8 Tier 5a rebuilds it to the approved design (Screens §1–2): the nav is
/// drawn in-body — "Projects" at `h2` over a `caption` count line, with a
/// labelled **New** button trailing — and the rows are a single `surface`
/// block separated by 2pt rules. Navigation, swipe-to-discard, scene restore
/// and every mutation are v0.7's, untouched.
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

    @Environment(\.reelPalette) private var palette

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                navHeader
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // The design draws the nav itself — `h2` title, count line and a
            // labelled button are all outside what a system bar can express.
            // The title stays set so the pushed editor still inherits
            // "Projects" as its back title.
            .navigationTitle("Projects")
            .hidingSystemNavigationBar()
            .onAppear { restoreLastOpenedIfPossible() }
            .onChange(of: path) { _, newPath in
                lastOpenedProjectID = newPath.last?.uuidString ?? ""
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
        .reelSurface(.print)
    }

    /// Skipped-project file selected for the JSON detail sheet.
    @State private var inspectingSkipped: SkippedProject?

    /// Skipped-project file pending discard confirmation.
    @State private var pendingDiscard: SkippedProject?

    // MARK: - Nav

    private var isLibraryEmpty: Bool {
        library.documents.isEmpty && library.skippedProjects.isEmpty
    }

    /// The design's 52pt top inset is measured from the top of the screen; on
    /// every device we ship to, the status-bar safe-area inset already spends
    /// that budget, so the header sits flush to the safe-area top.
    @ViewBuilder
    private var navHeader: some View {
        HStack(alignment: .bottom, spacing: Reel.Space.s3) {
            VStack(alignment: .leading, spacing: Reel.Space.s1) {
                Text("Projects")
                    .reelHeading(Reel.Typography.h2)
                if !isLibraryEmpty {
                    Text(
                        ProjectListView.countLine(
                            projects: library.documents.count,
                            skipped: library.skippedProjects.count
                        )
                    )
                    .font(Reel.Typography.caption)
                    .foregroundStyle(palette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            // The empty state owns the call to action; two plus-affordances
            // on one screen read as duplication.
            if !isLibraryEmpty {
                Button {
                    createNewProject()
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(ReelPrimaryButtonStyle())
                // The v0.5 sweep's spoken label for this control was
                // "New Project"; the caption shortens, the announcement
                // does not.
                .accessibilityLabel("New Project")
            }
        }
        .padding(.horizontal, Reel.Space.s4)
        .padding(.top, Reel.Space.s1)
        .padding(.bottom, Reel.Space.s3)
    }

    /// "3 projects · 2 skipped files". Pure so it's testable.
    ///
    /// Uses `String(localized:defaultValue:)` — the parameterized-string
    /// pattern this repo's `Localizable.strings` header documents — so the
    /// four new count keys read from the bundle once a translator lands them
    /// and fall back to correct English until then, rather than leaking the
    /// key into the nav.
    nonisolated static func countLine(projects: Int, skipped: Int) -> String {
        let projectsText = projects == 1
            ? String(
                localized: "library.count.oneProject",
                defaultValue: "1 project",
                comment: "Library header count, one project"
              )
            : String(
                localized: "library.count.manyProjects",
                defaultValue: "\(projects) projects",
                comment: "Library header count, N projects"
              )
        guard skipped > 0 else { return projectsText }
        let skippedText = skipped == 1
            ? String(
                localized: "library.count.oneSkipped",
                defaultValue: "1 skipped file",
                comment: "Library header count, one unreadable file"
              )
            : String(
                localized: "library.count.manySkipped",
                defaultValue: "\(skipped) skipped files",
                comment: "Library header count, N unreadable files"
              )
        return "\(projectsText) · \(skippedText)"
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLibraryEmpty {
            emptyState
        } else {
            projectList
        }
    }

    /// Screens §2 — a centred column whose text stays leading-aligned inside
    /// it. One primary action, one quiet alternative; never two peer buttons.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s4) {
            Image(systemName: "film.stack")
                .font(.system(size: Reel.Typography.Glyph.xxl, weight: Reel.Typography.headingWeight))
                .foregroundStyle(palette.textMuted)
            Text("No projects yet")
                .reelHeading(Reel.Typography.h4)
            Text("Start with a new project, or import the bundled sample to see what the editor can do.")
                .reelBody()
                .foregroundStyle(palette.textMuted)
            Button { createNewProject() } label: {
                Label("New Project", systemImage: "plus")
            }
            .buttonStyle(ReelPrimaryButtonStyle())
            Button { importSample() } label: {
                Label("Open the bundled sample", systemImage: "wand.and.stars")
            }
            .buttonStyle(ReelGhostButtonStyle())
            // The XCUITest reaches this affordance as "Sample" — the caption
            // grew into the design's sentence, the automation handle didn't
            // move.
            .accessibilityIdentifier("Sample")
        }
        .frame(maxWidth: Reel.emptyStateMeasure, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Reel.Space.s4)
    }

    private func importSample() {
        do {
            // Run the sample project through the persistence bridge so the
            // user lands on a real on-disk project they can keep editing.
            let runtime = SampleProject.make()
            var doc = try library.newProject(name: "Sample")
            // The sample is built from synthesised colour swatches. They have
            // no file behind them, so the store writes them into the library's
            // media directory and the project references them from there.
            doc = try runtime.toDocument(inheriting: doc, name: "Sample", images: library.makeImageStore())
            try library.save(doc)
            path.append(doc.id)
        } catch {
            errorMessage = ErrorSanitizer.sanitize(error)
        }
    }

    /// Still a `List`: swipe-to-discard is a `List` primitive, so the
    /// design's single `surface` block is reached by stripping the list's own
    /// chrome — insets, separators, row backgrounds — rather than by dropping
    /// the container that carries the gesture.
    private var projectList: some View {
        List {
            Section {
                ForEach(library.documents) { doc in
                    Button {
                        path.append(doc.id)
                    } label: {
                        ProjectRow(document: doc)
                    }
                    .buttonStyle(ProjectRowButtonStyle())
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onDelete(perform: deleteProjects)
            }
            if !library.skippedProjects.isEmpty {
                skippedSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, Reel.minHitTarget)
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
            Text(
                String(
                    format: NSLocalizedString("discard.dialog.message", comment: "Discard confirmation"),
                    skipped.id
                )
            )
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
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        } header: {
            Text("Skipped projects")
                .reelLabel()
                .padding(.horizontal, Reel.Space.s4)
                .padding(.top, Reel.Space.s6)
                .padding(.bottom, Reel.Space.s2)
                .listRowInsets(EdgeInsets())
        } footer: {
            Text("These files couldn't be loaded. Tap one to see details, or swipe to discard.")
                .font(Reel.Typography.caption)
                .foregroundStyle(palette.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Reel.Space.s4)
                .padding(.top, Reel.Space.s2)
                .listRowInsets(EdgeInsets())
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

// MARK: - Row press state

/// A project row's press state. The design tints a pressed row with
/// `accentTint`; a `NavigationLink`'s system highlight is a grey wash that
/// can't be retinted, so rows are `Button`s that push the same id onto the
/// same `NavigationStack` path.
private struct ProjectRowButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        @Environment(\.reelPalette) private var palette

        var body: some View {
            configuration.label
                .background(configuration.isPressed ? palette.accentTint : palette.surface)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Row

struct ProjectRow: View {

    let document: ProjectDocument

    @Environment(\.reelPalette) private var palette

    var body: some View {
        HStack(spacing: Reel.Space.s3) {
            ProjectThumbnailTile(document: document)
                .frame(
                    width: Reel.projectThumbnailSize,
                    height: Reel.projectThumbnailSize
                )
            VStack(alignment: .leading, spacing: Reel.Space.s1) {
                Text(document.name)
                    .font(Reel.Typography.bodyEmphasis)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: Reel.Space.s2) {
                    ReelTag(text: ProjectRow.presetLabel(for: document.composition?.video.preset))
                    HStack(spacing: Reel.Space.s2) {
                        Text(document.modifiedAt, format: .relative(presentation: .named))
                        Text("·")
                        Text(ProjectRow.clipCountLabel(document.compositionClips.count))
                    }
                    .font(Reel.Typography.caption)
                    .foregroundStyle(palette.textMuted)
                }
            }
            Spacer(minLength: Reel.Space.s2)
            Image(systemName: "chevron.right")
                .font(Reel.Typography.caption)
                .foregroundStyle(palette.textMuted)
        }
        .padding(.horizontal, Reel.Space.s4)
        .padding(.vertical, Reel.Space.s2)
        .frame(minHeight: Reel.minHitTarget)
        // Rows sit in one block, separated by the system's 2pt rule.
        .reelRule()
        // Collapse the row into a single VoiceOver element so the user
        // hears name + modified date + clip count as one announcement
        // instead of three sibling reads.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ProjectRow.accessibilityDescription(for: document))
        .accessibilityHint("Opens this project in the editor")
    }

    /// The preset's aspect ratio, for the row's `ReelTag` ("9:16").
    /// Pure so it's testable.
    /// The aspect-ratio tag for a row, read straight off the persisted preset.
    ///
    /// `nil` only for a document with no composition, which the library's
    /// migration makes unreachable — a row should still render rather than
    /// crash if one ever appears.
    nonisolated static func presetLabel(for preset: PresetData?) -> String {
        guard let preset else { return "Auto" }
        switch preset.kind {
        case "reelsAndShorts", "tiktok": return "9:16"
        case "square":                   return "1:1"
        case "cinema":                   return "16:9"
        case "custom":
            return ProjectRow.ratio(width: preset.width ?? 0, height: preset.height ?? 0)
        default:                         return "Auto"
        }
    }

    /// Reduce `1080×1920` to `9:16`. Falls back to the raw pair when either
    /// side is non-positive.
    nonisolated static func ratio(width: Int, height: Int) -> String {
        guard width > 0, height > 0 else { return "\(width):\(height)" }
        var a = width
        var b = height
        while b != 0 { (a, b) = (b, a % b) }
        let divisor = max(a, 1)
        return "\(width / divisor):\(height / divisor)"
    }

    /// "1 clip" / "3 clips", through the keys the bundle already carries.
    nonisolated static func clipCountLabel(_ count: Int) -> String {
        count == 1
            ? NSLocalizedString("project.row.singleClip", comment: "One clip")
            : String(
                format: NSLocalizedString("project.row.manyClips", comment: "N clips"),
                count
              )
    }

    /// Composed VoiceOver string for a project row. Pure so it's testable.
    /// Example: "Reels Demo, modified 2 days ago, 3 clips".
    nonisolated static func accessibilityDescription(for document: ProjectDocument) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: document.modifiedAt, relativeTo: Date())
        let clipCount = document.compositionClips.count
        let clipLabel = clipCount == 1 ? "1 clip" : "\(clipCount) clips"
        return "\(document.name), modified \(relative), \(clipLabel)"
    }
}

// MARK: - Skipped recovery views

struct SkippedProjectRow: View {

    let skipped: SkippedProject

    @Environment(\.reelPalette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: Reel.Space.s3) {
            // v0.8 Tier 3 / Decision 4 — the scheme has no warning role. This
            // is the one place the accent flags a problem.
            Image(systemName: iconName)
                .foregroundStyle(palette.accent)
                .font(Reel.Typography.h4)
            VStack(alignment: .leading, spacing: Reel.Space.s1) {
                Text(skipped.id)
                    .font(Reel.Typography.bodyEmphasis)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(skipped.reason.displayLabel)
                    .font(Reel.Typography.caption)
                    .foregroundStyle(palette.textMuted)
            }
            Spacer(minLength: Reel.Space.s2)
        }
        .padding(.horizontal, Reel.Space.s4)
        .padding(.vertical, Reel.Space.s2)
        .frame(minHeight: Reel.minHitTarget)
        .background(palette.surface)
        .reelRule()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: NSLocalizedString("skipped.row.a11y", comment: "Skipped file, reason"),
                skipped.id,
                skipped.reason.displayLabel
            )
        )
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
    @Environment(\.reelPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            ReelSheetHeader("Skipped project") {
                Button("Done") { dismiss() }
                    .buttonStyle(ReelGhostButtonStyle())
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Reel.Space.s6) {
                    label("File", value: skipped.id)
                    label("Reason", value: skipped.reason.displayLabel)
                    VStack(alignment: .leading, spacing: Reel.Space.s2) {
                        Text("Details")
                            .reelLabel()
                        Text(skipped.reason.detail)
                            .font(Reel.Typography.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Reel.Space.s4)
            }
        }
        .reelSheet(Reel.SheetDetent.export)
    }

    @ViewBuilder
    private func label(_ title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: Reel.Space.s2) {
            Text(title)
                .reelLabel()
            Text(value)
                .font(Reel.Typography.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Inline navigation-bar shim

/// `.toolbar(_:for:)` with a `.navigationBar` placement is iOS-only. Same
/// shim pattern `EditorView` uses — both screens draw their own nav.
private extension View {
    @ViewBuilder
    func hidingSystemNavigationBar() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
