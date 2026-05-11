import SwiftUI

/// Per-project + app-level preferences. Pushed from the editor's top-toolbar
/// gear icon. Three sections:
///
/// - **Appearance** — accent color (System / Custom segmented; Custom reveals
///   a `ColorPicker`). Per-project (writes to `Project.accentColor`).
/// - **Playback** — fixed-center playhead toggle. Per-project.
/// - **Haptics** — strength segmented (Off / Light / Medium). App-level
///   (writes to ``AppSettings/hapticIntensity``).
///
/// v0.5 Tier 1. The picker UI is reels-studio's only entry point for the
/// preferences v0.4 introduced — before this, the only way to set a custom
/// accent or disable the fixed-center playhead was editing JSON on disk.
@available(iOS 16, macOS 13, visionOS 1, *)
struct SettingsView: View {

    @ObservedObject var store: ProjectStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    /// Mirror of `store.project.accentColor != nil`. Bound to the System /
    /// Custom segmented picker. Local state because flipping the segment
    /// shouldn't fire the mutation until the user lands on a value — the
    /// `.onChange` below pushes the result through `setAccentColor`.
    @State private var useCustomAccent: Bool

    /// In-flight color while the `ColorPicker` is open. Defaults to the
    /// current project color or the system accent if none is set. Edits
    /// flow through to the store on every change.
    @State private var customAccent: Color

    init(store: ProjectStore) {
        self.store = store
        let existing = store.project.accentColor
        self._useCustomAccent = State(initialValue: existing != nil)
        self._customAccent = State(initialValue: existing ?? .accentColor)
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
    }

    // MARK: - Appearance

    @ViewBuilder
    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Accent", selection: $useCustomAccent) {
                Text("System").tag(false)
                Text("Custom").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: useCustomAccent) { newValue in
                store.setAccentColor(newValue ? customAccent : nil)
            }

            if useCustomAccent {
                ColorPicker("Color", selection: $customAccent, supportsOpacity: false)
                    .onChange(of: customAccent) { newValue in
                        store.setAccentColor(newValue)
                    }
            }
        }
    }

    // MARK: - Playback

    @ViewBuilder
    private var playbackSection: some View {
        Section("Playback") {
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

    @ViewBuilder
    private var hapticsSection: some View {
        Section("Haptics") {
            Picker("Strength", selection: $settings.hapticIntensity) {
                ForEach(HapticIntensity.allCases, id: \.self) { intensity in
                    Text(intensity.displayName).tag(intensity)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

@available(iOS 16, macOS 13, visionOS 1, *)
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
