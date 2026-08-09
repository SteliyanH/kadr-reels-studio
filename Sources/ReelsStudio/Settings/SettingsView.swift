import SwiftUI
import Kadr

/// Per-project + app-level preferences. Pushed from the editor's top-toolbar
/// gear icon. Three sections:
///
/// - **Appearance** — accent color, constrained to the Modernist accent ramp
///   (System / 500 / 600 / 700). Per-project (writes to `Project.accentColor`).
/// - **Playback** — fixed-center playhead toggle. Per-project.
/// - **Haptics** — strength segmented (Off / Light / Medium). App-level
///   (writes to ``AppSettings/hapticIntensity``).
///
/// v0.5 Tier 1. The picker UI is reels-studio's only entry point for the
/// preferences v0.4 introduced — before this, the only way to set a custom
/// accent or disable the fixed-center playhead was editing JSON on disk.
struct SettingsView: View {

    var store: ProjectStore
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

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
        NavigationStack {
            Form {
                appearanceSection
                playbackSection
                hapticsSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        // v0.8 Tier 2 — sheets are chrome; chrome is the print ground.
        .modernistSurface(.print)
    }

    // MARK: - Appearance

    @ViewBuilder
    private var appearanceSection: some View {
        Section(header: Text("Appearance").modernistLabel()) {
            Text("Accent")
            ModernistSegmentedControl(
                options: AccentChoice.allCases.map { ($0, $0.label) },
                selection: $accentChoice
            )
            .onChange(of: accentChoice) { _, newValue in
                // Same mutation v0.5 used — undo / redo / auto-save and the
                // hex round-trip all inherit unchanged.
                store.setAccentColor(newValue.color)
            }
        }
    }

    // MARK: - Playback

    @ViewBuilder
    private var playbackSection: some View {
        Section(header: Text("Playback").modernistLabel()) {
            Toggle(
                "Fixed-center playhead",
                isOn: Binding(
                    get: { store.project.fixedCenterPlayhead },
                    set: { store.setFixedCenterPlayhead($0) }
                )
            )
        }
    }

    // MARK: - Haptics

    private var hapticsSection: some View {
        // iOS 17 — derive a binding to the @Observable @Environment settings via a
        // local @Bindable (the replacement for `@ObservedObject` / `@EnvironmentObject`
        // bindings).
        @Bindable var settings = settings
        return Section(header: Text("Haptics").modernistLabel()) {
            Picker("Strength", selection: $settings.hapticIntensity) {
                ForEach(HapticIntensity.allCases, id: \.self) { intensity in
                    Text(intensity.displayName).tag(intensity)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

private extension View {
    @ViewBuilder
    func navigationBarTitleDisplayModeInline() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
