import SwiftUI
import CoreMedia
import Kadr

/// Root editor screen. Composes the approved design's six bands, top to
/// bottom: nav bar · stage (``PreviewArea``) · timeline (``TimelineArea``) ·
/// keyframes · inspector · toolbar (``EditorToolbar``), all on the studio
/// ground.
///
/// v0.2 Tier 2 — the editor is now per-project: it's constructed with a
/// ``ProjectDocument`` (loaded from ``ProjectLibrary``) and writes every
/// edit back through the library on a debounced auto-save. There is no
/// Save button anywhere; closing the editor is enough.
///
/// v0.8 Tier 5b — the chrome is drawn by the app rather than by
/// `NavigationStack`: the system bar can't carry a two-line title block, a
/// ruled undo/redo cell group and 44pt square icon cells, so it is hidden and
/// this view draws the band itself. Sheet presentation is unchanged and still
/// owned here.
struct EditorView: View {

    @State private var store: ProjectStore
    private var library: ProjectLibrary
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.scenePhase) private var scenePhase

    /// The document this editor is bound to. Mutated in-place as auto-save
    /// runs so `modifiedAt` / clip counts stay current for the project list.
    @State private var document: ProjectDocument

    /// v0.6 Tier 3: persisted playhead / selection so cold-relaunch puts the
    /// user back where they left off. `@SceneStorage` is per-scene UserDefaults
    /// — single-window iOS apps get one slot, so the values track whatever the
    /// last-opened project was. Restore is gated on the editor's
    /// `document.id` matching what was last written; switching projects clears
    /// the slot indirectly because we only seed on appear.
    @SceneStorage("editor.playheadSeconds") private var savedPlayheadSeconds: Double = 0
    @SceneStorage("editor.selectedClipID") private var savedSelectedClipID: String = ""
    @SceneStorage("editor.selectedOverlayID") private var savedSelectedOverlayID: String = ""
    @SceneStorage("editor.documentID") private var savedDocumentID: String = ""

    @State private var showPhotoPicker = false
    @State private var showOverlaySheet = false
    @State private var showLayersSheet = false
    @State private var showMusicSheet = false
    @State private var showSFXSheet = false
    @State private var showCaptionsSheet = false
    @State private var showExportSheet = false
    @State private var speedCurveClipID: ClipID?
    @State private var filtersClipID: ClipID?
    @State private var transitionClipID: ClipID?
    @State private var showSettings = false

    /// v0.6 Tier 4 — Photos access pre-check. When the user taps "Add clip"
    /// we resolve `PHPhotoLibrary.authorizationStatus` before showing the
    /// picker; a denial flips this to true and we show the Settings-redirect
    /// alert instead of presenting an empty picker.
    @State private var showPhotosDeniedAlert = false

    /// Debounce window for auto-save. Half a second swallows rapid edits
    /// (slider drags, inspector typing) while still feeling near-instant.
    private static let autoSaveDebounce: TimeInterval = 0.5

    /// In-flight debounced auto-save. Cancelled and restarted on every store
    /// mutation (iOS 17 replacement for the Combine `.debounce` pipeline).
    @State private var autoSaveTask: Task<Void, Never>?

    init(document: ProjectDocument, library: ProjectLibrary) {
        self._document = State(initialValue: document)
        self.library = library
        self._store = State(
            initialValue: ProjectStore(project: document.toRuntimeProject())
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // The nav bar is a child view, not an inlined block: `EditorView`'s
            // own `@Environment(\.reelPalette)` would resolve against the
            // *library's* print ground (this screen is pushed from it), and the
            // `.reelSurface(.studio)` applied at the bottom of this body
            // only reaches the subtree. A child reads the studio ground; the
            // enclosing struct cannot.
            EditorNavBar(
                title: document.name,
                statusMetrics: EditorView.statusMetrics(
                    preset: store.project.preset,
                    duration: store.video.duration
                ),
                canUndo: store.canUndo,
                canRedo: store.canRedo,
                onUndo: { store.undo() },
                onRedo: { store.redo() },
                onSettings: { showSettings = true }
            )
            stageBand
            TimelineArea(store: store)
            inspectorBands
            toolbarBand
        }
        // v0.4 Tier 3: per-project accent threads through every `.tint`-aware
        // surface (inspector tabs, keyframe playhead, timeline selection
        // ring). kadr-ui exposes no theming API, so this `.tint` is the app's
        // only channel into that package's internals — v0.8 Tier 2 keeps it
        // and retargets the fallback from the system tint to the studio
        // ground's accent token. It sits *inside* `.reelSurface(.studio)`
        // (which sets its own `.tint`) so the nearer value wins for the
        // subtree. Do not reorder these two.
        .tint(store.project.accentColor ?? ReelPalette.studio.accent)
        .addClipFlow(isPresented: $showPhotoPicker, store: store)
        .sheet(isPresented: $showOverlaySheet) {
            AddOverlaySheet(store: store)
        }
        .sheet(isPresented: $showLayersSheet) {
            LayersSheet(store: store)
        }
        .sheet(isPresented: $showMusicSheet) {
            AddMusicSheet(store: store)
        }
        .sheet(isPresented: $showSFXSheet) {
            AddSFXSheet(store: store)
        }
        .sheet(isPresented: $showCaptionsSheet) {
            AddCaptionsSheet(store: store)
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(store: store)
        }
        .sheet(
            isPresented: Binding(
                get: { speedCurveClipID != nil },
                set: { if !$0 { speedCurveClipID = nil } }
            )
        ) {
            if let id = speedCurveClipID {
                SpeedCurveSheet(store: store, clipID: id)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { filtersClipID != nil },
                set: { if !$0 { filtersClipID = nil } }
            )
        ) {
            if let id = filtersClipID {
                FiltersSheet(store: store, clipID: id)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { transitionClipID != nil },
                set: { if !$0 { transitionClipID = nil } }
            )
        ) {
            if let id = transitionClipID {
                TransitionsSheet(store: store, clipID: id)
            }
        }
        .sheet(isPresented: $showSettings) {
            // Re-inject AppSettings on the sheet: @Observable environment objects
            // injected at the app root don't reliably cross the sheet boundary the way
            // `.environmentObject` did, and SettingsView reads `@Environment(AppSettings.self)`.
            // `AppSettings.shared` is the same instance the root injects.
            SettingsView(store: store)
                .environment(AppSettings.shared)
        }
        .alert(
            "Photos access needed",
            isPresented: $showPhotosDeniedAlert
        ) {
            Button("Open Settings") { PhotosAuthorizationGate.openSystemSettings() }
            Button("Not now", role: .cancel) { }
        } message: {
            Text("Reels Studio needs access to your photo library to import clips. Turn it on in Settings.")
        }
        .navigationTitle(document.name)
        .hidingSystemNavigationBar()
        // Hiding the system bar took the edge-swipe back gesture with it —
        // UIKit ties the interactive pop to the presence of a back button it
        // draws itself. The band stays app-drawn; the gesture is handed back
        // here. See the shim at the foot of this file.
        .restoringInteractivePopGesture()
        // iOS 17 — @Observable has no Combine publisher, so debounce auto-save with a
        // cancel-and-restart Task keyed off the store's revision counter (replaces the
        // old `store.$project.debounce(...)` pipeline). Same 0.5s window.
        .onChange(of: store.revision) {
            autoSaveTask?.cancel()
            autoSaveTask = Task {
                try? await Task.sleep(for: .seconds(Self.autoSaveDebounce))
                guard !Task.isCancelled else { return }
                autoSave()
            }
        }
        .onAppear { restoreSceneStateIfMatching() }
        .onChange(of: store.currentTime) { _, newValue in
            savedPlayheadSeconds = CMTimeGetSeconds(newValue)
            savedDocumentID = document.id.uuidString
        }
        .onChange(of: store.selectedClipID) { _, newValue in
            savedSelectedClipID = newValue?.rawValue ?? ""
        }
        .onChange(of: store.selectedOverlayID) { _, newValue in
            savedSelectedOverlayID = newValue?.rawValue ?? ""
        }
        .onChange(of: scenePhase) { _, phase in
            // .background fires when the user backgrounds the app (home /
            // swipe-up / lock). Force-flush any pending autosave so a force-
            // quit while the debounce timer is in-flight doesn't lose work.
            if phase == .background {
                autoSave()
            }
        }
        // v0.8 Tier 2 — the editor's ground. Set once, at the root, outermost
        // so the whole subtree (stage, timeline, inspector, the AddClipFlow
        // overlay) reads `.studio` from the environment. Replaces the
        // `Color(.systemGray6)` background.
        .reelSurface(.studio)
    }

    // MARK: - Stage

    /// Fills whatever height the bands below leave, never below
    /// `stageMinHeight`. `PreviewArea` letterboxes itself to the preset.
    private var stageBand: some View {
        PreviewArea(store: store)
            .frame(
                maxWidth: .infinity,
                minHeight: Reel.stageMinHeight,
                maxHeight: .infinity
            )
            .padding(.horizontal, Reel.Space.s4)
            .padding(.vertical, Reel.Space.s3)
    }

    // MARK: - Keyframe + inspector bands

    /// Inspector / keyframe pair — routes to clip- or overlay-targeted
    /// surfaces based on which selection slot is active. Mutual exclusion is
    /// enforced by ProjectStore's didSet observers.
    /// v0.4 Tier 4: reveal / dismiss with the editor-wide spring detent.
    private var inspectorBands: some View {
        Group {
            if store.selectedOverlayID != nil {
                VStack(spacing: 0) {
                    OverlayKeyframeArea(store: store)
                    OverlayInspectorArea(store: store)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if store.selectedClipID != nil {
                VStack(spacing: 0) {
                    KeyframeArea(store: store)
                    InspectorArea(store: store)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(
            .interactiveSpring(response: 0.35, dampingFraction: 0.78),
            value: EditorView.inspectorPresentationKey(
                clip: store.selectedClipID,
                overlay: store.selectedOverlayID
            )
        )
    }

    // MARK: - Toolbar band

    /// The selection-driven toolbar, at the bottom of the stack where the
    /// approved design puts it. The band's own ground, its top rule and the
    /// safe-area gutter belong to `EditorToolbar` — it can read the studio
    /// palette from the environment, and this enclosing struct can't.
    private var toolbarBand: some View {
        EditorToolbar(
            store: store,
            onAddClip: { Task { await requestPhotosThenPick() } },
            onAddOverlay: { showOverlaySheet = true },
            onLayers: { showLayersSheet = true },
            onAddMusic: { showMusicSheet = true },
            onAddSFX: { showSFXSheet = true },
            onAddCaptions: { showCaptionsSheet = true },
            onExport: { showExportSheet = true },
            onSpeedCurve: { speedCurveClipID = $0 },
            onFilters: { filtersClipID = $0 },
            onTransition: { transitionClipID = $0 }
        )
    }

    // MARK: - Behaviour (unchanged)

    /// Re-apply scene-stored playhead / selection when re-entering the same
    /// project (cold launch, app restart). Gated on `savedDocumentID` to
    /// avoid bleeding state across projects: opening project A then B then
    /// reopening A should restore A's state, not B's. Selection is best-
    /// effort — if the clip was deleted while we were away, the binding
    /// silently drops the id.
    private func restoreSceneStateIfMatching() {
        guard savedDocumentID == document.id.uuidString else { return }
        if savedPlayheadSeconds > 0 {
            store.currentTime = CMTime(seconds: savedPlayheadSeconds, preferredTimescale: 600)
        }
        if !savedSelectedClipID.isEmpty {
            let id = ClipID(savedSelectedClipID)
            if store.video.clips.contains(where: { $0.clipID == id }) {
                store.selectedClipID = id
            }
        } else if !savedSelectedOverlayID.isEmpty {
            let id = LayerID(savedSelectedOverlayID)
            if store.project.overlays.contains(where: { $0.layerID == id }) {
                store.selectedOverlayID = id
            }
        }
    }

    /// Identity for the inspector-reveal animation. We can't use
    /// `selectedClipID` or `selectedOverlayID` directly as the `.animation`
    /// value because their types don't unify; collapse to a string the
    /// `.animation(value:)` modifier can compare. Pure for testability.
    static func inspectorPresentationKey(clip: ClipID?, overlay: LayerID?) -> String {
        if let overlay { return "overlay:\(overlay.rawValue)" }
        if let clip { return "clip:\(clip.rawValue)" }
        return "none"
    }

    /// v0.6 Tier 4 — gate the Photos picker on the current authorization
    /// status. Granted (full / limited) shows the picker; denied / restricted
    /// flips the Settings-redirect alert; not-determined triggers the system
    /// prompt and then dispatches based on the result.
    @MainActor
    private func requestPhotosThenPick() async {
        switch await PhotosAuthorizationGate.ensureAccess() {
        case .proceed, .unavailable:
            showPhotoPicker = true
        case .openSettings:
            showPhotosDeniedAlert = true
        }
    }

    /// Push the current in-memory project back through the library, preserving
    /// the document's id / createdAt / name. Failures surface as a transient
    /// toast; the in-memory edit is *not* rolled back — the next debounced
    /// cycle retries automatically.
    private func autoSave() {
        let updated = store.project.toDocument(inheriting: document)
        do {
            try library.save(updated)
            document = updated
        } catch {
            toasts.show(.transient(error, prefix: "Couldn't save"))
        }
    }
}

// MARK: - Nav status line (pure)

extension EditorView {

    /// The numeric tail of the nav bar's status line: " · 9:16 · 0:06".
    ///
    /// Split from the localised "Auto-saved" head so the digits can ride
    /// `Typography.numeric` — the system requires timecodes and ratios to be
    /// tabular, and a single interpolated string would set the whole line in
    /// one face. Pure for testability.
    nonisolated static func statusMetrics(preset: Preset, duration: CMTime) -> String {
        " · \(aspectLabel(for: preset)) · \(timecode(duration))"
    }

    /// The preset's aspect ratio in lowest terms — "9:16", "1:1", "16:9".
    /// Derived from the preset the project already carries; no new state.
    nonisolated static func aspectLabel(for preset: Preset) -> String {
        let width = Int(preset.resolution.width.rounded())
        let height = Int(preset.resolution.height.rounded())
        guard width > 0, height > 0 else { return "—" }
        let divisor = greatestCommonDivisor(width, height)
        return "\(width / divisor):\(height / divisor)"
    }

    /// `m:ss` — the design's duration format ("0:06"). Negative or
    /// indefinite times clamp to zero rather than rendering "-0:01".
    nonisolated static func timecode(_ time: CMTime) -> String {
        let seconds = CMTimeGetSeconds(time)
        let total = seconds.isFinite ? Int(max(0, seconds).rounded()) : 0
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    private nonisolated static func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        var (x, y) = (abs(a), abs(b))
        while y != 0 { (x, y) = (y, x % y) }
        return max(x, 1)
    }
}

// MARK: - Nav bar

/// The editor's own navigation band: back · two-line title block ·
/// undo/redo cell group · settings.
///
/// A view rather than a block inlined into ``EditorView`` so it resolves
/// `\.reelPalette` from *inside* `.reelSurface(.studio)` — the
/// editor is pushed from the print-ground library, and an `@Environment`
/// property on the enclosing struct would read that instead.
///
/// No rule under it: the design has the band sit flush on `bg`, and the stage
/// below is the same ground, so a divider there would be a line drawn for its
/// own sake.
private struct EditorNavBar: View {

    let title: String
    /// Pre-formatted " · 9:16 · 0:06" — see `EditorView.statusMetrics`.
    let statusMetrics: String
    let canUndo: Bool
    let canRedo: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onSettings: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.reelPalette) private var palette

    var body: some View {
        HStack(spacing: Reel.Space.s3) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(ReelIconButtonStyle())
            .accessibilityLabel("Back")
            .help("Back to projects")

            titleBlock

            undoRedoGroup

            Button(action: onSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(ReelIconButtonStyle())
            .accessibilityLabel("Settings")
            .help("Open settings")
        }
        .padding(.horizontal, Reel.Space.s3)
        .padding(.top, Reel.Space.s1)
        .padding(.bottom, Reel.Space.s2)
    }

    /// Project name + pencil glyph, and under it the status line: an `n400`
    /// dot (Decision 4 — status is not an accent job) plus "Auto-saved ·
    /// 9:16 · 0:06", every value read from state the editor already holds.
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s1 / 2) {
            HStack(spacing: Reel.Space.s1) {
                Text(title)
                    .font(Reel.Typography.bodyEmphasis)
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                // Decorative: the editor has no rename affordance, and adding
                // one would be a feature, not a restyle. Hidden from VoiceOver
                // so it can't be mistaken for a control.
                Image(systemName: "pencil")
                    .font(Reel.Typography.caption)
                    .foregroundStyle(palette.textMuted)
                    .accessibilityHidden(true)
            }
            HStack(spacing: Reel.Space.s1) {
                Circle()
                    .fill(Reel.Neutral.n400)
                    .frame(
                        width: Reel.navStatusDotSize,
                        height: Reel.navStatusDotSize
                    )
                Text("Auto-saved")
                    .font(Reel.Typography.caption)
                    .foregroundStyle(palette.textMuted)
                Text(verbatim: statusMetrics)
                    .font(Reel.Typography.numeric)
                    .foregroundStyle(palette.textMuted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Project status")
            .accessibilityValue(NSLocalizedString("Auto-saved", comment: "") + statusMetrics)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One ruled cell group, 2pt divider between the halves. The unavailable
    /// half drops to `Reel.pairedControlDisabledOpacity` (28%) rather
    /// than the repo-wide 45% — see that token for why the exception exists
    /// and why it is confined to this pair.
    private var undoRedoGroup: some View {
        HStack(spacing: 0) {
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(NavPairCellStyle())
            .disabled(!canUndo)
            .accessibilityLabel("Undo")
            .accessibilityHint(canUndo ? "Undo last action" : "Nothing to undo")
            .help(canUndo ? "Undo last action" : "Nothing to undo")

            Rectangle()
                .fill(palette.divider)
                .frame(width: Reel.ruleWidth, height: Reel.minHitTarget)

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .buttonStyle(NavPairCellStyle())
            .disabled(!canRedo)
            .accessibilityLabel("Redo")
            .accessibilityHint(canRedo ? "Redo last undone action" : "Nothing to redo")
            .help(canRedo ? "Redo last undone action" : "Nothing to redo")
        }
        .fixedSize()
    }
}

// MARK: - Nav pair cell

/// The undo/redo group's cell. Identical to `ReelIconButtonStyle` except
/// for the unavailable step: the shared style hard-wires the repo's 45%
/// disabled convention, and the approved design specifies 28% for this pair
/// (see `Reel.pairedControlDisabledOpacity`). Local to the editor so the
/// exception can't leak into the print ground's controls.
private struct NavPairCellStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        @Environment(\.reelPalette) private var palette
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Reel.Typography.bodyEmphasis)
                .foregroundStyle(palette.text)
                .frame(width: Reel.minHitTarget, height: Reel.minHitTarget)
                .background(configuration.isPressed ? palette.accentTint : palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Reel.Radius.sm))
                .opacity(isEnabled ? 1 : Reel.pairedControlDisabledOpacity)
                .contentShape(Rectangle())
        }
    }
}

