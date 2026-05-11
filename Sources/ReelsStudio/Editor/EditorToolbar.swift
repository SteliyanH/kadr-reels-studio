import SwiftUI
import Kadr

/// Two-tier bottom toolbar — selection-driven swap. CapCut / VN pattern: the
/// row above the timeline shows root verbs (`+ Clip` / `+ Overlay` / etc.) when
/// nothing's selected, swaps to clip-action verbs when a clip is selected,
/// and to overlay-action verbs when an overlay is selected.
///
/// v0.4 Tier 1a ships the state machine + Duplicate / Delete / Speed / Bring-
/// forward / Send-back actions. Split + Filters land in Tier 1b — the clip
/// row reserves their slots but renders them disabled until that PR.
struct EditorToolbar: View {

    @ObservedObject var store: ProjectStore
    @EnvironmentObject private var toasts: ToastCenter

    // Root-row callbacks — owned by `EditorView` so it can present sheets.
    var onAddClip: () -> Void
    var onAddOverlay: () -> Void
    var onLayers: () -> Void
    var onAddMusic: () -> Void
    var onAddSFX: () -> Void
    var onAddCaptions: () -> Void
    var onExport: () -> Void

    // Clip-row callbacks that need a sheet — also owned by the editor.
    var onSpeedCurve: (ClipID) -> Void
    var onFilters: (ClipID) -> Void = { _ in }

    private enum Mode: Equatable { case root, clip(ClipID), overlay(LayerID), multiSelect }

    private var mode: Mode {
        // Multi-select wins over everything — it's a transient mode the user
        // explicitly entered via long-press, so we don't fall back to the
        // single-select rows while it's active.
        if store.isMultiSelecting { return .multiSelect }
        if let id = store.selectedOverlayID { return .overlay(id) }
        if let id = store.selectedClipID { return .clip(id) }
        return .root
    }

