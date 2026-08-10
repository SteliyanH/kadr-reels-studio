import SwiftUI
import Kadr

/// Per-project + app-level preferences. Pushed from the editor's top-toolbar
/// gear icon. Three sections, per the approved design (Screens §9):
///
/// - **ACCENT · THIS PROJECT** — accent color, constrained to the Modernist
///   accent ramp (System / 500 / 600 / 700). Per-project (writes to
///   `Project.accentColor`).
/// - **PLAYBACK** — fixed-center playhead toggle, in a card with its own
///   explanation. Per-project.
/// - **HAPTICS · ALL PROJECTS** — strength segmented (Off / Light / Medium).
///   App-level (writes to ``AppSettings/hapticIntensity``).
///
/// v0.5 Tier 1. The picker UI is reels-studio's only entry point for the
/// preferences v0.4 introduced — before this, the only way to set a custom
/// accent or disable the fixed-center playhead was editing JSON on disk.
/// v0.8 Tier 5a moves it off `Form` onto the design's ruled block layout;
/// every mutation is the one v0.5 shipped.
struct SettingsView: View {

    var store: ProjectStore
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modernistPalette) private var palette

    /// Which segment of the accent ramp is showing. Local state because
    /// seeding it must not fire a mutation — the `.onChange` below is what
    /// pushes a *user* choice through `setAccentColor`. v0.8 Tier 3
    /// (Decision 3).
    @State private var accentChoice: AccentChoice

    init(store: ProjectStore) {
        self.store = store
        self._accentChoice = State(
            initialValue: SettingsView.choice(for: store.project.accentColor)
        )
    }

    /// Decision 3 — v0.5 shipped an unconstrained `ColorPicker`, which breaks
    /// a mono scheme on first use. The input narrows to the accent ramp plus
    /// a System option that clears the field. `Project.accentColor`, its hex
    /// round-trip and the `ProjectDocument` schema are untouched: this is a
    /// narrower control over the same mutation, not a data change.
    enum AccentChoice: Hashable, CaseIterable {
        case system, a500, a600, a700

        /// `nil` clears the per-project accent back to the app tint.
        var color: Color? {
            switch self {
            case .system: return nil
            case .a500:   return Modernist.Accent.a500
            case .a600:   return Modernist.Accent.a600
            case .a700:   return Modernist.Accent.a700
            }
        }

        /// Segment content. "System" is an existing localized key; the ramp
        /// steps carry the system's own token numbers, which are identifiers
        /// rather than prose and so don't translate.
        var label: String {
            switch self {
            case .system: return NSLocalizedString("System", comment: "Accent follows the app tint")
            case .a500:   return "500"
            case .a600:   return "600"
            case .a700:   return "700"
            }
        }
    }

    /// Which segment an already-persisted accent lands on.
    ///
    /// `nil` → System. A ramp step matches by hex, through the same helper
    /// the persistence round-trip uses. Anything else is a project saved by
    /// v0.5–v0.7's free picker: it shows the ramp's base step so the control
    /// reads as "an accent is set", and — because seeding never writes — the
    /// stored colour survives untouched until the user actually taps.
    nonisolated static func choice(for color: Color?) -> AccentChoice {
        guard let color else { return .system }
        let hex = ProjectDocument.hexString(from: PlatformColor(color))
        for candidate in AccentChoice.allCases {
            guard let rampColor = candidate.color else { continue }
            if ProjectDocument.hexString(from: PlatformColor(rampColor)) == hex {
                return candidate
            }
        }
        return .a500
    }

    var body: some View {
        VStack(spacing: 0) {
            ModernistSheetHeader("Settings") {
                Button("Done") { dismiss() }
                    .buttonStyle(ModernistGhostButtonStyle())
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Modernist.Space.s6) {
                    accentSection
                    playbackSection
                    hapticsSection
                }
                .padding(Modernist.Space.s4)
            }
        }
        .modernistSheet(Modernist.SheetDetent.settings)
    }

    // MARK: - Accent

    @ViewBuilder
    private var accentSection: some View {
        VStack(alignment: .leading, spacing: Modernist.Space.s3) {
            Text("Accent · This project").modernistLabel()
            ModernistSegmentedControl(
                options: AccentChoice.allCases.map { ($0, $0.label) },
                selection: $accentChoice
            )
            .onChange(of: accentChoice) { _, newValue in
                // Same mutation v0.5 used — undo / redo / auto-save and the
                // hex round-trip all inherit unchanged.
                store.setAccentColor(newValue.color)
            }
            // Deliberately *no* `.accessibilityLabel` on the control: a label
            // on a container of buttons relabels or swallows the segments,
            // and each segment's own label ("System", "500"…) is the thing
            // VoiceOver — and the XCUITest below — needs to reach.
        }
    }

    // MARK: - Playback

    @ViewBuilder
    private var playbackSection: some View {
        VStack(alignment: .leading, spacing: Modernist.Space.s3) {
            Text("Playback").modernistLabel()
            Toggle(
                isOn: Binding(
                    get: { store.project.fixedCenterPlayhead },
                    set: { store.setFixedCenterPlayhead($0) }
                )
            ) {
                VStack(alignment: .leading, spacing: Modernist.Space.s1) {
                    Text("Fixed-center playhead")
                        .font(Modernist.Typography.bodyEmphasis)
                    Text("The timeline scrolls under a pinned playhead instead of letting it drift.")
                        .font(Modernist.Typography.caption)
                        .foregroundStyle(palette.textMuted)
                }
            }
            // Decision 4 — the scheme has no success role, so the switch's
            // "on" fill is the accent, never the system green.
            .tint(palette.accent)
            .modernistCard()
        }
    }

    // MARK: - Haptics

    private var hapticsSection: some View {
        // iOS 17 — derive a binding to the @Observable @Environment settings via a
        // local @Bindable (the replacement for `@ObservedObject` / `@EnvironmentObject`
        // bindings).
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: Modernist.Space.s3) {
            Text("Haptics · All projects").modernistLabel()
            // Each segment is a real `Button` whose label is the intensity's
            // display name, so `app.buttons["Medium"]` — the XCUITest's proof
            // that this sheet presented — keeps resolving.
            ModernistSegmentedControl(
                options: HapticIntensity.allCases.map { ($0, $0.displayName) },
                selection: $settings.hapticIntensity
            )
        }
    }
}