/// `.navigationBarTitleDisplayMode(.inline)` and `.toolbar(_:for:)` with a
/// `.navigationBar` placement are iOS-only; this shim keeps the editor source
/// compilable on macOS / Catalyst targets where they aren't available.
private extension View {
    @ViewBuilder
    func hidingSystemNavigationBar() -> some View {
        #if os(iOS)
        self
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    /// Gives the editor back the interactive pop (edge swipe) that
    /// ``hidingSystemNavigationBar()`` costs it.
    ///
    /// UIKit gates `interactivePopGestureRecognizer` on a back button *it*
    /// draws: `.navigationBarBackButtonHidden(true)` makes the stock delegate
    /// refuse to begin, and hiding the bar removes the button the rule looks
    /// for. The approved design keeps the band app-drawn, so the gesture is
    /// restored by replacing that delegate rather than by restoring the bar.
    ///
    /// Same `#if os(iOS)` shim shape as its sibling above: `UIKit`,
    /// `UINavigationController` and the pop recogniser are iOS-only, and the
    /// editor source still has to compile for macOS / Catalyst / visionOS,
    /// where the system bar is never hidden and its native back affordance is
    /// untouched.
    @ViewBuilder
    func restoringInteractivePopGesture() -> some View {
        #if os(iOS)
        self.background {
            InteractivePopGestureBridge()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        #else
        self
        #endif
    }
}

// MARK: - Interactive pop shim (iOS)

#if os(iOS)
import UIKit

/// Zero-size probe that reaches the `UINavigationController` backing the
/// library's `NavigationStack` and installs ``InteractivePopGestureShim`` as
/// its pop recogniser's delegate for as long as the editor is on screen.
///
/// A `UIViewControllerRepresentable` rather than a `UIViewRepresentable`
/// because `UIViewController.navigationController` walks the parent chain for
/// us; the controller renders nothing and takes no touches.
///
/// Presentation-only: it reads `viewControllers` to decide whether a swipe may
/// begin and drives nothing else. No observable state, no store mutation, no
/// schema.
private struct InteractivePopGestureBridge: UIViewControllerRepresentable {

    func makeCoordinator() -> InteractivePopGestureShim {
        InteractivePopGestureShim()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        ProbeController(shim: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }

    /// Hand the recogniser back to UIKit's own delegate when the editor leaves
    /// the stack, so the shim's reach ends with the screen that needs it. Belt
    /// and braces — the depth gate already makes a surviving shim inert on the
    /// root screen.
    static func dismantleUIViewController(
        _ uiViewController: UIViewController,
        coordinator: InteractivePopGestureShim
    ) {
        coordinator.uninstall()
    }

    /// Exists only to be parented into the navigation stack's controller
    /// hierarchy, where `navigationController` resolves.
    private final class ProbeController: UIViewController {

        private let shim: InteractivePopGestureShim

        init(shim: InteractivePopGestureShim) {
            self.shim = shim
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("InteractivePopGestureBridge.ProbeController is never decoded")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
            view.isAccessibilityElement = false
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            shim.install(from: self)
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // `didMove(toParent:)` can land before SwiftUI has parented the
            // hosting controller into the stack, leaving nothing to resolve.
            // `install(from:)` is idempotent, so the retry is free when the
            // first attempt already took.
            shim.install(from: self)
        }
    }
}

/// What the interactive-pop recogniser looked like before any shim touched it,
/// pinned to the `UINavigationController` that owns it.
///
/// The shim used to chain: each `install` captured whichever delegate happened
/// to be in place at that moment, and each `uninstall` put that one back.
/// Pops are LIFO, so today the chain always unwinds in the order it was built
/// and UIKit's delegate does come back. But the chain has no anchor — every
/// link knows only its predecessor. A future `path.removeAll()` or pop-to-root
/// tears editors down in an order the chain can't unwind, and the surviving
/// link then restores a dead shim instead of UIKit's delegate: the swipe stays
/// disabled for the rest of the session with nothing to heal it.
///
/// This replaces the chain with a record. The first shim to arrive stores
/// UIKit's own delegate and the recogniser's original `isEnabled` on the
/// navigation controller itself; claimants after that are tracked as weak
/// references removed *by identity*, so any teardown order lands back on the
/// same recorded original.
@MainActor
private final class InteractivePopGestureAnchor {

    /// Only the address of this is ever read, never the value, so
    /// `nonisolated(unsafe)` is exact rather than a concession.
    private nonisolated(unsafe) static var associationKey: UInt8 = 0

    /// UIKit's delegate, from before the first shim. Weak for the same reason
    /// the shim's own reference was: the navigation controller owns it.
    private(set) weak var systemDelegate: UIGestureRecognizerDelegate?

    /// The recogniser's `isEnabled` from before the first shim forced it true.
    /// `install` used to set `true` unconditionally and `uninstall` put
    /// nothing back, so a stack that had deliberately disabled the swipe had
    /// it switched on permanently by opening an editor once.
    private(set) var systemIsEnabled: Bool

    /// Shims currently installed against this navigation controller, oldest
    /// first. Weak, so a claimant deallocated without an orderly `uninstall`
    /// drops out of the list instead of wedging it.
    private var claimants: [WeakClaimant] = []

    private struct WeakClaimant {
        weak var shim: InteractivePopGestureShim?
    }

    private init(systemDelegate: UIGestureRecognizerDelegate?, systemIsEnabled: Bool) {
        self.systemDelegate = systemDelegate
        self.systemIsEnabled = systemIsEnabled
    }

    /// The anchor for `navigation`, created from the recogniser's current
    /// state on first call. Creation is the only moment the original is still
    /// readable, so it must happen before any delegate swap.
    static func anchor(
        for navigation: UINavigationController,
        gesture: UIGestureRecognizer
    ) -> InteractivePopGestureAnchor {
        if let existing = existing(for: navigation) { return existing }
        let anchor = InteractivePopGestureAnchor(
            systemDelegate: gesture.delegate,
            systemIsEnabled: gesture.isEnabled
        )
        objc_setAssociatedObject(
            navigation,
            &associationKey,
            anchor,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return anchor
    }

    static func existing(
        for navigation: UINavigationController
    ) -> InteractivePopGestureAnchor? {
        objc_getAssociatedObject(navigation, &associationKey)
            as? InteractivePopGestureAnchor
    }

    func claim(_ shim: InteractivePopGestureShim) {
        claimants.removeAll { $0.shim == nil }
        guard !claimants.contains(where: { $0.shim === shim }) else { return }
        claimants.append(WeakClaimant(shim: shim))
    }

    /// Drops `shim` and reports who should hold the recogniser now: the most
    /// recent surviving claimant, or `nil` when the anchor is spent and the
    /// recorded original goes back. Removal is by identity, which is what
    /// makes an out-of-order teardown heal instead of wedge.
    func release(_ shim: InteractivePopGestureShim) -> InteractivePopGestureShim? {
        claimants.removeAll { $0.shim === shim || $0.shim == nil }
        return claimants.last?.shim
    }

    func retire(from navigation: UINavigationController) {
        objc_setAssociatedObject(
            navigation,
            &Self.associationKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}

/// The delegate that answers for the interactive pop while the editor owns the
/// screen. UIKit's stock delegate ties the gesture to a back button it draws;
/// this one ties it to the only thing that actually matters — whether there is
/// a screen underneath to pop back to.
///
/// `@MainActor` because every `UIKit` member it touches is, and the target
/// builds with `SWIFT_STRICT_CONCURRENCY = complete`.
@MainActor
private final class InteractivePopGestureShim: NSObject, UIGestureRecognizerDelegate {

    private weak var navigationController: UINavigationController?
    private var isInstalled = false

    /// Idempotent. Returns without effect until the probe is parented deeply
    /// enough for a navigation controller to resolve.
    func install(from controller: UIViewController) {
        guard !isInstalled,
              let navigation = Self.navigationController(from: controller),
              let gesture = navigation.interactivePopGestureRecognizer
        else { return }

        // Resolved *before* the swap below, so whichever shim gets here first
        // is the one that records UIKit's original delegate and enablement.
        let anchor = InteractivePopGestureAnchor.anchor(for: navigation, gesture: gesture)
        anchor.claim(self)

        navigationController = navigation
        gesture.delegate = self
        gesture.isEnabled = true
        isInstalled = true
    }

    func uninstall() {
        guard isInstalled else { return }
        isInstalled = false

        guard let navigation = navigationController,
              let gesture = navigation.interactivePopGestureRecognizer,
              let anchor = InteractivePopGestureAnchor.existing(for: navigation)
        else { return }

        if let successor = anchor.release(self) {
            // A shallower editor is still on screen and still wants the shim.
            // Hand it the recogniser rather than restoring anything.
            gesture.delegate = successor
            return
        }

        // Last one out. Both halves of the original state go back — the
        // delegate (ASH 6) and the enablement `install` forced (ASH 5) —
        // whatever order the editors tore down in.
        gesture.delegate = anchor.systemDelegate
        gesture.isEnabled = anchor.systemIsEnabled
        anchor.retire(from: navigation)
        navigationController = nil
    }

    // MARK: UIGestureRecognizerDelegate

    /// The root-screen guard, and the reason this shim is safe. A pop begun
    /// with nothing under the top view controller starts a transition that can
    /// never complete and wedges the stack — the classic frozen-UI bug that
    /// blanket `delegate = nil` shims ship with. Depth is the whole test; the
    /// in-flight check keeps a second swipe off a transition already running.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigation = navigationController else { return false }
        return navigation.viewControllers.count > 1
            && navigation.transitionCoordinator == nil
    }

    /// The editor's timeline is a horizontal scroller. Refusing simultaneous
    /// recognition keeps an edge drag from scrubbing the timeline while it
    /// pops — stock navigation-controller behaviour, restated because we now
    /// own the delegate that used to state it.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }

    // MARK: Resolution

    /// `navigationController` first (the ordinary case), then the responder
    /// chain: SwiftUI is free to host a `.background` representable in a
    /// container that isn't itself a direct child of the pushed controller.
    private static func navigationController(
        from controller: UIViewController
    ) -> UINavigationController? {
        if let navigation = controller.navigationController { return navigation }

        var responder: UIResponder? = controller.view
        while let current = responder {
            if let navigation = current as? UINavigationController { return navigation }
            if let viewController = current as? UIViewController,
               let navigation = viewController.navigationController {
                return navigation
            }
            responder = current.next
        }
        return nil
    }
}
#endif