    var body: some View {
        Group {
            switch mode {
            case .root:
                rootRow
                    .transition(.opacity)
            case .clip(let id):
                clipRow(id: id)
                    .transition(.opacity)
            case .overlay(let id):
                overlayRow(id: id)
                    .transition(.opacity)
            case .multiSelect:
                multiSelectRow
                    .transition(.opacity)
            }
        }
        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.78), value: mode)
        .padding(.horizontal)
    }

    // MARK: - Root row

    @ViewBuilder
    private var rootRow: some View {
        HStack(spacing: 12) {
            ToolbarButton(systemImage: "plus.rectangle", label: "Clip", action: onAddClip)
            ToolbarButton(systemImage: "textformat", label: "Overlay", action: onAddOverlay)
            ToolbarButton(systemImage: "square.stack.3d.up", label: "Layers", action: onLayers)
            ToolbarButton(systemImage: "music.note", label: "Music", action: onAddMusic)
            ToolbarButton(systemImage: "speaker.wave.2", label: "SFX", action: onAddSFX)
            ToolbarButton(systemImage: "captions.bubble", label: "Captions", action: onAddCaptions)
            Spacer()
            ToolbarButton(systemImage: "square.and.arrow.up", label: "Export", action: onExport)
        }
    }

    // MARK: - Clip-action row

    @ViewBuilder
    private func clipRow(id: ClipID) -> some View {
        HStack(spacing: 12) {
            ToolbarButton(
                systemImage: "scissors",
                label: "Split",
                hint: "Splits the clip at the playhead"
            ) {
                let result = store.splitClip(id: id, at: store.currentTime)
                if result != .ok {
                    toasts.show(.transient(message: "Can't split", detail: EditorToolbar.splitFailureDetail(result)))
                }
            }
            ToolbarButton(
                systemImage: "doc.on.doc",
                label: "Duplicate",
                hint: "Inserts a copy of this clip after itself"
            ) {
                store.duplicateClip(id: id)
            }
            ToolbarButton(
                systemImage: "speedometer",
                label: "Speed",
                hint: "Opens the speed curve editor"
            ) {
                onSpeedCurve(id)
            }
            ToolbarButton(
                systemImage: "camera.filters",
                label: "Filters",
                hint: "Opens the filter stack editor"
            ) {
                onFilters(id)
            }
            Spacer()
            ToolbarButton(
                systemImage: "trash",
                label: "Delete",
                role: .destructive,
                hint: "Removes this clip from the project"
            ) {
                HapticEngine.shared.thud()
                store.removeClip(id: id)
            }
        }
    }

    // MARK: - Overlay-action row

    @ViewBuilder
    private func overlayRow(id: LayerID) -> some View {
        HStack(spacing: 12) {
            ToolbarButton(
                systemImage: "doc.on.doc",
                label: "Duplicate",
                hint: "Inserts a copy of this overlay one z-step above"
            ) {
                store.duplicateOverlay(id: id)
            }
            ToolbarButton(
                systemImage: "square.3.stack.3d.top.fill",
                label: "Forward",
                hint: "Brings this overlay one step toward the front"
            ) {
                store.moveOverlay(id: id, by: 1)
            }
            ToolbarButton(
                systemImage: "square.3.stack.3d.bottom.fill",
                label: "Back",
                hint: "Sends this overlay one step toward the back"
            ) {
                store.moveOverlay(id: id, by: -1)
            }
            Spacer()
            ToolbarButton(
                systemImage: "trash",
                label: "Delete",
                role: .destructive,
                hint: "Removes this overlay from the project"
            ) {
                HapticEngine.shared.thud()
                store.removeOverlay(id: id)
            }
        }
    }

    // MARK: - Multi-select row

    @ViewBuilder
    private var multiSelectRow: some View {
        HStack(spacing: 12) {
            ToolbarButton(
                systemImage: "xmark",
                label: "Cancel",
                hint: "Exits multi-select mode without wrapping"
            ) {
                store.isMultiSelecting = false
            }
            Text("\(store.selectedClipIDs.count) selected")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
                .accessibilityLabel("Selection")
                .accessibilityValue("\(store.selectedClipIDs.count) clips selected")
            Spacer()
            ToolbarButton(
                systemImage: "rectangle.stack",
                label: "Wrap",
                hint: "Wraps the selected clips in a track"
            ) {
                let result = store.wrapInTrack(ids: store.selectedClipIDs)
                if result != .ok {
                    toasts.show(
                        .transient(
                            message: "Can't wrap",
                            detail: EditorToolbar.wrapFailureDetail(result)
                        )
                    )
                }
            }
            .disabled(store.selectedClipIDs.isEmpty)
        }
    }
}

extension EditorToolbar {
    /// User-facing detail for each `splitClip` failure mode.
    static func splitFailureDetail(_ result: ProjectStore.SplitResult) -> String {
        switch result {
        case .ok: return ""
        case .clipNotFound: return "The selected clip is no longer in the project."
        case .clipInsideTrack: return "Clips inside a track aren't splittable yet."
        case .offsetOutOfRange: return "Move the playhead inside the clip and try again."
        case .unsupportedSpeedRate: return "Clear the speed rate before splitting."
        }
    }

    /// User-facing detail for each `wrapInTrack` failure mode.
    static func wrapFailureDetail(_ result: ProjectStore.WrapInTrackResult) -> String {
        switch result {
        case .ok: return ""
        case .noSelection: return "Long-press a clip to start a selection."
        case .nonContiguous: return "Selection must be contiguous to wrap in a track."
        case .clipsNotAtTopLevel: return "Clips already inside a track can't be re-wrapped."
        }
    }
}

private struct ToolbarButton: View {
    let systemImage: String
    let label: String
    var role: ButtonRole? = nil
    /// Optional VoiceOver hint for non-obvious actions. The label alone is
    /// enough for `+ Clip` or `Export`; non-trivial verbs like `Split` or
    /// `Wrap` ride with a hint so VoiceOver users get the effect, not just
    /// the icon's name. v0.5 Tier 2.
    var hint: String? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(minWidth: 56, minHeight: 44)
        }
        .buttonStyle(.bordered)
        // Default VoiceOver output combines the image's localized name and
        // the text — verbose ("plus rectangle Clip"). Replace it with just
        // the user-facing label so the audio matches the visible text.
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
    }
}
